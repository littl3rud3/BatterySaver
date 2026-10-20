import SwiftUI
import AppKit

@main
struct BatterySaverApp: App {
    @StateObject private var monitor = PowerMonitor()
    @ObservedObject private var settings = SettingsStore.shared
    
    init() {
        // Run as menu bar accessory agent (no Dock icon)
        NSApplication.shared.setActivationPolicy(.accessory)
    }
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarExtraView(monitor: monitor)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: settings.menuBarIconType.symbolName)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color(nsColor: monitor.barState.nsColor))
                if let text = menuBarText {
                    Text(text)
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
    
    private var menuBarText: String? {
        let loadWatts = Int(round(monitor.systemLoadWatts))
        let adapterWatts = monitor.adapterWatts
        let targetWatts = monitor.targetAdapterWatts
        let pct = monitor.batteryPercent
        
        // When battery is Overheating, prominently display fire alert and temperature!
        if monitor.isOverheating {
            if settings.menuBarStyle == .dotOnly {
                return nil
            }
            if let temp = monitor.batteryTemperatureCelsius {
                return String(format: "🔥 %.1f°C", temp)
            } else {
                return "🔥 Hot"
            }
        }
        
        // When in Red state (Deficit or Excess), explicitly show which adapter to switch to!
        if monitor.barState == .red && adapterWatts > 0 {
            if settings.menuBarStyle == .full {
                return "\(loadWatts)W | \(adapterWatts)W -> \(targetWatts)W"
            } else if settings.menuBarStyle == .dotOnly {
                return nil
            } else {
                return "\(adapterWatts)W -> \(targetWatts)W"
            }
        }
        
        switch settings.menuBarStyle {
        case .smart:
            if adapterWatts > 0 {
                return "\(loadWatts)W / \(adapterWatts)W"
            } else {
                return "\(targetWatts)W"
            }
            
        case .full:
            if adapterWatts > 0 {
                return "\(loadWatts)W / \(adapterWatts)W"
            } else {
                return "\(loadWatts)W | \(targetWatts)W"
            }
            
        case .loadOnly:
            return "\(loadWatts)W"
            
        case .adapterOnly:
            if adapterWatts > 0 {
                return "\(adapterWatts)W"
            } else {
                return "\(targetWatts)W"
            }
            
        case .batteryPercent:
            return "\(pct)%"
            
        case .temperature:
            if let temp = monitor.batteryTemperatureCelsius {
                return String(format: "%.1f°C", temp)
            } else {
                return "—°C"
            }
            
        case .batteryAndTemp:
            if let temp = monitor.batteryTemperatureCelsius {
                return String(format: "%d%% • %.0f°C", pct, temp)
            } else {
                return "\(pct)%"
            }
            
        case .dotOnly:
            return nil
        }
    }
}
