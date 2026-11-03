import SwiftUI

struct ProfilePayments: View {
    @Environment(Store.self) private var store
    let p: Patient
    let wide: Bool
    @State private var showForm = false

    var body: some View {
        let B = store.bill(p)
        let layout = wide ? AnyLayout(HStackLayout(alignment: .top, spacing: 16)) : AnyLayout(VStackLayout(spacing: 16))
        layout {
            VStack(alignment: .leading, spacing: 14) {
                summary(B)
                rows(B)
                changes
            }
            .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 14) {
                PaymentForm(pid: p.id, compact: !wide)
                paysList(B)
            }
            .frame(width: wide ? 360 : nil)
        }
    }

    private func summary(_ B: Bill) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Still to pay").font(.rx(12.5)).foregroundStyle(RX.ink3)
                    Text(store.money(max(0, B.due))).font(.rx(34, .bold)).foregroundStyle(B.due > 0.004 ? RX.sand : RX.mint).contentTransition(.numericText())
                    if B.credit > 0.004 { Text("Credit " + store.money(B.credit)).font(.rx(12)).foregroundStyle(RX.mintLight) }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    kv("Total", store.money(B.total), strike: B.agreed != nil ? store.money(B.subT) : nil)
                    kv("Paid", store.money(B.paid))
                    if B.labT > 0 { kv("Lab costs", "−" + store.money(B.labT)) }
                    if B.gifts > 0 { kv("Gifts 🎁", store.money(B.gifts)) }
                }
            }
            Divider().overlay(RX.line)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { discountField; totalField; deciderMenu }
                VStack(alignment: .leading, spacing: 10) { HStack { discountField; totalField }; deciderMenu }
            }
            if B.planT > 0 { Text("Planned work not charged yet: " + store.money(B.planT)).font(.rx(12)).foregroundStyle(RX.ink4) }
        }
        .padding(16).rxCard(22)
    }

    private func kv(_ k: String, _ v: String, strike: String? = nil) -> some View {
        HStack(spacing: 8) {
            Text(k).font(.rx(12.5)).foregroundStyle(RX.ink3)
            if let strike { Text(strike).font(.rx(12.5)).foregroundStyle(RX.ink4).strikethrough() }
            Text(v).font(.rx(14, .semibold)).monospacedDigit()
        }
    }

    private var discountField: some View {
        HStack(spacing: 6) {
            Text("Discount").font(.rx(12)).foregroundStyle(RX.ink3)
            NumberBox(value: p.billing.discValue, width: 64) { v in
                store.priceChange(p.id, key: "disc", kind: "disc", what: "Discount on the whole bill", from: p.billing.discValue, to: v) { $0.billing.discValue = v }
            }
            Menu {
                Button("%") { store.updatePatient(p.id, nil, undo: false) { $0.billing.discKind = .pct } }
                Button("Amount") { store.updatePatient(p.id, nil, undo: false) { $0.billing.discKind = .amt } }
            } label: { Text(p.billing.discKind == .pct ? "%" : "$").font(.rx(13, .bold)).frame(width: 34, height: 36).background(RoundedRectangle(cornerRadius: 9).fill(RX.card2)) }
            .buttonStyle(.plain)
        }
    }

    private var totalField: some View {
        HStack(spacing: 6) {
            Text("Total by hand").font(.rx(12)).foregroundStyle(RX.ink3)
            NumberBox(value: p.billing.agreed, width: 84, placeholder: "—") { v in
                store.priceChange(p.id, key: "agreed", kind: "total", what: "Total set by hand", from: p.billing.agreed ?? 0, to: v) { $0.billing.agreed = v }
            }
            if p.billing.agreed != nil {
                Button { store.updatePatient(p.id, "Back to the worked-out total") { $0.billing.agreed = nil } } label: { Image(systemName: "arrow.uturn.backward").foregroundStyle(RX.ink3) }.buttonStyle(.plain).frame(width: 30, height: 30)
            }
        }
    }

    private var deciderMenu: some View {
        HStack(spacing: 6) {
            Text("Decided by").font(.rx(12)).foregroundStyle(RX.ink3)
            RXSelect(options: store.dentists.map { ($0.id, $0.full) }, sel: Binding(get: { p.billing.decider ?? store.dentists.first?.id ?? "d1" }, set: { v in store.updatePatient(p.id, nil, undo: false) { $0.billing.decider = v } }), width: 150)
        }
    }

    private func rows(_ B: Bill) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Work and prices", sub: "tap a price to change it for this patient")
            ForEach(B.charged + B.planned) { x in BillRowView(pid: p.id, x: x) }
            if B.rows.isEmpty { EmptyNote(text: "No procedures yet") }
        }
        .padding(16).rxCard(22)
    }

    @ViewBuilder private var changes: some View {
        if !p.billing.changes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(text: "Price changes")
                ForEach(p.billing.changes.reversed()) { c in
                    HStack(spacing: 10) {
                        Chip(text: c.kind == "gift" ? "Gift" : c.kind == "total" ? "Total" : c.kind == "pdisc" ? "−%" : c.kind == "disc" ? "Discount" : "Price", color: c.kind == "gift" ? RX.mintLight : RX.sand, size: 11)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(c.what).font(.rx(13, .semibold))
                            Text("Decided by \(store.memberName(c.dent)) · typed by \(store.memberName(c.by)) · \(Day.dm(c.at)) \(Day.hm(c.at))").font(.rx(11)).foregroundStyle(RX.ink4)
                        }
                        Spacer()
                        Text("\(fmt(c.from)) → \(fmt(c.to))").font(.rx(12.5, .semibold)).monospacedDigit().foregroundStyle(RX.ink2)
                    }
                }
            }
            .padding(16).rxCard(22)
        }
    }
    private func fmt(_ v: Double) -> String { v.rounded() == v ? String(Int(v)) : String(format: "%.2f", v) }

    private func paysList(_ B: Bill) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Payments", sub: "\(B.pays.count)")
            if B.pays.isEmpty { EmptyNote(text: "No payments yet") }
            ForEach(B.pays.reversed()) { py in
                HStack(spacing: 10) {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(RX.mintLight).frame(width: 30, height: 30).background(RoundedRectangle(cornerRadius: 9).fill(RX.mint.opacity(0.16)))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(Money.fmt(py.amount, py.cur)).font(.rx(14, .bold)).monospacedDigit()
                        Text("\(Day.dmy(py.at)) \(Day.hm(py.at)) · \(py.method) · \(store.memberName(py.by))" + (py.note.isEmpty ? "" : " · " + py.note)).font(.rx(11)).foregroundStyle(RX.ink3).lineLimit(2)
                    }
                    Spacer()
                    if py.cur != .usd { Text("≈ " + Money.fmt(store.payValue(py), .usd)).font(.rx(11.5)).foregroundStyle(RX.ink4) }
                }
                .padding(10).rxPanel(12, RX.deep)
                .contextMenu { Button("Remove payment", systemImage: "trash", role: .destructive) { store.removePayment(p.id, py.id) } }
            }
        }
        .padding(16).rxCard(22)
    }
}

