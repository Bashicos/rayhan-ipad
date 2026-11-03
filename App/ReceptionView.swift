import SwiftUI

struct ReceptionView: View {
    @Environment(Store.self) private var store
    @Environment(\.horizontalSizeClass) private var hsc
    @State private var sheet: ApptSheetMode?
    @State private var newPatient = false
    @State private var cancelled = false
    @State private var overRecep = false

    var body: some View {
        GeometryReader { g in
            let wide = g.size.width > 900
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header(wide: g.size.width > 700)
                    comingToday(wide: wide)
                    receptionRoom
                    rooms(wide: g.size.width > 700)
                    if !store.finishedToday.isEmpty { finished }
                }
                .padding(.horizontal, hsc == .compact ? 16 : 32).padding(.vertical, hsc == .compact ? 8 : 28)
                .padding(.bottom, 60)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(item: $sheet) { m in AppointmentSheet(mode: m).presentationDetents([.large]).presentationSizing(.form) }
        .sheet(isPresented: $newPatient) { NewPatientSheet(onCreate: { p in store.flash("\(p.name) added · saved to Patients", undo: true); newCreated = p.id }).presentationSizing(.form) }
        .sheet(isPresented: $cancelled) { CancelledSheet().presentationSizing(.form) }
        .overlay(alignment: .bottom) { createdToast }
        .onAppear(perform: pending)
        .onChange(of: store.pendingSheet) { _, _ in pending() }
        .task { demoOpen() }
    }

    @State private var newCreated: String?

    private func pending() {
        guard let p = store.pendingSheet else { return }
        store.pendingSheet = nil
        if p == "walkin" { sheet = .walkIn(nil) } else if p == "book" { sheet = .new(nil) }
    }

    private func demoOpen() {
        switch DemoScreen.current {
        case "appointment": if let a = store.comingToday.first { sheet = .edit(a) }
        case "cancel": cancelled = true
        case "newpatient": newPatient = true
        default: break
        }
    }

    // MARK: header

