import UIKit
import UserNotifications
import WidgetKit

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        // TODO: When you add the Firebase iOS SDK via Swift Package Manager:
        //   1. import FirebaseCore
        //   2. Uncomment → FirebaseApp.configure()
        //   Then replace the raw APNs token below with Messaging.messaging().token

        return true
    }

    // MARK: - APNs token

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // TODO: When Firebase is added, set:
        //   Messaging.messaging().apnsToken = deviceToken
        //   Then read the FCM token with Messaging.messaging().token(completion:)
        //
        // For now we send the raw APNs hex token so the server field is populated.
        let tokenHex = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task {
            try? await APIClient.shared.updateFcmToken(FcmTokenRequest(fcmToken: tokenHex))
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[APNs] Registration failed: \(error)")
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {

    /// Called when a notification arrives while the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // A new message likely arrived — refresh the home-screen widget
        WidgetCenter.shared.reloadAllTimelines()
        // Respect local notification rules (Settings → Notifications)
        guard NotificationPolicy.isEnabled() else { return [] }
        return [.banner, .badge, .sound]
    }

    /// Called when the user taps a notification.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        if let messageId = info["messageId"] as? String {
            await MainActor.run {
                NotificationRouter.shared.pendingMessageId = messageId
            }
        }
    }
}
