import Foundation
import SwiftUI

// MARK: - Team

enum Role: String, Codable, CaseIterable, Hashable {
    case dentist, reception, accountant, storage
    var name: String {
        switch self { case .dentist: "Dentist"; case .reception: "Reception"; case .accountant: "Accountant"; case .storage: "Storage" }
    }
}

struct Member: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var name: String
    var colorHex: String
    var role: Role
    var admin: Bool = false
    var room: String = ""
    var full: String { title.isEmpty ? name : title + " " + name }
    var initials: String { String(name.prefix(1)).uppercased() }
    var color: Color { Color(hex: colorHex) }
}

// MARK: - Catalog

struct ProcSpec: Codable, Identifiable, Hashable { var id: String; var name: String; var colorHex: String; var color: Color { Color(hex: colorHex) } }
struct ProcType: Codable, Identifiable, Hashable { var id: String; var spec: String; var name: String; var price: Double }
struct ProcAddon: Codable, Identifiable, Hashable { var id: String; var spec: String; var name: String; var price: Double }
struct ReasonSpec: Codable, Identifiable, Hashable { var id: String; var name: String; var colorHex: String; var treatments: [String]; var color: Color { Color(hex: colorHex) } }

// MARK: - Money

enum Currency: String, Codable, CaseIterable, Identifiable, Hashable {
    case usd = "USD", syp = "SYP", eur = "EUR"
    var id: String { rawValue }
    var sym: String { switch self { case .usd: "$"; case .syp: "SYP"; case .eur: "€" } }
    var decimals: Int { self == .syp ? 0 : 2 }
    var label: String { switch self { case .usd: "US dollar ($)"; case .syp: "Syrian pound (SYP)"; case .eur: "Euro (€)" } }
    var short: String { self == .syp ? "SYP" : sym + " " + rawValue }
}

struct FX: Codable, Hashable {
    var syp: Double = 14000
    var eur: Double = 0.92
    func rate(_ c: Currency) -> Double { switch c { case .usd: 1; case .syp: syp; case .eur: eur } }
    /// Converts v from one currency to another; `rateFrom` is the rate stored with a payment.
    func conv(_ v: Double, _ from: Currency, _ to: Currency, rateFrom: Double? = nil) -> Double {
        let usd = v / (rateFrom ?? rate(from))
        return usd * rate(to)
    }
}

enum Money {
    static func fmt(_ v: Double, _ c: Currency) -> String {
        let neg = v < 0, a = abs(v)
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US")
        f.maximumFractionDigits = c.decimals
        f.minimumFractionDigits = 0
        let t = f.string(from: NSNumber(value: a)) ?? "\(a)"
        return (neg ? "−" : "") + (c == .syp ? t + " SYP" : c.sym + t)
    }
}

// MARK: - Patients

enum Sex: String, Codable, CaseIterable, Hashable { case m = "M", f = "F", none = "" }

struct ToothState: Codable, Hashable {
    var missing = false
    var tags: [String] = []
    var note = ""
}

enum ProcStatus: String, Codable, CaseIterable, Hashable, Identifiable {
    case plan, doing, done
    var id: String { rawValue }
    var label: String { switch self { case .plan: "Planned"; case .doing: "In progress"; case .done: "Done" } }
    var color: Color { switch self { case .plan: RX.blue; case .doing: RX.sand; case .done: RX.mint } }
}

struct LabStep: Codable, Hashable, Identifiable {
    var id: String = UUID().uuidString
    var k: String
    var at: Date
    var by: String?
    var note: String = ""
}

struct LabWork: Codable, Hashable {
    var lab: String = ""
    var svc: String = ""
    var shade: String = ""
    var temp: Bool = false
    var note: String = ""
    var steps: [LabStep] = []
}

struct Procedure: Codable, Identifiable, Hashable {
    var id: String = "p" + UUID().uuidString.prefix(8)
    var teeth: [String] = []
    var spec: String
    var type: String
    var addons: [String] = []
    var status: ProcStatus = .plan
    var by: String?
    var at: Date = .now
    var doneAt: Date?
    var surf: [String] = []
    var lab: LabWork?
    var price: Double?
    var addPrices: [String: Double] = [:]
    var gift = false
    var giftAddons: [String] = []
    var discPct: Double = 0
    var tooth: String { teeth.first ?? "" }
}

struct Payment: Codable, Identifiable, Hashable {
    var id: String = "py" + UUID().uuidString.prefix(8)
    var amount: Double
    var cur: Currency
    var rate: Double
    var at: Date
    var by: String?
    var method: String = "Cash"
    var note: String = ""
    var items: [String] = []
}

enum DiscKind: String, Codable, Hashable { case pct, amt }

struct PriceChange: Codable, Identifiable, Hashable {
    var id: String = "aj" + UUID().uuidString.prefix(8)
    var key: String
    var kind: String // gift, pdisc, disc, total, price
    var what: String
    var from: Double
    var to: Double
    var at: Date
    var by: String?
    var dent: String?
}

