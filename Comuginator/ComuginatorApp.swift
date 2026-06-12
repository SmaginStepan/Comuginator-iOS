import SwiftUI
import UIKit
import UserNotifications
import WidgetKit

@main
struct ComuginatorApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var appState = AppState()
    @StateObject private var notificationRouter = NotificationRouter.shared

    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appLanguage") private var appLanguage = "system"

    init() {
        BackgroundTaskHandler.register()
        SessionStore.shared.syncToSharedDefaults()
    }

    var body: some Scene {
        WindowGroup {
            rootView
                // In-app language override (SwiftUI text re-resolves live)
                .environment(\.locale, appLanguage == "system"
                             ? .autoupdatingCurrent
                             : Locale(identifier: appLanguage))
                .environmentObject(notificationRouter)
                // Present IncomingMessageView when a push notification is tapped
                .sheet(item: Binding(
                    get: { notificationRouter.pendingMessageId.map { MessageIdWrapper($0) } },
                    set: { if $0 == nil { notificationRouter.pendingMessageId = nil } }
                )) { wrapper in
                    IncomingMessageView(messageId: wrapper.id)
                }
                // Deep links: widget tap (comuginator://message?id=…)
                .onOpenURL { url in
                    guard url.scheme == "comuginator" else { return }
                    if url.host == "message",
                       let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                           .queryItems?.first(where: { $0.name == "id" })?.value {
                        notificationRouter.pendingMessageId = id
                    }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                if appState.isLoggedIn {
                    // Like Android's onResume: allow pending messages to reopen
                    CommandSyncService.shared.resetRoutingMemory()
                    CommandSyncService.shared.start()
                }
            case .background:
                CommandSyncService.shared.stop()
                BackgroundTaskHandler.scheduleHeartbeat()
                WidgetCenter.shared.reloadAllTimelines()
            default:
                break
            }
        }
    }

    // MARK: - Root view

    @ViewBuilder
    private var rootView: some View {
        if appState.isLoggedIn {
            FamilyView()
                .environmentObject(appState)
                .onAppear {
                    requestPushPermissionIfNeeded()
                    CommandSyncService.shared.start()
                }
        } else {
            OnboardingView()
                .environmentObject(appState)
        }
    }

    // MARK: - Push permission

    private func requestPushPermissionIfNeeded() {
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()

            switch settings.authorizationStatus {
            case .notDetermined:
                let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
                if granted {
                    await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
                }
            case .authorized, .provisional, .ephemeral:
                // Re-register every launch so the APNs/FCM token stays fresh
                await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
            default:
                break
            }
        }
    }
}

// MARK: - Helpers

/// Makes a String identifiable so it can drive sheet(item:)
private struct MessageIdWrapper: Identifiable {
    let id: String
    init(_ id: String) { self.id = id }
}
