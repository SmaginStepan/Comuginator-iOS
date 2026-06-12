import UIKit
import UserNotifications
import WidgetKit
import FirebaseCore
import FirebaseMessaging

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // MARK: - APNs token

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Hand the APNs token to Firebase; the FCM token arrives via MessagingDelegate.
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[APNs] Registration failed: \(error)")
    }
}

// MARK: - MessagingDelegate (FCM)

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        print("[FCM] Token received: \(fcmToken)")
        guard SessionStore.shared.isConnected else { return }
        Task {
            _ = try? await APIClient.shared.updateFcmToken(FcmTokenRequest(fcmToken: fcmToken))
        }
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
