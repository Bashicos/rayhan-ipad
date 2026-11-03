import SwiftUI
import LocalAuthentication

struct SignInView: View {
    @Environment(Store.self) private var store
    @State private var welcome: Member?
    @State private var appear = false
    @AppStorage("faceID") private var faceID = false

    var body: some View {
        ZStack {
            if let w = welcome {
                VStack(spacing: 18) {
                    MemberAvatar(m: w, size: 120, ring: true)
                        .shadow(color: RX.mint.opacity(0.35), radius: 40)
                    Text("Welcome, \(w.full)").font(.rx(32, .bold)).tracking(-0.6)
                    Text(store.adminFlag(w.id) ? "Admin" : w.role.name).font(.rx(15)).foregroundStyle(RX.ink3)
                }
                .transition(.asymmetric(insertion: .scale(scale: 0.92).combined(with: .opacity), removal: .opacity))
            } else {
                picker
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { withAnimation(.spring(duration: 0.8).delay(0.1)) { appear = true } }
    }

    private var picker: some View {
        ScrollView {
            VStack(spacing: 28) {
                Image("logo_white").resizable().scaledToFit().frame(height: 64).padding(.top, 40)
                VStack(spacing: 8) {
                    Text("Who's working on this iPad?").font(.rx(30, .bold)).tracking(-0.6).multilineTextAlignment(.center)
                    Text("Tap your name to start").font(.rx(15)).foregroundStyle(RX.ink3)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)], spacing: 16) {
                    ForEach(Array(store.d.team.enumerated()), id: \.element.id) { item in
                        let i = item.offset, m = item.element
                        Button { pick(m) } label: {
                            VStack(spacing: 12) {
                                MemberAvatar(m: m, size: 76)
                                VStack(spacing: 3) {
                                    Text(m.full).font(.rx(16, .semibold)).foregroundStyle(RX.ink)
                                    Text(m.admin ? "Admin · " + m.role.name : m.role.name).font(.rx(12.5)).foregroundStyle(RX.ink3)
                                }
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 22)
                            .rxCard(22)
                            .contentShape(RoundedRectangle(cornerRadius: 22))
                        }
                        .buttonStyle(PressScale())
                        .opacity(appear ? 1 : 0).offset(y: appear ? 0 : 18)
                        .animation(.spring(duration: 0.6).delay(0.05 * Double(i)), value: appear)
                    }
                }
                .frame(maxWidth: 700)
                Toggle(isOn: $faceID) {
                    Label("Open with Face ID", systemImage: "faceid").font(.rx(14))
                }
                .toggleStyle(.switch).tint(RX.mint).frame(maxWidth: 320)
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
        }
    }

    private func pick(_ m: Member) {
        Haptics.tap()
        if faceID {
            let ctx = LAContext()
            var err: NSError?
            if ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) {
                ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Open Rayhan as \(m.full)") { ok, _ in
                    DispatchQueue.main.async { if ok { go(m) } }
                }
                return
            }
        }
        go(m)
    }

    private func go(_ m: Member) {
        withAnimation(.spring(duration: 0.6)) { welcome = m }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) { store.signIn(m.id) }
    }
}

struct PressScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.96 : 1).animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

extension Store { func adminFlag(_ id: String) -> Bool { member(id)?.admin ?? false } }
