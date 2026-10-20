import SwiftUI
import AppKit

/// Three-tier power system status
public enum BarState: String, Sendable, CaseIterable {
    /// Green: Everything is optimal, no action required
    case green
    
    /// Orange: Battery boundary reached (<= 20% or >= 80%), connect or disconnect cable
    case orange
    
    /// Red: Power mismatch! Insufficient or excess adapter wattage, or battery overheating
    case red
    
    public var nsColor: NSColor {
        switch self {
        case .green:
            return .systemGreen
        case .orange:
            return .systemOrange
        case .red:
            return .systemRed
        }
    }
    
    public var color: Color {
        Color(nsColor: nsColor)
    }
    
    public var title: String {
        switch self {
        case .green:
            return "Optimal"
        case .orange:
            return "Cable Action"
        case .red:
            return "Warning / Overheat"
        }
    }
    
    public var emoji: String {
        switch self {
        case .green: return "🟢"
        case .orange: return "🟠"
        case .red: return "🔴"
        }
    }
}
