import SwiftUI

@main
struct RayhanApp: App {
    @State private var store = Store()
    init() { Notifier.setup() }
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.dark)
                .tint(RX.mint)
                .onOpenURL { store.handle($0) }
        }
    }
}

extension Store {
    /// rayhan://reception, rayhan://walkin, rayhan://labs, rayhan://payments, rayhan://calendar, rayhan://patient/P1
    func handle(_ url: URL) {
        guard url.scheme == "rayhan" else { return }
        let host = url.host() ?? ""
        switch host {
        case "reception": section = .reception
        case "walkin": section = .reception; pendingSheet = "walkin"
        case "newappointment": section = .reception; pendingSheet = "book"
        case "calendar": section = .calendar
        case "labs": section = .labs
        case "payments": section = .payments
        case "patient":
            section = .patients
            openPatient = url.pathComponents.dropFirst().first
        default: break
        }
    }
}

struct RootView: View {
    @Environment(Store.self) private var store
    @Environment(\.horizontalSizeClass) private var hsc
    var body: some View {
        ZStack {
            RX.bg.ignoresSafeArea()
            Ambient().ignoresSafeArea()
            if store.me == nil {
                SignInView().transition(.opacity.combined(with: .scale(scale: 1.03)))
            } else if hsc == .compact {
                PhoneShell().transition(.opacity)
            } else {
                PadShell().transition(.opacity)
            }
        }
        .animation(.spring(duration: 0.7), value: store.me)
        .onAppear {
            if UserDefaults.standard.bool(forKey: "demoLandscape"), let sc = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                sc.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight)) { _ in }
            }
        }
        .overlay(alignment: .bottom) { ToastView().padding(.bottom, hsc == .compact ? 96 : 28).padding(.horizontal, 16) }
        .overlay(alignment: .top) { BannerView().padding(.top, 6).padding(.horizontal, 16) }
        .font(.rx(14))
        .foregroundStyle(RX.ink)
    }
}

