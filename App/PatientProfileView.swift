import SwiftUI
import UniformTypeIdentifiers

enum ProfileTab: String, CaseIterable, Identifiable {
    case xrays, chart, procedures, payments, files
    var id: String { rawValue }
    var label: String { switch self { case .xrays: "X-rays"; case .chart: "Dental chart"; case .procedures: "Procedures"; case .payments: "Payments"; case .files: "Files" } }
}

struct PatientProfileView: View {
    @Environment(Store.self) private var store
    @Environment(\.horizontalSizeClass) private var hsc
    @Environment(\.dismiss) private var dismiss
    let pid: String
    @State private var tab: ProfileTab = .chart
    @State private var edit = false
    @State private var viewer: Xray?
    @State private var selTooth: String?
    @State private var book = false

    var body: some View {
        if let p = store.patient(pid) {
            GeometryReader { g in
                let wide = g.size.width > 860
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        topBar(p)
                        header(p, wide: wide)
                        labSummary(p)
                        tabs(p)
                        switch tab {
                        case .xrays: XrayGrid(p: p, open: { viewer = $0 })
                        case .chart:
                            if wide {
                                HStack(alignment: .top, spacing: 16) {
                                    DentalChartCard(p: p, sel: $selTooth).frame(maxWidth: .infinity)
                                    TeethInspector(p: p, sel: $selTooth).frame(width: 340)
                                }
                            } else {
                                DentalChartCard(p: p, sel: $selTooth)
                                TeethInspector(p: p, sel: $selTooth)
                            }
                            ProceduresSection(p: p)
                        case .procedures: ProceduresSection(p: p)
                        case .payments: ProfilePayments(p: p, wide: wide)
                        case .files: FilesSection(p: p)
                        }
                    }
                    .padding(.horizontal, hsc == .compact ? 14 : 28).padding(.vertical, hsc == .compact ? 6 : 22).padding(.bottom, 80)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $edit) { NewPatientSheet(editing: p).presentationSizing(.form) }
            .sheet(isPresented: $book) { AppointmentSheet(mode: .new(p.id)).presentationSizing(.form) }
            .fullScreenCover(item: $viewer) { x in XrayViewer(pid: pid, xid: x.id) }
            .onAppear {
                switch DemoScreen.current {
                case "xray": if let x = p.xrays.first(where: { $0.id == "x2" }) ?? p.xrays.first { viewer = x }
                case "profile": tab = .chart; selTooth = "36"
                case "chart": tab = .chart; selTooth = "36"
                default: break
                }
            }
        } else {
            EmptyNote(text: "This patient is no longer here.")
        }
    }

    private func topBar(_ p: Patient) -> some View {
        HStack {
            Button { dismiss() } label: { Label { Text("Patients") } icon: { Icon(d: Ico.chevronL, size: 15, weight: 2.4) } }
                .font(.rx(14, .semibold)).foregroundStyle(RX.ink2).buttonStyle(.plain)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .glassEffect(.regular.tint(RX.card.opacity(0.5)).interactive(), in: .capsule)
            Spacer()
        }
    }

    // MARK: header

    private func header(_ p: Patient, wide: Bool) -> some View {
        let next = store.liveAppts.filter { $0.patient == p.id && $0.day >= store.today }.sorted { ($0.day, $0.startMin) < ($1.day, $1.startMin) }.first
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 18) {
                PatientIcon(p: p, size: wide ? 92 : 68)
                VStack(alignment: .leading, spacing: 6) {
                    Text(p.name).font(.rx(wide ? 30 : 24, .bold)).tracking(-0.6)
                    Text([p.ageNow.map { "\($0) years" }, p.sex == .m ? "Man" : p.sex == .f ? "Woman" : nil, "Patient since \(Day.dmy(p.created))"].compactMap { $0 }.joined(separator: " · ")).font(.rx(13.5)).foregroundStyle(RX.ink3)
                    if let d = p.dentist { HStack(spacing: 6) { Text("Usual dentist").font(.rx(12)).foregroundStyle(RX.ink4); store.dentChip(d) } }
                }
                Spacer(minLength: 0)
                if wide { actions(p) }
            }
            if !wide { actions(p) }
            HStack(alignment: .top, spacing: 12) {
                if !p.phones.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(p.phones, id: \.self) { ph in
                            HStack(spacing: 8) {
                                Text(ph).font(.rx(14, .medium)).monospacedDigit()
                                Button { openWhatsApp(ph, "") } label: { Icon(d: Ico.whatsapp, size: 15).foregroundStyle(RX.whatsapp) }.buttonStyle(.plain).frame(width: 34, height: 34).background(Circle().fill(RX.whatsapp.opacity(0.12)))
                                Button { callPhone(ph) } label: { Icon(d: Ico.phone, size: 15).foregroundStyle(RX.mintLight) }.buttonStyle(.plain).frame(width: 34, height: 34).background(Circle().fill(RX.card2))
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
                if let next {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("Next appointment").font(.rx(11.5)).foregroundStyle(RX.ink4)
                        Text((next.day == store.today ? "Today" : Day.short(next.day)) + " · " + next.time).font(.rx(14, .semibold)).foregroundStyle(RX.mintLight)
                        Text(store.memberName(next.dent) + " · " + apLabel(next)).font(.rx(12)).foregroundStyle(RX.ink3).lineLimit(1)
                    }
                }
            }
            if p.hasAlert || !p.med.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    alertRow("Allergies", p.allg, RX.salmon)
                    alertRow("Conditions", p.cond, RX.sand)
                    alertRow("Medications", p.med, RX.blue)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).fill(p.allg.isEmpty ? RX.card2.opacity(0.6) : RX.red.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(p.allg.isEmpty ? .clear : RX.red.opacity(0.35)))
            }
        }
        .padding(wide ? 24 : 16)
        .rxCard(26)
    }

    @ViewBuilder private func alertRow(_ t: String, _ L: [String], _ c: Color) -> some View {
        if !L.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(t).font(.rx(12)).foregroundStyle(RX.ink3).frame(width: 92, alignment: .leading)
                FlowLayout(spacing: 6) { ForEach(L, id: \.self) { Chip(text: $0, color: c) } }
            }
        }
    }

    private func actions(_ p: Patient) -> some View {
        HStack(spacing: 8) {
            Button { edit = true } label: { Label("Edit", systemImage: "pencil") }.buttonStyle(SoftButton(compact: true))
            Button { book = true } label: { Label("Book", systemImage: "calendar.badge.plus") }.buttonStyle(MintButton(compact: true))
        }
    }

    // MARK: lab summary

    @ViewBuilder private func labSummary(_ p: Patient) -> some View {
        let cases = p.procs.filter { $0.lab != nil && !($0.lab?.lab.isEmpty ?? true) && $0.status != .done }
        if !cases.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack { Icon(d: Ico.lab, size: 16).foregroundStyle(RX.tan); Text("Lab work").font(.rx(14, .semibold)) }
                ForEach(cases) { r in
                    let w = Catalog.labWhere(r.lab?.steps.last?.k)
                    HStack(spacing: 10) {
                        Text(Catalog.typeName(r.type) + (r.teeth.isEmpty ? "" : " " + r.teeth.joined(separator: "·"))).font(.rx(13.5, .semibold))
                        Text(store.lab(r.lab?.lab)?.name ?? "").font(.rx(12)).foregroundStyle(RX.ink3)
                        Spacer()
                        if let k = r.lab?.steps.last?.k { Text(Catalog.step(k)?.name ?? k).font(.rx(12)).foregroundStyle(Catalog.step(k)?.color ?? RX.ink3) }
                        Chip(text: w == .clinic ? "Here at the clinic · check it" : w.label, color: w.color, size: 11)
                    }
                }
            }
            .padding(14)
            .rxCard(18, fill: Color(rgb: 0x2A2216, 0.55))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(RX.tan.opacity(0.25)))
        }
    }

    // MARK: tabs

    private func tabs(_ p: Patient) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(ProfileTab.allCases) { t in
                    let on = tab == t
                    let n: Int = t == .xrays ? p.xrays.count : t == .procedures ? p.procs.count : t == .files ? p.files.count : 0
                    Button { withAnimation(.spring(duration: 0.35)) { tab = t }; Haptics.tap() } label: {
                        HStack(spacing: 6) {
                            Text(t.label).font(.rx(14, .semibold))
                            if n > 0 { Text("\(n)").font(.rx(11.5)).foregroundStyle(on ? RX.ink3 : RX.ink4) }
                        }
                        .foregroundStyle(on ? RX.ink : RX.ink3)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background { if on { Capsule().fill(RX.card3) } }
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .glassEffect(.regular.tint(RX.card.opacity(0.6)), in: .capsule)
        }
    }
}

