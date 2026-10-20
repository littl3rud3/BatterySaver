import SwiftUI
import Combine
import IOKit.ps

@MainActor
public final class PowerMonitor: ObservableObject {
    @Published public var adapterWatts: Int = 0
    @Published public var batteryPercent: Int = 0
    @Published public var netBatteryWatts: Double = 0.0
    @Published public var systemLoadWatts: Double = 0.0
    @Published public var averageLoad: Double = 0.0
    @Published public var sustainedLoadWatts: Double = 0.0
    @Published public var loadTrend: LoadTrend = .stable
    @Published public var targetAdapterWatts: Int = 35
    @Published public var candidateAdapterWatts: Int? = nil
    @Published public var candidateDwellRemainingSeconds: Int? = nil
    @Published public var recommendation: String = "Waiting for data..."
    @Published public var barState: BarState = .green
    @Published public var isOverheating: Bool = false
    
    // Telemetry details
    @Published public var batteryVoltage: Double = 0.0
    @Published public var batteryAmperage: Double = 0.0
    @Published public var batteryTemperatureCelsius: Double? = nil
    @Published public var cycleCount: Int? = nil
    @Published public var timeRemainingMinutes: Int? = nil
    @Published public var isCharging: Bool = false
    @Published public var isFullyCharged: Bool = false
    
    public var availableAdapters: [Int] {
        SettingsStore.shared.availableAdapters
    }
    
    public var minBatteryTarget: Int {
        SettingsStore.shared.minBatteryTarget
    }
    
    public var maxBatteryTarget: Int {
        SettingsStore.shared.maxBatteryTarget
    }
    
    private struct PowerSample {
        let timestamp: Date
        let systemLoadWatts: Double
        let netBatteryWatts: Double
    }
    
    private var periodicTimer: Timer?
    private var telemetryTimer: Timer?
    private nonisolated(unsafe) var iopsRunLoopSource: CFRunLoopSource?
    private var cancellables = Set<AnyCancellable>()
    private var powerSamples: [PowerSample] = []
    private var lastConnectedAdapterWatts: Int = -1
    private var connectionGracePeriodUntil: Date = .distantPast
    private var candidateSince: Date? = nil
    
    private let reader = PowerReader()
    private let notificationManager = NotificationManager.shared
    
    public init() {
        notificationManager.requestAuthorization()
        
        // Seed initial values from hardware
        updateMetrics()
        
        // Start power source change listener for instant plug/unplug updates
        setupPowerSourceListener()
        
        // Start continuous lightweight telemetry sampling timer (3s)
        startTelemetryTimer()
        
        // Start periodic check timer at user-configured interval (default 30s)
        restartPeriodicTimer(interval: Double(SettingsStore.shared.checkIntervalSeconds))
        
        // Listen to settings changes
        SettingsStore.shared.$availableAdapters
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.evaluateDynamics()
                self?.evaluateChargerState()
            }
            .store(in: &cancellables)
            
