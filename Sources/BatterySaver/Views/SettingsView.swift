import SwiftUI
import Combine

public struct SettingsView: View {
    @ObservedObject var settings = SettingsStore.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var customWattsInput: String = ""
    @FocusState private var isCustomWattsFocused: Bool
    @State private var liveTempCelsius: Double? = nil
    private let reader = PowerReader()
    private let timer = Timer.publish(every: 3.0, on: .main, in: .common).autoconnect()
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "bolt.batteryblock.fill")
                    .foregroundColor(.accentColor)
                    .font(.title2)
                Text("BatterySaver Settings")
                    .font(.title3)
                    .bold()
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // MARK: - Menu Bar Display Format (New Setting)
                    menuBarDisplaySection
                    
                    Divider()
                    
                    // MARK: - Available Adapters Management
                    adaptersSection
                    
                    Divider()
                    
                    // MARK: - Workload Dynamics & Anti-Flicker
                    dynamicsSection
                    
                    Divider()
                    
                    // MARK: - Power Headroom Reserve
                    headroomReserveSection
                    
                    Divider()
                    
                    // MARK: - Cycle Boundaries (20% – 80%)
                    cycleTargetsSection
                    
                    Divider()
                    
                    // MARK: - Battery Temperature & Thermal Protection (Red 🔴 Alert)
                    temperatureSection
                    
                    Divider()
                    
                    // MARK: - Notifications
                    notificationsSection
                    
                    Divider()
                    
                    // MARK: - System
                    systemSection
                }
                .padding(.vertical, 4)
            }
            
            Divider()
            
            HStack {
                Button("Reset to Defaults") {
                    settings.resetToDefaults()
                }
                .foregroundColor(.secondary)
                .buttonStyle(.plain)
                .font(.caption)
                
                Spacer()
                
                Text("\(settings.availableAdapters.count) adapters configured")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            refreshLiveTemperature()
        }
        .onReceive(timer) { _ in
            refreshLiveTemperature()
        }
    }
    
    private func refreshLiveTemperature() {
        liveTempCelsius = reader.readCurrentMetrics().batteryTemperatureCelsius
    }
    
    // MARK: - Menu Bar Display Section
    
    private var menuBarDisplaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Menu Bar Display Format")
                .font(.headline)
            
            Text("Choose what information is displayed in your macOS menu bar:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(MenuBarStyle.allCases) { style in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: settings.menuBarStyle == style ? "largecircle.fill.circle" : "circle")
                            .foregroundColor(settings.menuBarStyle == style ? .accentColor : .secondary)
                            .padding(.top, 2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(style.title)
                                .font(.subheadline)
                                .bold(settings.menuBarStyle == style)
                            
                            Text(style.descriptionText)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        settings.menuBarStyle = style
                    }
                    .padding(6)
                    .background(settings.menuBarStyle == style ? Color.accentColor.opacity(0.08) : Color.clear)
                    .cornerRadius(6)
                }
            }
            
            // App Icon Picker
            VStack(alignment: .leading, spacing: 6) {
                Text("App Icon in Menu Bar:")
                    .font(.subheadline)
                    .bold()
                
                Picker("", selection: $settings.menuBarIconType) {
                    ForEach(MenuBarIconType.allCases) { type in
                        Label(type.title, systemImage: type.symbolName)
                            .tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.vertical, 4)
            
            // Live Preview Card
            let previews = settings.menuBarStyle.preview(tempCelsius: liveTempCelsius ?? 31.0)
            VStack(alignment: .leading, spacing: 5) {
                Text("Live Preview:")
                    .font(.caption)
                    .bold()
                
                HStack(spacing: 20) {
                    HStack(spacing: 5) {
                        Image(systemName: settings.menuBarIconType.symbolName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.green)
                        Text("On Power:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(previews.power)
                            .font(.system(.caption, design: .monospaced))
                            .bold()
                    }
                    
                    HStack(spacing: 5) {
                        Image(systemName: settings.menuBarIconType.symbolName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.green)
                        Text("On Battery:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(previews.battery)
                            .font(.system(.caption, design: .monospaced))
                            .bold()
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Adapters Management Section
    
    private var adaptersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("My Power Adapters (Adaptive Rotation)")
                    .font(.headline)
                Spacer()
                Text("Active: \(settings.availableAdapters.map { "\($0)W" }.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("Add or remove the chargers you own. BatterySaver dynamically monitors real-time system power and guides switching only between your configured chargers.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Current Adapter Badges
            FlowLayout(spacing: 8) {
                ForEach(settings.availableAdapters, id: \.self) { watts in
                    HStack(spacing: 6) {
                        Image(systemName: "powerplug.fill")
                            .font(.caption2)
                            .foregroundColor(.accentColor)
                        
                        Text("\(watts)W")
                            .font(.system(.subheadline, design: .rounded))
                            .bold()
                        
                        if settings.availableAdapters.count > 1 {
                            Button {
                                settings.removeAdapter(watts)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Remove \(watts)W adapter")
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.12))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            
            // Add Custom Adapter Field
            HStack(spacing: 8) {
                TextField("Custom Watts (e.g. 70)", text: $customWattsInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 170)
                    .focused($isCustomWattsFocused)
                    .onSubmit {
                        addCustomAdapter()
                    }
                
                Button("Add") {
                    addCustomAdapter()
                }
                .disabled(Int(customWattsInput) == nil)
                
                Spacer()
            }
            .padding(.top, 2)
            
            // Popular Presets Quick-Add
            VStack(alignment: .leading, spacing: 5) {
                Text("Quick Add:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                FlowLayout(spacing: 6) {
                    ForEach([20, 30, 35, 45, 60, 65, 67, 70, 96, 100, 140], id: \.self) { preset in
                        if !settings.availableAdapters.contains(preset) {
                            Button("+\(preset)W") {
                                settings.addAdapter(preset)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                    }
                }
            }
            
            // Live Adaptive Behavior Summary
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("How BatterySaver adapts to your list:")
                        .font(.caption)
                        .bold()
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("• **Low Battery:** Suggests connecting your smallest adapter (**\(settings.smallestAdapter)W**).")
                    if settings.availableAdapters.count > 1 {
                        Text("• **Power Deficit:** If battery discharges while charging, prompts upgrading to next higher adapter (up to **\(settings.largestAdapter)W**).")
                        Text("• **Excess Power:** If Mac load fits into a smaller adapter with comfortable reserve, prompts switching to save heat and wear.")
                    } else {
                        Text("• Single adapter configured (**\(settings.smallestAdapter)W**). No excess prompts will be triggered since you have no smaller chargers.")
                    }
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            .padding(10)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Workload Dynamics & Anti-Flicker Section
    
    private var dynamicsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Workload Dynamics & Anti-Flicker")
                    .font(.headline)
                Spacer()
                Text(settings.dynamicsPreset.title)
                    .font(.caption)
                    .bold()
                    .foregroundColor(.accentColor)
            }
            
            Text("Measures power trends dynamically over a rolling time window instead of reacting instantly. Prevents switching advice back and forth (e.g. 35W → 45W → 65W) during brief CPU spikes.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Picker("Dynamics Profile:", selection: $settings.dynamicsPreset) {
                ForEach(DynamicsPreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            
            // Dynamics profile info card
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("Smoothing Profile Details:")
                        .font(.caption)
                        .bold()
                }
                
                Text(settings.dynamicsPreset.descriptionText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Divider()
                
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Window:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.0fs", settings.dynamicsPreset.windowSeconds))
                            .font(.system(.caption, design: .monospaced))
                            .bold()
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Upgrade Hold (35W -> 45W):")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.0fs", settings.dynamicsPreset.upgradeDwellSeconds))
                            .font(.system(.caption, design: .monospaced))
                            .bold()
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Downgrade Hold (45W -> 35W):")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.0fs", settings.dynamicsPreset.downgradeDwellSeconds))
                            .font(.system(.caption, design: .monospaced))
                            .bold()
                    }
                }
            }
            .padding(10)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Power Headroom Reserve Section
    
    private var headroomReserveSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Power Headroom Reserve (Safety Margin)")
                    .font(.headline)
                Spacer()
                Text("\(settings.headroomMarginPercent)% reserve")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.accentColor)
            }
            
            Text("Ensures power adapters are never pushed to 100% capacity. Leaves headroom for battery charging, peripherals, and transient spikes (e.g. 37W uses 45W, while 44W recommends 65W).")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Picker("Reserve Headroom:", selection: $settings.headroomMarginPercent) {
                Text("12% (Tight)").tag(12)
                Text("16% (Balanced)").tag(16)
                Text("20% (Conservative)").tag(20)
                Text("25% (High Headroom)").tag(25)
            }
            .pickerStyle(.segmented)
            
            // Dynamic capacity table for configured adapters
            VStack(alignment: .leading, spacing: 6) {
                Text("Adapter Safe Operating Limits with current margin:")
                    .font(.caption2)
                    .bold()
                    .foregroundColor(.secondary)
                
                ForEach(settings.availableAdapters, id: \.self) { watts in
                    let maxLoad = settings.maxSafeLoad(for: watts)
                    let headroom = settings.requiredHeadroom(for: watts)
                    HStack {
                        Text("\(watts)W Adapter:")
                            .font(.system(.caption, design: .monospaced))
                            .bold()
                        Spacer()
                        Text(String(format: "Up to %.1fW load", maxLoad))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.primary)
                        Text(String(format: "(%.1fW reserve)", headroom))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(10)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(8)
        }
    }
    
    private func addCustomAdapter() {
        if let val = Int(customWattsInput), val > 0 {
            settings.addAdapter(val)
            customWattsInput = ""
            isCustomWattsFocused = false
        }
    }
    
    // MARK: - Cycle Targets Section
    
    private var cycleTargetsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Charge Cycle Boundaries (Orange 🟠 Status)")
                .font(.headline)
            
            Text("The indicator turns orange and sends an alert when reaching these cycle thresholds:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Minimum (plug in):")
                        .font(.caption)
                    Picker("", selection: $settings.minBatteryTarget) {
                        Text("15%").tag(15)
                        Text("20% (Recommended)").tag(20)
                        Text("25%").tag(25)
                        Text("30%").tag(30)
                    }
                    .frame(width: 180)
                }
                
                VStack(alignment: .leading) {
                    Text("Maximum (unplug):")
                        .font(.caption)
                    Picker("", selection: $settings.maxBatteryTarget) {
                        Text("60%").tag(60)
                        Text("70%").tag(70)
                        Text("80% (Recommended)").tag(80)
                        Text("90%").tag(90)
                    }
                    .frame(width: 180)
                }
            }
        }
    }
    
    // MARK: - Battery Temperature & Overheat Protection Section
    
    private var temperatureSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "thermometer.sun.fill")
                        .foregroundColor(.red)
                    Text("Battery Temperature & Thermal Protection (Red 🔴 Alert)")
                        .font(.headline)
                }
                Spacer()
                if let temp = liveTempCelsius {
                    let threshold = Double(settings.maxBatteryTemperatureCelsius)
                    let badgeColor: Color = temp >= threshold ? .red : (temp >= threshold - 3.0 ? .orange : .green)
                    HStack(spacing: 5) {
                        Circle()
                            .fill(badgeColor)
                            .frame(width: 7, height: 7)
                        Text(String(format: "Live: %.1f°C", temp))
                            .font(.system(.caption, design: .monospaced))
                            .bold()
                            .foregroundColor(badgeColor)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(badgeColor.opacity(0.12))
                    .cornerRadius(6)
                }
            }
            
            Text("Excessive heat accelerates chemical degradation and causes battery capacity loss. When the battery exceeds your set limit, BatterySaver immediately activates the RED indicator, displays the alert in the menu bar, and sends a notification.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Toggle("Enable high-temperature protection & red light alert", isOn: $settings.temperatureAlertEnabled)
                .toggleStyle(.checkbox)
            
            if settings.temperatureAlertEnabled {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 16) {
                        Text("Overheating Warning Threshold:")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        HStack(spacing: 10) {
                            Text("\(settings.maxBatteryTemperatureCelsius) °C")
                                .font(.system(.body, design: .monospaced))
                                .bold()
                                .foregroundColor(settings.maxBatteryTemperatureCelsius >= 45 ? .red : (settings.maxBatteryTemperatureCelsius >= 40 ? .orange : .accentColor))
                            
                            Stepper("", value: $settings.maxBatteryTemperatureCelsius, in: 30...60)
                                .labelsHidden()
                        }
                    }
                    
                    // Quick presets
                    HStack(spacing: 6) {
                        Text("Quick Presets:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        ForEach([35, 38, 40, 42, 45, 50], id: \.self) { deg in
                            if settings.maxBatteryTemperatureCelsius == deg {
                                Button("\(deg)°C\(deg == 40 ? " (Rec)" : "")") {
                                    settings.maxBatteryTemperatureCelsius = deg
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.mini)
                            } else {
                                Button("\(deg)°C\(deg == 40 ? " (Rec)" : "")") {
                                    settings.maxBatteryTemperatureCelsius = deg
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            }
                        }
                    }
                    
                    // Live guide card
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("Battery Health & Thermal Protection:")
                                .font(.caption)
                                .bold()
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("• **Normal Range:** 15°C – 35°C (optimal everyday temperatures for Apple Silicon).")
                            Text("• **Degradation Zone:** Sustained temperatures above 40°C significantly accelerate capacity drop.")
                            Text("• **Action when triggered:** Status turns **RED 🔴**, menu bar shows **🔥 temp**, and a banner notification alerts you to disconnect chargers or reduce workload.")
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                    .padding(10)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Notifications Section
    
    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notifications")
                .font(.headline)
            
            Toggle("Enable banner notifications", isOn: $settings.notificationsEnabled)
                .toggleStyle(.checkbox)
            
            HStack {
                Text("Cooldown between duplicate alerts:")
                    .font(.subheadline)
                Spacer()
                Picker("", selection: $settings.cooldownMinutes) {
                    Text("5 minutes").tag(5)
                    Text("10 minutes (Standard)").tag(10)
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                }
                .frame(width: 180)
            }
            
            Text("Includes automatic 60-second global throttling to prevent rapid consecutive alerts.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Monitoring & System Section
    
    private var systemSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Monitoring & System")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sensor Check Frequency:")
                        .font(.subheadline)
                    Text("Background polling interval. Cable plug and unplug events always update immediately.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Picker("", selection: $settings.checkIntervalSeconds) {
                    Text("15 seconds").tag(15)
                    Text("30 seconds (Balanced)").tag(30)
                    Text("60 seconds (Relaxed)").tag(60)
                    Text("120 seconds (Battery Saver)").tag(120)
                }
                .frame(width: 190)
            }
            
            Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                .toggleStyle(.checkbox)
        }
    }
}

// MARK: - FlowLayout helper
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        var height: CGFloat = 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentX + size.width > width && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        height = currentY + lineHeight
        return CGSize(width: width, height: max(height, 30))
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0
        
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            view.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
