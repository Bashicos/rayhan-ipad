import SwiftUI
import UIKit
import AudioToolbox
import UserNotifications
import ActivityKit

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

/// Short chimes for each kind of event (system sounds, like the demo's Apple-style chimes).
enum Sounds {
    static var on: Bool { UserDefaults.standard.object(forKey: "sounds") as? Bool ?? true }
    private static func play(_ id: SystemSoundID) { if on { AudioServicesPlaySystemSound(id) } }
    static func arrive() { play(1307) }
    static func session() { play(1306) }
    static func done() { play(1057) }
    static func patient() { play(1054) }
}

/// Local notifications (they work without a paid developer account). Names are hidden on the Lock Screen.
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()
    static func setup() {
        let c = UNUserNotificationCenter.current()
        c.delegate = shared
        if UserDefaults.standard.string(forKey: "demoScreen") == nil { c.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in } }
        let open = UNNotificationAction(identifier: "open", title: "Open", options: [.foreground])
        c.setNotificationCategories([UNNotificationCategory(identifier: "rx", actions: [open], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: "New activity at the clinic", options: [.hiddenPreviewsShowTitle])])
    }
    static func post(title: String, body: String, patientName: String?) {
        let n = UNMutableNotificationContent()
        n.title = title
        n.body = body
        n.sound = .default
        n.categoryIdentifier = "rx"
        n.threadIdentifier = title
        n.interruptionLevel = .active
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: n, trigger: nil))
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { [.list] }
}

/// Live Activities: "Waiting in reception" and "In Room 2", one per patient.
enum LiveActivities {
    private static var enabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }
    private static func find(_ flowID: String) -> Activity<VisitAttributes>? { Activity<VisitAttributes>.activities.first { $0.attributes.flowID == flowID } }

    static func waiting(patient: String, dentist: String, since: Date, flowID: String) {
        guard enabled, !flowID.isEmpty else { return }
        let st = VisitAttributes.ContentState(stage: "waiting", since: since, room: "", dentist: dentist)
        if let a = find(flowID) { Task { await a.update(ActivityContent(state: st, staleDate: nil)) }; return }
        let ini = patient.split(separator: " ").compactMap { $0.first }.prefix(2).map(String.init).joined()
        _ = try? Activity.request(attributes: VisitAttributes(flowID: flowID, patient: patient, initials: ini), content: ActivityContent(state: st, staleDate: nil), pushType: nil)
    }
    static func inRoom(flowID: String, patient: String, room: String, dentist: String, since: Date) {
        guard enabled else { return }
        let st = VisitAttributes.ContentState(stage: "room", since: since, room: room, dentist: dentist)
        if let a = find(flowID) { Task { await a.update(ActivityContent(state: st, staleDate: nil)) } }
        else {
            let ini = patient.split(separator: " ").compactMap { $0.first }.prefix(2).map(String.init).joined()
            _ = try? Activity.request(attributes: VisitAttributes(flowID: flowID, patient: patient, initials: ini), content: ActivityContent(state: st, staleDate: nil), pushType: nil)
        }
    }
    static func end(flowID: String) {
        guard let a = find(flowID) else { return }
        Task { await a.end(nil, dismissalPolicy: .immediate) }
    }
}
