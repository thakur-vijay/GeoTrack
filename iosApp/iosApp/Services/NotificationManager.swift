//
//  NotificationManager.swift
//  iosApp
//
//  Created by Vijay Thakur on 11/10/26.
//


import Foundation
import UserNotifications

@MainActor
final class NotificationManager {

static let shared = NotificationManager()
private let center = UNUserNotificationCenter.current()
private init() {}
// MARK: - Request Permission
func requestPermission() async {
    let settings = await center.notificationSettings()
    print("🔔 Authorization: \(settings.authorizationStatus.rawValue)")
    print("🔔 Alert: \(settings.alertSetting.rawValue)")
    do {
        let granted = try await center.requestAuthorization(
            options: [.alert, .sound, .badge]
        )
        print("🔔 Permission granted: \(granted)")
    } catch {
        print("❌ Authorization error: \(error.localizedDescription)")
    }
}
// MARK: - Send Notification
func sendNotification(
    title: String,
    body: String
) async {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    let request = UNNotificationRequest(
        identifier: UUID().uuidString,
        content: content,
        trigger: nil
    )
    do {
        try await center.add(request)
        print("✅ Notification scheduled successfully")
    } catch {
        let nsError = error as NSError
        print("❌ Notification failed")
        print("Domain: \(nsError.domain)")
        print("Code: \(nsError.code)")
        print("Description: \(nsError.localizedDescription)")
    }
}

}