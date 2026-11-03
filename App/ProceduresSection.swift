import SwiftUI

struct ProceduresSection: View {
    @Environment(Store.self) private var store
    let p: Patient
    @State private var filter = "all"

    var body: some View {
        let bill = store.bill(p)
        let L = p.procs.filter { filter == "all" || $0.status.rawValue == filter }
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack { title; Spacer(); filters; addMenu }
                VStack(alignment: .leading, spacing: 10) { title; HStack { filters; Spacer(); addMenu } }
            }
            if L.isEmpty { EmptyNote(text: filter == "all" ? "No procedures yet. Add one, or set a treatment on the chart." : "Nothing here") }
            ForEach(L) { r in ProcedureRow(pid: p.id, r: r, row: bill.rows.first { $0.id == r.id }) }
        }
        .padding(16)
        .rxCard(22)
    }

    private var title: some View { SectionTitle(text: "Procedures", sub: "\(p.procs.count) · linked to the chart") }

    private var filters: some View {
        SegmentPicker(items: [("all", "All"), ("plan", "Planned"), ("doing", "In progress"), ("done", "Done")], sel: $filter,
                      counts: ["all": p.procs.count, "plan": p.procs.filter { $0.status == .plan }.count, "doing": p.procs.filter { $0.status == .doing }.count, "done": p.procs.filter { $0.status == .done }.count])
    }

    private var addMenu: some View {
        Menu {
            ForEach(Catalog.specs) { s in
                Menu(s.name) {
                    ForEach(Catalog.types.filter { $0.spec == s.id }) { t in
                        Button(t.name) {
                            var r = Procedure(spec: s.id, type: t.id, status: .plan, by: store.me, at: .now)
                            if Catalog.isLab(t.id) { r.lab = LabWork() }
                            store.addProcedure(p.id, r)
                        }
                    }
                }
            }
        } label: {
            Label { Text("Add procedure") } icon: { Icon(d: Ico.plus, size: 15, weight: 2.6) }
                .font(.rx(13, .bold)).foregroundStyle(RX.onMint).padding(.horizontal, 13).padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 12).fill(RX.mint))
        }
        .buttonStyle(.plain)
    }
}

struct ProcedureRow: View {
    @Environment(Store.self) private var store
    let pid: String
    let r: Procedure
    let row: BillRow?
    @State private var teethText = ""
    @State private var editingTeeth = false

