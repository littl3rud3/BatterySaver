import Foundation
import IOKit

/// Low-level power telemetry reader from IOKit (AppleSmartBattery).
public struct PowerReader: Sendable {
    
    public init() {}
    
    /// Reads current power and battery metrics from the system registry.
    public func readCurrentMetrics() -> PowerMetrics {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else {
            return .empty
        }
        defer { IOObjectRelease(service) }
        
        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any] else {
            return .empty
        }
        
        // 1. External power connection and adapter details
        let externalConnected = (dict["ExternalConnected"] as? Bool) ?? false
        var adapterWatts = 0
        var adapterVoltage = 0.0
        var adapterCurrent = 0.0
        var adapterDescription = ""
        
        if externalConnected, let adapterDetails = dict["AdapterDetails"] as? [String: Any] {
            adapterWatts = (adapterDetails["Watts"] as? Int) ?? 0
            if let v = adapterDetails["AdapterVoltage"] as? Int {
                adapterVoltage = Double(v) / 1000.0
            }
            if let c = adapterDetails["Current"] as? Int {
                adapterCurrent = Double(c) / 1000.0
            }
            adapterDescription = (adapterDetails["Description"] as? String) ?? "AC Adapter"
        }
        
        // 2. Battery parameters (Voltage in mV, InstantAmperage in mA)
        let rawVoltage = (dict["Voltage"] as? Int) ?? 0
        let rawAmperage = (dict["InstantAmperage"] as? Int) ?? 0
        let batteryVoltage = Double(rawVoltage) / 1000.0
        let batteryAmperage = Double(rawAmperage) / 1000.0
        
        // Use high-precision Apple Silicon PowerTelemetryData if present
        var netBatteryWatts = batteryVoltage * batteryAmperage
        var systemLoadWatts: Double = 0.0
        
        if let telemetry = dict["PowerTelemetryData"] as? [String: Any] {
            if let sysLoadMilliWatts = telemetry["SystemLoad"] as? Int, sysLoadMilliWatts > 0 {
                systemLoadWatts = Double(sysLoadMilliWatts) / 1000.0
            }
            if let batPowerMilliWatts = telemetry["BatteryPower"] as? Int {
                netBatteryWatts = Double(batPowerMilliWatts) / 1000.0
            }
            if systemLoadWatts <= 0.0, let sysInMilliWatts = telemetry["SystemPowerIn"] as? Int {
                let adapterInWatts = Double(sysInMilliWatts) / 1000.0
                systemLoadWatts = max(0.0, adapterInWatts - netBatteryWatts)
            }
        }
        
        // Fallback calculation if PowerTelemetryData is unavailable
        if systemLoadWatts <= 0.0 {
            if externalConnected && adapterWatts > 0 {
                if netBatteryWatts < 0 {
                    systemLoadWatts = Double(adapterWatts) + abs(netBatteryWatts)
                } else {
                    systemLoadWatts = max(3.0, Double(adapterWatts) - netBatteryWatts)
                }
            } else {
                systemLoadWatts = max(0.0, abs(netBatteryWatts))
            }
        }
        
        // 4. Capacity, charging state, temperature, cycle count
        let currentCap = (dict["CurrentCapacity"] as? Int) ?? 0
        let maxCap = (dict["MaxCapacity"] as? Int) ?? 100
        let batteryPercent = maxCap > 0 ? min(100, max(0, Int(round(Double(currentCap) / Double(maxCap) * 100.0)))) : currentCap
        
        let isCharging = (dict["IsCharging"] as? Bool) ?? false
        let isFullyCharged = (dict["FullyCharged"] as? Bool) ?? false
        let timeRemaining = dict["TimeRemaining"] as? Int
        
        var tempCelsius: Double? = nil
        if let rawTemp = dict["Temperature"] as? Int, rawTemp > 0 {
            tempCelsius = Double(rawTemp) / 100.0
        } else if let rawTemp = dict["Temperature"] as? Double, rawTemp > 0 {
            tempCelsius = rawTemp / 100.0
        } else if let rawVirtualTemp = dict["VirtualTemperature"] as? Int, rawVirtualTemp > 0 {
            tempCelsius = Double(rawVirtualTemp) / 100.0
        } else if let rawVirtualTemp = dict["VirtualTemperature"] as? Double, rawVirtualTemp > 0 {
            tempCelsius = rawVirtualTemp / 100.0
        }
        
        let cycleCount = dict["CycleCount"] as? Int
        
        return PowerMetrics(
            isExternalConnected: externalConnected,
            adapterWatts: adapterWatts,
            adapterVoltage: adapterVoltage,
            adapterCurrent: adapterCurrent,
            adapterDescription: adapterDescription,
            batteryVoltage: batteryVoltage,
            batteryAmperage: batteryAmperage,
            netBatteryWatts: netBatteryWatts,
            systemLoadWatts: systemLoadWatts,
            batteryPercentage: batteryPercent,
            isCharging: isCharging,
            isFullyCharged: isFullyCharged,
            timeRemainingMinutes: timeRemaining,
            batteryTemperatureCelsius: tempCelsius,
            cycleCount: cycleCount,
            timestamp: Date()
        )
    }
}
