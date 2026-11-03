import SwiftUI
import PencilKit

struct XrayViewer: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let pid: String
    let xid: String

    enum Tool: String, CaseIterable { case move, measure, angle, arrow, text, pen
        var icon: String { switch self { case .move: Ico.move; case .measure: Ico.measure; case .angle: Ico.angle; case .arrow: Ico.arrow; case .text: Ico.text; case .pen: Ico.pen } }
        var label: String { switch self { case .move: "Move"; case .measure: "Measure"; case .angle: "Angle"; case .arrow: "Arrow"; case .text: "Text"; case .pen: "Draw" } }
    }

    @State private var tool: Tool = .move
    @State private var zoom: CGFloat = 1
    @State private var zoomStart: CGFloat?
    @State private var pan: CGSize = .zero
    @State private var panStart: CGSize?
    @State private var pending: [P2] = []
    @State private var textAt: P2?
    @State private var textValue = ""
    @State private var drawing = PKDrawing()
    @State private var showAdjust = true
    @State private var current: String = ""

    var body: some View {
        let p = store.patient(pid)
        let list = p?.xrays.sorted { $0.takenAt > $1.takenAt } ?? []
        let x = list.first { $0.id == (current.isEmpty ? xid : current) } ?? list.first
        ZStack {
            Color.black.ignoresSafeArea()
            if let x { canvas(x) }
            VStack {
                topBar(p, x, list)
                Spacer()
                if let x { bottomBar(x) }
            }
        }
        .statusBarHidden()
        .onAppear { current = xid; loadDrawing() }
        .alert("Text on the X-ray", isPresented: Binding(get: { textAt != nil }, set: { if !$0 { textAt = nil } })) {
            TextField("Text", text: $textValue)
            Button("Add") { if let at = textAt, !textValue.isEmpty { addMark(XMark(kind: .text, pts: [at], text: textValue)) }; textAt = nil; textValue = "" }
            Button("Cancel", role: .cancel) { textAt = nil }
        }
    }

    // MARK: image + marks

    private func canvas(_ x: Xray) -> some View {
        GeometryReader { g in
            let img = UIImage(named: x.image)
            let isz = img?.size ?? CGSize(width: 1200, height: 800)
            let rotated = x.rot % 2 != 0
            let fitW = rotated ? isz.height : isz.width, fitH = rotated ? isz.width : isz.height
            let s = min(g.size.width / fitW, (g.size.height - 40) / fitH)
            let w = isz.width * s, h = isz.height * s
            ZStack {
                Image(x.image).resizable().interpolation(.high)
                    .frame(width: w, height: h)
                    .brightness((x.bright - 100) / 200)
                    .contrast(x.contrast / 100)
                    .colorInvert(x.invert)
                MarksLayer(marks: x.marks, pending: pending, tool: tool, size: CGSize(width: w, height: h), imgPx: isz, pixelMM: x.pixelMM)
                    .frame(width: w, height: h)
                    .allowsHitTesting(false)
                PencilLayer(drawing: $drawing, active: tool == .pen) { saveDrawing() }
                    .frame(width: w, height: h)
                    .allowsHitTesting(tool == .pen)
                if tool != .move && tool != .pen {
                    Color.clear.contentShape(Rectangle()).frame(width: w, height: h)
                        .onTapGesture { loc in tap(P2(Double(loc.x / w), Double(loc.y / h))) }
                }
            }
            .rotationEffect(.degrees(Double(x.rot) * 90))
            .scaleEffect(zoom)
            .offset(pan)
            .frame(width: g.size.width, height: g.size.height)
            .contentShape(Rectangle())
            .gesture(SimultaneousGesture(
                MagnifyGesture().onChanged { v in if zoomStart == nil { zoomStart = zoom }; zoom = min(8, max(1, (zoomStart ?? 1) * v.magnification)) }.onEnded { _ in zoomStart = nil; if zoom <= 1.01 { withAnimation(.spring) { pan = .zero } } },
                DragGesture(minimumDistance: tool == .move ? 4 : 30).onChanged { v in if panStart == nil { panStart = pan }; pan = CGSize(width: (panStart?.width ?? 0) + v.translation.width, height: (panStart?.height ?? 0) + v.translation.height) }.onEnded { _ in panStart = nil }
            ), including: tool == .pen ? .subviews : .all)
            .onTapGesture(count: 2) { withAnimation(.spring(duration: 0.4)) { if zoom > 1.1 { zoom = 1; pan = .zero } else { zoom = 2.5 } } }
        }
    }

    private func tap(_ pt: P2) {
        Haptics.tap()
        switch tool {
        case .measure:
            pending.append(pt)
            if pending.count == 2 { addMark(XMark(kind: .measure, pts: pending)); pending = [] }
        case .arrow:
            pending.append(pt)
            if pending.count == 2 { addMark(XMark(kind: .arrow, pts: pending)); pending = [] }
        case .angle:
            pending.append(pt)
            if pending.count == 3 { addMark(XMark(kind: .angle, pts: pending)); pending = [] }
        case .text:
            textAt = pt
        default: break
        }
    }

    private func addMark(_ m: XMark) {
        updateX { $0.marks.append(m) }
        store.log("xray", m.kind == .measure ? "Measured on an X-ray" : "Marked an X-ray", patient: pid, notify: false)
    }

    private func updateX(_ f: (inout Xray) -> Void) {
        let id = current.isEmpty ? xid : current
        store.updatePatient(pid, nil, undo: false) { P in if let i = P.xrays.firstIndex(where: { $0.id == id }) { f(&P.xrays[i]) } }
    }

    private func loadDrawing() {
        let id = current.isEmpty ? xid : current
        if let d = store.patient(pid)?.xrays.first(where: { $0.id == id })?.drawing, let pk = try? PKDrawing(data: d) { drawing = pk } else { drawing = PKDrawing() }
    }
    private func saveDrawing() { let data = drawing.dataRepresentation(); updateX { $0.drawing = data } }

    // MARK: bars

    private func topBar(_ p: Patient?, _ x: Xray?, _ list: [Xray]) -> some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: { Label { Text("Done") } icon: { Icon(d: Ico.chevronL, size: 15, weight: 2.4) } }
                .font(.rx(15, .semibold)).foregroundStyle(RX.ink).buttonStyle(.plain)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .glassEffect(.regular.interactive(), in: .capsule)
            VStack(alignment: .leading, spacing: 1) {
                Text(p?.name ?? "").font(.rx(15, .semibold))
                if let x { Text(xLine(x)).font(.rx(12)).foregroundStyle(RX.ink3) }
            }
            .padding(.horizontal, 14).padding(.vertical, 6)
            .glassEffect(.regular, in: .capsule)
            Spacer()
            if list.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(list) { y in
                            Button { current = y.id; zoom = 1; pan = .zero; pending = []; loadDrawing() } label: {
                                Image(y.image).resizable().scaledToFill().frame(width: 58, height: 40).clipShape(RoundedRectangle(cornerRadius: 7))
                                    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(y.id == x?.id ? RX.mint : .clear, lineWidth: 2))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(6)
                }
                .frame(maxWidth: 380)
                .glassEffect(.regular, in: .rect(cornerRadius: 14))
            }
        }
        .padding(.horizontal, 16).padding(.top, 10)
    }

    private func bottomBar(_ x: Xray) -> some View {
        VStack(spacing: 10) {
            if showAdjust {
                HStack(spacing: 18) {
                    slider("Brightness", Ico.sun, x.bright) { v in updateX { $0.bright = v } }
                    slider("Contrast", Ico.invert, x.contrast) { v in updateX { $0.contrast = v } }
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .glassEffect(.regular, in: .rect(cornerRadius: 18))
                .frame(maxWidth: 620)
            }
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 6) {
                    ForEach(Tool.allCases, id: \.self) { t in
                        Button { tool = t; pending = []; Haptics.tap() } label: {
                            VStack(spacing: 3) {
                                Icon(d: t.icon, size: 19)
                                Text(t.label).font(.rx(10.5, .semibold))
                            }
                            .foregroundStyle(tool == t ? RX.onMint : RX.ink)
                            .frame(width: 62, height: 54)
                            .background { if tool == t { RoundedRectangle(cornerRadius: 14).fill(RX.mint) } }
                        }
                        .buttonStyle(.plain)
                    }
                    Divider().frame(height: 34).overlay(RX.line2)
                    toolBtn(Ico.rotate, "Rotate") { updateX { $0.rot = ($0.rot + 1) % 4 } }
                    toolBtn(Ico.invert, x.invert ? "Normal" : "Invert") { updateX { $0.invert.toggle() } }
                    toolBtn(Ico.sun, "Adjust") { withAnimation { showAdjust.toggle() } }
                    toolBtn(Ico.undo, "Undo mark") { updateX { if !$0.marks.isEmpty { $0.marks.removeLast() } } }
                    toolBtn(Ico.trash, "Clear") { updateX { $0.marks = []; $0.drawing = nil; $0.bright = 100; $0.contrast = 100; $0.invert = false; $0.rot = 0 }; drawing = PKDrawing() }
                }
                .padding(6)
                .glassEffect(.regular.tint(RX.card.opacity(0.35)), in: .rect(cornerRadius: 20))
            }
            Text(hint).font(.rx(12)).foregroundStyle(RX.ink3)
        }
        .padding(.bottom, 14).padding(.horizontal, 12)
    }

    private func xLine(_ x: Xray) -> String {
        let teeth: String = x.teeth.isEmpty ? "" : "Teeth \(x.teeth.joined(separator: " · ")) · "
        return "\(teeth)\(Day.dmy(x.takenAt)) · \(store.memberName(x.by))"
    }

    private var hint: String {
        switch tool {
        case .move: "Pinch to zoom · drag to move · double-tap to zoom"
        case .measure: pending.isEmpty ? "Tap the start point" : "Tap the end point"
        case .angle: ["Tap the first point", "Tap the corner", "Tap the last point"][min(2, pending.count)]
        case .arrow: pending.isEmpty ? "Tap where the arrow starts" : "Tap where it points"
        case .text: "Tap where the text goes"
        case .pen: "Draw with Apple Pencil or your finger"
        }
    }

    private func toolBtn(_ icon: String, _ l: String, _ a: @escaping () -> Void) -> some View {
        Button { a(); Haptics.tap() } label: {
            VStack(spacing: 3) { Icon(d: icon, size: 19); Text(l).font(.rx(10.5, .semibold)) }
                .foregroundStyle(RX.ink).frame(width: 62, height: 54)
        }
        .buttonStyle(.plain)
    }

    private func slider(_ l: String, _ icon: String, _ v: Double, _ set: @escaping (Double) -> Void) -> some View {
        HStack(spacing: 10) {
            Icon(d: icon, size: 16).foregroundStyle(RX.ink3)
            Text(l).font(.rx(12.5)).foregroundStyle(RX.ink3).frame(width: 74, alignment: .leading)
            Slider(value: Binding(get: { v }, set: { set($0.rounded()) }), in: 40...200).tint(RX.mint)
            Text("\(Int(v))%").font(.rx(12, .semibold)).monospacedDigit().frame(width: 44)
        }
    }
}

