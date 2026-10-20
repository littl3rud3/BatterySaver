import SwiftUI
import Combine

/// Display format options for the macOS Menu Bar item
public enum MenuBarStyle: String, CaseIterable, Identifiable {
    /// 18W / 35W on power, 35W on battery
    case smart = "smart"
    /// 18W / 35W on power, 18W | 35W on battery
    case full = "full"
    /// 18W (live hardware power consumption)
    case loadOnly = "loadOnly"
    /// 35W on power, 35W on battery
    case adapterOnly = "adapterOnly"
    /// 78% (battery percentage)
    case batteryPercent = "batteryPercent"
    /// 31.0°C (battery temperature)
    case temperature = "temperature"
    /// 78% • 31°C (battery percentage and temperature)
    case batteryAndTemp = "batteryAndTemp"
    /// Colored status dot only (no text)
    case dotOnly = "dotOnly"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .smart:
            return "Smart (18W / 35W on power, 35W on battery)"
        case .full:
            return "Full (18W / 35W on power, 18W | 35W on battery)"
        case .loadOnly:
            return "Mac Consumption only (18W)"
        case .adapterOnly:
            return "Adapter only (35W on power, 35W on battery)"
        case .batteryPercent:
            return "Battery Percentage (78%)"
        case .temperature:
            return "Battery Temperature (31.0°C)"
        case .batteryAndTemp:
            return "Battery % & Temperature (78% • 31°C)"
        case .dotOnly:
            return "App Icon only (No text)"
        }
    }
    
    public var descriptionText: String {
        switch self {
        case .smart:
            return "Shows consumption and adapter on power; shows target adapter rating on battery."
        case .full:
            return "Shows both current power draw and connected/target adapter in all states."
        case .loadOnly:
            return "Always displays real-time Mac hardware power draw in Watts."
        case .adapterOnly:
            return "Displays connected charger rating or target charger wattage."
        case .batteryPercent:
            return "Displays the current battery charge percentage."
        case .temperature:
            return "Displays the real-time battery temperature in Celsius."
        case .batteryAndTemp:
            return "Displays both battery charge percentage and current temperature."
        case .dotOnly:
            return "Minimalist: only shows the colored app icon without text."
        }
    }
    
    public func preview(loadWatts: Int = 18, adapterWatts: Int = 35, targetWatts: Int = 35, batteryPct: Int = 78, tempCelsius: Double = 31.0) -> (power: String, battery: String) {
        switch self {
        case .smart:
            return ("\(loadWatts)W / \(adapterWatts)W", "\(targetWatts)W")
        case .full:
            return ("\(loadWatts)W / \(adapterWatts)W", "\(loadWatts)W | \(targetWatts)W")
        case .loadOnly:
            return ("\(loadWatts)W", "\(loadWatts)W")
        case .adapterOnly:
            return ("\(adapterWatts)W", "\(targetWatts)W")
        case .batteryPercent:
            return ("\(batteryPct)%", "\(batteryPct)%")
        case .temperature:
            let tempStr = String(format: "%.1f°C", tempCelsius)
            return (tempStr, tempStr)
        case .batteryAndTemp:
            let combo = String(format: "%d%% • %.0f°C", batteryPct, tempCelsius)
            return (combo, combo)
        case .dotOnly:
            return ("(dot only)", "(dot only)")
        }
    }
}

/// Icon style options for the macOS Menu Bar item
public enum MenuBarIconType: String, CaseIterable, Identifiable {
    /// Lightning bolt (bolt.fill)
    case bolt = "bolt"
    /// Battery with bolt (bolt.batteryblock.fill)
    case battery = "battery"
    /// Minimalist status dot (circle.fill)
    case dot = "dot"
    
    public var id: String { rawValue }
    
    public var symbolName: String {
        switch self {
        case .bolt: return "bolt.fill"
        case .battery: return "bolt.batteryblock.fill"
        case .dot: return "circle.fill"
        }
    }
    
    public var title: String {
        switch self {
        case .bolt: return "Lightning Bolt (Recommended)"
        case .battery: return "Battery with Bolt"
        case .dot: return "Status Dot"
        }
    }
    
    public var descriptionText: String {
        switch self {
        case .bolt: return "Energetic lightning bolt tinted in the current power state color."
        case .battery: return "Battery glyph showing active power state color."
        case .dot: return "Subtle minimalist circular status dot."
        }
    }
}

