import Foundation

/// Presets for workload dynamics evaluation and recommendation stabilization.
public enum DynamicsPreset: String, CaseIterable, Identifiable {
    /// Fast reaction: 1.5 min sliding window, 30s upgrade dwell, 60s downgrade dwell.
    case fast = "fast"
    /// Balanced (recommended): 3.0 min sliding window, 45s upgrade dwell, 120s downgrade dwell.
    case balanced = "balanced"
    /// Conservative / Ultra-smooth: 5.0 min sliding window, 60s upgrade dwell, 180s downgrade dwell.
    case conservative = "conservative"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .fast: return "Fast (1.5 min)"
        case .balanced: return "Balanced (3 min)"
        case .conservative: return "Conservative (5 min)"
        }
    }
    
    public var descriptionText: String {
        switch self {
        case .fast:
            return "Analyzes 1.5 min history. Confirms upgrade after 30s, downgrade after 60s. For dynamic testing."
        case .balanced:
            return "Analyzes 3 min history. Confirms upgrade after 45s, downgrade after 120s. Recommended for everyday use."
        case .conservative:
            return "Analyzes 5 min history. Confirms upgrade after 60s, downgrade after 180s. Maximum stability."
        }
    }
    
    /// Sliding window duration in seconds
    public var windowSeconds: TimeInterval {
        switch self {
        case .fast: return 90.0
        case .balanced: return 180.0
        case .conservative: return 300.0
        }
    }
    
    /// Sustained time required before upgrading recommended adapter wattage
    public var upgradeDwellSeconds: TimeInterval {
        switch self {
        case .fast: return 30.0
        case .balanced: return 45.0
        case .conservative: return 60.0
        }
    }
    
    /// Sustained time required before downgrading recommended adapter wattage
    public var downgradeDwellSeconds: TimeInterval {
        switch self {
        case .fast: return 60.0
        case .balanced: return 120.0
        case .conservative: return 180.0
        }
    }
}

/// Workload dynamic trend indicator
public enum LoadTrend: String, CaseIterable {
    case stable = "Stable"
    case rising = "Rising"
    case falling = "Falling"
    
    public var title: String {
        switch self {
        case .stable: return "Stable"
        case .rising: return "Rising"
        case .falling: return "Falling"
        }
    }
    
    public var iconName: String {
        switch self {
        case .stable: return "equal"
        case .rising: return "arrow.up.right"
        case .falling: return "arrow.down.right"
        }
    }
}
