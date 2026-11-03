import SwiftUI

// Colours, fonts and shapes taken from the Rayhan design demo.
extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        if s.count == 3 {
            let r = Double((v >> 8) & 0xF) / 15, g = Double((v >> 4) & 0xF) / 15, b = Double(v & 0xF) / 15
            self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
        } else {
            self.init(.sRGB, red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255, opacity: 1)
        }
    }
    init(rgb: UInt32, _ a: Double = 1) {
        self.init(.sRGB, red: Double((rgb >> 16) & 0xFF) / 255, green: Double((rgb >> 8) & 0xFF) / 255, blue: Double(rgb & 0xFF) / 255, opacity: a)
    }
}

enum RX {
    static let page = Color(rgb: 0x06120F)
    static let bg = Color(rgb: 0x0A211D)
    static let side = Color(rgb: 0x0D2924)
    static let card = Color(rgb: 0x10302A)
    static let card2 = Color(rgb: 0x153A33)
    static let card3 = Color(rgb: 0x1C4A41)
    static let sheet = Color(rgb: 0x0F2D27)
    static let deep = Color(rgb: 0x0B2622)
    static let deeper = Color(rgb: 0x0C2622)
    static let mint = Color(rgb: 0x34C3A4)
    static let mintLight = Color(rgb: 0x9FE6D4)
    static let mintPale = Color(rgb: 0xC9E8DE)
    static let ink = Color(rgb: 0xEEF5F2)
    static let ink2 = Color(rgb: 0xC5D8D2)
    static let ink3 = Color(rgb: 0x9FBAB2)
    static let ink4 = Color(rgb: 0x6F8F86)
    static let onMint = Color(rgb: 0x062019)
    static let red = Color(rgb: 0xFF6B5E)
    static let salmon = Color(rgb: 0xFF9A8E)
    static let pinkRed = Color(rgb: 0xFFB4AA)
    static let amber = Color(rgb: 0xE8AA5A)
    static let sand = Color(rgb: 0xF3C98B)
    static let tan = Color(rgb: 0xE7C9A6)
    static let gold = Color(rgb: 0xD9B48A)
    static let lilac = Color(rgb: 0xC9A7FF)
    static let blue = Color(rgb: 0x8FC2FF)
    static let whatsapp = Color(rgb: 0x25D366)
    static let line = Color(rgb: 0xD6EBE4, 0.08)
    static let line2 = Color(rgb: 0xD6EBE4, 0.12)
}

extension Font {
    /// Inter, as in the demo (falls back to the system font where Inter is not bundled, e.g. in widgets).
    static func rx(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black: name = "Inter-Bold"
        case .semibold: name = "Inter-SemiBold"
        case .medium: name = "Inter-Medium"
        default: name = "Inter-Regular"
        }
        return .custom(name, size: size, relativeTo: .body)
    }
}

/// The demo's glass card (".gl"): soft green gradient, hairline border, inner highlight and a deep shadow.
struct RXCard: ViewModifier {
    var radius: CGFloat = 20
    var fill: Color? = nil
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill.map { AnyShapeStyle($0) } ?? AnyShapeStyle(LinearGradient(colors: [Color(.sRGB, red: 40/255, green: 92/255, blue: 81/255, opacity: 0.50), Color(.sRGB, red: 14/255, green: 44/255, blue: 38/255, opacity: 0.38)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                    .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Color(rgb: 0xD6F5EC, 0.10), lineWidth: 1))
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(LinearGradient(colors: [Color.white.opacity(0.11), .clear], startPoint: .top, endPoint: .center), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.45), radius: 22, x: 0, y: 14)
            }
    }
}

extension View {
    func rxCard(_ radius: CGFloat = 20, fill: Color? = nil) -> some View { modifier(RXCard(radius: radius, fill: fill)) }
    func rxPanel(_ radius: CGFloat = 14, _ color: Color = RX.card2) -> some View {
        background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(color))
    }
}

// MARK: - The demo's line icons (24×24 SVG paths, stroked with round caps)

struct SVGPathShape: Shape {
    let d: String
    func path(in rect: CGRect) -> Path {
        let base = SVGPathParser.path(d)
        let s = min(rect.width, rect.height) / 24
        return base.applying(CGAffineTransform(scaleX: s, y: s).concatenating(CGAffineTransform(translationX: rect.minX + (rect.width - 24 * s) / 2, y: rect.minY + (rect.height - 24 * s) / 2)))
    }
}

