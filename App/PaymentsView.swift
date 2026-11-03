import SwiftUI
import Charts

struct PaymentsView: View {
    @Environment(Store.self) private var store
    @Environment(\.horizontalSizeClass) private var hsc
    @State private var tab = "dash"
    @State private var sort = "owe"
    @State private var q = ""
    @State private var lateF = 0
    @State private var payFor: String?

    var body: some View {
        @Bindable var store = store
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Payments").font(.rx(hsc == .compact ? 28 : 34, .bold)).tracking(-0.8)
                        Text("What came in, what the work is worth, and who still owes").font(.rx(15)).foregroundStyle(RX.ink3)
                    }
                    Spacer()
                    SegmentPicker(items: Currency.allCases.map { ($0, $0.sym) }, sel: $store.payShow)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    SegmentPicker(items: [("dash", "Overview"), ("due", "Balances"), ("adj", "Discounts & gifts"), ("labs", "Labs"), ("late", "Late payments · \(late.count)"), ("log", "Payments"), ("fx", "Currency & cash box")], sel: $tab)
                }
                switch tab {
                case "due": balances
                case "adj": adjustments
                case "labs": LabPayments()
                case "late": latePayments
                case "log": paymentsLog
                case "fx": currency
                default: overview
                }
            }
            .padding(.horizontal, hsc == .compact ? 14 : 32).padding(.vertical, hsc == .compact ? 8 : 28).padding(.bottom, 80)
        }
        .sheet(item: Binding(get: { payFor.map { IDBox(id: $0) } }, set: { payFor = $0?.id })) { b in
            VStack(spacing: 0) {
                SheetHeader(title: store.patient(b.id)?.name ?? "Payment", close: { payFor = nil })
                ScrollView { PaymentForm(pid: b.id).padding(20) }
            }
            .rxSheet { payFor = nil }.presentationDetents([.large]).presentationSizing(.form)
        }
        .onAppear {
            switch DemoScreen.current { case "paybal": tab = "due"; case "paylate": tab = "late"; case "paylabs": tab = "labs"; default: break }
        }
    }

    // MARK: data

    private struct Pay { let pid: String; let py: Payment; let v: Double; let day: String }
    private struct Work { let pid: String; let row: BillRow; let v: Double; let lab: Double; let day: String }

    private var all: (pays: [Pay], work: [Work], bills: [(Patient, Bill)]) {
        var P: [Pay] = [], W: [Work] = [], B: [(Patient, Bill)] = []
        for p in store.d.patients {
            let b = store.bill(p); B.append((p, b))
            for py in b.pays { P.append(Pay(pid: p.id, py: py, v: store.payValue(py), day: Day.iso(py.at))) }
            for x in b.charged { W.append(Work(pid: p.id, row: x, v: x.net, lab: x.labCost, day: Day.iso(x.day))) }
        }
        return (P, W, B)
    }

    private var late: [(Patient, Bill, Int)] {
        all.bills.compactMap { item -> (Patient, Bill, Int)? in
            let (p, b) = item
            guard b.due > 0.004 else { return nil }
            let oldest = b.charged.filter { $0.left > 0.004 }.map(\.day).min() ?? .now
            return (p, b, max(0, Int(Date.now.timeIntervalSince(oldest) / 86400)))
        }.sorted { $0.2 > $1.2 }
    }

    // MARK: overview

    private var overview: some View {
        let A = all, T = store.today, mon = String(T.prefix(7))
        let recMon = A.pays.filter { $0.day.hasPrefix(mon) }.reduce(0) { $0 + $1.v }
        let workMon = A.work.filter { $0.day.hasPrefix(mon) }.reduce(0) { $0 + $1.v }
        let labMon = A.work.filter { $0.day.hasPrefix(mon) }.reduce(0) { $0 + $1.lab }
        let owing = A.bills.filter { $0.1.due > 0.004 }
        let outstanding = owing.reduce(0) { $0 + $1.1.due }
        let days = (0..<14).map { Day.add(T, $0 - 13) }
        let box = store.cashBox
        return VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 12)], spacing: 12) {
                kpi("Cash received this month", store.money(recMon), "\(A.pays.filter { $0.day.hasPrefix(mon) }.count) payments", RX.mintLight)
                kpi("Work done this month", store.money(workMon), "Charged to patients", RX.ink)
                kpi("Earned after lab costs", store.money(workMon - labMon), "Lab costs " + store.money(labMon), RX.sand)
                kpi("Still to collect", store.money(outstanding), "\(owing.count) patients owe", RX.salmon)
            }
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) { chart14(days, A).frame(maxWidth: .infinity); VStack(spacing: 12) { today(A, T); cashBox(box) }.frame(width: 340) }
                VStack(spacing: 12) { chart14(days, A); today(A, T); cashBox(box) }
            }
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) { months(A); notes(A, outstanding, recMon, workMon, labMon); byDentist(A, mon) }
                VStack(spacing: 12) { months(A); notes(A, outstanding, recMon, workMon, labMon); byDentist(A, mon) }
            }
        }
    }

    private func kpi(_ l: String, _ v: String, _ sub: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(l).font(.rx(12.5)).foregroundStyle(RX.ink3)
            Text(v).font(.rx(26, .bold)).tracking(-0.4).foregroundStyle(c).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            Text(sub).font(.rx(11.5)).foregroundStyle(RX.ink4)
        }
        .padding(.horizontal, 18).padding(.vertical, 16).frame(maxWidth: .infinity, alignment: .leading)
        .rxCard(18)
    }

    private func conv(_ usd: Double) -> Double { store.d.fx.conv(usd, .usd, store.payShow) }

    private func chart14(_ days: [String], _ A: (pays: [Pay], work: [Work], bills: [(Patient, Bill)])) -> some View {
        let data = days.flatMap { d -> [BarPt] in
            [BarPt(x: Day.date(d), kind: "Received", v: conv(A.pays.filter { $0.day == d }.reduce(0) { $0 + $1.v })), BarPt(x: Day.date(d), kind: "Work done", v: conv(A.work.filter { $0.day == d }.reduce(0) { $0 + $1.v }))]
        }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Last 14 days").font(.rx(15, .semibold))
                Spacer()
                legendDot(RX.mint, "Received"); legendDot(Color(rgb: 0xD6EBE4, 0.28), "Work done")
            }
            Chart(data) { d in
                BarMark(x: .value("Day", d.x, unit: .day), y: .value("Amount", d.v))
                    .foregroundStyle(d.kind == "Received" ? RX.mint : Color(rgb: 0xD6EBE4, 0.28))
                    .position(by: .value("Kind", d.kind))
                    .cornerRadius(3)
            }
            .chartXAxis { AxisMarks(values: .stride(by: .day, count: 2)) { _ in AxisValueLabel(format: .dateTime.weekday(.narrow)).foregroundStyle(RX.ink3) } }
            .chartYAxis { AxisMarks { _ in AxisGridLine().foregroundStyle(RX.line); AxisValueLabel().foregroundStyle(RX.ink4) } }
            .frame(height: 170)
        }
        .padding(18).rxCard(20)
    }

    private func legendDot(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 6) { RoundedRectangle(cornerRadius: 3).fill(c).frame(width: 10, height: 10); Text(t).font(.rx(12)).foregroundStyle(RX.ink3) }
    }

    private func today(_ A: (pays: [Pay], work: [Work], bills: [(Patient, Bill)]), _ T: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) { Text("Received today").font(.rx(12)).foregroundStyle(RX.ink3); Text(store.money(A.pays.filter { $0.day == T }.reduce(0) { $0 + $1.v })).font(.rx(20, .bold)) }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading).rxCard(16)
            VStack(alignment: .leading, spacing: 3) { Text("Work done today").font(.rx(12)).foregroundStyle(RX.ink3); Text(store.money(A.work.filter { $0.day == T }.reduce(0) { $0 + $1.v })).font(.rx(20, .bold)) }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading).rxCard(16)
        }
    }

    private func cashBox(_ box: [Currency: Double]) -> some View {
        let total = box.reduce(0) { $0 + store.d.fx.conv($1.value, $1.key, .usd) }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Icon(d: Ico.cash, size: 16).foregroundStyle(RX.mintLight)
                Text("In the cash box").font(.rx(14, .semibold))
                Spacer()
                Text(store.d.cashOutAt == .distantPast ? "Since the start" : "Since " + Day.dm(store.d.cashOutAt) + " " + Day.hm(store.d.cashOutAt)).font(.rx(11.5)).foregroundStyle(RX.ink3)
            }
            HStack(spacing: 16) {
                ForEach(Currency.allCases) { c in Text(Money.fmt(box[c] ?? 0, c)).font(.rx(18, .bold)).monospacedDigit().opacity((box[c] ?? 0) > 0 ? 1 : 0.4) }
            }
            HStack {
                Text(store.money(total) + " in cash").font(.rx(12)).foregroundStyle(RX.mintLight)
                Spacer()
                Button("Count & empty it") { store.emptyCashBox() }.buttonStyle(SoftButton(compact: true, fill: Color(rgb: 0x0A211D, 0.6)))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(LinearGradient(colors: [Color(rgb: 0x34C3A4, 0.14), Color(rgb: 0x10302A, 0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(RX.mint.opacity(0.3)))
    }

    private func months(_ A: (pays: [Pay], work: [Work], bills: [(Patient, Bill)])) -> some View {
        let ms = (0..<6).map { i -> String in let d = Day.cal.date(byAdding: .month, value: i - 5, to: .now) ?? .now; return String(Day.iso(d).prefix(7)) }
        let data = ms.flatMap { m -> [BarPt] in
            [BarPt(x: Day.date(m + "-01"), kind: "Received", v: conv(A.pays.filter { $0.day.hasPrefix(m) }.reduce(0) { $0 + $1.v })), BarPt(x: Day.date(m + "-01"), kind: "Work done", v: conv(A.work.filter { $0.day.hasPrefix(m) }.reduce(0) { $0 + $1.v }))]
        }
        return VStack(alignment: .leading, spacing: 12) {
            Text("Last 6 months").font(.rx(15, .semibold))
            Chart(data) { d in
                BarMark(x: .value("Month", d.x, unit: .month), y: .value("Amount", d.v))
                    .foregroundStyle(d.kind == "Received" ? RX.mint : Color(rgb: 0xD6EBE4, 0.28))
                    .position(by: .value("Kind", d.kind)).cornerRadius(4)
            }
            .chartXAxis { AxisMarks(values: .stride(by: .month)) { _ in AxisValueLabel(format: .dateTime.month(.abbreviated)).foregroundStyle(RX.ink3) } }
            .chartYAxis { AxisMarks { _ in AxisGridLine().foregroundStyle(RX.line); AxisValueLabel().foregroundStyle(RX.ink4) } }
            .frame(height: 170)
        }
        .padding(18).frame(maxWidth: .infinity).rxCard(20)
    }

    private func notes(_ A: (pays: [Pay], work: [Work], bills: [(Patient, Bill)]), _ outstanding: Double, _ rec: Double, _ work: Double, _ lab: Double) -> some View {
        var N: [(String, Color)] = []
        if work > 0 { N.append(("Collection rate this month: \(Int((rec / work * 100).rounded()))% of the work done was paid.", RX.mintLight)) }
        let byDay = Dictionary(grouping: A.pays) { $0.day }.mapValues { $0.reduce(0) { $0 + $1.v } }
        if let best = byDay.max(by: { $0.value < $1.value }) { N.append(("Best day: \(Day.short(best.key)) with \(store.money(best.value)).", RX.ink2)) }
        let top = Dictionary(grouping: A.work) { $0.row.name }.mapValues { $0.reduce(0) { $0 + $1.v } }.max { $0.value < $1.value }
        if let top { N.append(("Top procedure: \(top.key) · \(store.money(top.value)).", RX.ink2)) }
        if work > 0 && lab > 0 { N.append(("Lab costs are \(Int((lab / work * 100).rounded()))% of this month's work.", RX.tan)) }
        let big = A.bills.filter { $0.1.due > 300 }.count
        if big > 0 { N.append(("\(big) patient\(big == 1 ? "" : "s") owe more than \(store.money(300)).", RX.salmon)) }
        let gifts = A.bills.reduce(0) { $0 + $1.1.gifts }
        if gifts > 0 { N.append(("Gifts given: \(store.money(gifts)).", RX.mintLight)) }
        return VStack(alignment: .leading, spacing: 10) {
            Text("Good to know").font(.rx(15, .semibold))
            ForEach(N, id: \.0) { n in
                HStack(alignment: .top, spacing: 9) { Circle().fill(n.1).frame(width: 6, height: 6).padding(.top, 7); Text(n.0).font(.rx(13)).foregroundStyle(n.1) }
            }
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading).rxCard(20)
    }

    private func byDentist(_ A: (pays: [Pay], work: [Work], bills: [(Patient, Bill)]), _ mon: String) -> some View {
        let L = store.dentists.map { d in (d, A.work.filter { $0.day.hasPrefix(mon) && $0.row.proc.by == d.id }.reduce(0) { $0 + $1.v }) }
        let mx = max(1, L.map(\.1).max() ?? 1)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Work done this month, by dentist").font(.rx(15, .semibold))
            ForEach(L, id: \.0.id) { d, v in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 9) { MemberAvatar(m: d, size: 26); Text(d.full).font(.rx(13.5, .semibold)); Spacer(); Text(store.money(v)).font(.rx(13.5, .bold)).monospacedDigit() }
                    GeometryReader { g in Capsule().fill(d.color).frame(width: g.size.width * v / mx, height: 6) }.frame(height: 6)
                }
            }
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading).rxCard(20)
    }

    // MARK: balances

    private var balances: some View {
        let t = q.lowercased()
        var L = all.bills.filter { t.isEmpty || $0.0.name.lowercased().contains(t) }
        switch sort {
        case "owe": L.sort { $0.1.due > $1.1.due }
        case "oweLeast": L.sort { $0.1.due < $1.1.due }
        case "paid": L.sort { $0.1.paid > $1.1.paid }
        case "paidLeast": L.sort { $0.1.paid < $1.1.paid }
        default: L.sort { $0.0.name < $1.0.name }
        }
        let owing = L.filter { $0.1.due > 0.004 }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                searchBox
                Spacer()
                Text("Sort").font(.rx(12.5)).foregroundStyle(RX.ink3)
                RXSelect(options: [("owe", "Owes the most"), ("oweLeast", "Owes the least"), ("paid", "Paid the most"), ("paidLeast", "Paid the least"), ("name", "Name")], sel: $sort, width: 170)
            }
            Text("\(owing.count) owe · \(store.money(owing.reduce(0) { $0 + $1.1.due })) in total").font(.rx(12.5)).foregroundStyle(RX.ink3)
            ForEach(L, id: \.0.id) { p, b in
                Button { store.section = .patients; store.openPatient = p.id } label: {
                    HStack(spacing: 14) {
                        PatientIcon(p: p, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.name).font(.rx(15, .semibold))
                            Text(b.pays.last.map { "Last paid " + Day.dm($0.at) } ?? "Never paid").font(.rx(12)).foregroundStyle(RX.ink3)
                        }
                        Spacer()
                        if hsc != .compact {
                            col("Total", store.money(b.total), RX.ink)
                            col("Paid", store.money(b.paid), RX.mintLight)
                        }
                        col("Still to pay", store.money(max(0, b.due)), b.due > 0.004 ? RX.sand : RX.ink3, bold: true)
                        if b.due > 0.004 { Button("Take payment") { payFor = p.id }.buttonStyle(MintButton(compact: true)) } else { Color.clear.frame(width: 110, height: 1) }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12).rxCard(16)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func col(_ l: String, _ v: String, _ c: Color, bold: Bool = false) -> some View {
        VStack(alignment: .trailing, spacing: 1) { Text(l).font(.rx(11)).foregroundStyle(RX.ink4); Text(v).font(.rx(bold ? 16 : 14, bold ? .bold : .regular)).foregroundStyle(c).monospacedDigit() }.frame(minWidth: 110, alignment: .trailing)
    }

    private var searchBox: some View {
        HStack(spacing: 8) {
            Icon(d: Ico.search, size: 14).foregroundStyle(RX.ink3)
            TextField("", text: $q, prompt: Text("Find a patient").foregroundStyle(RX.ink4)).font(.rx(14))
        }
        .padding(.horizontal, 12).frame(width: 260, height: 40).rxPanel(12, RX.card)
    }

    // MARK: discounts & gifts

    private var adjustments: some View {
        let L = store.d.patients.filter { !$0.billing.changes.isEmpty }.sorted { ($0.billing.changes.last?.at ?? .distantPast) > ($1.billing.changes.last?.at ?? .distantPast) }
        return VStack(alignment: .leading, spacing: 10) {
            Text("\(L.count) patients with a gift, discount, changed price or hand-set total").font(.rx(12.5)).foregroundStyle(RX.ink3)
            ForEach(L) { p in
                let b = store.bill(p)
                Button { store.section = .patients; store.openPatient = p.id } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            PatientIcon(p: p, size: 40)
                            VStack(alignment: .leading, spacing: 2) { Text(p.name).font(.rx(16, .semibold)); Text("Last change " + Day.dm(p.billing.changes.last?.at ?? .now)).font(.rx(12)).foregroundStyle(RX.ink3) }
                            Spacer()
                            store.dentChip(p.billing.decider ?? p.billing.changes.last?.dent)
                            Text(store.money(b.disc + b.gifts + b.rowDiscT)).font(.rx(17, .bold)).foregroundStyle(RX.mintLight).frame(minWidth: 100, alignment: .trailing)
                        }
                        ForEach(p.billing.changes.reversed()) { c in
                            HStack(spacing: 10) {
                                Chip(text: c.what, color: c.kind == "gift" ? RX.mintLight : RX.sand, size: 12)
                                Text("typed by \(store.memberName(c.by)) · \(Day.dm(c.at))").font(.rx(11.5)).foregroundStyle(RX.ink4)
                                Spacer()
                                Text("\(NumberBox.str(c.from)) → \(NumberBox.str(c.to))").font(.rx(13, .semibold)).foregroundStyle(RX.ink2)
                            }
                            .padding(.leading, 52)
                        }
                    }
                    .padding(14).rxCard(18)
                }
                .buttonStyle(.plain)
            }
            if L.isEmpty { EmptyNote(text: "No gifts, discounts or price changes.") }
        }
    }

    // MARK: late payments

    private var latePayments: some View {
        let thresholds = [0, 7, 14, 30, 60]
        let L = late.filter { $0.2 >= thresholds[lateF] }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                SegmentPicker(items: [(0, "All"), (1, "1 week +"), (2, "2 weeks +"), (3, "1 month +"), (4, "2 months +")], sel: $lateF)
                Spacer()
            }
            Text("\(L.count) patients · longest waiting first").font(.rx(12.5)).foregroundStyle(RX.ink3)
            ForEach(L, id: \.0.id) { p, b, days in
                let score = min(100, Int(Double(days) / 60 * 100)), c = Color(hue: 0.0 + 0.36 * (1 - Double(score) / 100) * 0.4, saturation: 0.55 + Double(score) / 300, brightness: 0.9)
                HStack(spacing: 14) {
                    PatientIcon(p: p, size: 40)
                    VStack(alignment: .leading, spacing: 2) { Text(p.name).font(.rx(15, .semibold)); Text("Oldest unpaid work \(days) day\(days == 1 ? "" : "s") ago").font(.rx(12)).foregroundStyle(RX.ink3) }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Lateness \(score)").font(.rx(11.5, .semibold)).foregroundStyle(c)
                        GeometryReader { g in ZStack(alignment: .leading) { Capsule().fill(RX.card2); Capsule().fill(c).frame(width: g.size.width * Double(score) / 100) } }.frame(width: 120, height: 6)
                    }
                    col("Owes", store.money(b.due), RX.sand, bold: true)
                    if !p.phone.isEmpty {
                        Button { openWhatsApp(p.phone, "Hello \(p.first), this is Rayhan Clinics. A friendly reminder that \(Money.fmt(b.due, .usd)) is still due for your treatment. Thank you!") } label: { Label("Remind", systemImage: "message.fill") }
                            .buttonStyle(SoftButton(compact: true, tint: Color(rgb: 0x7FE3A6), fill: RX.whatsapp.opacity(0.14)))
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 16).fill(c.opacity(0.08 + Double(score) / 600)))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(c.opacity(0.25 + Double(score) / 300)))
            }
            if L.isEmpty { EmptyNote(text: "Nobody is late") }
        }
    }

    // MARK: payments log

    private var paymentsLog: some View {
        let A = all.pays.sorted { $0.py.at > $1.py.at }
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) { recordBox.frame(width: 380); logList(A) }
            VStack(spacing: 16) { recordBox; logList(A) }
        }
    }

    @State private var pickQ = ""
    @State private var picked: String?
    private var recordBox: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Record a payment").font(.rx(15, .semibold))
            if let id = picked, let p = store.patient(id) {
                HStack { PatientIcon(p: p, size: 34); Text(p.name).font(.rx(15, .semibold)); Spacer(); Button("Change") { picked = nil }.font(.rx(13)).foregroundStyle(RX.mint).buttonStyle(.plain) }
                PaymentForm(pid: id)
            } else {
                HStack(spacing: 8) {
                    Icon(d: Ico.search, size: 14).foregroundStyle(RX.ink3)
                    TextField("", text: $pickQ, prompt: Text("Type a name to find the patient").foregroundStyle(RX.ink4)).font(.rx(14))
                }
                .padding(.horizontal, 12).frame(height: 44).rxPanel(12)
                let L = store.d.patients.filter { pickQ.isEmpty || $0.name.lowercased().contains(pickQ.lowercased()) }.sorted { store.bill($0).due > store.bill($1).due }.prefix(8)
                ForEach(Array(L)) { p in
                    Button { picked = p.id; pickQ = "" } label: {
                        HStack { PatientIcon(p: p, size: 28); Text(p.name).font(.rx(13.5)); Spacer(); let d = store.bill(p).due; if d > 0.004 { Text(store.money(d)).font(.rx(12.5, .semibold)).foregroundStyle(RX.sand) } }
                            .padding(.vertical, 4).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16).rxCard(20)
    }

    private func logList(_ A: [Pay]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "All payments", sub: "\(A.count)")
            ForEach(A, id: \.py.id) { x in
                HStack(spacing: 12) {
                    PatientIcon(p: store.patient(x.pid), size: 32)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(store.patient(x.pid)?.name ?? "").font(.rx(14, .semibold))
                        Text("\(Day.dmy(x.py.at)) \(Day.hm(x.py.at)) · \(x.py.method) · \(store.memberName(x.py.by))").font(.rx(11.5)).foregroundStyle(RX.ink3)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(Money.fmt(x.py.amount, x.py.cur)).font(.rx(14, .bold)).monospacedDigit()
                        if x.py.cur != store.payShow { Text("≈ " + store.money(x.v)).font(.rx(11)).foregroundStyle(RX.ink4) }
                    }
                }
                .padding(12).rxCard(14, fill: RX.card)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: currency

    private var currency: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Exchange rates").font(.rx(15, .semibold))
                HStack(spacing: 10) {
                    Text("$1 =").font(.rx(15))
                    NumberBox(value: store.d.fx.syp, width: 110) { v in store.change("Rate saved") { $0.fx.syp = v } }
                    Text("SYP").font(.rx(13)).foregroundStyle(RX.ink3)
                }
                HStack(spacing: 10) {
                    Text("$1 =").font(.rx(15))
                    NumberBox(value: store.d.fx.eur, width: 110) { v in store.change("Rate saved") { $0.fx.eur = v } }
                    Text("€").font(.rx(13)).foregroundStyle(RX.ink3)
                }
                Text("Each payment keeps the rate of its day, so changing the rate does not change old payments.").font(.rx(12)).foregroundStyle(RX.ink4)
            }
            .padding(18).rxCard(20)
            cashBox(store.cashBox)
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(text: "Cash box history")
                if store.d.cashLog.isEmpty { EmptyNote(text: "Not emptied yet") }
                ForEach(store.d.cashLog) { e in
                    HStack {
                        Text(Day.dmy(e.at) + " " + Day.hm(e.at)).font(.rx(13))
                        Text(store.memberName(e.by)).font(.rx(12)).foregroundStyle(RX.ink3)
                        Spacer()
                        Text([Money.fmt(e.usd, .usd), Money.fmt(e.syp, .syp), Money.fmt(e.eur, .eur)].joined(separator: " · ")).font(.rx(13, .semibold))
                    }
                    .padding(10).rxPanel(12, RX.card)
                }
            }
        }
        .frame(maxWidth: 700, alignment: .leading)
    }
}