@MainActor
public final class SettingsStore: ObservableObject {
    public static let shared = SettingsStore()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let availableAdapters = "BatterySaver_availableAdapters"
        static let minBatteryTarget = "BatterySaver_minBatteryTarget"
        static let maxBatteryTarget = "BatterySaver_maxBatteryTarget"
        static let cooldownMinutes = "BatterySaver_cooldownMinutes"
        static let notificationsEnabled = "BatterySaver_notificationsEnabled"
        static let launchAtLogin = "BatterySaver_launchAtLogin"
        static let menuBarStyle = "BatterySaver_menuBarStyle"
        static let menuBarIconType = "BatterySaver_menuBarIconType"
        static let headroomMarginPercent = "BatterySaver_headroomMarginPercent"
        static let checkIntervalSeconds = "BatterySaver_checkIntervalSeconds"
        static let dynamicsPreset = "BatterySaver_dynamicsPreset"
        static let maxBatteryTemperatureCelsius = "BatterySaver_maxBatteryTemperatureCelsius"
        static let temperatureAlertEnabled = "BatterySaver_temperatureAlertEnabled"
    }
    
    @Published public var availableAdapters: [Int] {
        didSet {
            defaults.set(availableAdapters.sorted(), forKey: Keys.availableAdapters)
        }
    }
    
    @Published public var minBatteryTarget: Int {
        didSet {
            defaults.set(minBatteryTarget, forKey: Keys.minBatteryTarget)
        }
    }
    
    @Published public var maxBatteryTarget: Int {
        didSet {
            defaults.set(maxBatteryTarget, forKey: Keys.maxBatteryTarget)
        }
    }
    
    @Published public var cooldownMinutes: Int {
        didSet {
            defaults.set(cooldownMinutes, forKey: Keys.cooldownMinutes)
        }
    }
    
    @Published public var notificationsEnabled: Bool {
        didSet {
            defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled)
        }
    }
    
    @Published public var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            LaunchAtLoginHelper.setEnabled(launchAtLogin)
        }
    }
    
    @Published public var menuBarStyle: MenuBarStyle {
        didSet {
            defaults.set(menuBarStyle.rawValue, forKey: Keys.menuBarStyle)
        }
    }
    
    /// Visual icon style displayed in the menu bar item
    @Published public var menuBarIconType: MenuBarIconType {
        didSet {
            defaults.set(menuBarIconType.rawValue, forKey: Keys.menuBarIconType)
        }
    }
    
    /// Headroom safety margin percentage (default 16%, min 6W headroom).
    /// Prevents adapters from running at 100% capacity and leaves power for charging & spikes.
    @Published public var headroomMarginPercent: Int {
        didSet {
            defaults.set(headroomMarginPercent, forKey: Keys.headroomMarginPercent)
        }
    }
    
    /// Polling check interval in seconds (default 30s).
    /// Reduces CPU wakeups and avoids checking too frequently.
    @Published public var checkIntervalSeconds: Int {
        didSet {
            defaults.set(checkIntervalSeconds, forKey: Keys.checkIntervalSeconds)
        }
    }
    
    /// Dynamics and anti-flicker smoothing preset (default: .balanced)
    @Published public var dynamicsPreset: DynamicsPreset {
        didSet {
            defaults.set(dynamicsPreset.rawValue, forKey: Keys.dynamicsPreset)
        }
    }
    
    /// Overheating threshold in Celsius (default 40°C).
    /// When exceeded, the indicator turns red and a high-priority warning notification is triggered.
    @Published public var maxBatteryTemperatureCelsius: Int {
        didSet {
            defaults.set(maxBatteryTemperatureCelsius, forKey: Keys.maxBatteryTemperatureCelsius)
        }
    }
    
    /// Whether high temperature alerts and red indicator are enabled
    @Published public var temperatureAlertEnabled: Bool {
        didSet {
            defaults.set(temperatureAlertEnabled, forKey: Keys.temperatureAlertEnabled)
        }
    }
    
    public var smallestAdapter: Int {
        availableAdapters.min() ?? 35
    }
    
    public var largestAdapter: Int {
        availableAdapters.max() ?? 65
    }
    
    private init() {
        let storedAdapters = defaults.array(forKey: Keys.availableAdapters) as? [Int]
        self.availableAdapters = (storedAdapters ?? [35, 45, 65]).sorted()
        
        let storedMin = defaults.integer(forKey: Keys.minBatteryTarget)
        self.minBatteryTarget = storedMin > 0 ? storedMin : 20
        
        let storedMax = defaults.integer(forKey: Keys.maxBatteryTarget)
        self.maxBatteryTarget = storedMax > 0 ? storedMax : 80
        
        let storedCooldown = defaults.integer(forKey: Keys.cooldownMinutes)
        self.cooldownMinutes = storedCooldown > 0 ? storedCooldown : 10
        
        if defaults.object(forKey: Keys.notificationsEnabled) != nil {
            self.notificationsEnabled = defaults.bool(forKey: Keys.notificationsEnabled)
        } else {
            self.notificationsEnabled = true
        }
        
        if let storedStyle = defaults.string(forKey: Keys.menuBarStyle),
           let style = MenuBarStyle(rawValue: storedStyle) {
            self.menuBarStyle = style
        } else {
            self.menuBarStyle = .smart
        }
        
        if let storedIcon = defaults.string(forKey: Keys.menuBarIconType),
           let iconType = MenuBarIconType(rawValue: storedIcon) {
            self.menuBarIconType = iconType
        } else {
            self.menuBarIconType = .bolt
        }
        
        let storedHeadroom = defaults.integer(forKey: Keys.headroomMarginPercent)
        self.headroomMarginPercent = storedHeadroom > 0 ? storedHeadroom : 16
        
        let storedCheckInterval = defaults.integer(forKey: Keys.checkIntervalSeconds)
        self.checkIntervalSeconds = storedCheckInterval > 0 ? storedCheckInterval : 30
        
        if let storedDynamics = defaults.string(forKey: Keys.dynamicsPreset),
           let preset = DynamicsPreset(rawValue: storedDynamics) {
            self.dynamicsPreset = preset
        } else {
            self.dynamicsPreset = .balanced
        }
        
        let storedTempLimit = defaults.integer(forKey: Keys.maxBatteryTemperatureCelsius)
        self.maxBatteryTemperatureCelsius = storedTempLimit > 0 ? storedTempLimit : 40
        
        if defaults.object(forKey: Keys.temperatureAlertEnabled) != nil {
            self.temperatureAlertEnabled = defaults.bool(forKey: Keys.temperatureAlertEnabled)
        } else {
            self.temperatureAlertEnabled = true
        }
        
        self.launchAtLogin = LaunchAtLoginHelper.isEnabled
    }
    
    /// Calculate required headroom in watts for a given adapter capacity.
    /// At least 6W, and defaults to 16% (e.g. 7.2W on 45W, 10.4W on 65W).
    public func requiredHeadroom(for adapterWatts: Int) -> Double {
        let percentHeadroom = Double(adapterWatts) * (Double(headroomMarginPercent) / 100.0)
        return max(6.0, percentHeadroom)
    }
    
    /// Maximum safe sustained workload an adapter can support while leaving healthy headroom.
    /// For example with default 16%:
    /// - 35W: max 29.0W (6.0W reserve)
    /// - 45W: max 37.8W (7.2W reserve -> 37W recommends 45W, 44W recommends 65W!)
    /// - 65W: max 54.6W (10.4W reserve -> 44W recommends 65W)
    public func maxSafeLoad(for adapterWatts: Int) -> Double {
        return Double(adapterWatts) - requiredHeadroom(for: adapterWatts)
    }
    
    public func addAdapter(_ watts: Int) {
        guard watts > 0, !availableAdapters.contains(watts) else { return }
        var list = availableAdapters
        list.append(watts)
        availableAdapters = list.sorted()
    }
    
    public func removeAdapter(_ watts: Int) {
        guard availableAdapters.count > 1 else { return }
        var list = availableAdapters
        list.removeAll { $0 == watts }
        availableAdapters = list.sorted()
    }
    
    public func resetToDefaults() {
        availableAdapters = [35, 45, 65]
        minBatteryTarget = 20
        maxBatteryTarget = 80
        cooldownMinutes = 10
        notificationsEnabled = true
        menuBarStyle = .smart
        menuBarIconType = .bolt
        headroomMarginPercent = 16
        checkIntervalSeconds = 30
        dynamicsPreset = .balanced
        maxBatteryTemperatureCelsius = 40
        temperatureAlertEnabled = true
    }
}