struct MarksLayer: View {
    let marks: [XMark]
    let pending: [P2]
    let tool: XrayViewer.Tool
    let size: CGSize
    let imgPx: CGSize
    let pixelMM: Double

    var body: some View {
        Canvas { ctx, s in
            func pt(_ p: P2) -> CGPoint { CGPoint(x: p.x * s.width, y: p.y * s.height) }
            let mint = Color(rgb: 0x34C3A4), amber = Color(rgb: 0xF3C98B)
            for m in marks {
                switch m.kind {
                case .measure where m.pts.count == 2:
                    let a = pt(m.pts[0]), b = pt(m.pts[1])
                    var l = Path(); l.move(to: a); l.addLine(to: b)
                    ctx.stroke(l, with: .color(mint), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    for e in [a, b] { ctx.fill(Path(ellipseIn: CGRect(x: e.x - 5, y: e.y - 5, width: 10, height: 10)), with: .color(mint)) }
                    let dx = (m.pts[1].x - m.pts[0].x) * imgPx.width, dy = (m.pts[1].y - m.pts[0].y) * imgPx.height
                    let mm = sqrt(dx * dx + dy * dy) * pixelMM
                    label(&ctx, String(format: "%.1f mm", mm), at: CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 - 16), mint)
                case .arrow where m.pts.count == 2:
                    let a = pt(m.pts[0]), b = pt(m.pts[1])
                    var l = Path(); l.move(to: a); l.addLine(to: b)
                    let ang = atan2(b.y - a.y, b.x - a.x), hl: CGFloat = 16
                    l.move(to: b); l.addLine(to: CGPoint(x: b.x - hl * cos(ang - .pi / 7), y: b.y - hl * sin(ang - .pi / 7)))
                    l.move(to: b); l.addLine(to: CGPoint(x: b.x - hl * cos(ang + .pi / 7), y: b.y - hl * sin(ang + .pi / 7)))
                    ctx.stroke(l, with: .color(amber), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                case .angle where m.pts.count == 3:
                    let a = pt(m.pts[0]), v = pt(m.pts[1]), b = pt(m.pts[2])
                    var l = Path(); l.move(to: a); l.addLine(to: v); l.addLine(to: b)
                    ctx.stroke(l, with: .color(Color(rgb: 0xC9A7FF)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    let a1 = atan2(Double((m.pts[0].y - m.pts[1].y) * imgPx.height), Double((m.pts[0].x - m.pts[1].x) * imgPx.width))
                    let a2 = atan2(Double((m.pts[2].y - m.pts[1].y) * imgPx.height), Double((m.pts[2].x - m.pts[1].x) * imgPx.width))
                    var deg = abs(a1 - a2) * 180 / .pi; if deg > 180 { deg = 360 - deg }
                    label(&ctx, String(format: "%.0f°", deg), at: CGPoint(x: v.x + 22, y: v.y - 18), Color(rgb: 0xC9A7FF))
                case .text where m.pts.count == 1:
                    label(&ctx, m.text, at: pt(m.pts[0]), .white)
                default: break
                }
            }
            for p in pending { let c = pt(p); ctx.fill(Path(ellipseIn: CGRect(x: c.x - 6, y: c.y - 6, width: 12, height: 12)), with: .color(mint)) }
        }
    }

    private func label(_ ctx: inout GraphicsContext, _ t: String, at p: CGPoint, _ c: Color) {
        let text = ctx.resolve(Text(t).font(.system(size: 14, weight: .bold)).foregroundStyle(.black))
        let sz = text.measure(in: CGSize(width: 400, height: 40))
        let r = CGRect(x: p.x - sz.width / 2 - 7, y: p.y - sz.height / 2 - 4, width: sz.width + 14, height: sz.height + 8)
        ctx.fill(Path(roundedRect: r, cornerRadius: 7), with: .color(c))
        ctx.draw(text, at: p)
    }
}

struct PencilLayer: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    let active: Bool
    let changed: () -> Void
    func makeUIView(context: Context) -> PKCanvasView {
        let v = PKCanvasView()
        v.backgroundColor = .clear
        v.isOpaque = false
        v.drawingPolicy = .anyInput
        v.tool = PKInkingTool(.pen, color: UIColor(red: 1, green: 0.42, blue: 0.37, alpha: 1), width: 4)
        v.delegate = context.coordinator
        v.isScrollEnabled = false
        v.drawing = drawing
        return v
    }
    func updateUIView(_ v: PKCanvasView, context: Context) {
        if v.drawing != drawing { v.drawing = drawing }
        v.isUserInteractionEnabled = active
    }
    func makeCoordinator() -> Coord { Coord(self) }
    final class Coord: NSObject, PKCanvasViewDelegate {
        var parent: PencilLayer
        init(_ p: PencilLayer) { parent = p }
        func canvasViewDrawingDidChange(_ v: PKCanvasView) {
            parent.drawing = v.drawing
            parent.changed()
        }
    }
}
