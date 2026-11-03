import SwiftUI
import PhotosUI

struct LabsView: View {
    @Environment(Store.self) private var store
    @Environment(\.horizontalSizeClass) private var hsc
    @State private var tab = "cases"
    @State private var filter = "all"
    @State private var edit: Store.LabCase?
    @State private var labSheet: Lab?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Labs").font(.rx(hsc == .compact ? 28 : 34, .bold)).tracking(-0.8)
                        Text("Crowns, bridges, veneers and dentures at the lab · newest first").font(.rx(15)).foregroundStyle(RX.ink3)
                    }
                    Spacer()
                    if hsc != .compact { tabs }
                }
                if hsc == .compact { tabs }
                if tab == "cases" { cases } else { labsList }
            }
            .padding(.horizontal, hsc == .compact ? 14 : 32).padding(.vertical, hsc == .compact ? 8 : 28).padding(.bottom, 80)
        }
        .sheet(item: $edit) { c in LabCaseSheet(pid: c.pid, procID: c.proc.id).presentationSizing(.form) }
        .sheet(item: $labSheet) { l in LabSheet(lab: l, isNew: store.lab(l.id) == nil).presentationSizing(.form) }
        .onAppear { if DemoScreen.current == "labcase", let c = store.labCases.first(where: { $0.proc.id == "pd7" }) { edit = c } }
    }

    private var tabs: some View { SegmentPicker(items: [("cases", "Lab cases"), ("labs", "Labs & prices")], sel: $tab) }

    private var cases: some View {
        let all = store.labCases
        let f: (Store.LabCase) -> Bool = { c in
            switch filter {
            case "doing": c.whereNow == .lab || c.whereNow == .notsent
            case "here": c.whereNow == .clinic
            case "attn": c.needsAttention
            case "done": c.whereNow == .done
            default: true
            }
        }
        let L = all.filter(f)
        return VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                SegmentPicker(items: [("all", "All"), ("doing", "In progress"), ("here", "Here at the clinic"), ("attn", "Needs attention"), ("done", "Delivered")], sel: $filter,
                              counts: ["all": all.count, "doing": all.filter { $0.whereNow == .lab || $0.whereNow == .notsent }.count, "here": all.filter { $0.whereNow == .clinic }.count, "attn": all.filter(\.needsAttention).count, "done": all.filter { $0.whereNow == .done }.count])
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 330), spacing: 14)], spacing: 14) {
                ForEach(L) { c in caseCard(c) }
            }
            if L.isEmpty { EmptyNote(text: "No lab work here") }
        }
    }

    private func caseCard(_ c: Store.LabCase) -> some View {
        let p = store.patient(c.pid), r = c.proc, lab = store.lab(r.lab?.lab)
        let last = c.lastStep
        let sv = lab?.services.first { $0.id == r.lab?.svc }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                PatientIcon(p: p, size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(p?.name ?? "").font(.rx(19, .bold)).tracking(-0.3)
                    Text(Catalog.typeName(r.type) + (r.teeth.isEmpty ? "" : " · " + r.teeth.joined(separator: " · "))).font(.rx(14, .semibold)).foregroundStyle(RX.ink2)
                    Text("Added " + Day.dmy(c.added)).font(.rx(11.5)).foregroundStyle(RX.ink4)
                }
                Spacer(minLength: 0)
                Chip(text: c.whereNow.label, color: c.whereNow.color, size: 11.5)
            }
            HStack(spacing: 10) {
                LabLogo(lab: lab, size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(lab?.name ?? "No lab").font(.rx(13, .semibold))
                    Text([sv?.name, r.lab?.shade.isEmpty == false ? "Shade " + (r.lab?.shade ?? "") : nil, r.lab?.temp == true ? "Temporary" : nil].compactMap { $0 }.joined(separator: " · ")).font(.rx(11.5)).foregroundStyle(RX.ink3).lineLimit(1)
                }
                Spacer()
            }
            if let last {
                HStack(spacing: 8) {
                    Circle().fill(Catalog.step(last.k)?.color ?? RX.ink3).frame(width: 8, height: 8)
                    Text(Catalog.step(last.k)?.name ?? last.k).font(.rx(13, .semibold)).foregroundStyle(Catalog.step(last.k)?.color ?? RX.ink)
                    Text("· " + Day.ago(last.at)).font(.rx(12)).foregroundStyle(RX.ink4)
                }
                if !last.note.isEmpty { Text("“\(last.note)”").font(.rx(12.5)).foregroundStyle(RX.ink2).padding(8).frame(maxWidth: .infinity, alignment: .leading).rxPanel(10, RX.deep) }
            }
            HStack(spacing: 8) {
                Button("Edit procedure") { edit = c }.buttonStyle(SoftButton(compact: true))
                if c.whereNow == .lab {
                    Button("Try-in arrived") { store.addLabStep(c.pid, r.id, "tryin") }.buttonStyle(SoftButton(compact: true, tint: RX.lilac, fill: RX.lilac.opacity(0.14)))
                    Button("Finished arrived") { store.addLabStep(c.pid, r.id, "recv") }.buttonStyle(SoftButton(compact: true, tint: RX.mintLight, fill: RX.mint.opacity(0.14)))
                }
                if c.whereNow == .clinic {
                    Button("Delivered · done") { store.addLabStep(c.pid, r.id, "done") }.buttonStyle(MintButton(compact: true))
                }
                Spacer()
                if let ph = lab?.phone { Button { openWhatsApp(ph, "") } label: { Icon(d: Ico.whatsapp, size: 16).foregroundStyle(RX.whatsapp) }.buttonStyle(.plain).frame(width: 38, height: 38).background(Circle().fill(RX.whatsapp.opacity(0.12))) }
            }
        }
        .padding(16)
        .rxCard(22)
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(c.needsAttention ? RX.amber.opacity(0.6) : .clear, lineWidth: 1.5))
        .contextMenu {
            Button("Open patient", systemImage: "person") { store.section = .patients; store.openPatient = c.pid }
            Button("Edit procedure", systemImage: "pencil") { edit = c }
        }
    }

    private var labsList: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionTitle(text: "Labs & prices", sub: "\(store.d.labs.count) labs")
                Spacer()
                Button { labSheet = Lab(id: "l" + UUID().uuidString.prefix(6), name: "", contact: "", phone: "", cur: .usd, note: "", services: []) } label: { Label("Add a lab", systemImage: "plus") }.buttonStyle(MintButton(compact: true))
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 14)], spacing: 14) {
                ForEach(store.d.labs) { l in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            LabLogo(lab: l, size: 52)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l.name).font(.rx(17, .bold))
                                Text([l.contact, l.phone].filter { !$0.isEmpty }.joined(separator: " · ")).font(.rx(12.5)).foregroundStyle(RX.ink3)
                            }
                            Spacer()
                            Button("Edit") { labSheet = l }.buttonStyle(SoftButton(compact: true))
                        }
                        if !l.note.isEmpty { Text(l.note).font(.rx(12.5)).foregroundStyle(RX.ink3) }
                        VStack(spacing: 4) {
                            ForEach(l.services) { s in
                                HStack { Text(s.name).font(.rx(13.5)); Spacer(); Text(Money.fmt(s.price, l.cur)).font(.rx(13.5, .semibold)).monospacedDigit() }
                                    .padding(.vertical, 6)
                                    .overlay(alignment: .bottom) { Rectangle().fill(RX.line).frame(height: 1) }
                            }
                        }
                        HStack(spacing: 8) {
                            Button { openWhatsApp(l.phone, "") } label: { Label("WhatsApp", systemImage: "message.fill") }.buttonStyle(SoftButton(compact: true, tint: Color(rgb: 0x7FE3A6), fill: RX.whatsapp.opacity(0.14)))
                            Button { callPhone(l.phone) } label: { Label("Call", systemImage: "phone.fill") }.buttonStyle(SoftButton(compact: true))
                            Spacer()
                            Text("Prices in \(l.cur.label)").font(.rx(11.5)).foregroundStyle(RX.ink4)
                        }
                    }
                    .padding(16).rxCard(22)
                }
            }
        }
    }
}

