import SwiftUI

struct DentalChartCard: View {
    @Environment(Store.self) private var store
    let p: Patient
    @Binding var sel: String?
    var body: some View {
        let M = store.marks(p)
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionTitle(text: "Dental chart", sub: "Tap a tooth")
                Spacer()
                legend
            }
            VStack(spacing: 6) {
                jaw(Catalog.upper, upper: true, M)
                Rectangle().fill(RX.line2).frame(height: 1).padding(.horizontal, 6)
                jaw(Catalog.lower, upper: false, M)
            }
            .padding(.vertical, 6)
        }
        .padding(16)
        .rxCard(22)
    }

    private var legend: some View {
        HStack(spacing: 10) {
            ForEach([("Filling", Color(rgb: 0x7FC8FF)), ("Root canal", Color(rgb: 0xFF9A8E)), ("Crown", RX.gold), ("Implant", Color(rgb: 0x6FA0E8))], id: \.0) { it in
                HStack(spacing: 4) { RoundedRectangle(cornerRadius: 2).fill(it.1).frame(width: 9, height: 9); Text(it.0).font(.rx(11)).foregroundStyle(RX.ink3) }
            }
        }
    }

    private func jaw(_ teeth: [String], upper: Bool, _ M: [String: (flags: Set<Catalog.Flag>, surf: [String])]) -> some View {
        HStack(spacing: 2) {
            ForEach(teeth, id: \.self) { n in
                let st = p.chart[n] ?? ToothState()
                let m = M[n]
                let bridged = p.procs.contains { $0.type == "bridge" && $0.status != .plan && $0.teeth.count > 1 && $0.teeth.contains(n) && $0.teeth.contains(nextTooth(n, teeth)) }
                Button { withAnimation(.spring(duration: 0.3)) { sel = sel == n ? nil : n }; Haptics.tap() } label: {
                    ToothGlyph(number: n, upper: upper, flags: m?.flags ?? [], surf: m?.surf ?? [], missing: st.missing, tagged: !st.tags.isEmpty, selected: sel == n)
                }
                .buttonStyle(.plain)
                .overlay(alignment: .trailing) {
                    if bridged { Capsule().fill(RX.gold).frame(width: 8, height: 4).offset(x: 5, y: upper ? 12 : -12) }
                }
                .accessibilityLabel("Tooth \(n)")
            }
        }
    }

    private func nextTooth(_ n: String, _ row: [String]) -> String {
        guard let i = row.firstIndex(of: n), i + 1 < row.count else { return "" }
        return row[i + 1]
    }
}

/// A tooth drawn like the demo's chart: crown, roots, and the marks on it.
struct ToothGlyph: View {
    let number: String
    let upper: Bool
    let flags: Set<Catalog.Flag>
    let surf: [String]
    let missing: Bool
    let tagged: Bool
    let selected: Bool

