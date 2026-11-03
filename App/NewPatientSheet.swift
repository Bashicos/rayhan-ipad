import SwiftUI

struct NewPatientSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    var prefill: String = ""
    var editing: Patient? = nil
    var onCreate: (Patient) -> Void = { _ in }

    @State private var p = Patient(first: "", last: "")
    @State private var ageText = ""
    @State private var born = false
    @State private var birth = Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now
    @State private var loaded = false

    static let conditions = ["Diabetes", "High blood pressure", "Heart disease", "Asthma", "Pregnancy", "Bleeding disorder", "Epilepsy", "Hepatitis", "Kidney disease", "Thyroid"]
    static let allergies = ["Penicillin", "Latex", "Local anaesthetic", "NSAIDs", "Iodine", "Sulfa drugs"]
    static let medications = ["Aspirin", "Warfarin", "Insulin", "Metformin", "Amlodipine", "Bisphosphonates", "Clopidogrel"]

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: editing == nil ? "New patient" : "Edit patient", primary: editing == nil ? "Create" : "Save", primaryOn: canSave, close: { dismiss() }, action: save)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 18) {
                        PatientIcon(p: preview, size: 84)
                        VStack(spacing: 12) {
                            HStack(spacing: 10) {
                                RXField(label: "First name", text: $p.first, placeholder: "First name")
                                RXField(label: "Last name", text: $p.last, placeholder: "Last name")
                            }
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Sex").font(.rx(12)).foregroundStyle(RX.ink3)
                                    SegmentPicker(items: [(Sex.m, "Man"), (Sex.f, "Woman")], sel: $p.sex)
                                }
                                Spacer()
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Age").font(.rx(12)).foregroundStyle(RX.ink3)
                            Spacer()
                            SegmentPicker(items: [(false, "Age"), (true, "Born")], sel: $born)
                        }
                        if born {
                            DatePicker("Date of birth", selection: $birth, in: ...Date.now, displayedComponents: .date).font(.rx(14))
                        } else {
                            RXField(label: "", text: $ageText, placeholder: "Age in years", keyboard: .numberPad)
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Phone / WhatsApp").font(.rx(12)).foregroundStyle(RX.ink3)
                        ForEach(p.phones.indices, id: \.self) { i in
                            HStack {
                                RXField(label: "", text: Binding(get: { p.phones[safe: i] ?? "" }, set: { if p.phones.indices.contains(i) { p.phones[i] = $0 } }), placeholder: "09xx xxx xxx", keyboard: .phonePad)
                                if p.phones.count > 1 { IconButton(icon: Ico.close, size: 34, label: "Remove phone") { p.phones.remove(at: i) } }
                            }
                        }
                        Button { p.phones.append("") } label: { Label("Add another number", systemImage: "plus") }.font(.rx(13, .semibold)).foregroundStyle(RX.mint).buttonStyle(.plain)
                    }
                    MedList(title: "Conditions", items: $p.cond, suggestions: Self.conditions, color: RX.sand)
                    MedList(title: "Allergies", items: $p.allg, suggestions: Self.allergies, color: RX.salmon)
                    MedList(title: "Medications", items: $p.med, suggestions: Self.medications, color: RX.blue)
                }
                .padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .rxSheet { dismiss() }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let e = editing {
                p = e; ageText = e.age.map(String.init) ?? ""; if let b = e.birth { born = true; birth = b }
            } else {
                let w = prefill.trimmingCharacters(in: .whitespaces)
                if w.allSatisfy({ $0.isNumber || $0 == " " || $0 == "+" }) && !w.isEmpty { p.phones = [w] }
                else { let parts = w.split(separator: " "); p.first = parts.first.map(String.init) ?? ""; p.last = parts.dropFirst().joined(separator: " ") }
                if p.phones.isEmpty { p.phones = [""] }
                if DemoScreen.current == "newpatient" { p.first = "Nour"; p.last = "Haddad"; p.sex = .f; ageText = "27"; p.phones = ["0933 777 120"] }
            }
        }
    }

    private var preview: Patient { var x = p; x.age = Int(ageText); if born { x.birth = birth }; return x }
    private var canSave: Bool { !p.first.trimmingCharacters(in: .whitespaces).isEmpty && p.sex != .none && (born || Int(ageText) != nil) }

    private func save() {
        guard canSave else { return }
        var n = p
        n.first = n.first.trimmingCharacters(in: .whitespaces); n.last = n.last.trimmingCharacters(in: .whitespaces)
        n.phones = n.phones.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if born { n.birth = birth; n.age = nil } else { n.birth = nil; n.age = Int(ageText) }
        if editing != nil {
            store.updatePatient(n.id, "Patient details saved") { $0 = n }
        } else {
            store.addPatient(n)
            onCreate(n)
        }
        dismiss()
    }
}

struct MedList: View {
    let title: String
    @Binding var items: [String]
    let suggestions: [String]
    let color: Color
    @State private var custom = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.rx(12)).foregroundStyle(RX.ink3)
            FlowLayout(spacing: 6) {
                ForEach(Array(Set(suggestions + items)).sorted(), id: \.self) { s in
                    let on = items.contains(s)
                    Button { if on { items.removeAll { $0 == s } } else { items.append(s) }; Haptics.tap() } label: {
                        Text(s).font(.rx(13, .semibold)).foregroundStyle(on ? RX.onMint : RX.ink2)
                            .padding(.horizontal, 11).padding(.vertical, 7)
                            .background(Capsule().fill(on ? color : RX.card2))
                    }
                    .buttonStyle(.plain)
                }
                HStack(spacing: 4) {
                    TextField("", text: $custom, prompt: Text("+ Add").foregroundStyle(RX.ink4)).font(.rx(13)).frame(width: 110)
                        .onSubmit { let t = custom.trimmingCharacters(in: .whitespaces); if !t.isEmpty && !items.contains(t) { items.append(t) }; custom = "" }
                }
                .padding(.horizontal, 11).padding(.vertical, 7)
                .overlay(Capsule().strokeBorder(Color(rgb: 0xD6EBE4, 0.24), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            }
        }
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