        SettingsStore.shared.$dynamicsPreset
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.evaluateDynamics()
                self?.evaluateChargerState()
            }
            .store(in: &cancellables)
        
        SettingsStore.shared.$minBatteryTarget
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.evaluateChargerState()
            }
            .store(in: &cancellables)
            
        SettingsStore.shared.$maxBatteryTarget
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.evaluateChargerState()
            }
            .store(in: &cancellables)
            
        SettingsStore.shared.$headroomMarginPercent
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.evaluateDynamics()
                self?.evaluateChargerState()
            }
            .store(in: &cancellables)
            
        SettingsStore.shared.$checkIntervalSeconds
            .receive(on: RunLoop.main)
            .sink { [weak self] newInterval in
                self?.restartPeriodicTimer(interval: Double(newInterval))
            }
            .store(in: &cancellables)
            
        SettingsStore.shared.$maxBatteryTemperatureCelsius
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.evaluateChargerState()
            }
            .store(in: &cancellables)
            
        SettingsStore.shared.$temperatureAlertEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.evaluateChargerState()
            }
            .store(in: &cancellables)
    }
    
    deinit {
        periodicTimer?.invalidate()
        telemetryTimer?.invalidate()
        if let source = iopsRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        }
    }
    
    private func startTelemetryTimer() {
        telemetryTimer?.invalidate()
        let t = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.sampleTelemetryTick()
            }
        }
        t.tolerance = 1.0 // Energy efficiency coalescing
        self.telemetryTimer = t
    }
    
    private func restartPeriodicTimer(interval: Double) {
        periodicTimer?.invalidate()
        let intervalClamped = max(5.0, interval)
        periodicTimer = Timer.scheduledTimer(withTimeInterval: intervalClamped, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMetrics()
            }
        }
    }
    
    private func setupPowerSourceListener() {
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        if let source = IOPSNotificationCreateRunLoopSource({ info in
            guard let info = info else { return }
            let monitor = Unmanaged<PowerMonitor>.fromOpaque(info).takeUnretainedValue()
            Task { @MainActor in
                monitor.updateMetrics()
            }
        }, context)?.takeRetainedValue() {
            self.iopsRunLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }
    }
    
    private func sampleTelemetryTick() {
        let metrics = reader.readCurrentMetrics()
        self.systemLoadWatts = metrics.systemLoadWatts
        self.netBatteryWatts = metrics.netBatteryWatts
        self.batteryPercent = metrics.batteryPercentage
        self.batteryVoltage = metrics.batteryVoltage
        self.batteryAmperage = metrics.batteryAmperage
        self.batteryTemperatureCelsius = metrics.batteryTemperatureCelsius
        self.cycleCount = metrics.cycleCount
        self.timeRemainingMinutes = metrics.timeRemainingMinutes
        self.isCharging = metrics.isCharging
        self.isFullyCharged = metrics.isFullyCharged
        
        recordSample(metrics: metrics)
        evaluateDynamics()
        evaluateChargerState()
    }
    
    public func updateMetrics() {
        let metrics = reader.readCurrentMetrics()
        
        self.batteryPercent = metrics.batteryPercentage
        self.batteryVoltage = metrics.batteryVoltage
        self.batteryAmperage = metrics.batteryAmperage
        self.netBatteryWatts = metrics.netBatteryWatts
        self.batteryTemperatureCelsius = metrics.batteryTemperatureCelsius
        self.cycleCount = metrics.cycleCount
        self.timeRemainingMinutes = metrics.timeRemainingMinutes
        self.isCharging = metrics.isCharging
        self.isFullyCharged = metrics.isFullyCharged
        self.systemLoadWatts = metrics.systemLoadWatts
        
        recordSample(metrics: metrics)
        evaluateDynamics()
        evaluateChargerState()
    }
    
    private func recordSample(metrics: PowerMetrics) {
        if metrics.isExternalConnected && metrics.adapterWatts > 0 {
            if lastConnectedAdapterWatts != metrics.adapterWatts {
                lastConnectedAdapterWatts = metrics.adapterWatts
                // Allow a 25-second grace period for USB-PD handshake and current ramp-up
                connectionGracePeriodUntil = Date().addingTimeInterval(25.0)
                powerSamples.removeAll()
                candidateAdapterWatts = nil
                candidateSince = nil
                candidateDwellRemainingSeconds = nil
            }
            self.adapterWatts = metrics.adapterWatts
            powerSamples.append(PowerSample(
                timestamp: Date(),
                systemLoadWatts: metrics.systemLoadWatts,
                netBatteryWatts: metrics.netBatteryWatts
            ))
        } else {
            // On battery
            if lastConnectedAdapterWatts != 0 {
                lastConnectedAdapterWatts = 0
                powerSamples.removeAll()
                candidateAdapterWatts = nil
                candidateSince = nil
                candidateDwellRemainingSeconds = nil
            }
            connectionGracePeriodUntil = .distantPast
            self.adapterWatts = 0
            let batLoad = max(0.0, abs(metrics.netBatteryWatts))
            if self.systemLoadWatts <= 0 {
                self.systemLoadWatts = batLoad
            }
            powerSamples.append(PowerSample(
                timestamp: Date(),
                systemLoadWatts: self.systemLoadWatts,
                netBatteryWatts: metrics.netBatteryWatts
            ))
        }
        
        // Prune samples based on active DynamicsPreset window
        let maxWindowSeconds = SettingsStore.shared.dynamicsPreset.windowSeconds
        powerSamples.removeAll { Date().timeIntervalSince($0.timestamp) > maxWindowSeconds }
    }
    
    // MARK: - Dynamics & Anti-Flicker Engine
    
    public func evaluateDynamics() {
        guard !powerSamples.isEmpty else {
            let initialLoad = systemLoadWatts > 0 ? systemLoadWatts : 15.0
            averageLoad = initialLoad
            sustainedLoadWatts = initialLoad
            loadTrend = .stable
            seedInitialTargetAdapter(for: initialLoad)
            return
        }
        
        // 1. Calculate Average Load across window
        let loads = powerSamples.map(\.systemLoadWatts)
        self.averageLoad = loads.reduce(0.0, +) / Double(loads.count)
        
        // 2. Calculate Sustained Workload (75th percentile of window to ignore transient bursts)
        let sorted = loads.sorted()
        let rank = 0.75 * Double(sorted.count - 1)
        let low = Int(floor(rank))
        let high = Int(ceil(rank))
        if low == high {
            self.sustainedLoadWatts = sorted[low]
        } else {
            let weight = rank - Double(low)
            self.sustainedLoadWatts = sorted[low] * (1.0 - weight) + sorted[high] * weight
        }
        
        // 3. Calculate Workload Trend (Compare older half vs newer half of window)
        if powerSamples.count >= 6 {
            let mid = powerSamples.count / 2
            let oldHalf = powerSamples[0..<mid].map(\.systemLoadWatts)
            let newHalf = powerSamples[mid...].map(\.systemLoadWatts)
            let oldAvg = oldHalf.reduce(0.0, +) / Double(oldHalf.count)
            let newAvg = newHalf.reduce(0.0, +) / Double(newHalf.count)
            let diff = newAvg - oldAvg
            if diff > 3.5 {
                self.loadTrend = .rising
            } else if diff < -3.5 {
                self.loadTrend = .falling
            } else {
                self.loadTrend = .stable
            }
        } else {
            self.loadTrend = .stable
        }
        
        // 4. Determine Ideal Adapter for the sustained workload
        let adapters = availableAdapters.sorted()
        guard !adapters.isEmpty else { return }
        let store = SettingsStore.shared
        
        let idealAdapter = adapters.first(where: { store.maxSafeLoad(for: $0) >= sustainedLoadWatts }) ?? (adapters.last ?? 35)
        
        // Seed initial target if uninitialized or not in available list
        if !adapters.contains(targetAdapterWatts) || targetAdapterWatts == 0 {
            targetAdapterWatts = idealAdapter
            candidateAdapterWatts = nil
            candidateSince = nil
            candidateDwellRemainingSeconds = nil
            return
        }
        
        // 5. Apply Hysteresis & Dwell Time confirmation
        if idealAdapter == targetAdapterWatts {
            // Already matching ideal target -> clear pending candidate
            candidateAdapterWatts = nil
            candidateSince = nil
            candidateDwellRemainingSeconds = nil
        } else {
            let isUpgrade = idealAdapter > targetAdapterWatts
            let preset = store.dynamicsPreset
            let requiredDwell = isUpgrade ? preset.upgradeDwellSeconds : preset.downgradeDwellSeconds
            
            // Fast-track deficit: if plugged in and battery is actively draining (< -1.5W),
            // accelerate upgrade to 15s for safety.
            let effectiveDwell: TimeInterval
            if isUpgrade && adapterWatts > 0 && netBatteryWatts < -1.5 {
                effectiveDwell = min(15.0, requiredDwell)
            } else {
                effectiveDwell = requiredDwell
            }
            
            if candidateAdapterWatts != idealAdapter {
                candidateAdapterWatts = idealAdapter
                candidateSince = Date()
                candidateDwellRemainingSeconds = Int(ceil(effectiveDwell))
            } else if let since = candidateSince {
                let elapsed = Date().timeIntervalSince(since)
                let remaining = max(0.0, effectiveDwell - elapsed)
                candidateDwellRemainingSeconds = Int(ceil(remaining))
                
                if elapsed >= effectiveDwell {
                    // Confirmed by dynamics! Transition to new target adapter
                    targetAdapterWatts = idealAdapter
                    candidateAdapterWatts = nil
                    candidateSince = nil
                    candidateDwellRemainingSeconds = nil
                }
            }
        }
    }
    
    private func seedInitialTargetAdapter(for load: Double) {
        let adapters = availableAdapters.sorted()
        guard !adapters.isEmpty else { return }
        let store = SettingsStore.shared
        targetAdapterWatts = adapters.first(where: { store.maxSafeLoad(for: $0) >= load }) ?? (adapters.last ?? 35)
    }
    
    // MARK: - Charger State & Recommendation Evaluation
    
    public func evaluateChargerState() {
        let store = SettingsStore.shared
        let adapters = availableAdapters.sorted()
        
        // 0. BATTERY OVERHEATING SAFETY CHECK (Red 🔴 Alert)
        let threshold = Double(store.maxBatteryTemperatureCelsius)
        let shouldTriggerOverheat: Bool = {
            guard store.temperatureAlertEnabled, let temp = batteryTemperatureCelsius else {
                return false
            }
            if isOverheating {
                // Hysteresis: cool down by at least 1.0°C below limit to clear alert
                return temp >= (threshold - 1.0)
            } else {
                return temp >= threshold
            }
        }()
        
        if shouldTriggerOverheat, let temp = batteryTemperatureCelsius {
            isOverheating = true
            barState = .red
            recommendation = String(
                format: "Overheating! Battery is %.1f°C (exceeds %d°C limit). Cool down your Mac",
                temp,
                store.maxBatteryTemperatureCelsius
            )
            
            if store.notificationsEnabled {
                notificationManager.sendNotification(
                    title: String(format: "Battery Overheating: %.1f°C 🔴", temp),
                    body: String(
                        format: "Battery temperature exceeded the safety limit of %d°C. Disconnect fast charger or reduce workload to prevent battery damage.",
                        store.maxBatteryTemperatureCelsius
                    ),
                    eventKey: "battery_overheating",
                    cooldownSeconds: Double(store.cooldownMinutes * 60)
                )
            }
            return
        } else {
            isOverheating = false
        }
        
        // A. ON BATTERY
        guard adapterWatts > 0 else {
            let target = targetAdapterWatts
            if batteryPercent <= minBatteryTarget + 1 {
                barState = .orange
                recommendation = "Battery at \(batteryPercent)%! Connect \(target)W adapter"
                if store.notificationsEnabled {
                    notificationManager.sendNotification(
                        title: "Battery reached \(batteryPercent)% 🟠",
                        body: "Time to connect the power adapter (\(target)W).",
                        eventKey: "low_battery_\(minBatteryTarget)",
                        cooldownSeconds: Double(store.cooldownMinutes * 60)
                    )
                }
            } else {
                barState = .green
                recommendation = "On Battery (\(target)W adapter)"
            }
            return
        }
        
        // B. TARGET BATTERY LEVEL REACHED (e.g. 80%) — Prompt Unplug
        if batteryPercent >= maxBatteryTarget {
            barState = .orange
            recommendation = "Battery at \(batteryPercent)%! Unplug charger"
            
            if store.notificationsEnabled {
                notificationManager.sendNotification(
                    title: "Battery reached \(batteryPercent)% 🟠",
                    body: "Time to disconnect the power adapter.",
                    eventKey: "unplug_\(maxBatteryTarget)",
                    cooldownSeconds: Double(store.cooldownMinutes * 60)
                )
            }
            return
        }
        
        // C. USB-PD CONNECTION GRACE PERIOD
        if Date() < connectionGracePeriodUntil {
            barState = .green
            let remainingSecs = max(1, Int(connectionGracePeriodUntil.timeIntervalSinceNow))
            recommendation = "Charger connected (\(adapterWatts)W). Stabilizing (\(remainingSecs)s)..."
            return
        }
        
        // D. Wait for sufficient telemetry samples
        guard powerSamples.count >= 2 else {
            barState = .green
            recommendation = "Analyzing workload dynamics..."
            return
        }
        
        let avgBatteryFlow = powerSamples.map(\.netBatteryWatts).reduce(0.0, +) / Double(powerSamples.count)
        
        // E. RED (DEFICIT): Discharging while plugged in (< -1.0W)
        if avgBatteryFlow < -1.0 {
            barState = .red
            let higherAdapters = adapters.filter { $0 > adapterWatts }
            
            if let target = higherAdapters.first(where: { store.maxSafeLoad(for: $0) >= sustainedLoadWatts }) ?? higherAdapters.last {
                recommendation = "Discharging! Switch to \(target)W adapter"
                if store.notificationsEnabled {
                    notificationManager.sendNotification(
                        title: "Switch to \(target)W adapter 🔴",
                        body: String(format: "Mac is drawing %.0fW sustained and discharging on %dW adapter.", sustainedLoadWatts, adapterWatts),
                        eventKey: "upgrade_to_\(target)",
                        cooldownSeconds: Double(store.cooldownMinutes * 60)
                    )
                }
            } else {
                recommendation = "Overload! Load exceeds available adapters"
            }
            return
        }
        
        // F. RED (EXCESS): Current adapter is significantly larger than what confirmed dynamics require
        let smallerAdapters = adapters.filter { $0 < adapterWatts }
        if !smallerAdapters.isEmpty && targetAdapterWatts < adapterWatts {
            let chargingFlow = max(0.0, avgBatteryFlow)
            let totalRequired = sustainedLoadWatts + chargingFlow
            
            // Require confirmed target adapter to safely accommodate workload + charging
            if store.maxSafeLoad(for: targetAdapterWatts) - 2.5 >= totalRequired {
                barState = .red
                recommendation = "Excess power! Switch to \(targetAdapterWatts)W adapter"
                if store.notificationsEnabled {
                    notificationManager.sendNotification(
                        title: "Switch to \(targetAdapterWatts)W adapter 🔴",
                        body: String(format: "Mac sustained load is only %.0fW. The %dW adapter is excess; switch to %dW.", sustainedLoadWatts, adapterWatts, targetAdapterWatts),
                        eventKey: "downgrade_to_\(targetAdapterWatts)",
                        cooldownSeconds: Double(store.cooldownMinutes * 60)
                    )
                }
                return
            }
        }
        
        // G. GREEN: Optimal adapter match
        barState = .green
        recommendation = "Optimal (\(adapterWatts)W adapter is well matched)"
    }
}
