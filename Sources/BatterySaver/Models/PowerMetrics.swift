import Foundation

/// Battery and power telemetry metrics read directly from IOKit AppleSmartBattery.
public struct PowerMetrics: Sendable, Equatable {
    /// Whether an external power adapter is connected
    public var isExternalConnected: Bool
    
    /// Connected adapter power rating (Watts)
    public var adapterWatts: Int
    
    /// Adapter voltage (Volts)
    public var adapterVoltage: Double
    
    /// Adapter max current (Amperes)
    public var adapterCurrent: Double
    
    /// Description of the adapter type (e.g. "pd charger")
    public var adapterDescription: String
    
    /// Battery voltage (Volts)
    public var batteryVoltage: Double
    
    /// Battery instant current (Amperes, >0 charging, <0 discharging)
    public var batteryAmperage: Double
    
    /// Net battery power flow (Watts, >0 charging, <0 discharging)
    public var netBatteryWatts: Double
    
    /// Current power consumption drawn by the Mac hardware (Watts)
    public var systemLoadWatts: Double
    
    /// Current battery charge percentage (0–100%)
    public var batteryPercentage: Int
    
    /// Whether the battery is actively charging
    public var isCharging: Bool
    
    /// Whether the battery is fully charged
    public var isFullyCharged: Bool
    
    /// Estimated time remaining to full charge or discharge (minutes)
    public var timeRemainingMinutes: Int?
    
    /// Battery temperature in Celsius (°C)
    public var batteryTemperatureCelsius: Double?
    
    /// Battery cycle count
    public var cycleCount: Int?
    
    /// Reading timestamp
    public var timestamp: Date

    public init(
        isExternalConnected: Bool = false,
        adapterWatts: Int = 0,
        adapterVoltage: Double = 0.0,
        adapterCurrent: Double = 0.0,
        adapterDescription: String = "",
        batteryVoltage: Double = 0.0,
        batteryAmperage: Double = 0.0,
        netBatteryWatts: Double = 0.0,
        systemLoadWatts: Double = 0.0,
        batteryPercentage: Int = 0,
        isCharging: Bool = false,
        isFullyCharged: Bool = false,
        timeRemainingMinutes: Int? = nil,
        batteryTemperatureCelsius: Double? = nil,
        cycleCount: Int? = nil,
        timestamp: Date = Date()
    ) {
        self.isExternalConnected = isExternalConnected
        self.adapterWatts = adapterWatts
        self.adapterVoltage = adapterVoltage
        self.adapterCurrent = adapterCurrent
        self.adapterDescription = adapterDescription
        self.batteryVoltage = batteryVoltage
        self.batteryAmperage = batteryAmperage
        self.netBatteryWatts = netBatteryWatts
        self.systemLoadWatts = systemLoadWatts
        self.batteryPercentage = batteryPercentage
        self.isCharging = isCharging
        self.isFullyCharged = isFullyCharged
        self.timeRemainingMinutes = timeRemainingMinutes
        self.batteryTemperatureCelsius = batteryTemperatureCelsius
        self.cycleCount = cycleCount
        self.timestamp = timestamp
    }
    
    public static var empty: PowerMetrics {
        PowerMetrics()
    }
    
    /// Formatted estimated time remaining
    public var formattedTimeRemaining: String {
        guard let mins = timeRemainingMinutes, mins > 0, mins < 65535 else {
            if isFullyCharged { return "Fully Charged" }
            return "Calculating..."
        }
        let hours = mins / 60
        let remainder = mins % 60
        if hours > 0 {
            return remainder > 0 ? "\(hours)h \(remainder)m" : "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }
}