struct BillRowView: View {
    @Environment(Store.self) private var store
    let pid: String
    let x: BillRow
    var body: some View {
        let r = x.proc
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text(r.teeth.isEmpty ? "—" : r.teeth.joined(separator: "·")).font(.rx(13, .bold)).frame(width: 64, alignment: .leading)
                VStack(alignment: .leading, spacing: 1) {
                    Text(x.name + (x.units > 1 && r.type == "bridge" ? " · \(x.units) units" : "")).font(.rx(13.5, .semibold))
                    Text(r.status == .plan ? "Planned" : x.state.label).font(.rx(11.5, .semibold)).foregroundStyle(r.status == .plan ? RX.blue : stateColor(x.state))
                }
                Spacer()
                giftBtn(on: r.gift) { store.priceChange(pid, key: "g:" + r.id, kind: "gift", what: (r.gift ? "No longer a gift: " : "Gift: ") + x.name, from: x.base, to: r.gift ? x.base : 0) { P in if let i = P.procs.firstIndex(where: { $0.id == r.id }) { P.procs[i].gift.toggle() } } }
                HStack(spacing: 4) {
                    Text("−%").font(.rx(11)).foregroundStyle(RX.ink4)
                    NumberBox(value: r.discPct == 0 ? nil : r.discPct, width: 46, placeholder: "0") { v in
                        store.priceChange(pid, key: "d:" + r.id, kind: "pdisc", what: "Discount on " + (r.teeth.first.map { $0 + " " } ?? "") + x.name, from: r.discPct, to: v) { P in if let i = P.procs.firstIndex(where: { $0.id == r.id }) { P.procs[i].discPct = max(0, min(100, v)) } }
                    }
                }
                NumberBox(value: x.base, width: 74) { v in
                    store.priceChange(pid, key: "p:" + r.id, kind: "price", what: "Price of " + x.name, from: x.base, to: v) { P in if let i = P.procs.firstIndex(where: { $0.id == r.id }) { P.procs[i].price = v == x.list ? nil : v } }
                }
                .opacity(r.gift ? 0.4 : 1)
                Text(store.money(x.sub)).font(.rx(14, .bold)).monospacedDigit().frame(width: 86, alignment: .trailing)
            }
            if x.overridden { Text("List price \(store.money(x.list))").font(.rx(11)).foregroundStyle(RX.ink4).padding(.leading, 74) }
            ForEach(x.adds, id: \.id) { a in
                HStack(spacing: 10) {
                    Color.clear.frame(width: 64, height: 1)
                    Text("+ " + a.name).font(.rx(12.5)).foregroundStyle(RX.ink2)
                    Spacer()
                    giftBtn(on: a.gift) { store.priceChange(pid, key: "ag:" + r.id + ":" + a.id, kind: "gift", what: (a.gift ? "No longer a gift: " : "Gift: ") + a.name + " on " + x.name, from: a.price, to: a.gift ? a.price : 0) { P in
                        if let i = P.procs.firstIndex(where: { $0.id == r.id }) { if P.procs[i].giftAddons.contains(a.id) { P.procs[i].giftAddons.removeAll { $0 == a.id } } else { P.procs[i].giftAddons.append(a.id) } } } }
                    NumberBox(value: a.price, width: 74) { v in
                        store.priceChange(pid, key: "ap:" + r.id + a.id, kind: "price", what: "Price of " + a.name, from: a.price, to: v) { P in if let i = P.procs.firstIndex(where: { $0.id == r.id }) { P.procs[i].addPrices[a.id] = v } }
                    }
                    .opacity(a.gift ? 0.4 : 1)
                    Color.clear.frame(width: 86, height: 1)
                }
            }
            if x.labCost > 0 { Text("Lab: \(x.labName) · −\(store.money(x.labCost))").font(.rx(11)).foregroundStyle(RX.tan).padding(.leading, 74) }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14).fill(RX.card))
    }

    private func giftBtn(on: Bool, _ a: @escaping () -> Void) -> some View {
        Button { a(); Haptics.tap() } label: {
            Text("🎁").font(.system(size: 15)).grayscale(on ? 0 : 1).opacity(on ? 1 : 0.45)
                .frame(width: 36, height: 36).background(RoundedRectangle(cornerRadius: 9).fill(on ? RX.mint.opacity(0.2) : RX.card2))
        }
        .buttonStyle(.plain).accessibilityLabel(on ? "Gift" : "Make it a gift")
    }
    private func stateColor(_ s: PayState) -> Color { switch s { case .paid: RX.mint; case .part: RX.sand; case .unpaid: RX.salmon; default: RX.mintLight } }
}

