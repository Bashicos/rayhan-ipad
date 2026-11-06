import SwiftUI
import Observation
import WidgetKit

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case reception, calendar, patients, labs, payments
    var id: String { rawValue }
    var label: String { switch self { case .reception: "Reception"; case .calendar: "Calendar"; case .patients: "Patients"; case .labs: "Labs"; case .payments: "Payments" } }
    var icon: String { switch self { case .reception: Ico.reception; case .calendar: Ico.calendar; case .patients: Ico.patients; case .labs: Ico.labs; case .payments: Ico.payments } }
    var symbol: String { switch self { case .reception: "house"; case .calendar: "calendar"; case .patients: "person"; case .labs: "flask"; case .payments: "creditcard" } }
}

struct Toast: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var canUndo: Bool
    static func == (a: Toast, b: Toast) -> Bool { a.id == b.id }
}

@Observable
final class Store {
    var d: ClinicData { didSet { scheduleSave() } }
    var me: String? { didSet { UserDefaults.standard.set(me, forKey: "me") } }
    var section: AppSection = .reception
    var openPatient: String?
    var pendingSheet: String?
    var toast: Toast?
    var banner: ActivityItem?
    var payShow: Currency = .usd
    @ObservationIgnored private var undoStack: [(String, ClinicData)] = []
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var bannerTask: Task<Void, Never>?

    static let fileURL: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("rayhan-clinic.json")

    init() {
        var loaded: ClinicData
        if let data = try? Data(contentsOf: Store.fileURL), let c = try? JSONDecoder.rx.decode(ClinicData.self, from: data) {
            loaded = c
        } else {
            loaded = DemoSeed.make()
        }
        Store.fixAgreed(&loaded)
        d = loaded
        me = UserDefaults.standard.string(forKey: "me")
        if let s = UserDefaults.standard.string(forKey: "demoScreen") { applyDemoScreen(s) }
    }

    /// older bills with a total set by hand: that total covers the procedures that were there; anything added later is charged on top
    static func fixAgreed(_ d: inout ClinicData) {
        for i in d.patients.indices where d.patients[i].billing.agreed != nil && d.patients[i].billing.agreedIds == nil {
            d.patients[i].billing.agreedIds = d.patients[i].procs.filter { $0.status != .plan && Catalog.type($0.type) != nil }.map(\.id)
        }
    }

    // MARK: persistence

    private func scheduleSave() {
        saveTask?.cancel()
        let snap = d
        saveTask = Task.detached(priority: .utility) {
            try? await Task.sleep(for: .milliseconds(400))
            if Task.isCancelled { return }
            if let data = try? JSONEncoder.rx.encode(snap) { try? data.write(to: Store.fileURL, options: .atomic) }
            WidgetSnapshot.write(from: snap)
        }
    }

    func resetDemo() {
        var fresh = DemoSeed.make(); Store.fixAgreed(&fresh); d = fresh
        undoStack.removeAll()
        flash("Demo data reset", undo: false)
    }

    // MARK: undo + toasts

    func change(_ msg: String?, undo: Bool = true, _ f: (inout ClinicData) -> Void) {
        if undo, let msg { undoStack.append((msg, d)); if undoStack.count > 30 { undoStack.removeFirst() } }
        var c = d
        f(&c)
        d = c
        if let msg { flash(msg, undo: undo) }
    }

    func undo() {
        guard let (_, prev) = undoStack.popLast() else { return }
        d = prev
        flash("Undone", undo: false)
        Haptics.tap()
    }

