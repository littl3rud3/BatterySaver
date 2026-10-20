import SwiftUI
import AppKit

public struct MenuBarExtraView: View {
    @ObservedObject var monitor: PowerMonitor
    @ObservedObject var settings = SettingsStore.shared
    
    @State private var isDetailsExpanded: Bool = false
    
    public init(monitor: PowerMonitor) {
        self.monitor = monitor
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // MARK: - Header
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(nsColor: monitor.barState.nsColor))
                    .frame(width: 10, height: 10)
                
                Text("Power Monitor")
                    .font(.headline)
                
                Spacer()
                
                Text(monitor.barState.emoji)
                    .font(.caption)
            }
            
            Divider()
            
            // MARK: - Primary Metrics
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Battery Level:")
                    Spacer()
                    Text("**\(monitor.batteryPercent)%**")
                        .foregroundColor(monitor.batteryPercent <= settings.minBatteryTarget ? .red : (monitor.batteryPercent >= settings.maxBatteryTarget ? .orange : .primary))
                }
                
                HStack {
                    Text("Power Adapter:")
                    Spacer()
                    if monitor.adapterWatts > 0 {
                        Text("**\(monitor.adapterWatts) W**")
                    } else {
                        Text("Disconnected (**\(monitor.targetAdapterWatts)W**)")
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text("Mac Consumption:")
                    Spacer()
                    Text(String(format: "**%.1f W**", monitor.systemLoadWatts))
                }
                
                HStack {
                    HStack(spacing: 4) {
                        Text("Sustained Workload:")
                        Image(systemName: monitor.loadTrend.iconName)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(String(format: "**%.1f W** (%@)", monitor.sustainedLoadWatts, monitor.loadTrend.title))
                        .foregroundColor(.secondary)
                }
                
                if let candidate = monitor.candidateAdapterWatts,
                   let remaining = monitor.candidateDwellRemainingSeconds, remaining > 0 {
                    HStack {
                        Text("Stabilizing Trend:")
                        Spacer()
                        Text("\(candidate)W target in \(remaining)s")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.orange)
                    }
                }
                
                HStack {
                    Text("Battery Flow:")
                    Spacer()
                    Text(String(format: "**%@%.1f W**", monitor.netBatteryWatts >= 0 ? "+" : "", monitor.netBatteryWatts))
                        .foregroundColor(monitor.netBatteryWatts < -0.5 ? .red : .green)
                }
                
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "thermometer.medium")
                            .font(.system(size: 11))
                            .foregroundColor(temperatureColor(monitor.batteryTemperatureCelsius))
                        Text("Battery Temp:")
                    }
                    Spacer()
                    if let temp = monitor.batteryTemperatureCelsius {
                        HStack(spacing: 4) {
                            Text(String(format: "**%.1f °C**", temp))
                            if monitor.isOverheating {
                                Text("🔥 Hot")
                                    .font(.caption2)
                                    .bold()
                            }
                        }
                        .foregroundColor(temperatureColor(temp))
                    } else {
                        Text("N/A")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .font(.subheadline)
            
            Divider()
            
            // MARK: - Status Banner
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(Color(nsColor: monitor.barState.nsColor))
                    .frame(width: 8, height: 8)
                    .padding(.top, 5)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Status:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(monitor.recommendation)
                        .font(.callout)
                        .bold()
                        .foregroundColor(Color(nsColor: monitor.barState.nsColor))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(8)
            .background(Color(nsColor: monitor.barState.nsColor).opacity(0.12))
            .cornerRadius(8)
            
            // MARK: - Technical Details Disclosure
            DisclosureGroup(isExpanded: $isDetailsExpanded) {
                VStack(spacing: 4) {
                    detailRow("Voltage", String(format: "%.2f V", monitor.batteryVoltage))
                    detailRow("Current", String(format: "%.2f A", monitor.batteryAmperage))
                    if let temp = monitor.batteryTemperatureCelsius {
                        detailRow("Temperature", String(format: "%.1f °C", temp), valueColor: temperatureColor(temp))
                    }
                    if let cycles = monitor.cycleCount {
                        detailRow("Cycle Count", "\(cycles)")
                    }
                    if let mins = monitor.timeRemainingMinutes, mins > 0, mins < 65535 {
                        let hours = mins / 60
                        let rem = mins % 60
                        detailRow("Time Remaining", hours > 0 ? "\(hours)h \(rem)m" : "\(rem)m")
                    }
                }
                .padding(.top, 4)
            } label: {
                Text("Battery Details")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // MARK: - Footer Actions
            HStack(alignment: .center, spacing: 6) {
                Button {
                    monitor.updateMetrics()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9, weight: .semibold))
                        Text("Check")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                ModernActionButton(
                    title: "Settings",
                    icon: "gearshape.fill",
                    isDestructive: false
                ) {
                    SettingsWindowController.shared.show()
                }
                .help("Settings (⌘,)")
                
                ModernActionButton(
                    title: "Quit",
                    icon: "power",
                    isDestructive: true
                ) {
                    NSApplication.shared.terminate(nil)
                }
                .help("Quit BatterySaver")
            }
            .font(.caption)
        }
        .padding(12)
        .frame(width: 290)
        .onAppear {
            monitor.updateMetrics()
        }
    }
    
    private func detailRow(_ title: String, _ value: String, valueColor: Color? = nil) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .bold()
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(valueColor ?? .primary)
        }
        .font(.caption)
    }
    
    private func temperatureColor(_ temp: Double?) -> Color {
        guard let temp = temp else { return .secondary }
        let threshold = Double(settings.maxBatteryTemperatureCelsius)
        if temp >= threshold {
            return .red
        } else if temp >= threshold - 3.0 {
            return .orange
        } else {
            return .green
        }
    }
}

// MARK: - Modern Action Button with Hover State

private struct ModernActionButton: View {
    let title: String
    let icon: String
    var isDestructive: Bool = false
    let action: () -> Void
    
    @State private var isHovered: Bool = false
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: isDestructive ? .bold : .medium))
                Text(title)
            }
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundColor(
                isDestructive
                    ? (isHovered ? .red : .secondary)
                    : (isHovered ? .primary : .secondary)
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 4.5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        isDestructive && isHovered
                            ? Color.red.opacity(0.12)
                            : (isHovered ? Color.primary.opacity(0.08) : Color.clear)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(
                        isDestructive && isHovered
                            ? Color.red.opacity(0.28)
                            : (isHovered ? Color.primary.opacity(0.14) : Color.clear),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
