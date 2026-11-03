import Foundation
import WidgetKit
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Live Activity for a patient in the reception room or in a room (Dynamic Island and Lock Screen).
struct VisitAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var stage: String // "waiting" | "room"
        var since: Date
        var room: String
        var dentist: String
    }
    var flowID: String
    var patient: String
    var initials: String
}

/// Small summary the app shares with its widgets (when the system lets them share a folder).
struct WidgetSnapshot: Codable {
    struct Item: Codable, Hashable { var time: String; var patient: String; var dentist: String; var colorHex: String; var what: String }
    var made: Date
    var day: String
    var next: [Item]
    var waiting: Int
    var longestWaitSince: Date?
    var inRooms: Int
    var labHere: Int
    var labHereItems: [String]
    var cashToday: String

    static let group = "group.com.rayhanclinics.xray"
    static var url: URL? { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?.appendingPathComponent("widget.json") }

    static func read() -> WidgetSnapshot? {
        guard let u = url, let d = try? Data(contentsOf: u) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: d)
    }

    static func make(from c: ClinicData, now: Date = .now) -> WidgetSnapshot {
        let T = Day.iso(now)
        let flowAppts = Set(c.flow.compactMap { $0.appt })
        let name: (String) -> String = { id in c.patients.first { $0.id == id }?.name ?? "" }
        let next = c.appts.filter { $0.cancel == nil && $0.day == T && !flowAppts.contains($0.id) }.sorted { $0.startMin < $1.startMin }.prefix(6).map { a -> Item in
            let m = c.team.first { $0.id == a.dent }
            let what = a.tx.isEmpty ? (Catalog.reason(a.spec)?.name ?? a.note) : a.tx.joined(separator: ", ")
            return Item(time: a.time, patient: name(a.patient), dentist: m?.full ?? "", colorHex: m?.colorHex ?? "#34C3A4", what: what)
        }
        let waiting = c.flow.filter { $0.stage == .waiting && Day.iso($0.arrivedAt) == T }
        var here: [String] = []
        for p in c.patients { for r in p.procs { if let k = r.lab?.steps.last?.k, Catalog.labWhere(k) == .clinic { here.append(Catalog.typeName(r.type) + (r.teeth.isEmpty ? "" : " " + r.teeth.joined(separator: "·")) + " · " + p.name) } } }
        var cash = 0.0
        for p in c.patients { for py in p.billing.pays where Day.iso(py.at) == T { cash += c.fx.conv(py.amount, py.cur, .usd, rateFrom: py.rate) } }
        return WidgetSnapshot(made: now, day: T, next: Array(next), waiting: waiting.count, longestWaitSince: waiting.map { $0.arrivedAt }.min(), inRooms: c.flow.filter { $0.stage == .room }.count, labHere: here.count, labHereItems: Array(here.prefix(4)), cashToday: Money.fmt(cash, .usd))
    }

    static func write(from c: ClinicData) {
        guard let u = url, let data = try? JSONEncoder().encode(make(from: c)) else { return }
        try? data.write(to: u, options: .atomic)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
