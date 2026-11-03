import SwiftUI

struct PatientsView: View {
    @Environment(Store.self) private var store
    @Environment(\.horizontalSizeClass) private var hsc
    @State private var q = ""
    @State private var newPatient = false
    @State private var path: [String] = []

    var body: some View {
        NavigationStack(path: $path) {
            list
                .navigationDestination(for: String.self) { id in PatientProfileView(pid: id) }
                .toolbar(.hidden, for: .navigationBar)
        }
        .onChange(of: store.openPatient, initial: true) { _, v in
            if let v { path = [v]; store.openPatient = nil }
        }
        .sheet(isPresented: $newPatient) { NewPatientSheet(onCreate: { p in path = [p.id] }).presentationSizing(.form) }
    }

    private var filtered: [Patient] {
        let t = q.trimmingCharacters(in: .whitespaces).lowercased()
        let L = store.d.patients.sorted { $0.name < $1.name }
        if t.isEmpty { return L }
        return L.filter { $0.name.lowercased().contains(t) || $0.phones.contains { $0.replacingOccurrences(of: " ", with: "").contains(t.replacingOccurrences(of: " ", with: "")) } }
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .bottom, spacing: 16) { titleBlock; Spacer(); searchField.frame(width: 300); newButton }
                    VStack(alignment: .leading, spacing: 14) { titleBlock; HStack { searchField; newButton } }
                }
                summary
                LazyVGrid(columns: [GridItem(.adaptive(minimum: hsc == .compact ? 300 : 280), spacing: 16)], spacing: 16) {
                    ForEach(filtered) { p in
                        NavigationLink(value: p.id) { PatientCard(p: p) }.buttonStyle(PressScale())
                    }
                }
                if filtered.isEmpty { EmptyNote(text: "No patient with that name or phone.") }
            }
            .padding(.horizontal, hsc == .compact ? 16 : 32).padding(.vertical, hsc == .compact ? 8 : 28).padding(.bottom, 60)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Patients").font(.rx(hsc == .compact ? 28 : 34, .bold)).tracking(-0.8)
            Text("Choose a patient to start, or create a new one.").font(.rx(15)).foregroundStyle(RX.ink3)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Icon(d: Ico.search, size: 16).foregroundStyle(RX.ink3)
            TextField("", text: $q, prompt: Text("Search by name or phone").foregroundStyle(RX.ink4)).font(.rx(15)).autocorrectionDisabled()
            if !q.isEmpty { Button { q = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(RX.ink4) }.buttonStyle(.plain) }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .rxCard(14, fill: RX.card)
    }

    private var newButton: some View {
        Button { newPatient = true } label: { Label { Text("New patient") } icon: { Icon(d: Ico.plus, size: 17, weight: 2.4) } }.buttonStyle(MintButton())
    }

    private var summary: some View {
        let xr = store.d.patients.reduce(0) { $0 + $1.xrays.count }
        let today = Set(store.liveAppts.filter { $0.day == store.today }.map(\.patient)).count
        return HStack(spacing: 24) {
            stat("\(store.d.patients.count)", "patients")
            stat("\(xr)", "X-rays")
            stat("\(today)", "coming today")
            Spacer()
        }
        .padding(22).rxCard(26)
    }
    private func stat(_ v: String, _ l: String) -> some View {
        VStack(alignment: .leading, spacing: 2) { Text(v).font(.rx(28, .bold)); Text(l).font(.rx(12.5)).foregroundStyle(RX.ink3) }
    }
}

struct PatientCard: View {
    @Environment(Store.self) private var store
    let p: Patient
    var body: some View {
        let last = p.xrays.map(\.takenAt).max()
        let next = store.liveAppts.filter { $0.patient == p.id && $0.day >= store.today }.sorted { ($0.day, $0.startMin) < ($1.day, $1.startMin) }.first
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                PatientIcon(p: p, size: 50)
                VStack(alignment: .leading, spacing: 3) {
                    Text(p.name).font(.rx(16, .semibold)).foregroundStyle(RX.ink).lineLimit(1)
                    Text([p.ageNow.map { "\($0) years" }, p.sex == .m ? "Man" : p.sex == .f ? "Woman" : nil, p.phone.isEmpty ? nil : p.phone].compactMap { $0 }.joined(separator: " · ")).font(.rx(12.5)).foregroundStyle(RX.ink3).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            if p.hasAlert {
                FlowLayout(spacing: 5) {
                    ForEach(p.allg, id: \.self) { Chip(text: $0, color: RX.salmon, size: 11) }
                    ForEach(p.cond, id: \.self) { Chip(text: $0, color: RX.sand, size: 11) }
                }
            }
            HStack(spacing: 14) {
                Label("\(p.xrays.count)", systemImage: "rectangle.portrait").font(.rx(12)).foregroundStyle(RX.ink3)
                if let last { Text("Last X-ray " + Day.dm(last)).font(.rx(12)).foregroundStyle(RX.ink3) }
                Spacer()
                if let next { Chip(text: (next.day == store.today ? "Today " : Day.short(next.day) + " ") + next.time, color: RX.mintLight, size: 11) }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .rxCard(22)
        .contextMenu {
            Button("Book appointment", systemImage: "calendar.badge.plus") { store.section = .reception; store.pendingSheet = "book" }
            if !p.phone.isEmpty {
                Button("WhatsApp", systemImage: "message") { openWhatsApp(p.phone, "") }
                Button("Call", systemImage: "phone") { callPhone(p.phone) }
            }
        }
    }
}