/// Number entry that commits when editing ends.
struct NumberBox: View {
    let value: Double?
    var width: CGFloat = 70
    var placeholder = ""
    let commit: (Double) -> Void
    @State private var text = ""
    @FocusState private var focus: Bool
    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(RX.ink4))
            .font(.rx(13.5, .semibold)).monospacedDigit().multilineTextAlignment(.trailing)
            .keyboardType(.decimalPad).focused($focus)
            .padding(.horizontal, 8).frame(width: width, height: 36)
            .background(RoundedRectangle(cornerRadius: 9).fill(RX.card2))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(focus ? RX.mint : RX.line2))
            .onAppear { text = value.map(Self.str) ?? "" }
            .onChange(of: value) { _, v in if !focus { text = v.map(Self.str) ?? "" } }
            .onChange(of: focus) { _, f in if !f, let v = Double(text.replacingOccurrences(of: ",", with: ".")), v != value { commit(v) } }
            .onSubmit { if let v = Double(text), v != value { commit(v) } }
    }
    static func str(_ v: Double) -> String { v.rounded() == v ? String(Int(v)) : String(format: "%.2f", v) }
}

/// Record a payment: amount (suggested), currency, how, "Paid on" that follows the clock until changed, and which procedures it is for.
struct PaymentForm: View {
    @Environment(Store.self) private var store
    let pid: String
    var compact = false
    @State private var amount = ""
    @State private var typed = false
    @State private var cur: Currency = .usd
    @State private var method = "Cash"
    @State private var note = ""
    @State private var when: Date?
    @State private var items: [String] = []

