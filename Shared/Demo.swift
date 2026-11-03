import Foundation

/// Everything the app keeps. Saved as one JSON file on the device.
struct ClinicData: Codable {
    var version = 1
    var createdAt = Date()
    var team: [Member]
    var patients: [Patient]
    var appts: [Appointment]
    var flow: [FlowItem]
    var rooms: [Room]
    var labs: [Lab]
    var labPays: [LabPayment]
    var fx = FX()
    var cashOutAt: Date = .distantPast
    var cashLog: [CashEmpty] = []
    var activity: [ActivityItem] = []
}

enum Day {
    static let cal: Calendar = { var c = Calendar(identifier: .gregorian); c.locale = Locale(identifier: "en_GB"); c.firstWeekday = 1; return c }()
    private static let fmt: DateFormatter = { let f = DateFormatter(); f.calendar = cal; f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f }()
    static func iso(_ d: Date) -> String { fmt.string(from: d) }
    static func date(_ iso: String) -> Date { fmt.date(from: iso) ?? .now }
    static func today() -> String { iso(.now) }
    static func add(_ iso: String, _ n: Int) -> String { Day.iso(cal.date(byAdding: .day, value: n, to: date(iso)) ?? .now) }
    static func offset(_ n: Int, from base: Date = .now) -> String { iso(cal.date(byAdding: .day, value: n, to: base) ?? base) }
    static func at(_ iso: String, _ hm: String) -> Date {
        let p = hm.split(separator: ":").compactMap { Int($0) }
        return cal.date(bySettingHour: p.first ?? 0, minute: p.count > 1 ? p[1] : 0, second: 0, of: date(iso)) ?? date(iso)
    }
    static func hm(_ d: Date) -> String { let c = cal.dateComponents([.hour, .minute], from: d); return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0) }
    static func hm(min m: Int) -> String { String(format: "%02d:%02d", max(0, min(23, m / 60)), max(0, m % 60)) }
    static func minutes(_ d: Date) -> Int { let c = cal.dateComponents([.hour, .minute], from: d); return (c.hour ?? 0) * 60 + (c.minute ?? 0) }
    static func long(_ iso: String) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "en_GB"); f.dateFormat = "EEEE d MMMM"; return f.string(from: date(iso)) }
    static func short(_ iso: String) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "en_GB"); f.dateFormat = "EEE d MMM"; return f.string(from: date(iso)) }
    static func dm(_ d: Date) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "en_GB"); f.dateFormat = "d MMM"; return f.string(from: d) }
    static func dmy(_ d: Date) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "en_GB"); f.dateFormat = "d MMM yyyy"; return f.string(from: d) }
    static func ago(_ d: Date, now: Date = .now) -> String {
        let s = Int(now.timeIntervalSince(d))
        if s < 60 { return "just now" }
        if s < 3600 { return "\(s / 60) min ago" }
        if s < 86400 { return "\(s / 3600) h ago" }
        let dd = s / 86400
        return dd == 1 ? "yesterday" : "\(dd) days ago"
    }
}

/// The demo clinic: invented patients and a full day at the clinic, laid out around the moment the app is first opened.
enum DemoSeed {
    static let team: [Member] = [
        Member(id: "d1", title: "Dr.", name: "Bashar", colorHex: "#34C3A4", role: .dentist, admin: true, room: "Room 1"),
        Member(id: "d2", title: "Dr.", name: "Lama", colorHex: "#C9A7FF", role: .dentist, room: "Room 2"),
        Member(id: "d3", title: "Dr.", name: "Omar", colorHex: "#F0C88F", role: .dentist, room: "Room 3"),
        Member(id: "d4", title: "", name: "Hala", colorHex: "#FF9A8E", role: .reception, room: "Room 1"),
        Member(id: "d5", title: "", name: "Sami", colorHex: "#8FC2FF", role: .accountant, room: "Room 1"),
        Member(id: "d6", title: "", name: "Yara", colorHex: "#9AD48A", role: .storage, room: "Room 1"),
    ]