    private func header(wide: Bool) -> some View {
        let todayCount = store.liveAppts.filter { $0.day == store.today }.count
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reception").font(.rx(hsc == .compact ? 28 : 34, .bold)).tracking(-0.8)
                    Text("\(Day.long(store.today)) · \(todayCount) appointments today").font(.rx(15)).foregroundStyle(RX.ink3)
                }
                Spacer()
                if wide { stats }
            }
            if !wide { stats }
            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: 10) {
                    HStack(spacing: 8) {
                        Button { newPatient = true } label: { Label { Text("New patient") } icon: { Icon(d: Ico.newPatient, size: 17).foregroundStyle(RX.mintLight) } }
                            .buttonStyle(SoftButton(fill: RX.card2)).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(RX.mint.opacity(0.35)))
                        Button("Walk-in") { sheet = .walkIn(nil) }.buttonStyle(SoftButton())
                        Button { sheet = .new(nil) } label: { Label { Text("New appointment") } icon: { Icon(d: Ico.plus, size: 16, weight: 2.6) } }.buttonStyle(MintButton())
                    }
                }
            }
        }
    }

    private var stats: some View {
        let items: [(Int, String, Color)] = [(store.waiting.count, "Waiting", RX.mintLight), (store.d.rooms.filter { store.inRoom($0.id) != nil }.count, "In a room", RX.lilac), (store.comingToday.count, "Still coming", RX.ink), (store.finishedToday.count, "Finished", RX.ink3)]
        return HStack(spacing: 8) {
            ForEach(items, id: \.1) { it in
                VStack(spacing: 2) {
                    Text("\(it.0)").font(.rx(22, .bold)).foregroundStyle(it.2).contentTransition(.numericText())
                    Text(it.1).font(.rx(11.5)).foregroundStyle(RX.ink3)
                }
                .frame(minWidth: hsc == .compact ? 0 : 84, maxWidth: hsc == .compact ? .infinity : nil).padding(.vertical, 10).padding(.horizontal, 6)
                .rxCard(16)
            }
        }
    }

    // MARK: coming today

    private func comingToday(wide: Bool) -> some View {
        let dents = store.dentists
        let cxToday = store.cancelled.filter { $0.day == store.today }.count
        return VStack(alignment: .leading, spacing: 14) {
            FlowLayout(spacing: 10) {
                Text("Coming today").font(.rx(15, .semibold))
                Text("\(store.comingToday.count) still coming").font(.rx(12)).foregroundStyle(RX.ink3)
                if cxToday > 0 {
                    Button("\(cxToday) cancelled today") { cancelled = true }.font(.rx(12, .bold)).foregroundStyle(RX.sand).underline().buttonStyle(.plain)
                }
                Button { cancelled = true } label: { Label("Cancelled · \(store.cancelled.count)", systemImage: "calendar.badge.minus") }
                    .font(.rx(12, .bold)).foregroundStyle(RX.sand).buttonStyle(.plain)
                    .padding(.horizontal, 11).padding(.vertical, 6).background(Capsule().strokeBorder(RX.sand.opacity(0.3)))
            }
            let layout = wide ? AnyLayout(HStackLayout(alignment: .top, spacing: 12)) : AnyLayout(VStackLayout(spacing: 12))
            layout {
                let cols = wide ? AnyLayout(HStackLayout(alignment: .top, spacing: 12)) : AnyLayout(VStackLayout(spacing: 10))
                cols {
                    ForEach(dents) { d in dentColumn(d) }
                }
                nextDays.frame(width: wide ? 280 : nil)
            }
            Text(hsc == .compact ? "Tap a patient to check them in · long-press for more" : "Drag a patient into the reception room when they arrive · or tap them").font(.rx(12)).foregroundStyle(RX.ink4)
        }
        .padding(16)
        .rxCard(24)
    }

    private func dentColumn(_ d: Member) -> some View {
        let mine = store.comingToday.filter { $0.dent == d.id }
        let all = store.liveAppts.filter { $0.day == store.today && $0.dent == d.id }.count
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                MemberAvatar(m: d, size: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text(d.full).font(.rx(16, .semibold))
                    Text("\(store.roomOf(dent: d.id)?.name ?? "No room") · \(mine.count) coming of \(all)").font(.rx(11.5)).foregroundStyle(RX.ink3)
                }
                Spacer(minLength: 0)
            }
            if mine.isEmpty {
                Text("Everyone has arrived").font(.rx(12.5)).foregroundStyle(RX.ink3).frame(maxWidth: .infinity).padding(.vertical, 14)
            }
            ForEach(mine) { a in comingRow(a) }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(RX.deep.opacity(0.85)))
        .overlay(alignment: .top) { UnevenRoundedRectangle(topLeadingRadius: 18, topTrailingRadius: 18).fill(d.color).frame(height: 3) }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func comingRow(_ a: Appointment) -> some View {
        let p = store.patient(a.patient)
        let late = Day.minutes(.now) - a.startMin
        return Menu {
            Button("Check in · waiting now", systemImage: "sofa") { store.checkIn(a) }
            Button("Edit appointment", systemImage: "pencil") { sheet = .edit(a) }
            Button("Open patient", systemImage: "person") { store.section = .patients; store.openPatient = a.patient }
            Button("Cancel appointment", systemImage: "calendar.badge.minus", role: .destructive) { sheet = .cancel(a) }
        } label: {
            HStack(spacing: 12) {
                Text(a.time).font(.rx(15, .bold)).monospacedDigit()
                VStack(alignment: .leading, spacing: 2) {
                    Text(p?.name ?? "").font(.rx(14, .semibold)).lineLimit(1)
                    Text(apLabel(a) + " · \(a.dur) min").font(.rx(12)).foregroundStyle(RX.ink3).lineLimit(1)
                }
                Spacer(minLength: 4)
                if late > 5 { Chip(text: "\(late) min late", color: RX.salmon, size: 11) }
                else if late >= -5 { Chip(text: "due now", color: RX.mintLight, size: 11) }
            }
            .padding(.horizontal, 12).padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(RX.card2))
            .contentShape(RoundedRectangle(cornerRadius: 13))
        } primaryAction: {
            sheet = .edit(a)
        }
        .buttonStyle(.plain)
        .draggable("appt:" + a.id) {
            Text(p?.name ?? "").font(.rx(14, .semibold)).padding(10).background(RoundedRectangle(cornerRadius: 12).fill(RX.card3))
        }
    }

    private var nextDays: some View {
        let days = (1...7).map { Day.add(store.today, $0) }.map { d in (d, store.liveAppts.filter { $0.day == d }.sorted { $0.startMin < $1.startMin }) }.filter { !$0.1.isEmpty }.prefix(4)
        return VStack(alignment: .leading, spacing: 10) {
            Text("NEXT DAYS").font(.rx(11, .semibold)).tracking(0.9).foregroundStyle(RX.ink3)
            ForEach(Array(days), id: \.0) { item in
                let d = item.0, L = item.1
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(Day.short(d)).font(.rx(13, .semibold))
                        Spacer()
                        Text("\(L.count) patient\(L.count == 1 ? "" : "s")").font(.rx(11.5)).foregroundStyle(RX.ink3)
                    }
                    ForEach(L.prefix(3)) { a in
                        Button { sheet = .edit(a) } label: {
                            HStack(spacing: 10) {
                                Text(a.time).font(.rx(13)).foregroundStyle(RX.ink3).monospacedDigit().frame(width: 44, alignment: .leading)
                                MemberAvatar(m: store.member(a.dent), size: 20)
                                Text(store.patient(a.patient)?.name ?? "").font(.rx(13)).lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 3).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    if L.count > 3 { Text("+\(L.count - 3) more").font(.rx(11.5)).foregroundStyle(RX.ink4) }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(RX.deep.opacity(0.85)))
    }

    // MARK: reception room

    private var receptionRoom: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Icon(d: Ico.sofa, size: 18).foregroundStyle(RX.mintLight).frame(width: 36, height: 36).background(RoundedRectangle(cornerRadius: 11).fill(RX.card2))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Reception room").font(.rx(16, .semibold))
                    Text("\(store.waiting.count) patient\(store.waiting.count == 1 ? "" : "s") waiting").font(.rx(12)).foregroundStyle(RX.ink3)
                }
                Spacer()
                if hsc != .compact { legend }
            }
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                if store.waiting.isEmpty {
                    Text(overRecep ? "Drop here when they arrive" : "Nobody is waiting").font(.rx(14)).foregroundStyle(RX.ink4).frame(maxWidth: .infinity, minHeight: 90)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 12)], spacing: 12) {
                        ForEach(store.waiting) { f in waitingCard(f, now: ctx.date) }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
        .rxCard(24)
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(RX.mint, lineWidth: overRecep ? 2 : 0))
        .dropDestination(for: String.self) { items, _ in
            guard let s = items.first else { return false }
            if s.hasPrefix("appt:"), let a = store.appt(String(s.dropFirst(5))) { store.checkIn(a); return true }
            if s.hasPrefix("flow:"), let f = store.d.flow.first(where: { $0.id == String(s.dropFirst(5)) }) { store.backToWaiting(f); return true }
            return false
        } isTargeted: { overRecep = $0 }
    }

    private var legend: some View {
        HStack(spacing: 10) {
            ForEach([0.0, 15, 30, 45, 60], id: \.self) { m in
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2).fill(waitColor(m)).frame(width: 9, height: 9)
                    Text(m == 60 ? "60+ min" : "\(Int(m)) min").font(.rx(11)).foregroundStyle(RX.ink3)
                }
            }
        }
    }

    private func waitingCard(_ f: FlowItem, now: Date) -> some View {
        let p = store.patient(f.patient), a = store.appt(f.appt)
        let secs = now.timeIntervalSince(f.arrivedAt), c = waitColor(secs / 60)
        return Menu {
            ForEach(store.d.rooms) { r in
                Button(r.name + (store.inRoom(r.id) != nil ? " · busy" : ""), systemImage: "door.left.hand.open") { store.toRoom(f, room: r) }
                    .disabled(store.inRoom(r.id) != nil)
            }
            Divider()
            Button("Back to coming today", systemImage: "arrow.uturn.backward") { store.backToComing(f) }
            Button("Open patient", systemImage: "person") { store.section = .patients; store.openPatient = f.patient }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    PatientIcon(p: p, size: 42).overlay(Circle().strokeBorder(c, lineWidth: 2.5))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p?.name ?? "").font(.rx(14.5, .semibold)).lineLimit(1)
                        Text("for \(store.memberName(a?.dent)) · \(a.map(apLabel) ?? "")").font(.rx(11.5)).foregroundStyle(RX.ink3).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                HStack {
                    Text("Waiting").font(.rx(12)).foregroundStyle(RX.ink3)
                    Spacer()
                    Text(clockText(secs)).font(.rx(16, .bold)).monospacedDigit().foregroundStyle(secs / 60 > 35 ? .white : RX.onMint)
                        .padding(.horizontal, 10).padding(.vertical, 3).background(Capsule().fill(c))
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(c.opacity(0.14)).overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(c.opacity(0.55), lineWidth: 1)))
            .overlay(alignment: .bottomLeading) {
                GeometryReader { g in Capsule().fill(c).frame(width: g.size.width * min(1, secs / 3600), height: 3) }.frame(height: 3).padding(.horizontal, 6)
            }
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .draggable("flow:" + f.id) { Text(p?.name ?? "").font(.rx(14, .semibold)).padding(10).background(RoundedRectangle(cornerRadius: 12).fill(RX.card3)) }
    }

    // MARK: rooms

    private func rooms(wide: Bool) -> some View {
        let layout = wide ? AnyLayout(HStackLayout(alignment: .top, spacing: 12)) : AnyLayout(VStackLayout(spacing: 12))
        return layout {
            ForEach(store.d.rooms) { r in RoomCard(room: r) }
        }
    }

    private var finished: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Finished today", sub: "\(store.finishedToday.count)")
            ForEach(store.finishedToday) { f in
                HStack(spacing: 10) {
                    PatientIcon(p: store.patient(f.patient), size: 30)
                    Text(store.patient(f.patient)?.name ?? "").font(.rx(13.5, .semibold))
                    Spacer()
                    if let s = f.startedAt, let e = f.doneAt { Text("\(Day.hm(s))–\(Day.hm(e))").font(.rx(12)).foregroundStyle(RX.ink3).monospacedDigit() }
                    Text(f.dents.map { store.memberName($0) }.joined(separator: ", ")).font(.rx(12)).foregroundStyle(RX.ink3)
                }
            }
        }
        .padding(16).rxCard(20)
    }

    @ViewBuilder private var createdToast: some View {
        if let id = newCreated, let p = store.patient(id) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(RX.mintLight).frame(width: 30, height: 30).background(RoundedRectangle(cornerRadius: 10).fill(RX.mint.opacity(0.2)))
                VStack(alignment: .leading, spacing: 1) { Text("\(p.name) added").font(.rx(13.5, .semibold)); Text("Saved to Patients").font(.rx(11.5)).foregroundStyle(RX.ink3) }
                Button("Check in now") { newCreated = nil; sheet = .walkIn(id) }.buttonStyle(MintButton(compact: true))
                Button("Book") { newCreated = nil; sheet = .new(id) }.buttonStyle(SoftButton(compact: true, fill: RX.card3))
                Button { newCreated = nil } label: { Image(systemName: "xmark").foregroundStyle(RX.ink3) }.buttonStyle(.plain).frame(width: 30, height: 30)
            }
            .padding(10)
            .glassEffect(.regular.tint(RX.card2.opacity(0.8)), in: .rect(cornerRadius: 18))
            .padding(.bottom, 90)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: id) { try? await Task.sleep(for: .seconds(15)); withAnimation { if newCreated == id { newCreated = nil } } }
        }
    }
}

