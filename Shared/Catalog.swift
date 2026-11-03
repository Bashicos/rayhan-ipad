import SwiftUI

enum Catalog {
    static let specs = CatalogData.specs
    static let types = CatalogData.types
    static let addons = CatalogData.addons
    static let reasons = CatalogData.reasons
    static let labTypes: Set<String> = ["crown", "bridge", "veneer", "post", "cden", "pden", "icrown", "onlay"]
    static let fillTypes: Set<String> = ["fill", "comp", "gic", "amal"]

    static func spec(_ id: String) -> ProcSpec? { specs.first { $0.id == id } }
    static func type(_ id: String) -> ProcType? { types.first { $0.id == id } }
    static func addon(_ id: String) -> ProcAddon? { addons.first { $0.id == id } }
    static func reason(_ id: String?) -> ReasonSpec? { reasons.first { $0.id == id } }
    static func typeName(_ id: String) -> String { type(id)?.name ?? id }
    static func isLab(_ type: String) -> Bool { labTypes.contains(type) }

    /// Chart marks and the procedure each one stands for (from the demo's procMap).
    enum Flag: String, CaseIterable { case rct, retx, crown, veneer, implant, surf }
    static func flag(of p: Procedure) -> Flag? {
        if fillTypes.contains(p.type) { return .surf }
        switch p.type {
        case "rct": return .rct
        case "retx": return .retx
        case "crown", "bridge": return .crown
        case "veneer": return .veneer
        case "place", "icrown": return .implant
        default: return nil
        }
    }
    static func procFor(_ f: Flag) -> (spec: String, type: String) {
        switch f {
        case .rct: ("endo", "rct"); case .retx: ("endo", "retx"); case .crown: ("pros", "crown")
        case .veneer: ("pros", "veneer"); case .implant: ("impl", "place"); case .surf: ("rest", "fill")
        }
    }
    static let surfOrder = ["M", "O", "D", "B", "L"]
    static func surfSorted(_ s: [String]) -> [String] { surfOrder.filter { s.contains($0) } }

    // MARK: Lab steps

    struct StepDef: Hashable { let k: String; let name: String; let color: Color }
    static let labSteps: [StepDef] = [
        .init(k: "imp", name: "Impression taken", color: Color(rgb: 0x8FB8FF)),
        .init(k: "sent", name: "Sent to the lab", color: Color(rgb: 0x8FB8FF)),
        .init(k: "tryin", name: "Try-in received", color: Color(rgb: 0xC9A7FF)),
        .init(k: "tryok", name: "Try-in fitted", color: Color(rgb: 0x6FE3C8)),
        .init(k: "mod", name: "Lab needs a modification", color: Color(rgb: 0xE8AA5A)),
        .init(k: "back", name: "Sent back for modification", color: Color(rgb: 0xE8AA5A)),
        .init(k: "dent", name: "Needs the dentist", color: Color(rgb: 0xFF8A7E)),
        .init(k: "prob", name: "Problem at the lab", color: Color(rgb: 0xFF6B5E)),
        .init(k: "ready", name: "Ready at the lab", color: Color(rgb: 0x6FE3C8)),
        .init(k: "recv", name: "Received from the lab", color: Color(rgb: 0x6FE3C8)),
        .init(k: "done", name: "Delivered · done", color: Color(rgb: 0x34C3A4)),
    ]
    static func step(_ k: String) -> StepDef? { labSteps.first { $0.k == k } }
    static let noteSteps: Set<String> = ["mod", "back", "dent", "prob"]
    static func labNext(_ k: String?) -> [String] {
        let m: [String: [String]] = ["": ["imp", "sent"], "imp": ["sent", "tryin", "recv", "done", "prob"], "sent": ["tryin", "ready", "recv", "mod", "prob", "done"],
                                     "tryin": ["tryok", "mod", "dent", "back", "done"], "tryok": ["recv", "ready", "done"], "mod": ["back", "dent", "tryin"],
                                     "back": ["tryin", "ready", "recv", "prob"], "dent": ["tryin", "back", "done", "mod"], "prob": ["back", "sent", "dent", "mod"],
                                     "ready": ["recv", "done", "prob"], "recv": ["done", "tryin", "mod", "back"], "done": []]
        return m[k ?? ""] ?? ["done"]
    }
    enum Where: String { case notsent, lab, clinic, done
        var label: String { switch self { case .notsent: "Not sent yet"; case .lab: "At the lab"; case .clinic: "Here at the clinic"; case .done: "Delivered" } }
        var color: Color { switch self { case .notsent: RX.ink3; case .lab: RX.tan; case .clinic: RX.lilac; case .done: RX.mint } }
    }
    static func labWhere(_ k: String?) -> Where {
        guard let k, k != "imp" else { return .notsent }
        if k == "done" { return .done }
        return ["tryin", "tryok", "recv", "dent"].contains(k) ? .clinic : .lab
    }