struct LabLogo: View {
    let lab: Lab?
    var size: CGFloat = 40
    var body: some View {
        ZStack {
            if let d = lab?.photo, let ui = UIImage(data: d) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                LinearGradient(colors: [Color(rgb: 0x7A5B3A), Color(rgb: 0x3D2C1B)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Text((lab?.name ?? "?").split(separator: " ").compactMap(\.first).prefix(2).map(String.init).joined().uppercased()).font(.rx(size * 0.36, .heavy)).foregroundStyle(Color(rgb: 0xF3D9B5))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
    }
}

struct LabCaseSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let pid: String
    let procID: String
    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Edit procedure", close: { dismiss() })
            ScrollView {
                if let p = store.patient(pid), let r = p.procs.first(where: { $0.id == procID }) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            PatientIcon(p: p, size: 44)
                            Text(p.name).font(.rx(20, .bold))
                            Spacer()
                            Button("Open patient") { dismiss(); store.section = .patients; store.openPatient = pid }.buttonStyle(SoftButton(compact: true))
                        }
                        ProcedureRow(pid: pid, r: r, row: store.bill(p).rows.first { $0.id == r.id })
                    }
                    .padding(20)
                }
            }
        }
        .rxSheet { dismiss() }
    }
}

struct LabSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var lab: Lab
    let isNew: Bool
    @State private var photoItem: PhotosPickerItem?
    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: isNew ? "New lab" : "Edit lab", primary: "Save", primaryOn: !lab.name.trimmingCharacters(in: .whitespaces).isEmpty, close: { dismiss() }) {
                store.saveLab(lab); dismiss()
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 14) {
                        LabLogo(lab: lab, size: 84)
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lab.photo == nil ? "Add a picture or logo" : "Change the picture").font(.rx(14, .semibold)).foregroundStyle(RX.mint)
                                Text("A photo of the lab or its logo").font(.rx(12)).foregroundStyle(RX.ink3)
                            }
                        }
                        if lab.photo != nil { Button("Remove") { lab.photo = nil }.font(.rx(12.5)).foregroundStyle(RX.salmon).buttonStyle(.plain) }
                    }
                    RXField(label: "Lab name", text: $lab.name, placeholder: "Lab name")
                    HStack(spacing: 10) {
                        RXField(label: "Contact person", text: $lab.contact)
                        RXField(label: "Phone / WhatsApp", text: $lab.phone, keyboard: .phonePad)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Prices in").font(.rx(12)).foregroundStyle(RX.ink3)
                        RXSelect(options: Currency.allCases.map { ($0, $0.label) }, sel: $lab.cur)
                    }
                    RXField(label: "Notes", text: $lab.note)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Price list").font(.rx(12)).foregroundStyle(RX.ink3)
                        ForEach($lab.services) { $s in
                            HStack(spacing: 8) {
                                TextField("", text: $s.name, prompt: Text("Service").foregroundStyle(RX.ink4)).font(.rx(14)).padding(.horizontal, 12).frame(height: 42).rxPanel(10)
                                NumberBox(value: s.price, width: 90) { v in s.price = v }
                                Text(lab.cur.sym).font(.rx(12)).foregroundStyle(RX.ink3).frame(width: 30)
                                Button { lab.services.removeAll { $0.id == s.id } } label: { Image(systemName: "minus.circle").foregroundStyle(RX.salmon) }.buttonStyle(.plain).frame(width: 36, height: 36)
                            }
                        }
                        Button { lab.services.append(LabService(id: "v" + UUID().uuidString.prefix(6), name: "", price: 0)) } label: { Label("Add a service", systemImage: "plus") }.font(.rx(13, .semibold)).foregroundStyle(RX.mint).buttonStyle(.plain)
                    }
                    if !isNew { Button("Delete this lab") { store.deleteLab(lab.id); dismiss() }.font(.rx(13, .semibold)).foregroundStyle(RX.salmon).buttonStyle(.plain) }
                }
                .padding(22)
            }
        }
        .rxSheet { dismiss() }
        .onChange(of: photoItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self), let ui = UIImage(data: data) {
                    let r = ui.preparingThumbnail(of: CGSize(width: 320, height: 320 * ui.size.height / max(1, ui.size.width)))
                    lab.photo = (r ?? ui).jpegData(compressionQuality: 0.85)
                }
            }
        }
    }
}
