import AppKit
import SwiftUI
import Combine

@MainActor
public final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let monitor: PowerMonitor
    private let settings = SettingsStore.shared
    private var cancellables = Set<AnyCancellable>()
    
    public init(monitor: PowerMonitor) {
        self.monitor = monitor
        super.init()
        
        NSLog(">>> StatusBarController: init START")
        setupStatusItem()
        setupPopover()
        observeChanges()
        updateStatusBar()
        NSLog(">>> StatusBarController: init END, button title='\(statusItem.button?.title ?? "")', image=\(String(describing: statusItem.button?.image))")
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 420)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: MenuBarExtraView(monitor: monitor)
        )
    }
    
    private func observeChanges() {
        monitor.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusBar()
            }
            .store(in: &cancellables)
            
        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusBar()
            }
            .store(in: &cancellables)
    }
    
    public func updateStatusBar() {
        guard let button = statusItem.button else { return }
        
        let iconType = settings.menuBarIconType
        let statusColor = monitor.barState.nsColor
        let config = NSImage.SymbolConfiguration(paletteColors: [statusColor])
        
        if let baseSymbol = NSImage(systemSymbolName: iconType.symbolName, accessibilityDescription: "BatterySaver") {
            button.image = baseSymbol.withSymbolConfiguration(config)
            button.imagePosition = .imageLeading
        }
        
        if let text = menuBarText {
            button.title = " " + text
        } else {
            button.title = ""
        }
        
        button.toolTip = "BatterySaver: \(monitor.recommendation)"
    }
    
    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        
        if popover.isShown {
            popover.performClose(sender)
        } else {
            monitor.updateMetrics()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
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
    
    private func makeColoredDot(color: NSColor) -> NSImage {
        let size = NSSize(width: 10, height: 10)
        let image = NSImage(size: size, flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
            return true
        }
        image.isTemplate = false
        return image
    }
}