/// Soft moving glows behind everything (the demo's ambient background).
struct Ambient: View {
    @State private var t = false
    var body: some View {
        GeometryReader { g in
            ZStack {
                Circle().fill(Color(rgb: 0x1C6B5B, 0.55)).frame(width: g.size.width * 0.6).blur(radius: 120)
                    .offset(x: t ? -g.size.width * 0.18 : -g.size.width * 0.3, y: t ? -g.size.height * 0.28 : -g.size.height * 0.2)
                Circle().fill(Color(rgb: 0x34C3A4, 0.16)).frame(width: g.size.width * 0.5).blur(radius: 140)
                    .offset(x: t ? g.size.width * 0.3 : g.size.width * 0.22, y: t ? g.size.height * 0.3 : g.size.height * 0.18)
                Circle().fill(Color(rgb: 0x0F4A3E, 0.5)).frame(width: g.size.width * 0.45).blur(radius: 110)
                    .offset(x: t ? g.size.width * 0.05 : g.size.width * 0.12, y: t ? -g.size.height * 0.05 : g.size.height * 0.08)
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .allowsHitTesting(false)
        .onAppear { withAnimation(.easeInOut(duration: 18).repeatForever(autoreverses: true)) { t = true } }
    }
}

// MARK: - iPad: the demo's sidebar + content

struct PadShell: View {
    @Environment(Store.self) private var store
    @AppStorage("sidebarCollapsed") private var collapsedPref = false
    var body: some View {
        GeometryReader { g in
            let narrow = g.size.width < 1000
            let collapsed = narrow || collapsedPref
            HStack(spacing: 0) {
                Sidebar(collapsed: collapsed, canExpand: !narrow, toggle: { withAnimation(.spring(duration: 0.45)) { collapsedPref.toggle() } })
                    .frame(width: collapsed ? 88 : 272)
                SectionContent(section: store.section)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .ignoresSafeArea(.keyboard)
    }
}

struct SectionContent: View {
    let section: AppSection
    var body: some View {
        switch section {
        case .reception: ReceptionView()
        case .calendar: CalendarView()
        case .patients: PatientsView()
        case .labs: LabsView()
        case .payments: PaymentsView()
        }
    }
}

struct Sidebar: View {
    @Environment(Store.self) private var store
    let collapsed: Bool
    let canExpand: Bool
    let toggle: () -> Void
    @State private var showNotes = false
    @State private var showMe = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                if collapsed {
                    Image("logo_white").resizable().scaledToFit().frame(height: 0).hidden()
                } else {
                    Image("logo_white").resizable().scaledToFit().frame(height: 44)
                    Spacer()
                }
                bell
            }
            .frame(maxWidth: .infinity, alignment: collapsed ? .center : .leading)
            .padding(.horizontal, collapsed ? 0 : 6).padding(.top, 4)

            meCard

            VStack(spacing: 2) {
                ForEach(store.sections) { s in navItem(s) }
            }

            Spacer(minLength: 0)

            if collapsed {
                if canExpand { tile(Ico.chevronR, "Show the sidebar", action: toggle) }
            } else {
                HStack(spacing: 8) {
                    tile(Ico.undo, "Undo") { store.undo() }
                    tile("M12 3a9 9 0 1 1-9 9 M12 3v4 M3 12H7", "Reset demo") { store.resetDemo() }
                    tile(Ico.sidebar, "Hide the sidebar", action: toggle).opacity(canExpand ? 1 : 0.35).disabled(!canExpand)
                }
            }
        }
        .padding(.vertical, 24).padding(.horizontal, collapsed ? 12 : 18)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(RX.side.opacity(0.92).ignoresSafeArea())
        .overlay(alignment: .trailing) { Rectangle().fill(RX.line).frame(width: 1).ignoresSafeArea() }
        .sheet(isPresented: $showMe) { MyProfileSheet().presentationDetents([.medium, .large]) }
    }

    private var bell: some View {
        Button { showNotes = true; Haptics.tap() } label: {
            Icon(d: Ico.bell, size: 19).foregroundStyle(RX.ink2)
                .frame(width: 44, height: 44)
                .glassEffect(.regular.tint(RX.card2.opacity(0.6)).interactive(), in: .rect(cornerRadius: 13))
                .overlay(alignment: .topTrailing) { if store.unread > 0 { Badge(n: store.unread).offset(x: 6, y: -6) } }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Notifications")
        .popover(isPresented: $showNotes, arrowEdge: .leading) { NotificationsPanel().frame(width: 380, height: 520).presentationCompactAdaptation(.sheet) }
    }

    private var meCard: some View {
        let m = store.meMember
        return HStack(spacing: 12) {
            Button { showMe = true } label: {
                HStack(spacing: 12) {
                    MemberAvatar(m: m, size: 40, ring: true)
                    if !collapsed {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(m?.full ?? "").font(.rx(14, .semibold)).lineLimit(1)
                            Text((store.isAdmin ? "Admin" : (m?.role.name ?? "")) + " · iPad").font(.rx(12)).foregroundStyle(RX.ink3)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if !collapsed {
                IconButton(icon: Ico.switchUser, size: 32, label: "Switch user") { store.me = nil }
            }
        }
        .padding(collapsed ? 6 : 10)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(rgb: 0xD6F5EC, 0.05)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color(rgb: 0xD6F5EC, 0.07), lineWidth: 1))
        .contextMenu { Button("Switch user", systemImage: "rectangle.portrait.and.arrow.right") { store.me = nil } }
    }

    private func navItem(_ s: AppSection) -> some View {
        let on = store.section == s
        let n = badge(s)
        return Button {
            withAnimation(.spring(duration: 0.35)) { store.section = s; store.openPatient = nil }
            Haptics.tap()
        } label: {
            HStack(spacing: 10) {
                Icon(d: s.icon, size: collapsed ? 22 : 18)
                if !collapsed {
                    Text(s.label).font(.rx(15, on ? .semibold : .regular))
                    Spacer()
                    if n.0 > 0 { Badge(n: n.0, fill: n.1, ink: n.2) }
                }
            }
            .foregroundStyle(on ? RX.ink : RX.ink3)
            .padding(.horizontal, 12).padding(.vertical, collapsed ? 13 : 11)
            .frame(maxWidth: .infinity, alignment: collapsed ? .center : .leading)
            .background { if on { RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(rgb: 0x34C3A4, 0.14)) } }
            .overlay(alignment: .topTrailing) { if collapsed && n.0 > 0 { Circle().fill(n.1).frame(width: 9, height: 9).offset(x: -10, y: 8) } }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(s.label)
        .hoverEffect(.highlight)
    }

    private func badge(_ s: AppSection) -> (Int, Color, Color) {
        switch s {
        case .reception:
            let w = store.waiting
            let longest = w.map { Date.now.timeIntervalSince($0.arrivedAt) / 60 }.max() ?? 0
            return (w.count, waitColor(longest), RX.onMint)
        case .labs: return (store.labCases.filter { $0.needsAttention || $0.whereNow == .clinic }.count, RX.amber, RX.onMint)
        case .payments: return (0, RX.red, .white)
        default: return (0, RX.red, .white)
        }
    }

    private func tile(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button { action(); Haptics.tap() } label: {
            Icon(d: icon, size: 18).foregroundStyle(RX.ink2)
                .frame(maxWidth: .infinity, minHeight: 50)
                .glassEffect(.regular.tint(RX.card.opacity(0.6)).interactive(), in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain).accessibilityLabel(label)
    }
}

// MARK: - iPhone: floating Liquid Glass tab bar

struct PhoneShell: View {
    @Environment(Store.self) private var store
    @State private var showNotes = false
    var body: some View {
        @Bindable var store = store
        TabView(selection: $store.section) {
            ForEach(store.sections) { s in
                Tab(s.label, systemImage: s.symbol, value: s) {
                    VStack(spacing: 0) {
                        phoneTop
                        SectionContent(section: s)
                    }
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            WaitingAccessory()
        }
        .sheet(isPresented: $showNotes) { NotificationsPanel().presentationDetents([.medium, .large]) }
    }

    private var phoneTop: some View {
        HStack {
            Button { store.me = nil } label: { MemberAvatar(m: store.meMember, size: 32, ring: true) }.buttonStyle(.plain).accessibilityLabel("Switch user")
            Spacer()
            Image("logo_white").resizable().scaledToFit().frame(height: 26)
            Spacer()
            Button { showNotes = true } label: {
                Icon(d: Ico.bell, size: 18).foregroundStyle(RX.ink2).frame(width: 40, height: 40)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .overlay(alignment: .topTrailing) { if store.unread > 0 { Badge(n: store.unread).scaleEffect(0.85).offset(x: 6, y: -6) } }
            }
            .buttonStyle(.plain).accessibilityLabel("Notifications")
        }
        .padding(.horizontal, 16).padding(.vertical, 6)
    }
}

struct WaitingAccessory: View {
    @Environment(Store.self) private var store
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let w = store.waiting
            Button { store.section = .reception } label: {
                HStack(spacing: 10) {
                    Image(systemName: "sofa.fill").foregroundStyle(RX.mint)
                    if let first = w.first {
                        let m = ctx.date.timeIntervalSince(first.arrivedAt)
                        Text("\(w.count) waiting").font(.rx(14, .semibold))
                        Text("· longest \(clockText(m))").font(.rx(13)).foregroundStyle(waitColor(m / 60)).monospacedDigit()
                    } else {
                        Text("Nobody waiting").font(.rx(14, .semibold))
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Notifications

struct NotificationsPanel: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Notifications").font(.rx(18, .bold))
                Spacer()
                if store.unread > 0 { Button("Mark all read") { store.markAllRead() }.font(.rx(13, .semibold)).foregroundStyle(RX.mint).buttonStyle(.plain) }
            }
            .padding(18)
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(store.d.activity) { a in
                        Button {
                            if let p = a.patient { store.section = .patients; store.openPatient = p }
                            dismiss()
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                MemberAvatar(m: store.member(a.by), size: 32)
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text(store.patient(a.patient)?.name ?? store.memberName(a.by)).font(.rx(14, .semibold))
                                        Spacer()
                                        Text(Day.ago(a.at)).font(.rx(11.5)).foregroundStyle(RX.ink4)
                                    }
                                    Text(a.text).font(.rx(13)).foregroundStyle(RX.ink3).multilineTextAlignment(.leading)
                                    Text(store.memberName(a.by)).font(.rx(11.5)).foregroundStyle(RX.ink4)
                                }
                                if !a.read { Circle().fill(RX.mint).frame(width: 8, height: 8).padding(.top, 6) }
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 14).fill(RX.card))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14).padding(.bottom, 14)
            }
        }
        .background(RX.sheet)
        .onDisappear { store.markAllRead() }
    }
}

// MARK: - My profile (own colour)

struct MyProfileSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    static let palette = ["#34C3A4", "#C9A7FF", "#F0C88F", "#FF9A8E", "#8FC2FF", "#9AD48A", "#F2A7D0", "#F5D547", "#6FE3C8", "#E8AA5A", "#B7C3BF", "#7FC8FF", "#FF6B5E", "#D9B48A", "#B89BFF", "#5FD6BB"]
    var body: some View {
        let m = store.meMember
        VStack(spacing: 0) {
            SheetHeader(title: "My profile", close: { dismiss() })
            ScrollView {
                VStack(spacing: 22) {
                    MemberAvatar(m: m, size: 96, ring: true).padding(.top, 10)
                    Text(m?.full ?? "").font(.rx(22, .bold))
                    Text(m?.role.name ?? "").font(.rx(13)).foregroundStyle(RX.ink3)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your colour").font(.rx(12)).foregroundStyle(RX.ink3)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 8), spacing: 10) {
                            ForEach(Self.palette, id: \.self) { h in
                                Button {
                                    store.change(nil, undo: false) { c in if let i = c.team.firstIndex(where: { $0.id == store.me }) { c.team[i].colorHex = h } }
                                    Haptics.tap()
                                } label: {
                                    Circle().fill(Color(hex: h)).frame(height: 36)
                                        .overlay(Circle().strokeBorder(.white, lineWidth: m?.colorHex == h ? 3 : 0))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16).rxCard(18)
                }
                .padding(22)
            }
        }
        .rxSheet { dismiss() }
    }
}