    var body: some View {
        if let p = store.patient(pid) {
            let B = store.bill(p)
            let open = B.charged.filter { $0.state == .unpaid || $0.state == .part }
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Take a payment").font(.rx(15, .semibold))
                    Spacer()
                    Text(B.due > 0.004 ? store.money(B.due) + " still to pay" : "Nothing to pay").font(.rx(12)).foregroundStyle(RX.ink3)
                }
                HStack(spacing: 8) {
                    TextField("", text: Binding(get: { typed ? amount : suggest(B) }, set: { amount = $0; typed = true }), prompt: Text("Amount").foregroundStyle(RX.ink4))
                        .font(.rx(20, .bold)).monospacedDigit().keyboardType(.decimalPad)
                        .padding(.horizontal, 12).frame(height: 50).rxPanel(12, RX.deep)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(RX.line2))
                    RXSelect(options: Currency.allCases.map { ($0, $0.short) }, sel: Binding(get: { cur }, set: { cur = $0; if !typed { amount = "" } }), width: 104)
                }
                if cur != .usd, let v = Double(typed ? amount : suggest(B)), v > 0 { Text("≈ " + Money.fmt(store.d.fx.conv(v, cur, .usd), .usd)).font(.rx(12)).foregroundStyle(RX.ink3) }
                HStack(spacing: 8) {
                    RXSelect(options: ["Cash", "Card", "Bank transfer", "Insurance"].map { ($0, $0) }, sel: $method)
                    TextField("", text: $note, prompt: Text("Note").foregroundStyle(RX.ink4)).font(.rx(14)).padding(.horizontal, 12).frame(height: 42).rxPanel(10)
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("Paid on").font(.rx(12)).foregroundStyle(RX.ink3)
                        if when == nil { Chip(text: "Now", color: RX.mintLight, size: 10.5) }
                        else { Button("Back to now") { when = nil }.font(.rx(11.5)).foregroundStyle(RX.ink3).underline().buttonStyle(.plain) }
                    }
                    TimelineView(.periodic(from: .now, by: 30)) { ctx in
                        DatePicker("", selection: Binding(get: { when ?? ctx.date }, set: { when = min($0, .now) }), in: ...Date.now, displayedComponents: [.date, .hourAndMinute]).labelsHidden()
                    }
                }
                if !open.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("For (optional — otherwise oldest first)").font(.rx(12)).foregroundStyle(RX.ink3)
                        ForEach(open) { x in
                            let on = items.contains(x.id)
                            Button { if on { items.removeAll { $0 == x.id } } else { items.append(x.id) }; typed = false; Haptics.tap() } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: on ? "checkmark.square.fill" : "square").foregroundStyle(on ? RX.mint : RX.ink3)
                                    Text((x.proc.teeth.isEmpty ? "" : x.proc.teeth.joined(separator: "·") + " · ") + x.name).font(.rx(13))
                                    Spacer()
                                    Text(store.money(x.left)).font(.rx(12.5, .semibold)).foregroundStyle(RX.ink2)
                                }
                                .contentShape(Rectangle()).frame(minHeight: 34)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Button {
                    let v = Double((typed ? amount : suggest(B)).replacingOccurrences(of: ",", with: "")) ?? 0
                    guard v > 0 else { store.flash("Type the amount first", undo: false); return }
                    store.addPayment(pid, amount: v, cur: cur, method: method, note: note, items: items, at: when ?? .now)
                    amount = ""; typed = false; note = ""; when = nil; items = []
                } label: { Text("Save payment").frame(maxWidth: .infinity) }
                .buttonStyle(MintButton())
            }
            .padding(16).rxCard(22)
        }
    }

    private func suggest(_ B: Bill) -> String {
        let usd = items.isEmpty ? max(0, B.due) : B.charged.filter { items.contains($0.id) }.reduce(0) { $0 + $1.left }
        guard usd > 0.004 else { return "" }
        let v = store.d.fx.conv(usd, .usd, cur)
        return cur == .syp ? String(Int(v.rounded())) : NumberBox.str((v * 100).rounded() / 100)
    }
}
