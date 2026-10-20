import Foundation
import UserNotifications

@MainActor
public final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    public static let shared = NotificationManager()
    
    private var eventHistory: [String: Date] = [:]
    private var lastGlobalNotificationTime: Date = .distantPast
    
    // Minimum interval between any notifications (anti-spam global throttle: 60s)
    private let globalMinInterval: TimeInterval = 60.0
    
    override private init() {
        super.init()
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        requestAuthorization()
    }
    
    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("[Notifications] Auth error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Send notification with both global throttling and per-event cooldown
    public func sendNotification(
        title: String,
        body: String,
        eventKey: String,
        cooldownSeconds: TimeInterval = 600
    ) {
        let now = Date()
        
        // 1. Global throttle: do not send any alerts within 60s of previous alert
        guard now.timeIntervalSince(lastGlobalNotificationTime) >= globalMinInterval else {
            return
        }
        
        // 2. Per-event cooldown: do not repeat the same event within the cooldown window
        if let lastTime = eventHistory[eventKey], now.timeIntervalSince(lastTime) < cooldownSeconds {
            return
        }
        
        lastGlobalNotificationTime = now
        eventHistory[eventKey] = now
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[Notifications] Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    public nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