// MARK: - X-rays grid

struct XrayGrid: View {
    @Environment(Store.self) private var store
    let p: Patient
    let open: (Xray) -> Void
    var body: some View {
        let groups = Dictionary(grouping: p.xrays.sorted { $0.takenAt > $1.takenAt }) { Day.iso($0.takenAt) }.sorted { $0.key > $1.key }
        VStack(alignment: .leading, spacing: 18) {
            if p.xrays.isEmpty { EmptyNote(text: "No X-rays yet. X-rays are taken on the PC with the sensor.") }
            ForEach(groups, id: \.key) { g in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(Day.long(g.key)).font(.rx(14, .semibold))
                        Text("\(g.value.count) X-ray\(g.value.count == 1 ? "" : "s")").font(.rx(12)).foregroundStyle(RX.ink3)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 12)], spacing: 12) {
                        ForEach(g.value) { x in
                            Button { open(x) } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Image(x.image).resizable().scaledToFill()
                                        .frame(height: 140).frame(maxWidth: .infinity).clipped()
                                        .colorMultiply(.white).brightness((x.bright - 100) / 200).contrast(x.contrast / 100)
                                        .colorInvert(x.invert)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    HStack {
                                        Text(x.teeth.isEmpty ? "Teeth not set" : x.teeth.joined(separator: " · ")).font(.rx(13, .semibold))
                                        Spacer()
                                        Text(Day.hm(x.takenAt)).font(.rx(12)).foregroundStyle(RX.ink3)
                                    }
                                    Text("Taken by \(store.memberName(x.by))" + (x.room.isEmpty ? "" : " · \(x.room)")).font(.rx(11.5)).foregroundStyle(RX.ink4)
                                }
                                .padding(10).rxCard(18)
                            }
                            .buttonStyle(PressScale())
                        }
                    }
                }
            }
        }
    }
}

