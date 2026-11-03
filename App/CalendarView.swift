import SwiftUI

struct CalendarView: View {
    @Environment(Store.self) private var store
    @Environment(\.horizontalSizeClass) private var hsc
    @AppStorage("calView") private var view = "day"
    @State private var base = Day.today()
    @AppStorage("calH") private var hp: Double = 64
    @State private var pinchStart: Double?
    @State private var hidden: Set<String> = []
    @State private var sheet: ApptSheetMode?
    @State private var cancelled = false
    @State private var morePop: String?

    private let hoursFrom = 8, hoursTo = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            filters
            Group {
                switch view {
                case "week": week
                case "month": month
                default: dayView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .rxCard(22, fill: RX.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .simultaneousGesture(MagnifyGesture().onChanged { v in
                if pinchStart == nil { pinchStart = hp }
                hp = min(180, max(30, (pinchStart ?? hp) * v.magnification))
            }.onEnded { _ in pinchStart = nil })
        }
        .padding(.horizontal, hsc == .compact ? 12 : 28).padding(.top, hsc == .compact ? 4 : 24).padding(.bottom, hsc == .compact ? 90 : 20)
        .sheet(item: $sheet) { m in AppointmentSheet(mode: m).presentationSizing(.form) }
        .sheet(isPresented: $cancelled) { CancelledSheet().presentationSizing(.form) }
        .onAppear {
            if DemoScreen.current == "calweek" { view = "week" } else if DemoScreen.current == "calmonth" { view = "month" } else if DemoScreen.current == "calendar" { view = "day" }
        }
    }

    // MARK: header

    private var title: String {
        let d = Day.date(base)
        switch view {
        case "week":
            let s = startOfWeek(base)
            return Day.dm(Day.date(s)) + " – " + Day.dmy(Day.date(Day.add(s, 6)))
        case "month": return d.formatted(.dateTime.month(.wide).year())
        default: return d.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
        }
    }

    private var header: some View {
        let compact = hsc == .compact
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                GlassEffectContainer(spacing: 6) {
                    HStack(spacing: 6) {
                        navBtn(Ico.chevronL) { step(-1) }
                        navBtn(Ico.chevronR) { step(1) }
                    }
                }
                if base != store.today { Button("Today") { withAnimation { base = store.today } }.buttonStyle(SoftButton(compact: true)) }
                Text(title).font(.rx(compact ? 20 : 28, .bold)).tracking(-0.6).lineLimit(1).minimumScaleFactor(0.6)
                Spacer(minLength: 8)
                if !compact {
                    viewPicker
                    Button { sheet = .new(nil) } label: { Label { Text("New appointment") } icon: { Icon(d: Ico.plus, size: 15, weight: 2.6) } }.buttonStyle(MintButton())
                }
            }
            if compact {
                HStack { viewPicker; Spacer(); Button { sheet = .new(nil) } label: { Icon(d: Ico.plus, size: 16, weight: 2.6) }.buttonStyle(MintButton(compact: true)) }
            }
        }
    }

    private func navBtn(_ icon: String, _ a: @escaping () -> Void) -> some View {
        Button { withAnimation(.spring(duration: 0.4)) { a() }; Haptics.tap() } label: {
            Icon(d: icon, size: 16, weight: 2.4).foregroundStyle(RX.ink).frame(width: 44, height: 44)
                .glassEffect(.regular.tint(RX.card2.opacity(0.6)).interactive(), in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var viewPicker: some View {
        SegmentPicker(items: [("day", "Day"), ("week", "Week"), ("month", "Month")], sel: $view)
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("Show").font(.rx(12)).foregroundStyle(RX.ink4)
                ForEach(store.dentists) { d in
                    let off = hidden.contains(d.id)
                    Button { withAnimation { if off { hidden.remove(d.id) } else { hidden.insert(d.id) } }; Haptics.tap() } label: {
                        HStack(spacing: 8) {
                            MemberAvatar(m: d, size: 26)
                            Text(d.full).font(.rx(12.5, .semibold))
                            Text(store.roomOf(dent: d.id)?.name ?? "").font(.rx(11.5)).foregroundStyle(RX.ink3)
                        }
                        .padding(.leading, 4).padding(.trailing, 12).padding(.vertical, 4)
                        .background(Capsule().fill(RX.card))
                        .overlay(Capsule().strokeBorder(d.color.opacity(off ? 0.15 : 0.85), lineWidth: 1.5))
                        .opacity(off ? 0.45 : 1)
                    }
                    .buttonStyle(.plain)
                }
                if hsc != .compact {
                    Text("Pinch to stretch · tap an empty time to book · hold and drag to move").font(.rx(12)).foregroundStyle(RX.ink4).padding(.leading, 8)
                }
                Button { cancelled = true } label: { Label("Cancelled · \(store.cancelled.count)", systemImage: "calendar.badge.minus") }
                    .font(.rx(12, .bold)).foregroundStyle(RX.sand).buttonStyle(.plain)
                    .padding(.horizontal, 12).padding(.vertical, 7).background(Capsule().fill(RX.card)).overlay(Capsule().strokeBorder(RX.sand.opacity(0.3)))
            }
        }
    }

    // MARK: data

    private var appts: [Appointment] { store.liveAppts.filter { !hidden.contains($0.dent) } }
    private var visDents: [Member] { store.dentists.filter { !hidden.contains($0.id) } }

    private func step(_ n: Int) {
        let d = Day.date(base)
        switch view {
        case "week": base = Day.add(base, 7 * n)
        case "month": base = Day.iso(Day.cal.date(byAdding: .month, value: n, to: d) ?? d)
        default: base = Day.add(base, n)
        }
    }
    private func startOfWeek(_ iso: String) -> String {
        let d = Day.date(iso), wd = Day.cal.component(.weekday, from: d)
        return Day.add(iso, -(wd - 1))
    }
    private func range(_ L: [Appointment]) -> (Int, Int) {
        var a = hoursFrom * 60, b = hoursTo * 60
        for x in L { a = min(a, (x.startMin / 60) * 60); b = max(b, Int(ceil(Double(x.startMin + x.dur) / 60)) * 60) }
        return (a, min(b, 24 * 60))
    }

    // MARK: day

    private var dayView: some View {
        let L = appts.filter { $0.day == base }
        let R = range(L)
        return ScrollView([.vertical]) {
            HStack(alignment: .top, spacing: 0) {
                hourRail(R).padding(.top, 58)
                ForEach(visDents) { d in
                    let C = L.filter { $0.dent == d.id }
                    VStack(spacing: 0) {
                        HStack(spacing: 8) {
                            MemberAvatar(m: d, size: 32)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(d.full).font(.rx(14, .semibold)).lineLimit(1)
                                Text("\(store.roomOf(dent: d.id)?.name ?? "") · \(C.count) appointment\(C.count == 1 ? "" : "s")").font(.rx(11)).foregroundStyle(RX.ink3).lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10).frame(height: 58)
                        .background(RX.card.opacity(0.96))
                        DayColumn(appts: C, range: R, hp: hp, isToday: base == store.today, tint: d.color, compact: false,
                                  onSlot: { m in sheet = .slot(day: base, time: Day.hm(min: m), dent: d.id) },
                                  onOpen: { a in sheet = .edit(a) },
                                  onDrop: { id, m in store.moveAppointment(id, day: base, time: Day.hm(min: m), dent: d.id) })
                    }
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .leading) { Rectangle().fill(RX.line).frame(width: 1) }
                }
                if visDents.isEmpty { EmptyNote(text: "Choose a dentist to show").frame(maxWidth: .infinity) }
            }
            .padding(.bottom, 20)
        }
    }

    private func hourRail(_ R: (Int, Int)) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(stride(from: R.0, to: R.1, by: 60)), id: \.self) { m in
                Text(String(format: "%02d:00", m / 60)).font(.rx(11)).foregroundStyle(RX.ink4).monospacedDigit()
                    .frame(width: 52, height: hp, alignment: .topTrailing).padding(.trailing, 6).offset(y: -6)
            }
        }
    }

    // MARK: week

    private var week: some View {
        let s = startOfWeek(base)
        let days = (0..<7).map { Day.add(s, $0) }
        let L = appts.filter { days.contains($0.day) }
        let R = range(L)
        return ScrollView([.vertical]) {
            HStack(alignment: .top, spacing: 0) {
                hourRail(R).padding(.top, 58)
                ForEach(days, id: \.self) { iso in
                    let C = L.filter { $0.day == iso }, isT = iso == store.today, dt = Day.date(iso)
                    VStack(spacing: 0) {
                        Button { withAnimation { view = "day"; base = iso } } label: {
                            VStack(spacing: 2) {
                                Text(dt.formatted(.dateTime.weekday(.abbreviated))).font(.rx(11.5, .semibold)).foregroundStyle(RX.ink3)
                                Text("\(Day.cal.component(.day, from: dt))").font(.rx(17, .bold)).foregroundStyle(isT ? RX.onMint : RX.ink)
                                    .frame(width: 32, height: 32).background(Circle().fill(isT ? RX.mint : .clear))
                            }
                            .frame(maxWidth: .infinity).frame(height: 58)
                        }
                        .buttonStyle(.plain)
                        .background(RX.card.opacity(0.96))
                        DayColumn(appts: C, range: R, hp: hp, isToday: isT, tint: nil, compact: true,
                                  onSlot: { m in sheet = .slot(day: iso, time: Day.hm(min: m), dent: visDents.first?.id ?? "d1") },
                                  onOpen: { a in sheet = .edit(a) },
                                  onDrop: { id, m in store.moveAppointment(id, day: iso, time: Day.hm(min: m)) })
                            .background(isT ? RX.mint.opacity(0.05) : .clear)
                    }
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .leading) { Rectangle().fill(RX.line).frame(width: 1) }
                }
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: month

    private var month: some View {
        let d = Day.date(base)
        let first = Day.cal.date(from: Day.cal.dateComponents([.year, .month], from: d)) ?? d
        let wd = Day.cal.component(.weekday, from: first)
        let start = Day.cal.date(byAdding: .day, value: -(wd - 1), to: first) ?? first
        let cells = (0..<42).map { Day.iso(Day.cal.date(byAdding: .day, value: $0, to: start) ?? start) }
        let monthN = Day.cal.component(.month, from: d)
        let weeks = stride(from: 0, to: 42, by: 7).map { Array(cells[$0..<$0 + 7]) }.filter { row in row.contains { Day.cal.component(.month, from: Day.date($0)) == monthN } }
        let rowH = max(96, hp * 1.6), per = max(1, Int((rowH - 34) / 23))
        return ScrollView {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { t in
                        Text(t).font(.rx(12, .semibold)).foregroundStyle(RX.ink3).frame(maxWidth: .infinity, alignment: .leading).padding(10)
                    }
                }
                .background(RX.card2.opacity(0.5))
                ForEach(weeks, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(row, id: \.self) { iso in monthCell(iso, rowH: rowH, per: per, out: Day.cal.component(.month, from: Day.date(iso)) != monthN) }
                    }
                    .overlay(alignment: .bottom) { Rectangle().fill(RX.line).frame(height: 1) }
                }
            }
        }
    }

    private func monthCell(_ iso: String, rowH: Double, per: Int, out: Bool) -> some View {
        let L = appts.filter { $0.day == iso }.sorted { $0.startMin < $1.startMin }
        let isT = iso == store.today
        return VStack(alignment: .leading, spacing: 3) {
            Text("\(Day.cal.component(.day, from: Day.date(iso)))").font(.rx(13, .bold)).foregroundStyle(isT ? RX.onMint : out ? RX.ink4 : RX.ink)
                .frame(minWidth: 24, minHeight: 24).padding(.horizontal, 4).background(Capsule().fill(isT ? RX.mint : .clear))
            ForEach(L.prefix(per)) { a in monthItem(a) }
            if L.count > per {
                Button { morePop = iso } label: { Text("+\(L.count - per) more").font(.rx(11, .semibold)).foregroundStyle(RX.ink3).padding(.leading, 4).padding(.vertical, 2) }
                    .buttonStyle(.plain)
                    .popover(isPresented: Binding(get: { morePop == iso }, set: { if !$0 { morePop = nil } })) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(Day.long(iso)).font(.rx(14, .bold)).padding(.bottom, 4)
                            ForEach(L) { a in monthItem(a) }
                        }
                        .padding(14).frame(width: 280).background(RX.card2).presentationCompactAdaptation(.popover)
                    }
            }
            Spacer(minLength: 0)
        }
        .padding(6)
        .frame(maxWidth: .infinity, minHeight: rowH, alignment: .topLeading)
        .background(isT ? RX.mint.opacity(0.07) : .clear)
        .opacity(out ? 0.55 : 1)
        .overlay(alignment: .leading) { Rectangle().fill(RX.line).frame(width: 1) }
        .contentShape(Rectangle())
        .onTapGesture { withAnimation { view = "day"; base = iso } }
        .dropDestination(for: String.self) { items, _ in
            guard let s = items.first, s.hasPrefix("cal:") else { return false }
            store.moveAppointment(String(s.dropFirst(4)), day: iso); return true
        }
    }

    private func monthItem(_ a: Appointment) -> some View {
        let m = store.member(a.dent), c = m?.color ?? RX.mint
        return Button { sheet = .edit(a) } label: {
            HStack(spacing: 5) {
                MemberAvatar(m: m, size: 16)
                Text(a.time + " " + (store.patient(a.patient)?.name ?? "")).font(.rx(11)).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 3).padding(.leading, 3).padding(.trailing, 6)
            .background(RoundedRectangle(cornerRadius: 7).fill(c.opacity(0.18)))
        }
        .buttonStyle(.plain)
        .draggable("cal:" + a.id)
    }
}