    var body: some View {
        let sp = Catalog.spec(r.spec)
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { tooth; specMenu; typeMenu; Spacer(minLength: 4); statusPicker; price; more }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) { tooth; specMenu; typeMenu; Spacer(minLength: 0); more }
                    HStack { statusPicker; Spacer(); price }
                }
            }
            addons
            if Catalog.isLab(r.type) { LabPanel(pid: pid, r: r) }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(RX.card))
        .overlay(alignment: .leading) { UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 16).fill(sp?.color ?? RX.mint).frame(width: 3) }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contextMenu {
            Button("Remove procedure", systemImage: "trash", role: .destructive) { store.deleteProcedure(pid, r.id) }
        }
        .swipeActions { Button("Remove", role: .destructive) { store.deleteProcedure(pid, r.id) } }
    }

    private var tooth: some View {
        Button { teethText = r.teeth.joined(separator: " "); editingTeeth = true } label: {
            Text(r.teeth.isEmpty ? "—" : r.teeth.joined(separator: "·")).font(.rx(15, .bold)).monospacedDigit()
                .frame(minWidth: 46, minHeight: 36).padding(.horizontal, 6).background(RoundedRectangle(cornerRadius: 10).fill(RX.card2))
        }
        .buttonStyle(.plain)
        .alert("Teeth", isPresented: $editingTeeth) {
            TextField("e.g. 36 or 14 15 16", text: $teethText).keyboardType(.numbersAndPunctuation)
            Button("Save") {
                let t = teethText.split(whereSeparator: { !$0.isNumber }).map(String.init).filter { $0.count == 2 }
                store.updateProcedure(pid, r.id, msg: "Teeth changed") { $0.teeth = t }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("FDI numbers, separated by spaces") }
    }

    private var specMenu: some View {
        Menu {
            ForEach(Catalog.specs) { s in
                Button(s.name) {
                    let first = Catalog.types.first { $0.spec == s.id }?.id ?? r.type
                    store.updateProcedure(pid, r.id, msg: "Specialty changed") { $0.spec = s.id; $0.type = first; $0.addons = []; if Catalog.isLab(first) && $0.lab == nil { $0.lab = LabWork() } }
                }
            }
        } label: { menuLabel(Catalog.spec(r.spec)?.name ?? r.spec, dot: Catalog.spec(r.spec)?.color) }
        .buttonStyle(.plain)
    }

    private var typeMenu: some View {
        Menu {
            ForEach(Catalog.types.filter { $0.spec == r.spec }) { t in
                Button(t.name) { store.updateProcedure(pid, r.id, msg: "Procedure changed") { $0.type = t.id; if Catalog.isLab(t.id) && $0.lab == nil { $0.lab = LabWork() } } }
            }
        } label: { menuLabel(Catalog.typeName(r.type) + (r.surf.isEmpty ? "" : " " + r.surf.joined()), bold: true) }
        .buttonStyle(.plain)
    }

    private func menuLabel(_ t: String, dot: Color? = nil, bold: Bool = false) -> some View {
        HStack(spacing: 6) {
            if let dot { Circle().fill(dot).frame(width: 8, height: 8) }
            Text(t).font(.rx(13.5, bold ? .semibold : .medium)).lineLimit(1)
            Icon(d: Ico.chevronD, size: 10, weight: 3).foregroundStyle(RX.ink4)
        }
        .padding(.horizontal, 11).frame(minHeight: 36)
        .background(RoundedRectangle(cornerRadius: 10).fill(RX.card2))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(RX.line2))
    }

    private var statusPicker: some View {
        HStack(spacing: 2) {
            ForEach(ProcStatus.allCases) { s in
                let on = r.status == s
                Button { store.updateProcedure(pid, r.id, msg: s.label) { $0.status = s }; Haptics.tap() } label: {
                    Text(s.label).font(.rx(12, .semibold)).foregroundStyle(on ? RX.onMint : RX.ink3)
                        .padding(.horizontal, 10).frame(minHeight: 34)
                        .background { if on { RoundedRectangle(cornerRadius: 8).fill(s.color) } }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2).background(RoundedRectangle(cornerRadius: 10).fill(RX.card2))
    }

    @ViewBuilder private var price: some View {
        if let row {
            VStack(alignment: .trailing, spacing: 1) {
                HStack(spacing: 4) {
                    if row.gift { Text("🎁") }
                    Text(store.money(row.sub)).font(.rx(14, .bold)).monospacedDigit()
                }
                if r.status != .plan { Text(row.state.label).font(.rx(11, .semibold)).foregroundStyle(row.state == .paid ? RX.mint : row.state == .part ? RX.sand : row.state == .unpaid ? RX.salmon : RX.mintLight) }
            }
            .frame(minWidth: 74, alignment: .trailing)
        }
    }

    private var more: some View {
        Menu {
            Button("Remove procedure", systemImage: "trash", role: .destructive) { store.deleteProcedure(pid, r.id) }
            if r.type == "crown" || r.type == "bridge" {
                Button("Make a bridge…", systemImage: "link") { teethText = r.teeth.joined(separator: " "); editingTeeth = true; store.updateProcedure(pid, r.id) { $0.type = "bridge" } }
            }
        } label: { Image(systemName: "ellipsis").font(.system(size: 14, weight: .bold)).foregroundStyle(RX.ink3).frame(width: 36, height: 36).background(Circle().fill(RX.card2)) }
        .buttonStyle(.plain)
    }

    private var addons: some View {
        FlowLayout(spacing: 6) {
            ForEach(Array(r.addons.enumerated()), id: \.offset) { item in
                let i = item.offset, a = item.element
                HStack(spacing: 6) {
                    Text("\(i + 1)").font(.rx(10, .bold)).foregroundStyle(RX.onMint).frame(width: 17, height: 17).background(Circle().fill(RX.mintLight))
                    Text(Catalog.addon(a)?.name ?? a).font(.rx(12.5, .medium))
                    if r.giftAddons.contains(a) { Text("🎁").font(.system(size: 11)) }
                    Button { store.updateProcedure(pid, r.id, msg: "Add-on removed") { $0.addons.remove(at: i) } } label: { Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(RX.ink4) }.buttonStyle(.plain)
                }
                .padding(.leading, 5).padding(.trailing, 9).padding(.vertical, 5)
                .background(Capsule().fill(RX.card2))
            }
            Menu {
                ForEach(Catalog.addons.filter { $0.spec == r.spec }) { a in
                    Button(a.name) { store.updateProcedure(pid, r.id, msg: "Add-on added") { $0.addons.append(a.id) } }
                }
                Menu("Other specialties") {
                    ForEach(Catalog.addons.filter { $0.spec != r.spec }) { a in Button(a.name) { store.updateProcedure(pid, r.id, msg: "Add-on added") { $0.addons.append(a.id) } } }
                }
            } label: {
                Text("+ Add-on").font(.rx(12.5, .medium)).foregroundStyle(RX.ink3)
                    .padding(.horizontal, 11).padding(.vertical, 6)
                    .overlay(Capsule().strokeBorder(Color(rgb: 0xD6EBE4, 0.24), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Lab work on a procedure

struct LabPanel: View {
    @Environment(Store.self) private var store
    let pid: String
    let r: Procedure
    @State private var shade = false
    @State private var noteStep: String?
    @State private var noteText = ""

    var body: some View {
        let L = r.lab ?? LabWork()
        let lab = store.lab(L.lab)
        let units = max(1, r.teeth.count)
        let last = L.steps.last?.k
        let w = Catalog.labWhere(last)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Icon(d: Ico.lab, size: 15).foregroundStyle(RX.tan)
                Text("Lab work").font(.rx(13, .semibold))
                Spacer()
                Chip(text: w.label, color: w.color, size: 11)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { labMenu(L); svcMenu(L, lab, units); shadeButton(L); tempToggle(L) }
                VStack(alignment: .leading, spacing: 8) { HStack(spacing: 8) { labMenu(L); svcMenu(L, lab, units) }; HStack(spacing: 8) { shadeButton(L); tempToggle(L) } }
            }
            TextField("", text: Binding(get: { L.note }, set: { v in store.updateProcedure(pid, r.id) { $0.lab?.note = v } }), prompt: Text("Notes for the lab").foregroundStyle(RX.ink4))
                .font(.rx(13)).padding(.horizontal, 12).padding(.vertical, 9).rxPanel(10)
            // step bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(L.steps) { s in
                        let def = Catalog.step(s.k)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(def?.name ?? s.k).font(.rx(12, .semibold)).foregroundStyle(def?.color ?? RX.ink)
                            Text(Day.dm(s.at) + " " + Day.hm(s.at) + (s.by.map { " · " + store.memberName($0) } ?? "")).font(.rx(10.5)).foregroundStyle(RX.ink4)
                            if !s.note.isEmpty { Text("“\(s.note)”").font(.rx(11)).foregroundStyle(RX.ink2).lineLimit(2) }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 10).fill((def?.color ?? RX.ink3).opacity(0.12)))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder((def?.color ?? RX.ink3).opacity(0.4)))
                        Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)).foregroundStyle(RX.ink4)
                    }
                    let next = Catalog.labNext(last)
                    if !next.isEmpty {
                        Menu {
                            ForEach(next, id: \.self) { k in
                                Button(Catalog.step(k)?.name ?? k) {
                                    if Catalog.noteSteps.contains(k) { noteText = ""; noteStep = k } else { store.addLabStep(pid, r.id, k) }
                                }
                            }
                        } label: {
                            Text(L.steps.isEmpty ? "Start · first step" : "Next step").font(.rx(12.5, .bold)).foregroundStyle(RX.onMint)
                                .padding(.horizontal, 12).frame(minHeight: 40).background(RoundedRectangle(cornerRadius: 10).fill(RX.mint))
                        }
                        .buttonStyle(.plain)
                    }
                    if !L.steps.isEmpty {
                        Button { store.removeLastLabStep(pid, r.id) } label: { Image(systemName: "arrow.uturn.backward").foregroundStyle(RX.ink3).frame(width: 40, height: 40).background(Circle().fill(RX.card2)) }
                            .buttonStyle(.plain).accessibilityLabel("Remove the last step")
                    }
                }
            }
            if w == .lab || w == .notsent {
                HStack(spacing: 8) {
                    Button("Try-in arrived") { store.addLabStep(pid, r.id, "tryin") }.buttonStyle(SoftButton(compact: true, tint: RX.lilac, fill: RX.lilac.opacity(0.14)))
                    Button("Finished work arrived") { store.addLabStep(pid, r.id, "recv") }.buttonStyle(SoftButton(compact: true, tint: RX.mintLight, fill: RX.mint.opacity(0.14)))
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(rgb: 0x2A2216, 0.35)).overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(RX.tan.opacity(0.22))))
        .sheet(isPresented: $shade) { ShadePicker(sel: Binding(get: { r.lab?.shade ?? "" }, set: { v in store.updateProcedure(pid, r.id) { $0.lab?.shade = v } })).presentationDetents([.large]).presentationSizing(.form) }
        .alert(Catalog.step(noteStep ?? "")?.name ?? "", isPresented: Binding(get: { noteStep != nil }, set: { if !$0 { noteStep = nil } })) {
            TextField("What needs to change?", text: $noteText)
            Button("Save") { if let k = noteStep { store.addLabStep(pid, r.id, k, note: noteText) }; noteStep = nil }
            Button("Cancel", role: .cancel) { noteStep = nil }
        } message: { Text("Write what the modification or problem is") }
    }

    private func labMenu(_ L: LabWork) -> some View {
        Menu {
            ForEach(store.d.labs) { l in Button(l.name) { store.updateProcedure(pid, r.id, msg: "Lab: \(l.name)") { $0.lab?.lab = l.id; $0.lab?.svc = l.services.first?.id ?? "" } } }
        } label: { pill(store.lab(L.lab)?.name ?? "Choose a lab", sub: "Lab") }
        .buttonStyle(.plain)
    }

    private func svcMenu(_ L: LabWork, _ lab: Lab?, _ units: Int) -> some View {
        Menu {
            ForEach(lab?.services ?? []) { s in Button(s.name + " · " + Money.fmt(s.price, lab?.cur ?? .usd)) { store.updateProcedure(pid, r.id) { $0.lab?.svc = s.id } } }
        } label: {
            let sv = lab?.services.first { $0.id == L.svc }
            let per = sv?.name.lowercased().contains("per unit") ?? false
            pill(sv.map { $0.name } ?? "Type & price", sub: sv.map { Money.fmt(per ? $0.price * Double(units) : $0.price, lab?.cur ?? .usd) + (per ? " · \(units) units" : "") } ?? "Type")
        }
        .buttonStyle(.plain).disabled(lab == nil)
    }

    private func shadeButton(_ L: LabWork) -> some View {
        Button { shade = true } label: {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 5).fill(L.shade.isEmpty ? RX.card3 : Catalog.shadeColor(L.shade)).frame(width: 22, height: 26)
                VStack(alignment: .leading, spacing: 0) { Text("Shade").font(.rx(10.5)).foregroundStyle(RX.ink4); Text(L.shade.isEmpty ? "Choose" : L.shade).font(.rx(13, .semibold)) }
            }
            .padding(.horizontal, 10).frame(minHeight: 44).background(RoundedRectangle(cornerRadius: 10).fill(RX.card2))
        }
        .buttonStyle(.plain)
    }

    private func tempToggle(_ L: LabWork) -> some View {
        Button { store.updateProcedure(pid, r.id) { $0.lab?.temp.toggle() }; Haptics.tap() } label: {
            HStack(spacing: 6) {
                Image(systemName: L.temp ? "checkmark.square.fill" : "square").foregroundStyle(L.temp ? RX.mint : RX.ink3)
                Text("Temporary").font(.rx(13, .medium))
            }
            .padding(.horizontal, 10).frame(minHeight: 44).background(RoundedRectangle(cornerRadius: 10).fill(RX.card2))
        }
        .buttonStyle(.plain)
    }

    private func pill(_ t: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(sub).font(.rx(10.5)).foregroundStyle(RX.ink4)
            HStack(spacing: 6) { Text(t).font(.rx(13, .semibold)).lineLimit(1); Icon(d: Ico.chevronD, size: 9, weight: 3).foregroundStyle(RX.ink4) }
        }
        .padding(.horizontal, 10).frame(minHeight: 44).background(RoundedRectangle(cornerRadius: 10).fill(RX.card2))
    }
}