    func flash(_ text: String, undo: Bool) {
        toastTask?.cancel()
        withAnimation(.spring(duration: 0.45)) { toast = Toast(text: text, canUndo: undo) }
        toastTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            if !Task.isCancelled { withAnimation(.easeOut(duration: 0.3)) { self.toast = nil } }
        }
    }

    func log(_ kind: String, _ text: String, patient: String? = nil, notify: Bool = true) {
        let a = ActivityItem(kind: kind, text: text, patient: patient, by: me, at: .now)
        d.activity.insert(a, at: 0)
        if d.activity.count > 200 { d.activity.removeLast(d.activity.count - 200) }
        if notify {
            Notifier.post(title: notifyTitle(kind), body: text, patientName: patient.flatMap { self.patient($0)?.name })
            bannerTask?.cancel()
            withAnimation(.spring(duration: 0.5)) { banner = a }
            bannerTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(5))
                if !Task.isCancelled { withAnimation { self.banner = nil } }
            }
        }
    }
    private func notifyTitle(_ k: String) -> String {
        switch k { case "lab": "Lab work"; case "reception": "Reception"; case "payment": "Payments"; case "appt": "Appointments"; case "xray": "New X-ray"; default: "Rayhan" }
    }
    var unread: Int { d.activity.filter { !$0.read }.count }
    func markAllRead() { for i in d.activity.indices { d.activity[i].read = true } }

    // MARK: lookups

    var meMember: Member? { member(me) }
    var role: Role { meMember?.role ?? .dentist }
    var isAdmin: Bool { meMember?.admin ?? false }
    var dentists: [Member] { d.team.filter { $0.role == .dentist } }
    func member(_ id: String?) -> Member? { d.team.first { $0.id == id } }
    func memberName(_ id: String?) -> String { member(id)?.full ?? "" }
    func patient(_ id: String?) -> Patient? { d.patients.first { $0.id == id } }
    func pIndex(_ id: String) -> Int? { d.patients.firstIndex { $0.id == id } }
    func lab(_ id: String?) -> Lab? { d.labs.first { $0.id == id } }
    func appt(_ id: String?) -> Appointment? { d.appts.first { $0.id == id } }
    func room(_ id: String?) -> Room? { d.rooms.first { $0.id == id } }
    func roomOf(dent: String) -> Room? { d.rooms.first { $0.dents.contains(dent) } }

    var sections: [AppSection] {
        switch role {
        case .dentist: return isAdmin ? [.reception, .calendar, .patients, .labs, .payments] : [.reception, .calendar, .patients, .labs]
        case .reception: return [.reception, .calendar, .patients, .labs, .payments]
        case .accountant: return [.payments, .reception, .calendar, .patients, .labs]
        case .storage: return [.reception, .calendar, .patients]
        }
    }
    func home(for r: Role) -> AppSection { r == .accountant ? .payments : r == .dentist ? .patients : .reception }

    func signIn(_ id: String) {
        me = id
        let r = member(id)?.role ?? .dentist
        section = home(for: r)
        Haptics.success()
    }

    // MARK: reception

    var today: String { Day.today() }
    var liveAppts: [Appointment] { d.appts.filter { $0.cancel == nil } }
    var cancelled: [Appointment] { d.appts.filter { $0.cancel != nil } }
    func flow(for appt: String) -> FlowItem? { d.flow.first { $0.appt == appt } }
    var comingToday: [Appointment] {
        liveAppts.filter { $0.day == today && flow(for: $0.id) == nil }.sorted { $0.startMin < $1.startMin }
    }
    var waiting: [FlowItem] { d.flow.filter { $0.stage == .waiting && Day.iso($0.arrivedAt) == today }.sorted { $0.arrivedAt < $1.arrivedAt } }
    var finishedToday: [FlowItem] { d.flow.filter { $0.stage == .done && Day.iso($0.arrivedAt) == today } }
    func inRoom(_ r: String) -> FlowItem? { d.flow.first { $0.stage == .room && $0.room == r } }

    func checkIn(_ a: Appointment) {
        change("\(patient(a.patient)?.name ?? "Patient") is waiting") { c in
            c.flow.append(FlowItem(appt: a.id, patient: a.patient, stage: .waiting, arrivedAt: .now))
        }
        log("reception", "Arrived · waiting in the reception room (for \(memberName(a.dent)))", patient: a.patient)
        Haptics.success(); Sounds.arrive()
        LiveActivities.waiting(patient: patient(a.patient)?.name ?? "", dentist: memberName(a.dent), since: .now, flowID: d.flow.last?.id ?? "")
    }

    func walkIn(patient pid: String, dent: String, spec: String?, tx: [String], note: String, dur: Int) {
        let a = Appointment(patient: pid, day: today, time: Day.hm(.now), dent: dent, dur: dur, spec: spec, tx: tx, note: note)
        change("\(patient(pid)?.name ?? "Patient") checked in (walk-in)") { c in
            c.appts.append(a)
            c.flow.append(FlowItem(appt: a.id, patient: pid, stage: .waiting, arrivedAt: .now))
        }
        log("reception", "Walked in · waiting in the reception room", patient: pid)
        Haptics.success(); Sounds.arrive()
        LiveActivities.waiting(patient: patient(pid)?.name ?? "", dentist: memberName(dent), since: .now, flowID: d.flow.last?.id ?? "")
    }

    func toRoom(_ f: FlowItem, room r: Room) {
        if let busy = inRoom(r.id), busy.id != f.id { flash("\(r.name) is busy", undo: false); Haptics.error(); return }
        let dentID = r.dents.first ?? f.dents.first ?? "d1"
        change("Session started in \(r.name)") { c in
            guard let i = c.flow.firstIndex(where: { $0.id == f.id }) else { return }
            c.flow[i].stage = .room; c.flow[i].room = r.id; c.flow[i].startedAt = .now
            if c.flow[i].dents.isEmpty { c.flow[i].dents = [dentID] }
        }
        log("reception", "Started a session in \(r.name) with \(memberName(dentID))", patient: f.patient)
        Haptics.success(); Sounds.session()
        LiveActivities.inRoom(flowID: f.id, patient: patient(f.patient)?.name ?? "", room: r.name, dentist: memberName(dentID), since: .now)
    }

    func backToWaiting(_ f: FlowItem) {
        change("Back in the reception room") { c in
            guard let i = c.flow.firstIndex(where: { $0.id == f.id }) else { return }
            c.flow[i].stage = .waiting; c.flow[i].room = nil; c.flow[i].startedAt = nil
        }
        LiveActivities.waiting(patient: patient(f.patient)?.name ?? "", dentist: memberName(f.dents.first), since: f.arrivedAt, flowID: f.id)
    }

    func backToComing(_ f: FlowItem) {
        change("Back to coming today") { c in c.flow.removeAll { $0.id == f.id } }
        LiveActivities.end(flowID: f.id)
    }

    func finish(_ f: FlowItem) {
        change("Session finished") { c in
            guard let i = c.flow.firstIndex(where: { $0.id == f.id }) else { return }
            c.flow[i].stage = .done; c.flow[i].doneAt = .now
        }
        log("reception", "Finished the session", patient: f.patient, notify: false)
        Haptics.success(); Sounds.done()
        LiveActivities.end(flowID: f.id)
    }

    func addDentist(_ f: FlowItem, _ dent: String) {
        change("\(memberName(dent)) added to the session") { c in
            guard let i = c.flow.firstIndex(where: { $0.id == f.id }) else { return }
            if !c.flow[i].dents.contains(dent) { c.flow[i].dents.append(dent) }
        }
    }

    func moveDentist(_ dent: String, to room: String?) {
        change(room.map { "\(memberName(dent)) is now in \(self.room($0)?.name ?? "")" } ?? "\(memberName(dent)) is not in a room") { c in
            for i in c.rooms.indices { c.rooms[i].dents.removeAll { $0 == dent } }
            if let room, let i = c.rooms.firstIndex(where: { $0.id == room }) { c.rooms[i].dents.append(dent) }
        }
    }

    // MARK: appointments

    func saveAppointment(_ a: Appointment, isNew: Bool) {
        change(isNew ? "Appointment booked" : "Appointment changed") { c in
            if let i = c.appts.firstIndex(where: { $0.id == a.id }) { c.appts[i] = a } else { c.appts.append(a) }
        }
        log("appt", (isNew ? "Booked an appointment for " : "Moved the appointment to ") + Day.short(a.day) + " " + a.time + " with " + memberName(a.dent), patient: a.patient, notify: false)
        Haptics.success()
    }

    func moveAppointment(_ id: String, day: String? = nil, time: String? = nil, dent: String? = nil) {
        guard let a = appt(id) else { return }
        var b = a
        if let day { b.day = day }
        if let time { b.time = time }
        if let dent { b.dent = dent }
        if b == a { return }
        change("Moved to \(Day.short(b.day)) \(b.time)") { c in if let i = c.appts.firstIndex(where: { $0.id == id }) { c.appts[i] = b } }
        Haptics.tap()
    }

    func cancelAppointment(_ id: String, by: CancelInfo.By, reason: String) {
        change("Appointment cancelled · moved to Cancelled") { c in
            guard let i = c.appts.firstIndex(where: { $0.id == id }) else { return }
            c.appts[i].cancel = CancelInfo(by: by, reason: reason.trimmingCharacters(in: .whitespaces), at: .now, who: me)
            c.flow.removeAll { $0.appt == id && $0.stage != .done }
        }
        if let a = appt(id) { log("appt", "Marked an appointment as cancelled by " + (by == .patient ? "the patient" : "the clinic") + (reason.isEmpty ? "" : " · " + reason), patient: a.patient, notify: false) }
        Haptics.warning()
    }

    func restoreAppointment(_ id: String) {
        change("Appointment brought back") { c in if let i = c.appts.firstIndex(where: { $0.id == id }) { c.appts[i].cancel = nil } }
    }

    func removeAppointment(_ id: String) {
        change("Appointment removed") { c in
            c.appts.removeAll { $0.id == id }
            c.flow.removeAll { $0.appt == id && $0.stage != .done }
        }
        Haptics.warning()
    }

    // MARK: patients

    func addPatient(_ p: Patient) {
        var n = p; n.created = .now; n.createdBy = me
        change("\(n.name) added") { c in c.patients.append(n) }
        log("patient", "Created a new patient profile", patient: n.id, notify: false)
        Haptics.success(); Sounds.patient()
    }

    func updatePatient(_ id: String, _ msg: String? = nil, undo: Bool = true, _ f: (inout Patient) -> Void) {
        guard let i = pIndex(id) else { return }
        change(msg, undo: undo) { c in f(&c.patients[i]) }
    }

    // MARK: chart ↔ procedures (always linked)

    /// Marks on the chart come from procedures that are under way or done.
    func marks(_ p: Patient) -> [String: (flags: Set<Catalog.Flag>, surf: [String])] {
        var out: [String: (flags: Set<Catalog.Flag>, surf: [String])] = [:]
        for r in p.procs where r.status != .plan {
            guard let f = Catalog.flag(of: r) else { continue }
            for t in r.teeth {
                var cur = out[t] ?? ([], [])
                if f == .surf { cur.surf = Catalog.surfSorted(Array(Set(cur.surf + r.surf))) } else { cur.flags.insert(f) }
                out[t] = cur
            }
        }
        return out
    }

    func toggleMark(_ pid: String, tooth: String, _ f: Catalog.Flag) {
        guard let p = patient(pid) else { return }
        let has = marks(p)[tooth]?.flags.contains(f) ?? false
        let name = Catalog.typeName(Catalog.procFor(f).type)
        updatePatient(pid, has ? "\(name) removed from \(tooth)" : "\(name) added on \(tooth)") { P in
            if has {
                // take it off the chart: the procedures that put it there go (bridges just lose this tooth)
                P.procs = P.procs.compactMap { (r: Procedure) -> Procedure? in
                    guard r.status != .plan, Catalog.flag(of: r) == f, r.teeth.contains(tooth) else { return r }
                    if r.teeth.count > 1 { var q = r; q.teeth.removeAll { $0 == tooth }; return q }
                    return nil
                }
            } else {
                let (spec, type) = Catalog.procFor(f)
                // a planned row for the same thing becomes done instead of adding a second one
                if let i = P.procs.firstIndex(where: { $0.teeth.contains(tooth) && Catalog.flag(of: $0) == f && $0.status == .plan }) {
                    P.procs[i].status = .done; P.procs[i].doneAt = .now
                } else {
                    P.procs.insert(Procedure(teeth: [tooth], spec: spec, type: type, status: .done, by: me, at: .now, doneAt: .now), at: 0)
                }
                // exclusive pairs, as in the demo
                let off: Catalog.Flag? = f == .crown ? .veneer : f == .veneer ? .crown : nil
                if let off { P.procs.removeAll { $0.status != .plan && Catalog.flag(of: $0) == off && $0.teeth == [tooth] } }
                if f == .implant { P.chart[tooth, default: ToothState()].missing = false }
            }
        }
        Haptics.tap()
    }

    func setSurfaces(_ pid: String, tooth: String, _ surf: [String]) {
        let s = Catalog.surfSorted(surf)
        updatePatient(pid, nil, undo: false) { P in
            let live = P.procs.indices.filter { P.procs[$0].status != .plan && Catalog.flag(of: P.procs[$0]) == .surf && P.procs[$0].teeth.contains(tooth) }
            if s.isEmpty {
                P.procs.removeAll { $0.status != .plan && Catalog.flag(of: $0) == .surf && $0.teeth == [tooth] }
            } else if let i = live.first {
                P.procs[i].surf = s
            } else if let i = P.procs.firstIndex(where: { Catalog.flag(of: $0) == .surf && $0.teeth.contains(tooth) && $0.status == .plan }) {
                P.procs[i].surf = s; P.procs[i].status = .done; P.procs[i].doneAt = .now
            } else {
                P.procs.insert(Procedure(teeth: [tooth], spec: "rest", type: "fill", status: .done, by: me, at: .now, doneAt: .now, surf: s), at: 0)
            }
        }
        Haptics.tap()
    }

    func addProcedure(_ pid: String, _ r: Procedure) {
        updatePatient(pid, "\(Catalog.typeName(r.type)) added") { P in P.procs.insert(r, at: 0) }
        Haptics.tap()
    }

    func updateProcedure(_ pid: String, _ id: String, msg: String? = nil, _ f: (inout Procedure) -> Void) {
        updatePatient(pid, msg, undo: msg != nil) { P in
            guard let i = P.procs.firstIndex(where: { $0.id == id }) else { return }
            let was = P.procs[i].status
            f(&P.procs[i])
            if was != .done && P.procs[i].status == .done { P.procs[i].doneAt = .now }
        }
    }

    func deleteProcedure(_ pid: String, _ id: String) {
        updatePatient(pid, "Procedure removed") { P in P.procs.removeAll { $0.id == id } }
        Haptics.warning()
    }

    func setTooth(_ pid: String, _ tooth: String, _ f: (inout ToothState) -> Void) {
        updatePatient(pid, nil, undo: false) { P in f(&P.chart[tooth, default: ToothState()]) }
    }

    // MARK: labs

    struct LabCase: Identifiable {
        let pid: String
        let proc: Procedure
        var id: String { proc.id }
        var lastStep: LabStep? { proc.lab?.steps.last }
        var whereNow: Catalog.Where { Catalog.labWhere(lastStep?.k) }
        var needsAttention: Bool { ["mod", "dent", "prob"].contains(lastStep?.k ?? "") }
        var added: Date { proc.lab?.steps.first?.at ?? proc.at }
    }

    var labCases: [LabCase] {
        d.patients.flatMap { p in p.procs.filter { $0.lab != nil && !($0.lab?.lab ?? "").isEmpty }.map { LabCase(pid: p.id, proc: $0) } }.sorted { $0.added > $1.added }
    }

    func addLabStep(_ pid: String, _ procID: String, _ k: String, note: String = "") {
        guard let p = patient(pid), let r = p.procs.first(where: { $0.id == procID }) else { return }
        let name = Catalog.step(k)?.name ?? k
        updatePatient(pid, name) { P in
            guard let i = P.procs.firstIndex(where: { $0.id == procID }) else { return }
            if P.procs[i].lab == nil { P.procs[i].lab = LabWork() }
            P.procs[i].lab!.steps.append(LabStep(k: k, at: .now, by: me, note: note))
            if k == "done" { P.procs[i].status = .done; P.procs[i].doneAt = .now }
            else if P.procs[i].status == .plan { P.procs[i].status = .doing }
        }
        let what = Catalog.typeName(r.type) + (r.teeth.isEmpty ? "" : " " + r.teeth.joined(separator: "·"))
        if ["tryin", "recv"].contains(k) {
            log("lab", (k == "tryin" ? "Try-in arrived · " : "Finished work arrived · ") + what + " · " + p.name, patient: pid)
            Sounds.arrive()
        } else {
            log("lab", name + " · " + what + " · " + p.name, patient: pid, notify: false)
        }
        Haptics.tap()
    }

    func removeLastLabStep(_ pid: String, _ procID: String) {
        updatePatient(pid, "Step removed") { P in
            guard let i = P.procs.firstIndex(where: { $0.id == procID }), P.procs[i].lab?.steps.isEmpty == false else { return }
            let k = P.procs[i].lab!.steps.removeLast().k
            if k == "done" { P.procs[i].status = .doing; P.procs[i].doneAt = nil }
        }
    }

    func saveLab(_ l: Lab) {
        change("\(l.name) saved") { c in if let i = c.labs.firstIndex(where: { $0.id == l.id }) { c.labs[i] = l } else { c.labs.append(l) } }
    }
    func deleteLab(_ id: String) { change("Lab deleted") { c in c.labs.removeAll { $0.id == id } } }

    // MARK: money

    func bill(_ p: Patient) -> Bill { BillEngine.bill(p, labs: d.labs, fx: d.fx) }
    func money(_ usd: Double) -> String { Money.fmt(d.fx.conv(usd, .usd, payShow), payShow) }
    func payValue(_ p: Payment) -> Double { d.fx.conv(p.amount, p.cur, .usd, rateFrom: p.rate) }

    func addPayment(_ pid: String, amount: Double, cur: Currency, method: String, note: String, items: [String], at: Date) {
        let py = Payment(amount: cur == .syp ? amount.rounded() : (amount * 100).rounded() / 100, cur: cur, rate: d.fx.rate(cur), at: min(at, .now), by: me, method: method, note: note, items: items)
        updatePatient(pid, "Payment saved") { P in P.billing.pays.append(py) }
        log("payment", "Received " + Money.fmt(py.amount, cur) + " (\(method.lowercased()))", patient: pid, notify: false)
        Haptics.success(); Sounds.done()
    }
    func removePayment(_ pid: String, _ id: String) { updatePatient(pid, "Payment removed") { P in P.billing.pays.removeAll { $0.id == id } } }

    /// Every price change is written down: what, before → after, the dentist who decided and who typed it.
    func priceChange(_ pid: String, key: String, kind: String, what: String, from: Double, to: Double, _ f: (inout Patient) -> Void) {
        updatePatient(pid, nil, undo: false) { P in
            f(&P)
            let dent = P.billing.decider ?? P.procs.last(where: { self.member($0.by)?.role == .dentist })?.by ?? "d1"
            if let last = P.billing.changes.last, last.key == key, last.by == self.me, Date.now.timeIntervalSince(last.at) < 120 {
                P.billing.changes[P.billing.changes.count - 1] = PriceChange(id: last.id, key: key, kind: kind, what: what, from: last.from, to: to, at: .now, by: me, dent: dent)
            } else {
                P.billing.changes.append(PriceChange(key: key, kind: kind, what: what, from: from, to: to, at: .now, by: me, dent: dent))
            }
        }
    }

    func addLabPayment(lab: String, amount: Double, cur: Currency, method: String, note: String, at: Date) {
        let lp = LabPayment(lab: lab, amount: cur == .syp ? amount.rounded() : (amount * 100).rounded() / 100, cur: cur, rate: d.fx.rate(cur), at: min(at, .now), by: me, method: method, note: note)
        change("Payment to \(self.lab(lab)?.name ?? "the lab") saved") { c in c.labPays.append(lp) }
        log("payment", "Paid " + Money.fmt(lp.amount, cur) + " to " + (self.lab(lab)?.name ?? "the lab"), notify: false)
        Haptics.success()
    }

    struct LabBill: Identifiable { let pid: String; let proc: Procedure; let lab: Lab; let cost: Double; let billed: Bool; let at: Date; let sent: Bool; var id: String { proc.id } }
    func labBills() -> [LabBill] {
        var out: [LabBill] = []
        for p in d.patients {
            for r in p.procs {
                guard let L = r.lab, let lb = lab(L.lab) else { continue }
                let sv = lb.services.first { $0.id == L.svc }
                let u = max(1, r.teeth.count)
                let cost = (sv?.price ?? 0) * Double((sv?.name.lowercased().contains("per unit") ?? false) ? u : 1)
                let arr = L.steps.first { ["tryin", "recv", "done"].contains($0.k) }
                let sent = L.steps.first { $0.k == "sent" }
                out.append(LabBill(pid: p.id, proc: r, lab: lb, cost: cost, billed: arr != nil, at: arr?.at ?? sent?.at ?? r.at, sent: sent != nil))
            }
        }
        return out
    }

    /// Cash taken since the box was last emptied, per currency as it was paid.
    var cashBox: [Currency: Double] {
        var box: [Currency: Double] = [.usd: 0, .syp: 0, .eur: 0]
        for p in d.patients { for py in p.billing.pays where py.method == "Cash" && py.at > d.cashOutAt { box[py.cur, default: 0] += py.amount } }
        return box
    }
    func emptyCashBox() {
        let b = cashBox
        change("Cash box counted and emptied") { c in
            c.cashLog.insert(CashEmpty(at: .now, by: me, usd: b[.usd] ?? 0, syp: b[.syp] ?? 0, eur: b[.eur] ?? 0), at: 0)
            c.cashOutAt = .now
        }
    }

    // MARK: demo screens (used for screenshots)

    private func applyDemoScreen(_ s: String) {
        let who: [String: String] = ["signin": "", "reception": "d4", "calendar": "d4", "calweek": "d4", "calmonth": "d4", "patients": "d1", "profile": "d1", "chart": "d1", "xray": "d1", "labs": "d4", "labcase": "d4", "payments": "d5", "paybal": "d5", "paylate": "d5", "paylabs": "d5", "appointment": "d4", "cancel": "d4", "newpatient": "d4"]
        let id = who[s] ?? "d1"
        me = id.isEmpty ? nil : id
        switch s {
        case "reception", "appointment", "cancel", "newpatient": section = .reception
        case "calendar", "calweek", "calmonth": section = .calendar
        case "patients": section = .patients
        case "profile", "chart", "xray": section = .patients; openPatient = "P1"
        case "labs", "labcase": section = .labs
        case "payments", "paybal", "paylate", "paylabs": section = .payments
        default: break
        }
        DemoScreen.current = s
    }
}

enum DemoScreen { static var current: String = "" }

extension JSONEncoder { static let rx: JSONEncoder = { let e = JSONEncoder(); e.dateEncodingStrategy = .secondsSince1970; return e }() }
extension JSONDecoder { static let rx: JSONDecoder = { let e = JSONDecoder(); e.dateDecodingStrategy = .secondsSince1970; return e }() }
