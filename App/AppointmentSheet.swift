import SwiftUI

enum ApptSheetMode: Identifiable {
    case new(String?), walkIn(String?), edit(Appointment), cancel(Appointment), slot(day: String, time: String, dent: String), prefill(Appointment)
    var id: String {
        switch self {
        case .new(let p): "new" + (p ?? "")
        case .walkIn(let p): "walk" + (p ?? "")
        case .edit(let a): "edit" + a.id
        case .cancel(let a): "cx" + a.id
        case .slot(let d, let t, let de): "slot" + d + t + de
        case .prefill(let a): "pre" + a.id
        }
    }
}

struct AppointmentSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let mode: ApptSheetMode

    @State private var a = Appointment(patient: "", day: Day.today(), time: "09:00", dent: "d1")
    @State private var q = ""
    @State private var walk = false
    @State private var isNew = true
    @State private var cxStep = false
    @State private var cxBy: CancelInfo.By?
    @State private var cxReason = ""
    @State private var newPatient = false
    @State private var loaded = false

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: walk ? "Walk-in" : isNew ? "New appointment" : "Appointment", primary: walk ? "Check in now" : isNew ? "Book" : "Save", primaryOn: canSave, close: { dismiss() }, action: save)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    patientBlock
                    if !walk { dayBlock }
                    dentistBlock
                    lengthBlock
                    ReasonPicker(spec: $a.spec, tx: $a.tx, note: $a.note)
                    Text(whenText).font(.rx(13, .semibold)).foregroundStyle(RX.mintLight)
                    if !isNew && !walk { cancelBlock }
                }
                .padding(.horizontal, 24).padding(.vertical, 20)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .rxSheet { dismiss() }
        .onAppear(perform: load)
        .sheet(isPresented: $newPatient) {
            NewPatientSheet(prefill: q, onCreate: { p in a.patient = p.id; q = "" })
        }
    }

    private var canSave: Bool { !a.patient.isEmpty && (!a.time.isEmpty || walk) }

    private func load() {
        guard !loaded else { return }
        loaded = true
        let m = Day.minutes(.now), next = ((m + 14) / 15) * 15
        a.time = Day.hm(min: min(next, 23 * 60 + 45))
        a.dent = store.dentists.first?.id ?? "d1"
        switch mode {
        case .new(let p): if let p { a.patient = p }
        case .walkIn(let p): walk = true; if let p { a.patient = p }
        case .edit(let x): a = x; isNew = false
        case .cancel(let x): a = x; isNew = false; cxStep = true
        case .slot(let d, let t, let de): a.day = d; a.time = t; a.dent = de
        case .prefill(let x): a = x
        }
        if case .cancel = mode {} else if DemoScreen.current == "cancel" { cxStep = true; cxBy = .patient; cxReason = "Travelling this week" }
    }

    private func save() {
        guard canSave else { return }
        if walk { store.walkIn(patient: a.patient, dent: a.dent, spec: a.spec, tx: a.tx, note: a.note, dur: a.dur) }
        else { store.saveAppointment(a, isNew: isNew) }
        dismiss()
    }

    private var whenText: String {
        walk ? "Arriving now · goes straight to the reception room" : Day.long(a.day) + " at " + a.time
    }

    // MARK: patient

    @ViewBuilder private var patientBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Patient").font(.rx(12)).foregroundStyle(RX.ink3)
            if let p = store.patient(a.patient) {
                HStack(spacing: 12) {
                    PatientIcon(p: p, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.name).font(.rx(15, .semibold))
                        Text([p.ageNow.map { "\($0) years" }, p.phone].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")).font(.rx(12)).foregroundStyle(RX.ink3)
                    }
                    Spacer()
                    Button("Change") { a.patient = "" }.font(.rx(13)).foregroundStyle(RX.mint).buttonStyle(.plain)
                }
                .padding(12).rxPanel(14)
            } else {
                HStack(spacing: 8) {
                    Icon(d: Ico.search, size: 16).foregroundStyle(RX.ink3)
                    TextField("", text: $q, prompt: Text("Search by name or phone").foregroundStyle(RX.ink4)).font(.rx(15))
                        .textInputAutocapitalization(.words).autocorrectionDisabled()
                }
                .padding(.horizontal, 14).padding(.vertical, 13).rxPanel(12)
                let sugg = matches
                if !sugg.isEmpty {
                    VStack(spacing: 2) {
                        ForEach(sugg) { p in
                            Button { a.patient = p.id; q = ""; Haptics.tap() } label: {
                                HStack(spacing: 10) {
                                    PatientIcon(p: p, size: 30)
                                    Text(p.name).font(.rx(14, .semibold))
                                    Spacer()
                                    Text([p.ageNow.map { "\($0) years" }, p.phone].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")).font(.rx(12)).foregroundStyle(RX.ink3)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 8).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4).rxPanel(14)
                }
                if !q.trimmingCharacters(in: .whitespaces).isEmpty && sugg.isEmpty {
                    HStack {
                        Text("No patient with that name yet.").font(.rx(12)).foregroundStyle(RX.ink3)
                        Spacer()
                        Button { newPatient = true } label: { Label("Create new patient", systemImage: "plus") }.buttonStyle(MintButton(compact: true))
                    }
                }
            }
        }
    }

    private var matches: [Patient] {
        let t = q.trimmingCharacters(in: .whitespaces).lowercased()
        if t.isEmpty { return Array(store.d.patients.prefix(0)) }
        return Array(store.d.patients.filter { $0.name.lowercased().contains(t) || $0.phones.contains { $0.replacingOccurrences(of: " ", with: "").contains(t.replacingOccurrences(of: " ", with: "")) } }.prefix(5))
    }

    // MARK: day + time

    private var dayBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Day").font(.rx(12)).foregroundStyle(RX.ink3)
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { n in
                    let d = Day.add(store.today, n), on = a.day == d, dt = Day.date(d)
                    Button { a.day = d; Haptics.tap() } label: {
                        VStack(spacing: 2) {
                            Text(n == 0 ? "Today" : n == 1 ? "Tomorrow" : dt.formatted(.dateTime.weekday(.abbreviated))).font(.rx(11, .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                            Text("\(Day.cal.component(.day, from: dt))").font(.rx(17, .bold))
                        }
                        .foregroundStyle(on ? RX.onMint : RX.ink2)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(on ? RX.mint : RX.card2))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Or pick a date").font(.rx(12)).foregroundStyle(RX.ink3)
                    DatePicker("", selection: Binding(get: { Day.date(a.day) }, set: { a.day = Day.iso($0) }), in: Day.date(store.today)..., displayedComponents: .date)
                        .labelsHidden().datePickerStyle(.compact)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Time").font(.rx(12)).foregroundStyle(RX.ink3)
                    DatePicker("", selection: Binding(get: { Day.at(a.day, a.time) }, set: { a.time = Day.hm(min: (Day.minutes($0) / 5) * 5) }), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
            }
        }
    }

    private var dentistBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dentist").font(.rx(12)).foregroundStyle(RX.ink3)
            HStack(spacing: 18) {
                ForEach(store.dentists) { d in
                    let on = a.dent == d.id
                    Button { a.dent = d.id; Haptics.tap() } label: {
                        VStack(spacing: 6) {
                            MemberAvatar(m: d, size: 50)
                                .overlay(Circle().strokeBorder(on ? RX.mint : .clear, lineWidth: 2).padding(-4))
                            Text(d.full).font(.rx(12, .semibold)).foregroundStyle(on ? RX.ink : RX.ink3)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var lengthBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Length").font(.rx(12)).foregroundStyle(RX.ink3)
            HStack(spacing: 6) {
                ForEach([15, 30, 45, 60, 90], id: \.self) { m in
                    let on = a.dur == m
                    Button("\(m) min") { a.dur = m; Haptics.tap() }
                        .font(.rx(13, .semibold)).foregroundStyle(RX.ink)
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 10).fill(on ? RX.card3 : RX.card2))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(on ? RX.mint : .clear, lineWidth: 1.5))
                        .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: cancel / remove

    @ViewBuilder private var cancelBlock: some View {
        if !cxStep {
            HStack(spacing: 10) {
                Button { withAnimation(.spring(duration: 0.4)) { cxStep = true } } label: {
                    Label { Text("Cancel appointment") } icon: { Icon(d: Ico.cancelCal, size: 15) }
                }
                .buttonStyle(SoftButton(compact: true, tint: RX.sand, fill: Color(rgb: 0xF3C98B, 0.14)))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(RX.sand.opacity(0.35)))
                Text("Keeps it under Cancelled").font(.rx(11.5)).foregroundStyle(RX.ink4)
                Spacer()
                Button("Remove appointment") { store.removeAppointment(a.id); dismiss() }
                    .font(.rx(12.5, .semibold)).foregroundStyle(RX.salmon).buttonStyle(.plain)
            }
            .padding(.top, 14)
            .overlay(alignment: .top) { Rectangle().fill(RX.line).frame(height: 1) }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Who cancelled?").font(.rx(14.5, .bold))
                HStack(spacing: 8) {
                    whoButton(.patient, "The patient cancelled", "Called, messaged or did not want it", RX.sand)
                    whoButton(.clinic, "The clinic cancelled", "The dentist or the clinic called it off", RX.lilac)
                }
                TextField("", text: $cxReason, prompt: Text("Reason (optional), e.g. sick, travelling, dentist away").foregroundStyle(RX.ink4))
                    .font(.rx(14)).padding(.horizontal, 13).padding(.vertical, 11).rxPanel(12)
                HStack {
                    Spacer()
                    Button("Keep the appointment") { withAnimation { cxStep = false; cxBy = nil; cxReason = "" } }.font(.rx(13, .semibold)).foregroundStyle(RX.ink3).buttonStyle(.plain)
                    Button("Mark as cancelled") {
                        guard let by = cxBy else { return }
                        store.cancelAppointment(a.id, by: by, reason: cxReason); dismiss()
                    }
                    .font(.rx(13, .heavy)).foregroundStyle(cxBy != nil ? Color(rgb: 0x2A1A0A) : RX.ink4)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(cxBy != nil ? RX.sand : RX.card2))
                    .buttonStyle(.plain).disabled(cxBy == nil)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color(rgb: 0xF3C98B, 0.07)).overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(RX.sand.opacity(0.28))))
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    private func whoButton(_ k: CancelInfo.By, _ l: String, _ sub: String, _ c: Color) -> some View {
        let on = cxBy == k
        return Button { withAnimation(.spring(duration: 0.3)) { cxBy = k }; Haptics.tap() } label: {
            HStack(alignment: .top, spacing: 10) {
                Circle().fill(c).frame(width: 10, height: 10).padding(.top, 4)
                VStack(alignment: .leading, spacing: 2) {
                    Text(l).font(.rx(13.5, .bold)).foregroundStyle(RX.ink)
                    Text(sub).font(.rx(11.5)).foregroundStyle(RX.ink3).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(12).frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 14).fill(on ? c.opacity(0.16) : RX.card2))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(on ? c : RX.line, lineWidth: on ? 2 : 1))
        }
        .buttonStyle(.plain)
    }
}

/// Reason: optional specialty chip, then one or more treatments, and/or a typed note.
struct ReasonPicker: View {
    @Binding var spec: String?
    @Binding var tx: [String]
    @Binding var note: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Reason").font(.rx(12)).foregroundStyle(RX.ink3) + Text(" · optional — pick, type, or both").font(.rx(12)).foregroundStyle(RX.ink4)
                Spacer()
                Button("Clear") { spec = nil; tx = []; note = "" }.font(.rx(12)).foregroundStyle(RX.ink3).buttonStyle(.plain)
            }
            FlowLayout(spacing: 6) {
                ForEach(Catalog.reasons) { r in
                    let on = spec == r.id
                    Button { withAnimation(.spring(duration: 0.3)) { if on { spec = nil; tx = [] } else { spec = r.id; tx = [] } }; Haptics.tap() } label: {
                        HStack(spacing: 7) {
                            Circle().fill(on ? RX.onMint.opacity(0.4) : r.color).frame(width: 8, height: 8)
                            Text(r.name).font(.rx(12.5, .semibold))
                            if on && !tx.isEmpty { Text("\(tx.count)").font(.rx(10, .bold)).foregroundStyle(r.color).frame(width: 17, height: 17).background(Circle().fill(RX.onMint)) }
                        }
                        .foregroundStyle(on ? RX.onMint : RX.ink2)
                        .padding(.horizontal, 11).padding(.vertical, 8)
                        .background(Capsule().fill(on ? r.color : RX.card2))
                    }
                    .buttonStyle(.plain)
                }
            }
            if let r = Catalog.reason(spec) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(r.name.uppercased()) · TAP ONE OR MORE").font(.rx(11, .semibold)).tracking(0.6).foregroundStyle(RX.ink3)
                    FlowLayout(spacing: 6) {
                        ForEach(r.treatments, id: \.self) { t in
                            let on = tx.contains(t)
                            Button { if on { tx.removeAll { $0 == t } } else { tx.append(t) }; Haptics.tap() } label: {
                                HStack(spacing: 6) {
                                    if on { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)) }
                                    Text(t).font(.rx(13, .semibold))
                                }
                                .foregroundStyle(on ? RX.ink : RX.ink2)
                                .padding(.horizontal, 11).padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 10).fill(on ? RX.mint.opacity(0.18) : .clear))
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(on ? r.color : Color(rgb: 0xD6EBE4, 0.18), lineWidth: 1.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(12).rxPanel(14, Color(rgb: 0x153A33, 0.6))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            TextField("", text: $note, prompt: Text("Or type it, e.g. tooth 36, pain since Friday").foregroundStyle(RX.ink4)).font(.rx(14))
                .padding(.horizontal, 14).padding(.vertical, 12).rxPanel(12)
            let summary = { () -> String in
                let t = tx.joined(separator: ", ")
                let base = !t.isEmpty ? t : (Catalog.reason(spec)?.name ?? "")
                let n = note.trimmingCharacters(in: .whitespaces)
                return [base, n].filter { !$0.isEmpty }.joined(separator: " · ")
            }()
            Label { Text(summary.isEmpty ? "No reason yet — that is fine" : summary) } icon: { Image(systemName: "list.bullet") }
                .font(.rx(13)).foregroundStyle(summary.isEmpty ? RX.ink4 : RX.ink)
        }
    }
}