struct Billing: Codable, Hashable {
    var discKind: DiscKind = .pct
    var discValue: Double = 0
    var agreed: Double?
    /// the procedures a hand-set total covers; anything added later is charged on top
    var agreedIds: [String]?
    var decider: String?
    var pays: [Payment] = []
    var changes: [PriceChange] = []
}

struct P2: Codable, Hashable { var x: Double; var y: Double; var cg: CGPoint { CGPoint(x: x, y: y) }; init(_ x: Double, _ y: Double) { self.x = x; self.y = y }; init(_ p: CGPoint) { x = p.x; y = p.y } }

struct XMark: Codable, Hashable, Identifiable {
    enum Kind: String, Codable { case measure, angle, arrow, text }
    var id: String = UUID().uuidString
    var kind: Kind
    var pts: [P2] // normalised 0…1 in image space
    var text: String = ""
}

struct Xray: Codable, Identifiable, Hashable {
    var id: String = "x" + UUID().uuidString.prefix(8)
    var image: String
    var takenAt: Date
    var by: String?
    var room: String = ""
    var teeth: [String] = []
    var bright: Double = 100
    var contrast: Double = 100
    var invert = false
    var rot: Int = 0
    var marks: [XMark] = []
    var drawing: Data?
    var pixelMM: Double = 0.025
    var note: String = ""
}

struct PatientFile: Codable, Identifiable, Hashable {
    var id: String = "f" + UUID().uuidString.prefix(8)
    var name: String
    var kind: String // stl, dicom, video, photo, pdf
    var size: Int
    var at: Date
    var tooth: String = ""
    var note: String = ""
}

struct Patient: Codable, Identifiable, Hashable {
    var id: String = "P" + UUID().uuidString.prefix(8)
    var first: String
    var last: String
    var sex: Sex = .none
    var age: Int?
    var birth: Date?
    var phones: [String] = []
    var cond: [String] = []
    var allg: [String] = []
    var med: [String] = []
    var created: Date = .now
    var createdBy: String?
    var chart: [String: ToothState] = [:]
    var procs: [Procedure] = []
    var billing = Billing()
    var xrays: [Xray] = []
    var files: [PatientFile] = []
    var dentist: String?

    var name: String { (first + " " + last).trimmingCharacters(in: .whitespaces) }
    var phone: String { phones.first ?? "" }
    var ageNow: Int? {
        if let b = birth { return Calendar.current.dateComponents([.year], from: b, to: .now).year }
        return age
    }
    var hasAlert: Bool { !allg.isEmpty || !cond.isEmpty }
    var iconName: String {
        let a = ageNow ?? 30
        switch sex {
        case .m: return a < 13 ? "pi_boy" : a >= 60 ? "pi_oldman" : "pi_man"
        case .f: return a < 13 ? "pi_girl" : a >= 60 ? "pi_oldwoman" : "pi_woman"
        case .none: return "pi_person"
        }
    }
}

// MARK: - Reception

struct CancelInfo: Codable, Hashable {
    enum By: String, Codable { case patient, clinic }
    var by: By
    var reason: String
    var at: Date
    var who: String?
}

struct Appointment: Codable, Identifiable, Hashable {
    var id: String = "ap" + UUID().uuidString.prefix(8)
    var patient: String
    var day: String // yyyy-MM-dd
    var time: String // HH:mm
    var dent: String
    var dur: Int = 30
    var spec: String?
    var tx: [String] = []
    var note: String = ""
    var cancel: CancelInfo?
    var startMin: Int { let p = time.split(separator: ":").compactMap { Int($0) }; return (p.first ?? 0) * 60 + (p.count > 1 ? p[1] : 0) }
}

enum FlowStage: String, Codable, Hashable { case waiting, room, done }

struct FlowItem: Codable, Identifiable, Hashable {
    var id: String = "fl" + UUID().uuidString.prefix(8)
    var appt: String?
    var patient: String
    var stage: FlowStage
    var room: String?
    var dents: [String] = []
    var arrivedAt: Date
    var startedAt: Date?
    var doneAt: Date?
}

struct Room: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var dents: [String]
}

// MARK: - Labs

struct LabService: Codable, Identifiable, Hashable { var id: String; var name: String; var price: Double }

struct Lab: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var contact: String
    var phone: String
    var cur: Currency
    var note: String
    var services: [LabService]
    var photo: Data?
}

struct LabPayment: Codable, Identifiable, Hashable {
    var id: String = "lp" + UUID().uuidString.prefix(8)
    var lab: String
    var amount: Double
    var cur: Currency
    var rate: Double
    var at: Date
    var by: String?
    var method: String = "Cash"
    var note: String = ""
}

// MARK: - Activity

struct ActivityItem: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var kind: String
    var text: String
    var patient: String?
    var by: String?
    var at: Date = .now
    var read = false
}

struct CashEmpty: Codable, Hashable, Identifiable {
    var id: String = UUID().uuidString
    var at: Date
    var by: String?
    var usd: Double
    var syp: Double
    var eur: Double
}
