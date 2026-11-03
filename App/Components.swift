import SwiftUI

// MARK: - Avatars

struct MemberAvatar: View {
    let m: Member?
    var size: CGFloat = 32
    var ring: Bool = false
    var body: some View {
        ZStack {
            Circle().fill(m?.color ?? RX.ink4)
            Text(m?.initials ?? "?").font(.rx(size * 0.4, .bold)).foregroundStyle(RX.onMint)
        }
        .frame(width: size, height: size)
        .overlay { if ring { Circle().strokeBorder(RX.mint.opacity(0.6), lineWidth: 1.5).padding(-3.5) } }
        .accessibilityLabel(m?.full ?? "")
    }
}

struct PatientIcon: View {
    let p: Patient?
    var size: CGFloat = 40
    var body: some View {
        Image(p?.iconName ?? "pi_person").resizable().interpolation(.high).scaledToFill()
            .frame(width: size, height: size).background(RX.mintPale).clipShape(Circle())
            .overlay(alignment: .topTrailing) {
                if p?.hasAlert == true { Circle().fill(RX.red).frame(width: size * 0.24, height: size * 0.24).overlay(Circle().stroke(RX.bg, lineWidth: 2)) }
            }
    }
}

// MARK: - Buttons

struct MintButton: ButtonStyle {
    var compact = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rx(compact ? 13 : 15, .bold)).foregroundStyle(RX.onMint)
            .padding(.horizontal, compact ? 13 : 18).padding(.vertical, compact ? 9 : 12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(RX.mint))
            .scaleEffect(configuration.isPressed ? 0.96 : 1).opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

struct SoftButton: ButtonStyle {
    var compact = false
    var tint: Color = RX.ink
    var fill: Color = RX.card2
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rx(compact ? 13 : 15, .semibold)).foregroundStyle(tint)
            .padding(.horizontal, compact ? 12 : 16).padding(.vertical, compact ? 8 : 12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(fill))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

struct IconButton: View {
    let icon: String
    var size: CGFloat = 36
    var fill: Color = RX.card2
    var tint: Color = RX.ink2
    var label: String = ""
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Icon(d: icon, size: size * 0.44, weight: 2.2).foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(RoundedRectangle(cornerRadius: size * 0.31, style: .continuous).fill(fill))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .frame(minWidth: 44, minHeight: 44)
    }
}

/// Top-right round X used on every pop-up (as in the demo).
struct CloseX: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Icon(d: Ico.close, size: 13, weight: 3).foregroundStyle(RX.ink)
                .frame(width: 34, height: 34)
                .glassEffect(.regular.tint(RX.card3.opacity(0.7)).interactive(), in: .circle)
        }
        .buttonStyle(.plain).accessibilityLabel("Close")
        .frame(width: 44, height: 44)
    }
}

// MARK: - Chips and small parts

struct Chip: View {
    let text: String
    var color: Color = RX.ink2
    var fill: Color? = nil
    var size: CGFloat = 12
    var body: some View {
        Text(text).font(.rx(size, .semibold)).foregroundStyle(color).lineLimit(1)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Capsule().fill(fill ?? color.opacity(0.16)))
    }
}

struct Badge: View {
    let n: Int
    var fill: Color = RX.red
    var ink: Color = .white
    var body: some View {
        Text("\(n)").font(.rx(11, .bold)).foregroundStyle(ink)
            .frame(minWidth: 22, minHeight: 22).padding(.horizontal, n > 9 ? 4 : 0)
            .background(Capsule().fill(fill))
    }
}

struct SegmentPicker<T: Hashable>: View {
    let items: [(T, String)]
    @Binding var sel: T
    var counts: [T: Int] = [:]
    var body: some View {
        HStack(spacing: 2) {
            ForEach(items, id: \.0) { item in
                let k = item.0, l = item.1
                let on = sel == k
                Button { withAnimation(.spring(duration: 0.35)) { sel = k }; Haptics.tap() } label: {
                    HStack(spacing: 6) {
                        Text(l).font(.rx(13, .semibold))
                        if let n = counts[k] { Text("\(n)").font(.rx(11, .medium)).foregroundStyle(on ? RX.ink3 : RX.ink4) }
                    }
                    .foregroundStyle(on ? RX.ink : RX.ink3)
                    .padding(.horizontal, 13).padding(.vertical, 8)
                    .background { if on { RoundedRectangle(cornerRadius: 9, style: .continuous).fill(RX.card3) } }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(RX.card))
    }
}

/// Wraps chips onto several lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineH: CGFloat = 0, maxW: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > 0 && x + sz.width > w { x = 0; y += lineH + lineSpacing; lineH = 0 }
            x += sz.width + spacing; lineH = max(lineH, sz.height); maxW = max(maxW, x - spacing)
        }
        return CGSize(width: min(w, maxW), height: y + lineH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > bounds.minX && x + sz.width > bounds.maxX { x = bounds.minX; y += lineH + lineSpacing; lineH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing; lineH = max(lineH, sz.height)
        }
    }
}

struct RXField: View {
    let label: String
    @Binding var text: String
    var placeholder = ""
    var keyboard: UIKeyboardType = .default
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !label.isEmpty { Text(label).font(.rx(12)).foregroundStyle(RX.ink3) }
            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(RX.ink4))
                .font(.rx(15)).foregroundStyle(RX.ink)
                .keyboardType(keyboard)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(RX.card2))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(RX.line, lineWidth: 1))
        }
    }
}