// MARK: - VITA shade picker

struct ShadePicker: View {
    @Binding var sel: String
    @Environment(\.dismiss) private var dismiss
    @State private var sys = "classical"
    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Shade", close: { dismiss() })
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SegmentPicker(items: [("classical", "VITA classical"), ("3d", "VITA 3D-Master"), ("bleach", "Bleach")], sel: $sys)
                    switch sys {
                    case "3d":
                        ForEach(Catalog.master3D, id: \.0) { g in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Value group \(g.0)").font(.rx(12)).foregroundStyle(RX.ink3)
                                FlowLayout(spacing: 8) { ForEach(g.1, id: \.self) { swatch($0) } }
                            }
                        }
                    case "bleach":
                        FlowLayout(spacing: 8) { ForEach(Catalog.bleach, id: \.0) { swatch($0.0) } }
                    default:
                        Text("Light to dark (value order)").font(.rx(12)).foregroundStyle(RX.ink3)
                        FlowLayout(spacing: 8) { ForEach(Catalog.vitaValueOrder, id: \.self) { swatch($0) } }
                        ForEach(Catalog.vitaGroups, id: \.0) { g in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(g.0) · \(g.1)").font(.rx(12)).foregroundStyle(RX.ink3)
                                FlowLayout(spacing: 8) { ForEach(g.2, id: \.self) { swatch($0) } }
                            }
                        }
                    }
                    if !sel.isEmpty { Button("No shade") { sel = ""; dismiss() }.buttonStyle(SoftButton(compact: true)) }
                }
                .padding(22)
            }
        }
        .rxSheet { dismiss() }
    }

    private func swatch(_ k: String) -> some View {
        let on = sel == k
        return Button { sel = k; Haptics.tap(); dismiss() } label: {
            VStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 8).fill(Catalog.shadeColor(k))
                    .frame(width: 44, height: 56)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(on ? RX.mint : .white.opacity(0.2), lineWidth: on ? 3 : 1))
                Text(k).font(.rx(12, .semibold)).foregroundStyle(on ? RX.mintLight : RX.ink2)
            }
        }
        .buttonStyle(.plain)
    }
}
