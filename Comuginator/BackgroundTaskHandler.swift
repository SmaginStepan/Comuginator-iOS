import Foundation
import BackgroundTasks
#if canImport(UIKit)
import UIKit
#endif

/// Registers and handles BGAppRefreshTask work.
///
/// IMPORTANT — add the identifier below to your app's Info.plist:
///   Key: BGTaskSchedulerPermittedIdentifiers
///   Value: ["com.comuginator.heartbeat"]
/// In Xcode: select your target → Info tab → + → Background Task Scheduler Permitted Identifiers
enum BackgroundTaskHandler {

    static let heartbeatIdentifier = "com.comuginator.heartbeat"

    // MARK: - Registration (call once at app launch)

    static func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: heartbeatIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            Self.handleHeartbeat(refreshTask)
        }
    }

    // MARK: - Schedule next run

    static func scheduleHeartbeat() {
        let request = BGAppRefreshTaskRequest(identifier: heartbeatIdentifier)
        // System will run this no earlier than 15 min from now
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("[BG] Failed to schedule heartbeat: \(error)")
        }
    }

    // MARK: - Task handler

    private static func handleHeartbeat(_ task: BGAppRefreshTask) {
        // Reschedule immediately so there's always a pending run
        scheduleHeartbeat()

        let work = Task {
            await sendHeartbeat()
            task.setTaskCompleted(success: true)
        }
        // System gives us ~30 s; if time runs out, cancel gracefully
        task.expirationHandler = {
            work.cancel()
            task.setTaskCompleted(success: false)
        }
    }

    // MARK: - Heartbeat payload

    static func sendHeartbeat() async {
        #if canImport(UIKit)
        let (batteryPercent, isCharging, model, osVersion): (Int?, Bool, String, String) =
            await MainActor.run {
                UIDevice.current.isBatteryMonitoringEnabled = true
                let level  = UIDevice.current.batteryLevel
                let pct    = level >= 0 ? Int(level * 100) : nil
                let charge = [UIDevice.BatteryState.charging, .full].contains(UIDevice.current.batteryState)
                return (pct, charge, UIDevice.current.model, UIDevice.current.systemVersion)
            }
        #else
        let batteryPercent: Int? = nil
        let isCharging = false
        let model = "Mac"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        #endif

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let body = HeartbeatRequest(
            batteryPercent: batteryPercent,
            volumePercent: nil,
            isCharging: isCharging,
            reportedAt: ISO8601DateFormatter().string(from: Date()),
            platform: "ios",
            model: model,
            osVersion: osVersion,
            appVersion: appVersion
        )
        try? await APIClient.shared.heartbeat(body)
    }
}