/// One column of a day: hour lines, the "now" line, appointment blocks, tap to book, drop to move.
struct DayColumn: View {
    @Environment(Store.self) private var store
    let appts: [Appointment]
    let range: (Int, Int)
    let hp: Double
    let isToday: Bool
    let tint: Color?
    let compact: Bool
    let onSlot: (Int) -> Void
    let onOpen: (Appointment) -> Void
    let onDrop: (String, Int) -> Void
    @State private var ghost: Int?

    var body: some View {
        let H = Double(range.1 - range.0) / 60 * hp
        let lanes = laneMap(appts)
        TimelineView(.periodic(from: .now, by: 30)) { ctx in
            let nowMin = Day.minutes(ctx.date)
            GeometryReader { g in
                ZStack(alignment: .topLeading) {
                    // hour lines
                    ForEach(Array(stride(from: range.0, to: range.1, by: 60)), id: \.self) { m in
                        let hourOn = isToday && nowMin / 60 == m / 60
                        Rectangle().fill(hourOn ? RX.mint.opacity(0.07) : .clear).frame(height: hp)
                            .overlay(alignment: .top) { Rectangle().fill(RX.line).frame(height: 1) }
                            .offset(y: Double(m - range.0) / 60 * hp)
                    }
                    if let gm = ghost {
                        RoundedRectangle(cornerRadius: 10).strokeBorder(RX.mint, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            .background(RoundedRectangle(cornerRadius: 10).fill(RX.mint.opacity(0.12)))
                            .overlay(alignment: .topLeading) { Text(Day.hm(min: gm)).font(.rx(11, .bold)).foregroundStyle(RX.mintLight).padding(6) }
                            .frame(height: hp / 2).offset(y: Double(gm - range.0) / 60 * hp).padding(.horizontal, 3)
                    }
                    ForEach(appts) { a in
                        let ln = lanes[a.id] ?? (0, 1)
                        let w = g.size.width / Double(ln.1)
                        ApptBlock(a: a, hp: hp, compact: compact || ln.1 > 1, now: isToday && nowMin >= a.startMin && nowMin < a.startMin + a.dur)
                            .frame(width: max(10, w - 4), height: max(22, Double(a.dur) / 60 * hp - 3))
                            .offset(x: w * Double(ln.0) + 2, y: Double(a.startMin - range.0) / 60 * hp + 1)
                            .onTapGesture { onOpen(a) }
                    }
                    if isToday && nowMin >= range.0 && nowMin < range.1 {
                        HStack(spacing: 0) {
                            Circle().fill(RX.red).frame(width: 8, height: 8)
                            Rectangle().fill(RX.red).frame(height: 1.5)
                        }
                        .offset(x: -4, y: Double(nowMin - range.0) / 60 * hp - 4)
                        .allowsHitTesting(false)
                    }
                }
                .frame(width: g.size.width, height: H, alignment: .topLeading)
                .contentShape(Rectangle())
                .onTapGesture { loc in onSlot(minute(at: loc.y)) }
                .dropDestination(for: String.self) { items, loc in
                    ghost = nil
                    guard let s = items.first, s.hasPrefix("cal:") else { return false }
                    onDrop(String(s.dropFirst(4)), minute(at: loc.y - 10)); return true
                } isTargeted: { if !$0 { ghost = nil } }
            }
            .frame(height: H)
        }
    }

    private func minute(at y: Double) -> Int {
        let m = range.0 + Int((y / hp * 4).rounded(.down)) * 15
        return max(range.0, min(range.1 - 15, m))
    }

    private func laneMap(_ L: [Appointment]) -> [String: (Int, Int)] {
        let S = L.sorted { $0.startMin < $1.startMin }
        var ends: [Int] = [], lane: [String: Int] = [:]
        for x in S {
            if let k = ends.firstIndex(where: { $0 <= x.startMin }) { ends[k] = x.startMin + x.dur; lane[x.id] = k }
            else { ends.append(x.startMin + x.dur); lane[x.id] = ends.count - 1 }
        }
        var out: [String: (Int, Int)] = [:]
        for x in S {
            let en = x.startMin + x.dur
            let n = S.filter { $0.startMin < en && $0.startMin + $0.dur > x.startMin }.map { (lane[$0.id] ?? 0) + 1 }.max() ?? 1
            out[x.id] = (lane[x.id] ?? 0, max(1, n))
        }
        return out
    }
}

struct ApptBlock: View {
    @Environment(Store.self) private var store
    let a: Appointment
    let hp: Double
    let compact: Bool
    let now: Bool
    var body: some View {
        let m = store.member(a.dent), c = m?.color ?? RX.mint
        let h = Double(a.dur) / 60 * hp
        let sp = Catalog.reason(a.spec)
        HStack(alignment: .top, spacing: 0) {
            Rectangle().fill(c).frame(width: 3.5)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if !compact && h > 40 { MemberAvatar(m: m, size: 18) }
                    Text(store.patient(a.patient)?.name ?? "").font(.rx(compact ? 11.5 : 13, .semibold)).lineLimit(h > 70 ? 2 : 1)
                    Spacer(minLength: 0)
                    if now { Text("NOW").font(.rx(9, .heavy)).foregroundStyle(RX.onMint).padding(.horizontal, 5).padding(.vertical, 2).background(Capsule().fill(c)) }
                }
                if h > 34 {
                    Text(apLabel(a)).font(.rx(compact ? 10.5 : 11.5)).foregroundStyle(RX.ink2).lineLimit(h > 90 ? 3 : 1)
                }
                if h > 56 && !compact {
                    Text(a.time + " · \(a.dur) min · " + (m?.full ?? "")).font(.rx(11)).foregroundStyle(RX.ink3).lineLimit(1)
                }
            }
            .padding(.horizontal, 7).padding(.vertical, 5)
            Spacer(minLength: 0)
        }
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(c.opacity(now ? 0.34 : 0.22)))
        .overlay(alignment: .topTrailing) { if let sp { Circle().fill(sp.color).frame(width: 6, height: 6).padding(5) } }
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .shadow(color: now ? c.opacity(0.5) : .black.opacity(0.4), radius: now ? 14 : 6, y: 4)
        .overlay { if now { RoundedRectangle(cornerRadius: 9).strokeBorder(c, lineWidth: 2) } }
        .contentShape(Rectangle())
        .draggable("cal:" + a.id) {
            Text(store.patient(a.patient)?.name ?? "").font(.rx(13, .semibold)).padding(10).background(RoundedRectangle(cornerRadius: 10).fill(c.opacity(0.5)))
        }
        .contextMenu {
            Button("Open patient", systemImage: "person") { store.section = .patients; store.openPatient = a.patient }
        }
        .accessibilityLabel("\(store.patient(a.patient)?.name ?? ""), \(a.time), \(m?.full ?? "")")
    }
}