    var body: some View {
        VStack(spacing: 4) {
            if !upper { Text(number).font(.rx(11, .semibold)).foregroundStyle(selected ? RX.mintLight : RX.ink3) }
            Canvas { ctx, size in draw(&ctx, size) }
                .frame(minWidth: 26, maxWidth: 56).aspectRatio(0.5, contentMode: .fit)
            surfaces.frame(width: 26, height: 26)
            if upper { Text(number).font(.rx(11, .semibold)).foregroundStyle(selected ? RX.mintLight : RX.ink3) }
        }
        .padding(.vertical, 6).padding(.horizontal, 2)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(selected ? RX.mint.opacity(0.16) : .clear))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(selected ? RX.mint : .clear, lineWidth: 1.5))
        .overlay(alignment: .top) { if tagged { Circle().fill(RX.amber).frame(width: 6, height: 6).offset(y: 2) } }
        .contentShape(Rectangle())
    }

    private var isMolar: Bool { Int(String(number.last!)) ?? 1 >= 6 }
    private var roots: Int { let t = Int(String(number.last!)) ?? 1; return t >= 6 ? (upper ? 3 : 2) : (t == 4 && upper ? 2 : 1) }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height
        // crown occupies the chewing end, roots the other
        let crownH = h * 0.36, crownY = upper ? h - crownH : 0
        let crownRect = CGRect(x: w * 0.08, y: crownY, width: w * 0.84, height: crownH)
        let rootTop = upper ? crownY : crownH, rootLen = h - crownH
        var rootsPath = Path()
        let neck = w * 0.68, r = roots
        for k in 0..<r {
            let x1 = (w - neck) / 2 + neck * CGFloat(k) / CGFloat(r), x2 = x1 + neck / CGFloat(r)
            let tipX = (x1 + x2) / 2 + (CGFloat(k) - CGFloat(r - 1) / 2) * w * 0.06
            let tipY = upper ? rootTop - rootLen * 0.96 : rootTop + rootLen * 0.96
            rootsPath.move(to: CGPoint(x: x1 + 1, y: rootTop))
            rootsPath.addQuadCurve(to: CGPoint(x: tipX, y: tipY), control: CGPoint(x: x1 + (x2 - x1) * 0.15, y: (rootTop + tipY) / 2))
            rootsPath.addQuadCurve(to: CGPoint(x: x2 - 1, y: rootTop), control: CGPoint(x: x2 - (x2 - x1) * 0.15, y: (rootTop + tipY) / 2))
            rootsPath.closeSubpath()
        }
        let crownPath = Path(roundedRect: crownRect, cornerSize: CGSize(width: w * (isMolar ? 0.22 : 0.3), height: crownH * 0.4))
        let base = Color(rgb: 0xE9F2EE, missing ? 0.12 : 0.9)
        if flags.contains(.implant) {
            // implant: wide blue screw instead of roots
            let sw = w * 0.42, sx = (w - sw) / 2
            var screw = Path()
            let top = upper ? rootTop - rootLen * 0.9 : rootTop
            screw.addRoundedRect(in: CGRect(x: sx, y: top, width: sw, height: rootLen * 0.9), cornerSize: CGSize(width: sw * 0.3, height: sw * 0.3))
            ctx.fill(screw, with: .color(Color(rgb: 0x6FA0E8)))
            for i in 0..<6 {
                let y = top + rootLen * 0.9 * (CGFloat(i) + 0.5) / 6
                var t = Path(); t.move(to: CGPoint(x: sx - 3, y: y)); t.addLine(to: CGPoint(x: sx + sw + 3, y: y))
                ctx.stroke(t, with: .color(Color(rgb: 0xA9C6F2)), lineWidth: 1.6)
            }
        } else {
            ctx.fill(rootsPath, with: .color(base.opacity(missing ? 1 : 0.78)))
            ctx.stroke(rootsPath, with: .color(Color(rgb: 0x9FBAB2, 0.5)), lineWidth: 0.8)
        }
        ctx.fill(crownPath, with: .color(base))
        ctx.stroke(crownPath, with: .color(Color(rgb: 0x9FBAB2, 0.5)), lineWidth: 0.8)
        if flags.contains(.rct) || flags.contains(.retx) {
            let c = flags.contains(.retx) ? Color(rgb: 0xE8AA5A) : Color(rgb: 0xFF6B5E)
            for k in 0..<r {
                let x1 = (w - neck) / 2 + neck * CGFloat(k) / CGFloat(r), x2 = x1 + neck / CGFloat(r)
                let tipX = (x1 + x2) / 2 + (CGFloat(k) - CGFloat(r - 1) / 2) * w * 0.06
                var l = Path()
                l.move(to: CGPoint(x: (x1 + x2) / 2, y: upper ? rootTop + crownH * 0.2 : rootTop - crownH * 0.2))
                l.addLine(to: CGPoint(x: tipX, y: upper ? rootTop - rootLen * 0.88 : rootTop + rootLen * 0.88))
                ctx.stroke(l, with: .color(c), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            }
        }
        if flags.contains(.crown) || flags.contains(.implant) {
            ctx.fill(crownPath, with: .color(RX.gold.opacity(flags.contains(.implant) ? 0.75 : 0.9)))
            ctx.stroke(crownPath, with: .color(Color(rgb: 0xF3D9B5)), lineWidth: 1.2)
        }
        if flags.contains(.veneer) {
            let f = Path(roundedRect: crownRect.insetBy(dx: w * 0.05, dy: crownH * 0.08), cornerSize: CGSize(width: w * 0.25, height: crownH * 0.35))
            ctx.fill(f, with: .color(Color(rgb: 0xFBF3EA)))
            ctx.stroke(f, with: .color(Color(rgb: 0xF2A7D0)), lineWidth: 1.8)
        }
        if missing {
            var x = Path(); x.move(to: CGPoint(x: w * 0.15, y: h * 0.25)); x.addLine(to: CGPoint(x: w * 0.85, y: h * 0.75)); x.move(to: CGPoint(x: w * 0.85, y: h * 0.25)); x.addLine(to: CGPoint(x: w * 0.15, y: h * 0.75))
            ctx.stroke(x, with: .color(RX.ink4), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }

    /// The five-surface square (M O D B L) under the tooth.
    private var surfaces: some View {
        let fill = Color(rgb: 0x7FC8FF)
        return Canvas { ctx, s in
            let w = s.width, c = CGRect(x: w * 0.3, y: w * 0.3, width: w * 0.4, height: w * 0.4)
            func poly(_ pts: [CGPoint]) -> Path { var p = Path(); p.addLines(pts); p.closeSubpath(); return p }
            let tl = CGPoint(x: 0, y: 0), tr = CGPoint(x: w, y: 0), br = CGPoint(x: w, y: w), bl = CGPoint(x: 0, y: w)
            let parts: [(String, Path)] = [
                ("B", poly([tl, tr, CGPoint(x: c.maxX, y: c.minY), CGPoint(x: c.minX, y: c.minY)])),
                ("L", poly([bl, br, CGPoint(x: c.maxX, y: c.maxY), CGPoint(x: c.minX, y: c.maxY)])),
                ("M", poly([tl, bl, CGPoint(x: c.minX, y: c.maxY), CGPoint(x: c.minX, y: c.minY)])),
                ("D", poly([tr, br, CGPoint(x: c.maxX, y: c.maxY), CGPoint(x: c.maxX, y: c.minY)])),
                ("O", Path(c)),
            ]
            for (k, pth) in parts {
                ctx.fill(pth, with: .color(surf.contains(k) ? fill : Color(rgb: 0x153A33)))
                ctx.stroke(pth, with: .color(Color(rgb: 0x0A211D)), lineWidth: 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .opacity(missing ? 0.3 : 1)
    }
}

// MARK: - Tooth panel

struct TeethInspector: View {
    @Environment(Store.self) private var store
    let p: Patient
    @Binding var sel: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let n = sel {
                let M = store.marks(p)[n]
                let st = p.chart[n] ?? ToothState()
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tooth \(n)").font(.rx(22, .bold))
                        Text(Catalog.toothName(n)).font(.rx(13)).foregroundStyle(RX.ink3)
                    }
                    Spacer()
                    IconButton(icon: Ico.close, size: 34, label: "Close") { sel = nil }
                }
                let procs = p.procs.filter { $0.teeth.contains(n) }
                if !procs.isEmpty || !st.tags.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(procs) { r in Chip(text: Catalog.typeName(r.type) + (r.surf.isEmpty ? "" : " " + r.surf.joined()) + " · " + r.status.label, color: r.status.color, size: 11.5) }
                        ForEach(st.tags, id: \.self) { Chip(text: $0, color: RX.amber, size: 11.5) }
                    }
                }
                Text("TREATMENT").font(.rx(11, .semibold)).tracking(0.8).foregroundStyle(RX.ink4)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    toggle("Root canal", on: M?.flags.contains(.rct) ?? false, c: RX.salmon) { store.toggleMark(p.id, tooth: n, .rct) }
                    toggle("Retreatment", on: M?.flags.contains(.retx) ?? false, c: RX.amber) { store.toggleMark(p.id, tooth: n, .retx) }
                    toggle("Crown", on: M?.flags.contains(.crown) ?? false, c: RX.gold) { store.toggleMark(p.id, tooth: n, .crown) }
                    toggle("Veneer", on: M?.flags.contains(.veneer) ?? false, c: Color(rgb: 0xF2A7D0)) { store.toggleMark(p.id, tooth: n, .veneer) }
                    toggle("Implant", on: M?.flags.contains(.implant) ?? false, c: Color(rgb: 0x6FA0E8)) { store.toggleMark(p.id, tooth: n, .implant) }
                    toggle("Missing", on: st.missing, c: RX.ink3) { store.setTooth(p.id, n) { $0.missing.toggle() }; Haptics.tap() }
                }
                Text("FILLING SURFACES").font(.rx(11, .semibold)).tracking(0.8).foregroundStyle(RX.ink4)
                HStack(spacing: 6) {
                    ForEach(Catalog.surfOrder, id: \.self) { s in
                        let on = M?.surf.contains(s) ?? false
                        Button {
                            var cur = M?.surf ?? []
                            if on { cur.removeAll { $0 == s } } else { cur.append(s) }
                            store.setSurfaces(p.id, tooth: n, cur)
                        } label: {
                            Text(s).font(.rx(15, .bold)).foregroundStyle(on ? RX.onMint : RX.ink2)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(RoundedRectangle(cornerRadius: 11).fill(on ? Color(rgb: 0x7FC8FF) : RX.card2))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("ISSUES & NOTES").font(.rx(11, .semibold)).tracking(0.8).foregroundStyle(RX.ink4)
                FlowLayout(spacing: 6) {
                    ForEach(Catalog.toothTags, id: \.self) { t in
                        let on = st.tags.contains(t)
                        Button { store.setTooth(p.id, n) { s in if on { s.tags.removeAll { $0 == t } } else { s.tags.append(t) } }; Haptics.tap() } label: {
                            Text(t).font(.rx(12.5, .semibold)).foregroundStyle(on ? RX.onMint : RX.ink2).padding(.horizontal, 10).padding(.vertical, 7).background(Capsule().fill(on ? RX.amber : RX.card2))
                        }
                        .buttonStyle(.plain)
                    }
                }
                TextField("", text: Binding(get: { st.note }, set: { v in store.setTooth(p.id, n) { $0.note = v } }), prompt: Text("Note for this tooth").foregroundStyle(RX.ink4), axis: .vertical)
                    .font(.rx(14)).lineLimit(2...5).padding(12).rxPanel(12)
            } else {
                VStack(spacing: 10) {
                    Icon(d: Ico.tooth, size: 34, weight: 1.6).foregroundStyle(RX.ink4)
                    Text("Tap a tooth on the chart").font(.rx(14, .semibold)).foregroundStyle(RX.ink3)
                    Text("Treatments you set here add a procedure, and removing one takes it off the chart. Everything stays linked.").font(.rx(12.5)).foregroundStyle(RX.ink4).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 40)
            }
        }
        .padding(16)
        .rxCard(22)
    }

    private func toggle(_ t: String, on: Bool, c: Color, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            HStack(spacing: 8) {
                Circle().fill(c).frame(width: 9, height: 9)
                Text(t).font(.rx(13.5, .semibold)).foregroundStyle(on ? RX.ink : RX.ink2)
                Spacer(minLength: 0)
                if on { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(c) }
            }
            .padding(.horizontal, 12).frame(minHeight: 46)
            .background(RoundedRectangle(cornerRadius: 12).fill(on ? c.opacity(0.16) : RX.card2))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(on ? c.opacity(0.8) : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}