struct IDBox: Identifiable { let id: String }
struct BarPt: Identifiable { let id = UUID(); let x: Date; let kind: String; let v: Double }

// MARK: - Labs: owed, paid, pay the lab

struct LabPayments: View {
    @Environment(Store.self) private var store
    @State private var sel: String?
    @State private var amount = ""
    @State private var typed = false
    @State private var cur: Currency?
    @State private var method = "Cash"
    @State private var note = ""
    @State private var when: Date?

    private struct Row { let lab: Lab; let bills: [Store.LabBill]; let pays: [LabPayment]; let billed: Double; let pending: Double; let paid: Double; let owe: Double }

    var body: some View {
        let B = store.labBills(), fx = store.d.fx
        let rows: [Row] = store.d.labs.map { l in
            let bl = B.filter { $0.lab.id == l.id }, ps = store.d.labPays.filter { $0.lab == l.id }
            let billed = bl.filter(\.billed).reduce(0) { $0 + $1.cost }, pending = bl.filter { !$0.billed && $0.sent }.reduce(0) { $0 + $1.cost }
            let paid = ps.reduce(0) { $0 + fx.conv($1.amount, $1.cur, l.cur, rateFrom: $1.rate) }
            let owe0 = billed - paid
            return Row(lab: l, bills: bl, pays: ps, billed: billed, pending: pending, paid: paid, owe: l.cur == .syp ? owe0.rounded() : (owe0 * 100).rounded() / 100)
        }
        let mon = String(store.today.prefix(7))
        let owedAll = rows.reduce(0) { $0 + max(0, fx.conv($1.owe, $1.lab.cur, .usd)) }
        let paidMon = store.d.labPays.filter { Day.iso($0.at).hasPrefix(mon) }.reduce(0) { $0 + fx.conv($1.amount, $1.cur, .usd, rateFrom: $1.rate) }
        let billMon = B.filter { $0.billed && Day.iso($0.at).hasPrefix(mon) }.reduce(0) { $0 + fx.conv($1.cost, $1.lab.cur, .usd) }
        let pend = rows.reduce(0) { $0 + fx.conv($1.pending, $1.lab.cur, .usd) }
        let S = rows.first { $0.lab.id == sel } ?? rows.max { fx.conv($0.owe, $0.lab.cur, .usd) < fx.conv($1.owe, $1.lab.cur, .usd) }
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 12)], spacing: 12) {
                kpi("Owed to labs", store.money(owedAll), "\(rows.filter { $0.owe > 0.004 }.count) labs to pay", RX.sand)
                kpi("Paid to labs this month", store.money(paidMon), "Money that went out", RX.mintLight)
                kpi("Lab work billed this month", store.money(billMon), "Work that came back from labs", RX.ink)
                kpi("Still at the labs", store.money(pend), "Will be billed when it comes back", RX.tan)
            }
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 14) { cards(rows, S).frame(maxWidth: .infinity); if let S { account(S).frame(maxWidth: .infinity) } }
                VStack(spacing: 14) { cards(rows, S); if let S { account(S) } }
            }
        }
    }

    private func kpi(_ l: String, _ v: String, _ sub: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(l).font(.rx(12.5)).foregroundStyle(RX.ink3)
            Text(v).font(.rx(26, .bold)).foregroundStyle(c).monospacedDigit()
            Text(sub).font(.rx(11.5)).foregroundStyle(RX.ink4)
        }
        .padding(.horizontal, 18).padding(.vertical, 16).frame(maxWidth: .infinity, alignment: .leading).rxCard(18)
    }

    private func cards(_ rows: [Row], _ S: Row?) -> some View {
        VStack(spacing: 10) {
            ForEach(rows, id: \.lab.id) { r in
                let on = S?.lab.id == r.lab.id
                let pct = r.billed > 0 ? max(0, min(1, r.paid / r.billed)) : 1
                Button { sel = r.lab.id; amount = ""; typed = false; cur = nil; Haptics.tap() } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            LabLogo(lab: r.lab, size: 42)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.lab.name).font(.rx(15.5, .semibold))
                                Text(r.pays.max { $0.at < $1.at }.map { "Last paid " + Day.dm($0.at) } ?? "Never paid").font(.rx(12)).foregroundStyle(RX.ink3)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 1) {
                                Text("You owe").font(.rx(11)).foregroundStyle(RX.ink4)
                                Text(r.owe > 0.004 ? Money.fmt(r.owe, r.lab.cur) : r.owe < -0.004 ? Money.fmt(-r.owe, r.lab.cur) + " credit" : "Nothing owed").font(.rx(18, .bold)).foregroundStyle(r.owe > 0.004 ? RX.sand : RX.mintLight)
                            }
                        }
                        GeometryReader { g in ZStack(alignment: .leading) { Capsule().fill(Color(rgb: 0xD6EBE4, 0.08)); Capsule().fill(LinearGradient(colors: [RX.mint, RX.mintLight], startPoint: .leading, endPoint: .trailing)).frame(width: g.size.width * pct) } }.frame(height: 6)
                        HStack(spacing: 12) {
                            Text("Billed ").font(.rx(12)).foregroundStyle(RX.ink3) + Text(Money.fmt(r.billed, r.lab.cur)).font(.rx(12, .bold))
                            Text("Paid ").font(.rx(12)).foregroundStyle(RX.ink3) + Text(Money.fmt(r.paid, r.lab.cur)).font(.rx(12, .bold)).foregroundStyle(RX.mintLight)
                            Spacer()
                            Text("\(Int(pct * 100))% paid").font(.rx(12)).foregroundStyle(RX.ink3)
                        }
                        Text(r.pending > 0 ? Money.fmt(r.pending, r.lab.cur) + " still at the lab" : "Nothing at the lab").font(.rx(12)).foregroundStyle(RX.tan)
                    }
                    .padding(14).rxCard(18)
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(on ? RX.gold : .clear, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func account(_ S: Row) -> some View {
        let c = cur ?? S.lab.cur
        let sugg = max(0, store.d.fx.conv(S.owe, S.lab.cur, c))
        let suggTxt = sugg > 0.004 ? (c == .syp ? String(Int(sugg.rounded())) : NumberBox.str((sugg * 100).rounded() / 100)) : ""
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) { Text("Account with").font(.rx(12.5)).foregroundStyle(RX.ink3); Text(S.lab.name).font(.rx(20, .bold)) }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) { Text("Left to pay").font(.rx(12)).foregroundStyle(RX.ink3); Text(Money.fmt(max(0, S.owe), S.lab.cur)).font(.rx(30, .bold)).foregroundStyle(RX.sand) }
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("Pay the lab").font(.rx(14, .semibold))
                HStack(spacing: 8) {
                    TextField("", text: Binding(get: { typed ? amount : suggTxt }, set: { amount = $0; typed = true }), prompt: Text("Amount").foregroundStyle(RX.ink4))
                        .font(.rx(18, .bold)).keyboardType(.decimalPad).padding(.horizontal, 12).frame(height: 48).rxPanel(11, RX.deep)
                    RXSelect(options: Currency.allCases.map { ($0, $0.short) }, sel: Binding(get: { c }, set: { cur = $0; typed = false }), width: 100)
                    RXSelect(options: ["Cash", "Bank transfer", "Card"].map { ($0, $0) }, sel: $method, width: 130)
                }
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack { Text("Paid on").font(.rx(12)).foregroundStyle(RX.ink3); if when == nil { Chip(text: "Now", color: RX.mintLight, size: 10.5) } else { Button("Back to now") { when = nil }.font(.rx(11)).underline().foregroundStyle(RX.ink3).buttonStyle(.plain) } }
                        DatePicker("", selection: Binding(get: { when ?? .now }, set: { when = min($0, .now) }), in: ...Date.now, displayedComponents: [.date, .hourAndMinute]).labelsHidden()
                    }
                    TextField("", text: $note, prompt: Text("Note, e.g. crowns of October").foregroundStyle(RX.ink4)).font(.rx(14)).padding(.horizontal, 12).frame(height: 44).rxPanel(10, RX.deep)
                }
                HStack {
                    Spacer()
                    Button("Save payment to the lab") {
                        let v = Double((typed ? amount : suggTxt).replacingOccurrences(of: ",", with: "")) ?? 0
                        guard v > 0 else { store.flash("Type the amount first", undo: false); return }
                        store.addLabPayment(lab: S.lab.id, amount: v, cur: c, method: method, note: note, at: when ?? .now)
                        amount = ""; typed = false; note = ""; when = nil; sel = S.lab.id
                    }
                    .font(.rx(13.5, .heavy)).foregroundStyle(Color(rgb: 0x2A1A0A)).padding(.horizontal, 18).padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 12).fill(RX.gold)).buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [Color(rgb: 0xD9B48A, 0.14), Color(rgb: 0x0B2622, 0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(RX.gold.opacity(0.25)))
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) { works(S); pays(S) }
                VStack(spacing: 16) { works(S); pays(S) }
            }
        }
        .padding(20).rxCard(22)
    }

    private func works(_ S: Row) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Work from this lab").font(.rx(13.5, .bold)).foregroundStyle(RX.ink2)
            ForEach(S.bills.sorted { $0.at > $1.at }) { b in
                Button { store.section = .patients; store.openPatient = b.pid } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(store.patient(b.pid)?.name ?? "").font(.rx(13.5, .semibold))
                            Text(Catalog.typeName(b.proc.type) + (b.proc.teeth.isEmpty ? "" : " " + b.proc.teeth.joined(separator: "·")) + " · ").font(.rx(11.5)).foregroundStyle(RX.ink3)
                                + Text(b.billed ? "Back at the clinic" : b.sent ? "At the lab" : "Not sent").font(.rx(11.5)).foregroundStyle(b.billed ? RX.mintLight : b.sent ? RX.tan : RX.ink4)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) { Text(Money.fmt(b.cost, b.lab.cur)).font(.rx(13.5, .bold)); Text(Day.dm(b.at)).font(.rx(11)).foregroundStyle(RX.ink4) }
                    }
                    .padding(10).rxPanel(12, RX.deep)
                }
                .buttonStyle(.plain)
            }
            if S.bills.isEmpty { Text("No work sent to this lab yet.").font(.rx(12.5)).foregroundStyle(RX.ink4) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pays(_ S: Row) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Paid to this lab").font(.rx(13.5, .bold)).foregroundStyle(RX.ink2)
            ForEach(S.pays.sorted { $0.at > $1.at }) { p in
                HStack(spacing: 10) {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(RX.mintLight).frame(width: 28, height: 28).background(RoundedRectangle(cornerRadius: 9).fill(RX.mint.opacity(0.16)))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(Money.fmt(p.amount, p.cur)).font(.rx(14, .bold))
                        Text(Day.dmy(p.at) + " · " + p.method + " · " + store.memberName(p.by) + (p.note.isEmpty ? "" : " · " + p.note)).font(.rx(11)).foregroundStyle(RX.ink3).lineLimit(1)
                    }
                    Spacer()
                    Button { store.change("Payment removed") { $0.labPays.removeAll { $0.id == p.id } } } label: { Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(RX.ink4) }.buttonStyle(.plain).frame(width: 32, height: 32)
                }
                .padding(10).rxPanel(12, RX.deep)
            }
            if S.pays.isEmpty { Text("Nothing paid to this lab yet.").font(.rx(12.5)).foregroundStyle(RX.ink4) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