extension View {
    @ViewBuilder func colorInvert(_ on: Bool) -> some View { if on { self.colorInvert() } else { self } }
}

// MARK: - Files

struct FilesSection: View {
    @Environment(Store.self) private var store
    let p: Patient
    @State private var importing = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(text: "Files", sub: "STL scans, DICOM / CBCT, videos, photos, PDFs")
                Spacer()
                Button { importing = true } label: { Label("Add files", systemImage: "plus") }.buttonStyle(MintButton(compact: true))
            }
            if p.files.isEmpty { EmptyNote(text: "No files yet") }
            ForEach(p.files) { f in
                HStack(spacing: 12) {
                    Text(f.kind.uppercased()).font(.rx(10.5, .bold)).foregroundStyle(RX.onMint).frame(width: 48, height: 48).background(RoundedRectangle(cornerRadius: 12).fill(kindColor(f.kind)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(f.name).font(.rx(14, .semibold))
                        Text(ByteCountFormatter.string(fromByteCount: Int64(f.size), countStyle: .file) + " · " + Day.dmy(f.at) + (f.tooth.isEmpty ? "" : " · tooth \(f.tooth)") + (f.note.isEmpty ? "" : " · \(f.note)")).font(.rx(12)).foregroundStyle(RX.ink3)
                    }
                    Spacer()
                    Button { store.updatePatient(p.id, "File removed") { P in P.files.removeAll { $0.id == f.id } } } label: { Image(systemName: "trash").foregroundStyle(RX.ink4) }.buttonStyle(.plain).frame(width: 40, height: 40)
                }
                .padding(12).rxCard(16, fill: RX.card)
            }
        }
        .padding(16).rxCard(22)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.item], allowsMultipleSelection: true) { r in
            guard case .success(let urls) = r else { return }
            let add = urls.map { u -> PatientFile in
                let ext = u.pathExtension.lowercased()
                let kind = ext == "stl" ? "stl" : ["dcm", "dicom"].contains(ext) ? "dicom" : ["mp4", "mov", "m4v"].contains(ext) ? "video" : ["jpg", "jpeg", "png", "heic"].contains(ext) ? "photo" : ext == "pdf" ? "pdf" : ext
                let size = (try? u.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                return PatientFile(name: u.lastPathComponent, kind: kind, size: size, at: .now)
            }
            store.updatePatient(p.id, "\(add.count) file\(add.count == 1 ? "" : "s") added") { P in P.files.append(contentsOf: add) }
        }
    }
    private func kindColor(_ k: String) -> Color { switch k { case "stl": RX.blue; case "dicom": RX.lilac; case "video": RX.salmon; case "photo": RX.mintLight; case "pdf": RX.sand; default: RX.ink3 } }
}