    // MARK: VITA shades

    static let vitaColors: [String: String] = ["B1": "#F3EBD9", "A1": "#F0E5CE", "B2": "#ECDFC0", "D2": "#E5D9C3", "A2": "#E9DABD", "C1": "#E5DBC6", "C2": "#DACDB2", "D4": "#D5C5A4", "A3": "#E2CEA7", "D3": "#DBCCB0", "B3": "#E1CDA0", "A3.5": "#DBC198", "B4": "#D8BF8D", "C3": "#CFC09F", "A4": "#D1B183", "C4": "#C1AD88"]
    static let vitaValueOrder = ["B1", "A1", "B2", "D2", "A2", "C1", "C2", "D4", "A3", "D3", "B3", "A3.5", "B4", "C3", "A4", "C4"]
    static let vitaGroups: [(String, String, [String])] = [("A", "Reddish-brown", ["A1", "A2", "A3", "A3.5", "A4"]), ("B", "Reddish-yellow", ["B1", "B2", "B3", "B4"]), ("C", "Grey", ["C1", "C2", "C3", "C4"]), ("D", "Reddish-grey", ["D2", "D3", "D4"])]
    static let bleach: [(String, String)] = [("BL1", "#FAF7F1"), ("BL2", "#F7F2E8"), ("BL3", "#F4EEE1"), ("BL4", "#F1E9D7")]
    static let master3D: [(Int, [String])] = [(0, ["0M1", "0M2", "0M3"]), (1, ["1M1", "1M2"]), (2, ["2L1.5", "2L2.5", "2M1", "2M2", "2M3", "2R1.5", "2R2.5"]), (3, ["3L1.5", "3L2.5", "3M1", "3M2", "3M3", "3R1.5", "3R2.5"]), (4, ["4L1.5", "4L2.5", "4M1", "4M2", "4M3", "4R1.5", "4R2.5"]), (5, ["5M1", "5M2", "5M3"])]
    static func shadeColor(_ k: String) -> Color {
        if let h = vitaColors[k] { return Color(hex: h) }
        if let b = bleach.first(where: { $0.0 == k }) { return Color(hex: b.1) }
        // 3D-Master: value group 0–5, L yellower / M / R redder, chroma 1–3
        let chars = Array(k)
        guard chars.count >= 3, let g = Int(String(chars[0])) else { return RX.ink3 }
        let h = chars[1], c = Double(String(chars[2...])) ?? 1
        let L = 95 - Double(g) * 6.2 - c * 1.6, sat = min(55, 14 + c * 9 + Double(g) * 2), hue = h == "L" ? 44.0 : h == "R" ? 33.0 : 39.0
        return Color(hue: hue / 360, saturation: hslToHsb(s: sat / 100, l: L / 100).s, brightness: hslToHsb(s: sat / 100, l: L / 100).b)
    }
    private static func hslToHsb(s: Double, l: Double) -> (s: Double, b: Double) {
        let b = l + s * min(l, 1 - l)
        return (b == 0 ? 0 : 2 * (1 - l / b), b)
    }

    // MARK: Teeth (FDI)

    static let upper = ["18", "17", "16", "15", "14", "13", "12", "11", "21", "22", "23", "24", "25", "26", "27", "28"]
    static let lower = ["48", "47", "46", "45", "44", "43", "42", "41", "31", "32", "33", "34", "35", "36", "37", "38"]
    static func toothName(_ n: String) -> String {
        guard n.count == 2, let q = Int(String(n.first!)), let t = Int(String(n.last!)) else { return "Tooth " + n }
        let jaw = q <= 2 ? "upper" : "lower", side = (q == 1 || q == 4) ? "right" : "left"
        let kind = ["", "central incisor", "lateral incisor", "canine", "first premolar", "second premolar", "first molar", "second molar", "wisdom tooth"][min(8, max(0, t))]
        return "\(jaw.capitalized) \(side) \(kind)"
    }
    static let toothTags = ["Broken file", "Retreatment", "Fractured", "Mobile", "Sensitive", "Caries", "Abscess", "Watch"]
}