// MARK: - Cancelled appointments

struct CancelledSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var when = "today"
    @State private var by = "all"
    @State private var book: ApptSheetMode?

    var body: some View {
        let T = store.today, L0 = store.cancelled
        let LW = L0.filter { when == "all" || (when == "today" ? $0.day == T : $0.day > T) }
        let L = LW.filter { by == "all" || $0.cancel?.by.rawValue == by }.sorted { ($0.cancel?.at ?? .distantPast) > ($1.cancel?.at ?? .distantPast) }
        let nPat = LW.filter { $0.cancel?.by == .patient }.count
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Cancelled appointments").font(.rx(19, .bold))
                Text((when == "today" ? "Appointments that were for today" : when == "coming" ? "Appointments that were for the coming days" : "Every cancelled appointment, past and coming") + " · \(nPat) by patients · \(LW.count - nPat) by the clinic").font(.rx(12.5)).foregroundStyle(RX.ink3)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        SegmentPicker(items: [("today", "Today"), ("coming", "Coming days"), ("all", "All")], sel: $when, counts: ["today": L0.filter { $0.day == T }.count, "coming": L0.filter { $0.day > T }.count, "all": L0.count])
                        SegmentPicker(items: [("all", "Anyone"), ("patient", "By the patient"), ("clinic", "By the clinic")], sel: $by, counts: ["all": LW.count, "patient": nPat, "clinic": LW.count - nPat])
                    }
                }
            }
            .padding(.horizontal, 22).padding(.top, 22).padding(.bottom, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) { Rectangle().fill(RX.line).frame(height: 1) }
            ScrollView {
                VStack(spacing: 8) {
                    if L.isEmpty { EmptyNote(text: "Nothing cancelled here.") }
                    ForEach(L) { c in row(c) }
                }
                .padding(18)
            }
        }
        .rxSheet { dismiss() }
        .sheet(item: $book) { m in AppointmentSheet(mode: m) }
        .onAppear { if L0.filter({ $0.day == T }).isEmpty { when = "all" } }
    }

    private func row(_ c: Appointment) -> some View {
        let X = c.cancel!, isP = X.by == .patient, p = store.patient(c.patient)
        let col = isP ? RX.sand : RX.lilac
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Button { dismiss(); store.section = .patients; store.openPatient = c.patient } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p?.name ?? "").font(.rx(16, .semibold)).foregroundStyle(RX.ink)
                        Text(Day.short(c.day) + " · " + c.time + " · " + apLabel(c)).font(.rx(12.5)).foregroundStyle(c.day < store.today ? RX.ink4 : RX.ink2).strikethrough(color: RX.ink3)
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                store.dentChip(c.dent)
                Chip(text: isP ? "Patient cancelled" : "Clinic cancelled", color: col)
            }
            if !X.reason.isEmpty {
                Text("“\(X.reason)”").font(.rx(13.5)).padding(.horizontal, 12).padding(.vertical, 9).frame(maxWidth: .infinity, alignment: .leading).rxPanel(12, RX.deep)
            }
            HStack(spacing: 8) {
                Text("Marked \(Day.dm(X.at)) \(Day.hm(X.at))" + (X.who.map { " by " + store.memberName($0) } ?? "") + (X.reason.isEmpty ? " · no reason written" : "")).font(.rx(11.5)).foregroundStyle(RX.ink4)
                Spacer()
                if let ph = p?.phone, !ph.isEmpty {
                    Button { openWhatsApp(ph, "Hello \(p?.first ?? ""), this is Rayhan Clinics. Your appointment on \(Day.short(c.day)) at \(c.time) was cancelled. Would you like to book a new time?") } label: { Label("WhatsApp", systemImage: "message.fill") }
                        .buttonStyle(SoftButton(compact: true, tint: Color(rgb: 0x7FE3A6), fill: RX.whatsapp.opacity(0.14)))
                }
                Button("Book again") {
                    var n = c; n.cancel = nil; n.id = "ap" + UUID().uuidString.prefix(8); if n.day < store.today { n.day = store.today }
                    book = .prefill(n)
                }.buttonStyle(MintButton(compact: true))
                if c.day >= store.today { Button("Not cancelled after all") { store.restoreAppointment(c.id) }.buttonStyle(SoftButton(compact: true)) }
                Button("Remove") { store.removeAppointment(c.id) }.font(.rx(12, .semibold)).foregroundStyle(RX.salmon).buttonStyle(.plain)
            }
        }
        .padding(14)
        .rxCard(18, fill: RX.card)
    }
}

func openWhatsApp(_ phone: String, _ text: String) {
    var d = phone.filter(\.isNumber)
    if d.hasPrefix("00") { d.removeFirst(2) } else if d.hasPrefix("0") { d = "963" + d.dropFirst() }
    let t = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    if let u = URL(string: "https://wa.me/\(d)?text=\(t)") { UIApplication.shared.open(u) }
}

func callPhone(_ phone: String) {
    let d = phone.filter { $0.isNumber || $0 == "+" }
    if let u = URL(string: "tel:\(d)") { UIApplication.shared.open(u) }
}