func apLabel(_ a: Appointment) -> String {
    let t = a.tx.joined(separator: ", ")
    if !t.isEmpty { return t + (a.note.isEmpty ? "" : " · " + a.note) }
    if let r = Catalog.reason(a.spec) { return r.name + (a.note.isEmpty ? "" : " · " + a.note) }
    return a.note.isEmpty ? "No reason given" : a.note
}

struct RoomCard: View {
    @Environment(Store.self) private var store
    let room: Room
    @State private var over = false
    var body: some View {
        let f = store.inRoom(room.id)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(room.name).font(.rx(16, .semibold))
                Spacer()
                if f == nil { Chip(text: "Free", color: RX.mintLight, size: 11.5) } else { Chip(text: "In session", color: RX.lilac, size: 11.5) }
            }
            HStack(spacing: 6) {
                ForEach(room.dents, id: \.self) { d in store.dentChip(d) }
                Menu {
                    ForEach(store.dentists) { d in Button(d.full + (room.dents.contains(d.id) ? " ✓" : "")) { store.moveDentist(d.id, to: room.dents.contains(d.id) ? nil : room.id) } }
                } label: { Image(systemName: "plus").font(.system(size: 11, weight: .bold)).foregroundStyle(RX.ink3).frame(width: 28, height: 28).background(Circle().fill(RX.card2)) }
                .buttonStyle(.plain).accessibilityLabel("Dentists in this room")
            }
            if let f {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    let p = store.patient(f.patient)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            PatientIcon(p: p, size: 42)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p?.name ?? "").font(.rx(15, .semibold))
                                Text(store.appt(f.appt).map(apLabel) ?? "").font(.rx(12)).foregroundStyle(RX.ink3).lineLimit(1)
                            }
                            Spacer()
                            Text(clockText(ctx.date.timeIntervalSince(f.startedAt ?? .now))).font(.rx(20, .bold)).monospacedDigit().foregroundStyle(RX.lilac)
                        }
                        if let s = f.startedAt { Text("Waited \(Int(s.timeIntervalSince(f.arrivedAt) / 60)) min").font(.rx(11.5)).foregroundStyle(RX.ink4) }
                        HStack(spacing: 6) {
                            ForEach(f.dents, id: \.self) { d in store.dentChip(d) }
                            Menu {
                                ForEach(store.dentists.filter { !f.dents.contains($0.id) }) { d in Button(d.full) { store.addDentist(f, d.id) } }
                            } label: { Text("+ Dentist").font(.rx(12, .semibold)).foregroundStyle(RX.ink2).padding(.horizontal, 10).padding(.vertical, 5).background(Capsule().fill(RX.card2)) }
                            .buttonStyle(.plain)
                        }
                        HStack(spacing: 8) {
                            Button("Finish session") { store.finish(f) }.buttonStyle(MintButton(compact: true))
                            Button("Back to waiting") { store.backToWaiting(f) }.buttonStyle(SoftButton(compact: true))
                            Spacer()
                            Button { store.section = .patients; store.openPatient = f.patient } label: { Image(systemName: "person.crop.circle").foregroundStyle(RX.ink3) }.buttonStyle(.plain).frame(width: 36, height: 36)
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(rgb: 0xC9A7FF, 0.10)).overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(RX.lilac.opacity(0.35))))
                    .draggable("flow:" + f.id)
                }
            } else {
                Text(over ? "Drop to start the session" : "Drag a waiting patient here").font(.rx(13)).foregroundStyle(RX.ink4).frame(maxWidth: .infinity, minHeight: 80)
                    .background(RoundedRectangle(cornerRadius: 16).strokeBorder(RX.line2, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .rxCard(22)
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(f == nil ? RX.mint : RX.red, lineWidth: over ? 2 : 0))
        .dropDestination(for: String.self) { items, _ in
            guard let s = items.first, s.hasPrefix("flow:"), let fl = store.d.flow.first(where: { $0.id == String(s.dropFirst(5)) }) else { return false }
            store.toRoom(fl, room: room)
            return true
        } isTargeted: { over = $0 }
    }
}