    static func make(now: Date = .now) -> ClinicData {
        let T = Day.iso(now)
        func at(_ d: Int, _ hm: String) -> Date { Day.at(Day.offset(d, from: now), hm) }
        func ago(min m: Double) -> Date { now.addingTimeInterval(-m * 60) }
        func step(_ k: String, _ d: Date, _ by: String?, _ note: String = "") -> LabStep { LabStep(k: k, at: d, by: by, note: note) }

        // ---------- patients ----------
        var P: [Patient] = []
        var demo = Patient(id: "P1", first: "Demo", last: "Patient", sex: .m, age: 34, phones: ["0933 222 444"], cond: ["Diabetes"], allg: ["Penicillin"], med: ["Aspirin"], created: at(-400, "10:00"), createdBy: "d4")
        demo.dentist = "d2"
        demo.chart = ["15": ToothState(missing: true), "36": ToothState(tags: ["Broken file", "Retreatment"], note: "Old root filling short, file in the mesial canal")]
        demo.procs = [
            Procedure(id: "pd1", teeth: ["36"], spec: "endo", type: "retx", addons: ["caoh", "ledge", "xcanal"], status: .doing, by: "d2", at: at(-4, "10:00")),
            Procedure(id: "pd2", teeth: ["36"], spec: "pros", type: "crown", status: .plan, by: "d2", at: at(-4, "10:20"), lab: LabWork(lab: "l2", svc: "v8", shade: "A3", temp: true, note: "After the retreatment is finished")),
            Procedure(id: "pd3", teeth: ["48"], spec: "surg", type: "wis", addons: ["sect", "sut"], status: .plan, by: "d1", at: at(-30, "12:00")),
            Procedure(id: "pd4", teeth: ["46"], spec: "endo", type: "rct", addons: ["dam"], status: .done, by: "d2", at: at(-100, "10:00"), doneAt: at(-100, "11:00"), giftAddons: ["dam"]),
            Procedure(id: "pd5", teeth: ["46"], spec: "pros", type: "crown", status: .done, by: "d2", at: at(-100, "11:10"), doneAt: at(-86, "12:00"),
                      lab: LabWork(lab: "l1", svc: "v1", shade: "A2", temp: true, note: "", steps: [step("imp", at(-100, "11:10"), "d2"), step("sent", at(-99, "09:00"), "d4"), step("recv", at(-90, "13:00"), "d4"), step("done", at(-86, "12:00"), "d2")])),
            Procedure(id: "pd6", teeth: ["26"], spec: "rest", type: "comp", status: .done, by: "d1", at: at(-40, "16:00"), doneAt: at(-40, "16:40"), surf: ["M", "O", "D"]),
            Procedure(id: "pd7", teeth: ["11"], spec: "pros", type: "crown", status: .doing, by: "d2", at: at(-9, "12:00"),
                      lab: LabWork(lab: "l1", svc: "v2", shade: "A1", temp: true, note: "Match 21, translucent edge", steps: [step("imp", at(-9, "12:00"), "d2"), step("sent", at(-8, "09:00"), "d4"), step("tryin", ago(min: 95), "d4")])),
            Procedure(id: "pd8", teeth: ["14", "15", "16"], spec: "pros", type: "bridge", status: .doing, by: "d2", at: at(-3, "11:00"),
                      lab: LabWork(lab: "l1", svc: "v4", shade: "A3", temp: true, note: "3-unit bridge, pontic on 15", steps: [step("imp", at(-3, "11:00"), "d2"), step("sent", at(-2, "09:30"), "d4")])),
            Procedure(id: "pd9", teeth: ["24"], spec: "rest", type: "comp", status: .done, by: "d1", at: at(-1, "17:00"), doneAt: at(-1, "17:40"), surf: ["D", "O"]),
        ]
        demo.billing = Billing(decider: "d2", pays: [
            Payment(id: "py1", amount: 300, cur: .usd, rate: 1, at: at(-100, "11:30"), by: "d5", items: ["pd4", "pd5"]),
            Payment(id: "py2", amount: 150, cur: .usd, rate: 1, at: at(-40, "16:50"), by: "d5", items: ["pd6"]),
            Payment(id: "py3", amount: 2_800_000, cur: .syp, rate: 14000, at: at(-9, "12:40"), by: "d4", note: "Towards the crown on 11"),
        ], changes: [PriceChange(key: "ag:pd4:dam", kind: "gift", what: "Gift: Rubber dam on 46 Root canal treatment", from: 10, to: 0, at: at(-100, "11:20"), by: "d5", dent: "d2")])
        demo.xrays = [
            Xray(id: "x1", image: "xr_lower_molar_rct", takenAt: at(-100, "10:05"), by: "d2", room: "Room 2", teeth: ["46"]),
            Xray(id: "x2", image: "xr_lower_lesion", takenAt: at(-4, "10:02"), by: "d2", room: "Room 2", teeth: ["36"], note: "Periapical lesion on 36"),
            Xray(id: "x3", image: "xr_upper_premolars", takenAt: at(-3, "11:05"), by: "d2", room: "Room 2", teeth: ["14", "15", "16"]),
            Xray(id: "x4", image: "xr_upper_molars", takenAt: at(-40, "16:02"), by: "d1", room: "Room 1", teeth: ["26"]),
            Xray(id: "x5", image: "xr_lower_molars", takenAt: at(-1, "17:02"), by: "d1", room: "Room 1", teeth: ["47", "48"]),
        ]
        demo.files = [PatientFile(name: "Upper jaw scan.stl", kind: "stl", size: 18_400_000, at: at(-3, "11:20"), tooth: "15", note: "For the bridge"), PatientFile(name: "CBCT lower right.dcm", kind: "dicom", size: 96_000_000, at: at(-30, "12:10"), tooth: "48")]
        P.append(demo)

        var rami = Patient(id: "P2", first: "Rami", last: "Haddad", sex: .m, age: 36, phones: ["0944 111 222"], cond: ["Diabetes"], created: at(-600, "10:00"))
        rami.dentist = "d3"
        rami.procs = [
            Procedure(id: "rq1", teeth: ["26"], spec: "endo", type: "rct", addons: ["caoh", "dam"], status: .done, by: "d3", at: at(-21, "10:00"), doneAt: at(-14, "10:00")),
            Procedure(id: "rq2", teeth: ["26"], spec: "pros", type: "crown", status: .doing, by: "d3", at: at(-6, "10:00"), lab: LabWork(lab: "l1", svc: "v1", shade: "A3", temp: true, steps: [step("imp", at(-6, "10:00"), "d3"), step("sent", at(-5, "09:00"), "d4"), step("ready", at(-1, "15:00"), "d4")]), discPct: 10),
            Procedure(id: "rq3", spec: "perio", type: "scal", addons: ["polish"], status: .done, by: "d3", at: at(-21, "09:30"), doneAt: at(-21, "09:50")),
        ]
        rami.billing = Billing(decider: "d3", pays: [Payment(id: "pq1", amount: 1_400_000, cur: .syp, rate: 14000, at: at(-21, "11:00"), by: "d5", items: ["rq3", "rq1"]), Payment(id: "pq2", amount: 50, cur: .usd, rate: 1, at: at(-14, "10:30"), by: "d5")],
                                changes: [PriceChange(key: "d:rq2", kind: "pdisc", what: "Discount on 26 Crown", from: 0, to: 10, at: at(-6, "10:10"), by: "d5", dent: "d3")])
        rami.xrays = [Xray(id: "x6", image: "xr_upper_molars", takenAt: at(-21, "10:02"), by: "d3", room: "Room 3", teeth: ["26"]), Xray(id: "x7", image: "xr_upper_premolars", takenAt: at(-14, "10:05"), by: "d3", room: "Room 3", teeth: ["24", "25"])]
        P.append(rami)

        var lina = Patient(id: "P3", first: "Lina", last: "Saleh", sex: .f, age: 30, phones: ["0944 555 777"], created: at(-480, "10:00"))
        lina.dentist = "d1"
        lina.procs = [
            Procedure(id: "lq1", teeth: ["37"], spec: "rest", type: "comp", addons: ["liner"], status: .done, by: "d1", at: at(-1, "10:30"), doneAt: at(-1, "11:00"), surf: ["O"]),
            Procedure(id: "lq2", teeth: ["36"], spec: "rest", type: "comp", status: .done, by: "d1", at: ago(min: 120), doneAt: ago(min: 90), surf: ["M", "O"]),
            Procedure(id: "lq3", spec: "prev", type: "white", status: .plan, by: "d1", at: ago(min: 90)),
        ]
        lina.billing = Billing(decider: "d1", pays: [Payment(id: "pl1", amount: 55, cur: .usd, rate: 1, at: at(-1, "11:10"), by: "d4", method: "Card", items: ["lq1"]), Payment(id: "pl2", amount: 700_000, cur: .syp, rate: 14000, at: ago(min: 80), by: "d4", items: ["lq2"])])
        lina.xrays = [Xray(id: "x8", image: "xr_lower_molars", takenAt: ago(min: 118), by: "d1", room: "Room 1", teeth: ["36", "37"])]
        P.append(lina)

        var omar = Patient(id: "P4", first: "Omar", last: "Khatib", sex: .m, age: 48, phones: ["0933 555 010"], created: at(-500, "10:00"))
        omar.dentist = "d2"
        omar.procs = [
            Procedure(id: "oq1", teeth: ["48"], spec: "surg", type: "wis", addons: ["sect", "sut"], status: .done, by: "d2", at: at(-35, "10:00"), doneAt: at(-35, "11:00")),
            Procedure(id: "oq2", teeth: ["45"], spec: "impl", type: "place", addons: ["igraft"], status: .doing, by: "d2", at: at(-11, "10:00")),
        ]
        omar.billing = Billing(agreed: 900, decider: "d2", pays: [Payment(id: "po1", amount: 145, cur: .usd, rate: 1, at: at(-35, "11:30"), by: "d5", items: ["oq1"]), Payment(id: "po2", amount: 300, cur: .eur, rate: 0.92, at: at(-11, "11:00"), by: "d5", method: "Bank transfer", note: "Deposit for the implant")],
                               changes: [PriceChange(key: "agreed", kind: "total", what: "Total set by hand", from: 945, to: 900, at: at(-11, "10:40"), by: "d5", dent: "d2")])
        omar.xrays = [Xray(id: "x9", image: "xr_lower_implant", takenAt: at(-11, "10:50"), by: "d2", room: "Room 2", teeth: ["45"])]
        P.append(omar)

        var sample = Patient(id: "P5", first: "Sample", last: "Imported", sex: .f, age: 67, phones: [], created: at(-900, "10:00"))
        sample.procs = [Procedure(id: "sq1", spec: "pros", type: "cden", addons: ["impr"], status: .done, by: "d2", at: at(-48, "11:00"), doneAt: at(-40, "11:00"),
                                  lab: LabWork(lab: "l2", svc: "v9", steps: [step("imp", at(-48, "11:00"), "d2"), step("sent", at(-47, "09:00"), "d4"), step("recv", at(-41, "12:00"), "d4"), step("done", at(-40, "11:00"), "d2")]))]
        sample.billing = Billing(pays: [Payment(id: "ps1", amount: 350, cur: .usd, rate: 1, at: at(-40, "11:30"), by: "d5")])
        P.append(sample)

        var yasmin = Patient(id: "P6", first: "Yasmin", last: "Darwish", sex: .f, age: 8, phones: ["0955 300 120"], created: at(-60, "10:00"))
        yasmin.dentist = "d3"
        yasmin.procs = [Procedure(id: "yq1", teeth: ["75"], spec: "pedo", type: "ppulp", addons: ["behav"], status: .plan, by: "d3", at: at(-2, "16:00")), Procedure(id: "yq2", teeth: ["36", "46"], spec: "prev", type: "seal", status: .done, by: "d3", at: at(-2, "16:10"), doneAt: at(-2, "16:30"))]
        yasmin.billing = Billing(pays: [])
        P.append(yasmin)

        var karim = Patient(id: "P7", first: "Karim", last: "Nasser", sex: .m, age: 72, phones: ["0944 820 016"], cond: ["High blood pressure"], med: ["Amlodipine"], created: at(-700, "10:00"))
        karim.dentist = "d1"
        karim.chart = ["36": ToothState(missing: true), "37": ToothState(missing: true)]
        karim.procs = [Procedure(id: "kq1", teeth: ["44"], spec: "surg", type: "ext", status: .done, by: "d1", at: at(-25, "12:00"), doneAt: at(-25, "12:20")), Procedure(id: "kq2", spec: "pros", type: "pden", status: .plan, by: "d1", at: at(-25, "12:30"), lab: LabWork(lab: "l2", svc: "v10"))]
        karim.billing = Billing(pays: [Payment(id: "pk1", amount: 30, cur: .usd, rate: 1, at: at(-25, "12:30"), by: "d4")])
        P.append(karim)

        var hiba = Patient(id: "P8", first: "Hiba", last: "Mansour", sex: .f, age: 41, phones: ["0933 404 552"], allg: ["Latex"], created: at(-200, "10:00"))
        hiba.dentist = "d2"
        hiba.procs = [Procedure(id: "hq1", spec: "perio", type: "srp", addons: ["lab"], status: .done, by: "d2", at: at(-60, "15:00"), doneAt: at(-60, "16:00"))]
        hiba.billing = Billing(pays: [])
        P.append(hiba)

        var fadi = Patient(id: "P9", first: "Fadi", last: "Azar", sex: .m, age: 29, phones: ["0999 714 300"], created: at(-90, "10:00"))
        fadi.dentist = "d1"
        fadi.procs = [Procedure(id: "fq1", teeth: ["11"], spec: "pros", type: "veneer", status: .doing, by: "d1", at: at(-12, "13:00"), lab: LabWork(lab: "l2", svc: "v7", shade: "BL2", temp: false, note: "Smile design attached", steps: [step("imp", at(-12, "13:00"), "d1"), step("sent", at(-11, "09:00"), "d4"), step("tryin", at(-5, "12:00"), "d4"), step("mod", at(-4, "13:00"), "d1", "Incisal edge 0.5 mm shorter")])),
                      Procedure(id: "fq2", teeth: ["21"], spec: "pros", type: "veneer", status: .doing, by: "d1", at: at(-12, "13:05"), lab: LabWork(lab: "l2", svc: "v7", shade: "BL2", steps: [step("imp", at(-12, "13:05"), "d1"), step("sent", at(-11, "09:00"), "d4")]))]
        fadi.billing = Billing(pays: [Payment(id: "pf1", amount: 200, cur: .usd, rate: 1, at: at(-12, "13:30"), by: "d5", note: "Deposit")])
        P.append(fadi)

        var maya = Patient(id: "P10", first: "Maya", last: "Khoury", sex: .f, age: 64, phones: ["0944 909 818"], created: at(-300, "10:00"))
        maya.dentist = "d3"
        maya.procs = [Procedure(id: "mq1", spec: "perio", type: "scal", status: .done, by: "d3", at: at(-62, "09:00"), doneAt: at(-62, "09:30"))]
        maya.billing = Billing(pays: [])
        P.append(maya)

        // ---------- today at reception (times around "now") ----------
        let nowMin = Day.minutes(now)
        let anchor = min(max(nowMin, 11 * 60), 16 * 60) // keep the demo day inside clinic hours, even at night
        func tm(_ off: Int) -> String { Day.hm(min: max(8 * 60, min(20 * 60, (anchor / 15) * 15 + off))) }
        var A: [Appointment] = []
        A.append(Appointment(id: "ap1", patient: "P2", day: T, time: tm(-150), dent: "d1", dur: 45, spec: "pros", tx: ["Cementation"]))
        A.append(Appointment(id: "ap2", patient: "P1", day: T, time: tm(-60), dent: "d2", dur: 60, spec: "endo", tx: ["Retreatment"], note: "Second visit"))
        A.append(Appointment(id: "ap3", patient: "P3", day: T, time: tm(-30), dent: "d1", dur: 30, spec: "gen", tx: ["Examination"]))
        A.append(Appointment(id: "ap4", patient: "P5", day: T, time: tm(-15), dent: "d2", dur: 30, spec: "gen", tx: ["X-ray"]))
        A.append(Appointment(id: "ap5", patient: "P7", day: T, time: tm(-20), dent: "d3", dur: 45, spec: "pros", tx: ["Impression"]))
        A.append(Appointment(id: "ap6", patient: "P8", day: T, time: tm(15), dent: "d1", dur: 45, spec: "endo", tx: ["Retreatment"]))
        A.append(Appointment(id: "ap7", patient: "P9", day: T, time: tm(30), dent: "d2", dur: 45, spec: "pros", tx: ["Try-in"], note: "Veneers 11 21"))
        A.append(Appointment(id: "ap8", patient: "P10", day: T, time: tm(60), dent: "d2", dur: 30, spec: "perio", tx: ["Scaling & polishing"]))
        A.append(Appointment(id: "ap9", patient: "P6", day: T, time: tm(90), dent: "d1", dur: 30, spec: "pedo", tx: ["Child check-up"]))
        A.append(Appointment(id: "ap10", patient: "P4", day: T, time: tm(120), dent: "d3", dur: 45, spec: "impl", tx: ["Implant check"]))
        // the coming days and the week behind, so the calendar is full
        let pool = ["P1", "P2", "P3", "P4", "P6", "P7", "P8", "P9", "P10", "P5"], dents = ["d1", "d2", "d3"]
        let reasons: [(String, String)] = [("endo", "Root canal treatment"), ("rest", "Composite filling"), ("perio", "Scaling & polishing"), ("pros", "Crown"), ("gen", "Examination"), ("surg", "Simple extraction"), ("impl", "Implant check"), ("ortho", "Adjustment")]
        var seed: UInt64 = 2026
        func rnd(_ n: Int) -> Int { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Int((seed >> 33) % UInt64(n)) }
        for d in -9...16 where d != 0 {
            let iso = Day.offset(d, from: now)
            let wd = Day.cal.component(.weekday, from: Day.date(iso))
            if wd == 6 { continue } // Friday off
            let n = 3 + rnd(5)
            var used = Set<String>()
            for k in 0..<n {
                let dent = dents[rnd(3)], start = 9 * 60 + rnd(20) * 30
                let key = dent + "\(start)"
                if used.contains(key) { continue }
                used.insert(key)
                let r = reasons[rnd(reasons.count)]
                A.append(Appointment(id: "ad\(d)_\(k)", patient: pool[rnd(pool.count)], day: iso, time: Day.hm(min: start), dent: dent, dur: [30, 30, 45, 60][rnd(4)], spec: r.0, tx: [r.1]))
            }
        }
        // cancelled, kept with who cancelled and why
        A.append(Appointment(id: "apc1", patient: "P2", day: T, time: tm(150), dent: "d2", dur: 30, spec: "rest", tx: ["Composite filling"], cancel: CancelInfo(by: .patient, reason: "Has a fever, will call to book again", at: at(-1, "18:10"), who: "d4")))
        A.append(Appointment(id: "apc2", patient: "P3", day: Day.offset(2, from: now), time: "10:00", dent: "d1", dur: 45, spec: "endo", tx: ["Root canal treatment"], cancel: CancelInfo(by: .clinic, reason: "Dr. away at a course that day", at: at(-1, "11:40"), who: "d1")))
        A.append(Appointment(id: "apc3", patient: "P4", day: Day.offset(-3, from: now), time: "17:00", dent: "d3", dur: 30, note: "Check-up", cancel: CancelInfo(by: .patient, reason: "", at: at(-4, "09:05"), who: "d4")))

        let F: [FlowItem] = [
            FlowItem(id: "fl1", appt: "ap1", patient: "P2", stage: .done, room: "r1", dents: ["d1"], arrivedAt: ago(min: 160), startedAt: ago(min: 152), doneAt: ago(min: 110)),
            FlowItem(id: "fl2", appt: "ap2", patient: "P1", stage: .waiting, arrivedAt: ago(min: 46)),
            FlowItem(id: "fl3", appt: "ap3", patient: "P3", stage: .waiting, arrivedAt: ago(min: 24)),
            FlowItem(id: "fl4", appt: "ap4", patient: "P5", stage: .waiting, arrivedAt: ago(min: 4)),
            FlowItem(id: "fl5", appt: "ap5", patient: "P7", stage: .room, room: "r3", dents: ["d3"], arrivedAt: ago(min: 30), startedAt: ago(min: 18)),
        ]
        let rooms = [Room(id: "r1", name: "Room 1", dents: ["d1"]), Room(id: "r2", name: "Room 2", dents: ["d2"]), Room(id: "r3", name: "Room 3", dents: ["d3"])]
        let labPays = [LabPayment(id: "lp1", lab: "l1", amount: 90, cur: .usd, rate: 1, at: at(-98, "17:00"), by: "d5", note: "Crown 46 · Demo Patient"),
                       LabPayment(id: "lp2", lab: "l2", amount: 1_000_000, cur: .syp, rate: 14000, at: at(-2, "16:00"), by: "d5", note: "For the denture")]
        let act = [
            ActivityItem(kind: "lab", text: "Try-in arrived · Crown 11 · Demo Patient", patient: "P1", by: "d4", at: ago(min: 95)),
            ActivityItem(kind: "xray", text: "Took an X-ray · 36 37 · Lina Saleh", patient: "P3", by: "d1", at: ago(min: 118)),
            ActivityItem(kind: "reception", text: "Arrived · waiting in the reception room (for Dr. Lama)", patient: "P1", by: "d4", at: ago(min: 46)),
            ActivityItem(kind: "payment", text: "Received 700,000 SYP (cash)", patient: "P3", by: "d4", at: ago(min: 80)),
        ]
        return ClinicData(team: team, patients: P, appts: A, flow: F, rooms: rooms, labs: CatalogData.labs, labPays: labPays, activity: act)
    }
}