struct Icon: View {
    let d: String
    var size: CGFloat = 18
    var weight: CGFloat = 2
    var body: some View {
        SVGPathShape(d: d)
            .stroke(style: StrokeStyle(lineWidth: weight * size / 24, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
    }
}

enum SVGPathParser {
    private static var cache: [String: Path] = [:]
    private static let lock = NSLock()

    static func path(_ d: String) -> Path {
        lock.lock(); defer { lock.unlock() }
        if let p = cache[d] { return p }
        let p = parse(d)
        cache[d] = p
        return p
    }

    private static func parse(_ d: String) -> Path {
        var p = Path()
        let chars = Array(d.utf8)
        var i = 0
        var cmd: UInt8 = 0
        var cur = CGPoint.zero, start = CGPoint.zero, lastCtrl: CGPoint? = nil, lastQ: CGPoint? = nil
        func skip() { while i < chars.count, chars[i] == 32 || chars[i] == 44 || chars[i] == 10 || chars[i] == 9 { i += 1 } }
        func isCmd(_ c: UInt8) -> Bool { (c >= 65 && c <= 90 || c >= 97 && c <= 122) && c != 101 && c != 69 }
        func num() -> CGFloat? {
            skip()
            guard i < chars.count else { return nil }
            var j = i
            if chars[j] == 45 || chars[j] == 43 { j += 1 }
            var dot = false, digits = false
            while j < chars.count {
                let c = chars[j]
                if c >= 48 && c <= 57 { digits = true; j += 1 }
                else if c == 46 && !dot { dot = true; j += 1 }
                else if (c == 101 || c == 69) && digits { j += 1; if j < chars.count, chars[j] == 45 || chars[j] == 43 { j += 1 } }
                else { break }
            }
            guard digits else { return nil }
            let s = String(decoding: chars[i..<j], as: UTF8.self)
            i = j
            return CGFloat(Double(s) ?? 0)
        }
        func flag() -> Bool? {
            skip()
            guard i < chars.count else { return nil }
            let c = chars[i]
            if c == 48 || c == 49 { i += 1; return c == 49 }
            return nil
        }
        while true {
            skip()
            if i >= chars.count { break }
            if isCmd(chars[i]) { cmd = chars[i]; i += 1 }
            let rel = cmd >= 97
            let C = rel ? cmd - 32 : cmd
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { rel ? CGPoint(x: cur.x + x, y: cur.y + y) : CGPoint(x: x, y: y) }
            switch C {
            case 77: // M
                guard let x = num(), let y = num() else { i = chars.count; break }
                cur = pt(x, y); start = cur; p.move(to: cur)
                cmd = rel ? 108 : 76 // following pairs are line-tos
                lastCtrl = nil; lastQ = nil
            case 76:
                guard let x = num(), let y = num() else { i = chars.count; break }
                cur = pt(x, y); p.addLine(to: cur); lastCtrl = nil; lastQ = nil
            case 72:
                guard let x = num() else { i = chars.count; break }
                cur = CGPoint(x: rel ? cur.x + x : x, y: cur.y); p.addLine(to: cur); lastCtrl = nil; lastQ = nil
            case 86:
                guard let y = num() else { i = chars.count; break }
                cur = CGPoint(x: cur.x, y: rel ? cur.y + y : y); p.addLine(to: cur); lastCtrl = nil; lastQ = nil
            case 67:
                guard let x1 = num(), let y1 = num(), let x2 = num(), let y2 = num(), let x = num(), let y = num() else { i = chars.count; break }
                let c1 = pt(x1, y1), c2 = pt(x2, y2), e = pt(x, y)
                p.addCurve(to: e, control1: c1, control2: c2); cur = e; lastCtrl = c2; lastQ = nil
            case 83:
                guard let x2 = num(), let y2 = num(), let x = num(), let y = num() else { i = chars.count; break }
                let c1 = lastCtrl.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                let c2 = pt(x2, y2), e = pt(x, y)
                p.addCurve(to: e, control1: c1, control2: c2); cur = e; lastCtrl = c2; lastQ = nil
            case 81:
                guard let x1 = num(), let y1 = num(), let x = num(), let y = num() else { i = chars.count; break }
                let c = pt(x1, y1), e = pt(x, y)
                p.addQuadCurve(to: e, control: c); cur = e; lastQ = c; lastCtrl = nil
            case 84:
                guard let x = num(), let y = num() else { i = chars.count; break }
                let c = lastQ.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                let e = pt(x, y)
                p.addQuadCurve(to: e, control: c); cur = e; lastQ = c; lastCtrl = nil
            case 65:
                guard let rx = num(), let ry = num(), let rot = num(), let large = flag(), let sweep = flag(), let x = num(), let y = num() else { i = chars.count; break }
                let e = pt(x, y)
                arc(&p, from: cur, to: e, rx: abs(rx), ry: abs(ry), phiDeg: rot, large: large, sweep: sweep)
                cur = e; lastCtrl = nil; lastQ = nil
            case 90:
                p.closeSubpath(); cur = start; lastCtrl = nil; lastQ = nil
            default:
                i += 1
            }
        }
        return p
    }

    private static func arc(_ p: inout Path, from a: CGPoint, to b: CGPoint, rx rx0: CGFloat, ry ry0: CGFloat, phiDeg: CGFloat, large: Bool, sweep: Bool) {
        if rx0 == 0 || ry0 == 0 || a == b { p.addLine(to: b); return }
        let phi = phiDeg * .pi / 180, cp = cos(phi), sp = sin(phi)
        let dx = (a.x - b.x) / 2, dy = (a.y - b.y) / 2
        let x1 = cp * dx + sp * dy, y1 = -sp * dx + cp * dy
        var rx = rx0, ry = ry0
        let lam = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
        if lam > 1 { rx *= sqrt(lam); ry *= sqrt(lam) }
        let num = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
        let den = rx * rx * y1 * y1 + ry * ry * x1 * x1
        var co = sqrt(max(0, num / den))
        if large == sweep { co = -co }
        let cx1 = co * rx * y1 / ry, cy1 = -co * ry * x1 / rx
        let cx = cp * cx1 - sp * cy1 + (a.x + b.x) / 2, cy = sp * cx1 + cp * cy1 + (a.y + b.y) / 2
        func ang(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let d = (ux * vx + uy * vy) / (sqrt(ux * ux + uy * uy) * sqrt(vx * vx + vy * vy))
            let s: CGFloat = (ux * vy - uy * vx) < 0 ? -1 : 1
            return s * acos(min(1, max(-1, d)))
        }
        let t1 = ang(1, 0, (x1 - cx1) / rx, (y1 - cy1) / ry)
        var dt = ang((x1 - cx1) / rx, (y1 - cy1) / ry, (-x1 - cx1) / rx, (-y1 - cy1) / ry)
        if !sweep && dt > 0 { dt -= 2 * .pi } else if sweep && dt < 0 { dt += 2 * .pi }
        let n = max(4, Int(abs(dt) / (.pi / 16)))
        for k in 1...n {
            let t = t1 + dt * CGFloat(k) / CGFloat(n)
            let x = cx + rx * cos(t) * cp - ry * sin(t) * sp
            let y = cy + rx * cos(t) * sp + ry * sin(t) * cp
            p.addLine(to: CGPoint(x: x, y: y))
        }
    }
}

/// Icon paths used across the app (copied from the demo).
enum Ico {
    static let reception = "M3 21V9.5L12 4l9 5.5V21 M9 21v-6h6v6"
    static let calendar = "M6 5h12a3 3 0 0 1 3 3v10a3 3 0 0 1-3 3H6a3 3 0 0 1-3-3V8a3 3 0 0 1 3-3z M8 3v4M16 3v4M3 10h18 M7.5 14h2M11 14h2M14.5 14h2M7.5 17.5h2M11 17.5h2"
    static let patients = "M12 4a4 4 0 1 1 0 8a4 4 0 1 1 0-8z M4 21c1.5-4 4.5-6 8-6s6.5 2 8 6"
    static let labs = "M9 3h6 M10 3v6L4.5 18.5A2 2 0 0 0 6.2 21.5h11.6a2 2 0 0 0 1.7-3L14 9V3 M7 15h10"
    static let payments = "M3 6h18v12H3z M3 10h18 M7 15h4"
    static let todo = "M9 6h11M9 12h11M9 18h11 M3.5 6.5l1.5 1.5 2.5-3 M3.5 12.5l1.5 1.5 2.5-3 M5 17a1.5 1.5 0 1 1 0 3a1.5 1.5 0 1 1 0-3z"
    static let bell = "M6 9a6 6 0 1 1 12 0c0 6.5 2.5 8 2.5 8h-17S6 15.5 6 9z M10 20.5a2.2 2.2 0 0 0 4 0"
    static let switchUser = "M16 17l5-5-5-5 M21 12H9 M12 21H6a3 3 0 0 1-3-3V6a3 3 0 0 1 3-3h6"
    static let plus = "M12 5v14M5 12h14"
    static let search = "M11 4a7 7 0 1 1 0 14a7 7 0 1 1 0-14z M20 20l-3.5-3.5"
    static let close = "M6 6l12 12M18 6L6 18"
    static let check = "M5 12l5 5L20 7"
    static let chevronL = "M15 18l-6-6 6-6"
    static let chevronR = "M9 18l6-6-6-6"
    static let chevronD = "M6 9l6 6 6-6"
    static let whatsapp = "M4 20l1.4-4.1A8 8 0 1 1 8.3 18.7z M9 9.5c.3 1.9 1.8 3.8 4 4.6l1.2-1.1 1.8.8-.3 1.6c-3.6.2-7.2-3.3-7.5-6.9l1.6-.3.8 1.8z"
    static let phone = "M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2"
    static let newPatient = "M10 11a4 4 0 1 0 0-8a4 4 0 0 0 0 8z M3 21c0-3.9 3.1-7 7-7c1.3 0 2.5.3 3.5.9 M18 14v7 M14.5 17.5h7"
    static let cancelCal = "M4 5h16v15H4z M4 10h16 M10 13l4 4 M14 13l-4 4"
    static let edit = "M12 20h9 M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z"
    static let measure = "M3 17L17 3l4 4L7 21z M7 13l2 2M10 10l2 2M13 7l2 2"
    static let angle = "M4 20L20 4 M4 20h16 M9 20a5 5 0 0 0-1.5-3.5"
    static let arrow = "M5 19L19 5 M10 5h9v9"
    static let pen = "M12 20h9 M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z"
    static let text = "M5 7V4h14v3 M12 4v16 M9 20h6"
    static let zoom = "M11 4a7 7 0 1 0 0 14a7 7 0 1 0 0-14 M21 21l-5-5 M11 8v6 M8 11h6"
    static let rotate = "M20 12a8 8 0 1 1-2.3-5.6 M20 4v5h-5"
    static let invert = "M12 3a9 9 0 1 0 0 18z M12 3a9 9 0 1 1 0 18"
    static let sun = "M12 8a4 4 0 1 1 0 8a4 4 0 1 1 0-8z M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"
    static let trash = "M4 7h16 M9 7V4h6v3 M6 7l1 13h10l1-13"
    static let undo = "M9 14L4 9l5-5 M4 9h11a5 5 0 0 1 0 10h-3"
    static let gift = "M3 9h18v4H3z M5 13h14v8H5z M12 9v12 M12 9c-2-4-6-4-6-1.5S9 9 12 9z M12 9c2-4 6-4 6-1.5S15 9 12 9z"
    static let tooth = "M7 3c-2.5 0-4 2-4 5 0 4 2 5 2.5 9 .3 2.5 1 4 2.2 4 1.6 0 1.6-5 4.3-5s2.7 5 4.3 5c1.2 0 1.9-1.5 2.2-4 .5-4 2.5-5 2.5-9 0-3-1.5-5-4-5-2 0-3 1-5 1s-3-1-5-1z"
    static let xray = "M8 3h8a3 3 0 0 1 3 3v12a3 3 0 0 1-3 3H8a3 3 0 0 1-3-3V6a3 3 0 0 1 3-3z M9 8h6M9 12h6"
    static let clock = "M12 3a9 9 0 1 1 0 18a9 9 0 1 1 0-18z M12 7v5l3 2"
    static let room = "M4 21V5a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v16 M2 21h20 M14 12h.01"
    static let sofa = "M4 11V8a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v3 M2 13a2 2 0 0 1 4 0v2h12v-2a2 2 0 0 1 4 0v5H2z M5 18v2M19 18v2"
    static let cash = "M3 7h18v12H3z M3 11h18 M8 3h8v4H8z"
    static let chart = "M4 20V10 M10 20V4 M16 20v-7 M22 20H2"
    static let lab = "M9 3h6 M10 3v6L4.5 18.5A2 2 0 0 0 6.2 21.5h11.6a2 2 0 0 0 1.7-3L14 9V3 M7 15h10"
    static let file = "M6 3h9l4 4v14H6z M14 3v5h5 M9 12h7 M9 16h5"
    static let alert = "M12 3l9.5 17h-19z M12 10v4 M12 17h.01"
    static let more = "M5 12h.01 M12 12h.01 M19 12h.01"
    static let sidebar = "M4 4h16v16H4z M9 4v16"
    static let move = "M5 9l-3 3 3 3 M9 5l3-3 3 3 M15 19l-3 3-3-3 M19 9l3 3-3 3 M2 12h20 M12 2v20"
    static let walk = "M13 4a2 2 0 1 1 0 4a2 2 0 1 1 0-4z M9 21l3-7 3 3v5 M7 12l3-3 4 1 3 3"
    static let back = "M10 19l-7-7 7-7 M3 12h18"
    static let face = "M8 3H5a2 2 0 0 0-2 2v3 M16 3h3a2 2 0 0 1 2 2v3 M8 21H5a2 2 0 0 1-2-2v-3 M16 21h3a2 2 0 0 0 2-2v-3 M9 9v1 M15 9v1 M12 9v4h-1 M9 16c1.7 1.3 4.3 1.3 6 0"
}