/// The demo's dark dropdown (".rx-sel") as a touch menu.
struct RXSelect<T: Hashable>: View {
    let options: [(T, String)]
    @Binding var sel: T
    var placeholder = "Choose"
    var width: CGFloat? = nil
    var body: some View {
        Menu {
            ForEach(options, id: \.0) { item in
                let k = item.0, l = item.1
                Button { sel = k; Haptics.tap() } label: { if k == sel { Label(l, systemImage: "checkmark") } else { Text(l) } }
            }
        } label: {
            HStack(spacing: 8) {
                Text(options.first { $0.0 == sel }?.1 ?? placeholder).font(.rx(14, .medium)).foregroundStyle(RX.ink).lineLimit(1)
                Spacer(minLength: 4)
                Icon(d: Ico.chevronD, size: 11, weight: 3).foregroundStyle(RX.ink3)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(width: width)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(RX.card2))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(RX.line2, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SectionTitle: View {
    let text: String
    var sub: String = ""
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(text).font(.rx(15, .semibold)).foregroundStyle(RX.ink)
            if !sub.isEmpty { Text(sub).font(.rx(12)).foregroundStyle(RX.ink3) }
        }
    }
}

struct EmptyNote: View {
    let text: String
    var body: some View { Text(text).font(.rx(14)).foregroundStyle(RX.ink4).frame(maxWidth: .infinity).padding(30) }
}

/// Sheet chrome from the demo: Close · title · primary action, plus the round X.
struct SheetHeader: View {
    let title: String
    var primary: String? = nil
    var primaryOn = true
    var close: () -> Void
    var action: () -> Void = {}
    var body: some View {
        HStack {
            Button("Close", action: close).font(.rx(15)).foregroundStyle(RX.ink3).buttonStyle(.plain).frame(minWidth: 60, alignment: .leading)
            Spacer()
            Text(title).font(.rx(17, .semibold)).foregroundStyle(RX.ink)
            Spacer()
            if let primary {
                Button(primary, action: action)
                    .font(.rx(15, .bold)).foregroundStyle(primaryOn ? RX.onMint : RX.ink4)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(primaryOn ? RX.mint : RX.card2))
                    .buttonStyle(.plain).disabled(!primaryOn)
            } else { Color.clear.frame(width: 60, height: 1) }
        }
        .padding(.horizontal, 22).padding(.vertical, 16)
        .overlay(alignment: .bottom) { Rectangle().fill(RX.line).frame(height: 1) }
    }
}

extension View {
    /// Dark sheet background matching the demo, with the round X in the corner.
    func rxSheet(close: @escaping () -> Void) -> some View {
        self.background(RX.sheet)
            .overlay(alignment: .topTrailing) { CloseX(action: close).padding(6) }
            .presentationBackground(RX.sheet)
            .presentationCornerRadius(28)
    }
}

// MARK: - Toast + banner

struct ToastView: View {
    @Environment(Store.self) private var store
    var body: some View {
        if let t = store.toast {
            HStack(spacing: 12) {
                Text(t.text).font(.rx(13, .semibold)).foregroundStyle(RX.ink).lineLimit(2)
                if t.canUndo {
                    Button("Undo") { store.undo() }.font(.rx(13, .semibold)).foregroundStyle(RX.mintLight)
                        .padding(.horizontal, 12).padding(.vertical, 7).background(RoundedRectangle(cornerRadius: 10).fill(RX.card3)).buttonStyle(.plain)
                }
            }
            .padding(.leading, 16).padding(.trailing, 10).padding(.vertical, 10)
            .glassEffect(.regular.tint(RX.card2.opacity(0.75)), in: .rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(RX.mint.opacity(0.4), lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 30, y: 18)
            .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.96)))
            .id(t.id)
        }
    }
}

struct BannerView: View {
    @Environment(Store.self) private var store
    var body: some View {
        if let a = store.banner {
            Button {
                if let p = a.patient { store.section = .patients; store.openPatient = p }
                withAnimation { store.banner = nil }
            } label: {
                HStack(spacing: 12) {
                    MemberAvatar(m: store.member(a.by), size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.patient(a.patient)?.name ?? store.memberName(a.by)).font(.rx(14, .semibold)).foregroundStyle(RX.ink)
                        Text(a.text).font(.rx(12.5)).foregroundStyle(RX.ink3).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12).frame(maxWidth: 420)
                .glassEffect(.regular.tint(RX.card.opacity(0.7)).interactive(), in: .rect(cornerRadius: 20))
                .shadow(color: .black.opacity(0.45), radius: 24, y: 12)
            }
            .buttonStyle(.plain)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - Misc helpers

extension Store {
    func dentChip(_ id: String?) -> some View {
        let m = member(id)
        return HStack(spacing: 7) {
            MemberAvatar(m: m, size: 22)
            Text(m?.full ?? "").font(.rx(12, .semibold)).foregroundStyle(RX.ink)
        }
        .padding(.leading, 3).padding(.trailing, 10).padding(.vertical, 3)
        .background(Capsule().fill(RX.card2))
    }
}

func waitColor(_ min: Double) -> Color {
    let st: [(Double, (Double, Double, Double))] = [(0, (168, 235, 214)), (10, (95, 211, 180)), (20, (52, 195, 164)), (30, (33, 137, 111)), (40, (124, 122, 69)), (50, (181, 84, 62)), (60, (216, 68, 58))]
    let m = max(0, Swift.min(60, min))
    var i = 0
    while i < st.count - 2 && m > st[i + 1].0 { i += 1 }
    let (a0, c0) = st[i], (a1, c1) = st[i + 1], f = (m - a0) / (a1 - a0)
    return Color(.sRGB, red: (c0.0 + (c1.0 - c0.0) * f) / 255, green: (c0.1 + (c1.1 - c0.1) * f) / 255, blue: (c0.2 + (c1.2 - c0.2) * f) / 255, opacity: 1)
}

func clockText(_ s: TimeInterval) -> String {
    let t = max(0, Int(s)), h = t / 3600, m = (t % 3600) / 60, sec = t % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
}
