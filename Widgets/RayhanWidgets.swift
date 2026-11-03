import WidgetKit
import SwiftUI
import ActivityKit
import AppIntents

@main
struct RayhanWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextPatientsWidget()
        WaitingWidget()
        LabHereWidget()
        VisitLiveActivity()
        WalkInControl()
        ReceptionControl()
    }
}

// MARK: - Timeline

struct RXEntry: TimelineEntry {
    let date: Date
    let s: WidgetSnapshot
}

struct RXProvider: TimelineProvider {
    private func snap() -> WidgetSnapshot { WidgetSnapshot.read() ?? WidgetSnapshot.make(from: DemoSeed.make()) }
    func placeholder(in context: Context) -> RXEntry { RXEntry(date: .now, s: WidgetSnapshot.make(from: DemoSeed.make())) }
    func getSnapshot(in context: Context, completion: @escaping (RXEntry) -> Void) { completion(RXEntry(date: .now, s: snap())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<RXEntry>) -> Void) {
        let e = RXEntry(date: .now, s: snap())
        completion(Timeline(entries: [e], policy: .after(Date.now.addingTimeInterval(15 * 60))))
    }
}

private extension View {
    func rxWidgetBackground() -> some View {
        containerBackground(for: .widget) {
            LinearGradient(colors: [Color(rgb: 0x123D35), Color(rgb: 0x0A211D)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

// MARK: - Next patients

struct NextPatientsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "next", provider: RXProvider()) { e in NextPatientsView(e: e).rxWidgetBackground() }
            .configurationDisplayName("Next patients")
            .description("Who is coming next, with their dentist.")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
    }
}

struct NextPatientsView: View {
    @Environment(\.widgetFamily) private var family
    let e: RXEntry
    var body: some View {
        let L = e.s.next
        switch family {
        case .accessoryInline:
            Text(L.first.map { "\($0.time) \($0.patient)" } ?? "No more patients today").privacySensitive()
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text("Next patient").font(.caption2).foregroundStyle(.secondary)
                if let f = L.first {
                    Text(f.time + " · " + f.patient).font(.headline).lineLimit(1).privacySensitive()
                    Text(f.dentist).font(.caption).lineLimit(1)
                } else { Text("No more today").font(.headline) }
            }
            .widgetURL(URL(string: "rayhan://reception"))
        default:
            let n = family == .systemSmall ? 2 : family == .systemMedium ? 3 : 7
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Coming next").font(.system(size: 13, weight: .semibold)).foregroundStyle(RX.ink3)
                    Spacer()
                    Text("\(L.count)").font(.system(size: 13, weight: .bold)).foregroundStyle(RX.mintLight)
                }
                if L.isEmpty {
                    Spacer()
                    Text("No more patients today").font(.system(size: 14, weight: .semibold)).foregroundStyle(RX.ink2)
                    Spacer()
                }
                ForEach(Array(L.prefix(n)), id: \.self) { it in
                    HStack(spacing: 8) {
                        Text(it.time).font(.system(size: 14, weight: .bold)).monospacedDigit().foregroundStyle(RX.ink)
                        Circle().fill(Color(hex: it.colorHex)).frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(it.patient).font(.system(size: 13, weight: .semibold)).foregroundStyle(RX.ink).lineLimit(1).privacySensitive()
                            if family != .systemSmall { Text(it.dentist + " · " + it.what).font(.system(size: 11)).foregroundStyle(RX.ink3).lineLimit(1) }
                        }
                        Spacer(minLength: 0)
                    }
                }
                Spacer(minLength: 0)
            }
            .widgetURL(URL(string: "rayhan://reception"))
        }
    }
}

// MARK: - Waiting room

struct WaitingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "waiting", provider: RXProvider()) { e in WaitingView(e: e).rxWidgetBackground() }
            .configurationDisplayName("Waiting room")
            .description("How many patients are waiting and for how long.")
            .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

struct WaitingView: View {
    @Environment(\.widgetFamily) private var family
    let e: RXEntry
    var body: some View {
        if family == .accessoryCircular {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "sofa.fill").font(.system(size: 12))
                    Text("\(e.s.waiting)").font(.system(size: 20, weight: .bold))
                }
            }
            .widgetURL(URL(string: "rayhan://reception"))
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "sofa.fill").foregroundStyle(RX.mint).font(.system(size: 18))
                Spacer()
                Text("\(e.s.waiting)").font(.system(size: 40, weight: .bold)).foregroundStyle(RX.ink)
                Text(e.s.waiting == 1 ? "patient waiting" : "patients waiting").font(.system(size: 13, weight: .semibold)).foregroundStyle(RX.ink3)
                if let since = e.s.longestWaitSince {
                    HStack(spacing: 4) {
                        Text("Longest").font(.system(size: 11)).foregroundStyle(RX.ink4)
                        Text(since, style: .timer).font(.system(size: 12, weight: .bold)).monospacedDigit().foregroundStyle(RX.sand)
                    }
                }
                Button(intent: OpenRayhanIntent(screen: "walkin")) {
                    Label("Walk-in", systemImage: "plus").font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(.borderedProminent).tint(RX.mint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetURL(URL(string: "rayhan://reception"))
        }
    }
}

// MARK: - Lab work here

struct LabHereWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "labs", provider: RXProvider()) { e in
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "flask.fill").foregroundStyle(RX.tan)
                    Text("Lab work here").font(.system(size: 13, weight: .semibold)).foregroundStyle(RX.ink3)
                    Spacer()
                    Text("\(e.s.labHere)").font(.system(size: 16, weight: .bold)).foregroundStyle(RX.lilac)
                }
                ForEach(e.s.labHereItems, id: \.self) { t in Text(t).font(.system(size: 12, weight: .medium)).foregroundStyle(RX.ink).lineLimit(1).privacySensitive() }
                if e.s.labHereItems.isEmpty { Text("Nothing waiting to be checked").font(.system(size: 12)).foregroundStyle(RX.ink3) }
                Spacer(minLength: 0)
            }
            .widgetURL(URL(string: "rayhan://labs"))
            .rxWidgetBackground()
        }
        .configurationDisplayName("Lab work here")
        .description("Try-ins and finished work that arrived and need checking.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Live Activity (Dynamic Island + Lock Screen)

struct VisitLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: VisitAttributes.self) { ctx in
            HStack(spacing: 12) {
                ZStack { Circle().fill(RX.mintPale); Text(ctx.attributes.initials).font(.system(size: 15, weight: .bold)).foregroundStyle(RX.onMint) }.frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ctx.attributes.patient).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white).privacySensitive()
                    Text(ctx.state.stage == "room" ? "In \(ctx.state.room) · \(ctx.state.dentist)" : "Waiting in reception · for \(ctx.state.dentist)").font(.system(size: 13)).foregroundStyle(RX.ink3)
                }
                Spacer()
                Text(ctx.state.since, style: .timer).font(.system(size: 24, weight: .bold)).monospacedDigit().foregroundStyle(ctx.state.stage == "room" ? RX.lilac : RX.mintLight).frame(width: 90, alignment: .trailing)
            }
            .padding(16)
            .activityBackgroundTint(Color(rgb: 0x0A211D, 0.92))
            .activitySystemActionForegroundColor(RX.mint)
            .widgetURL(URL(string: "rayhan://reception"))
        } dynamicIsland: { ctx in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(ctx.state.stage == "room" ? ctx.state.room : "Waiting", systemImage: ctx.state.stage == "room" ? "door.left.hand.open" : "sofa.fill").font(.system(size: 13, weight: .semibold)).foregroundStyle(RX.mint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(ctx.state.since, style: .timer).font(.system(size: 20, weight: .bold)).monospacedDigit().foregroundStyle(RX.mintLight).frame(width: 80, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(ctx.attributes.patient).font(.system(size: 15, weight: .semibold)).privacySensitive()
                        Spacer()
                        Text(ctx.state.dentist).font(.system(size: 13)).foregroundStyle(RX.ink3)
                    }
                }
            } compactLeading: {
                Text(ctx.attributes.initials).font(.system(size: 12, weight: .bold)).foregroundStyle(RX.mint)
            } compactTrailing: {
                Text(ctx.state.since, style: .timer).monospacedDigit().font(.system(size: 13, weight: .semibold)).foregroundStyle(ctx.state.stage == "room" ? RX.lilac : RX.mintLight).frame(maxWidth: 52)
            } minimal: {
                Image(systemName: ctx.state.stage == "room" ? "door.left.hand.open" : "sofa.fill").foregroundStyle(RX.mint)
            }
            .widgetURL(URL(string: "rayhan://reception"))
            .keylineTint(RX.mint)
        }
    }
}

// MARK: - Control Center

struct WalkInControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.rayhanclinics.xray.walkin") {
            ControlWidgetButton(action: OpenRayhanIntent(screen: "walkin")) {
                Label("Walk-in", systemImage: "figure.walk")
            }
        }
        .displayName("Walk-in")
        .description("Check in a patient who walked in.")
    }
}

struct ReceptionControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.rayhanclinics.xray.reception") {
            ControlWidgetButton(action: OpenRayhanIntent(screen: "reception")) {
                Label("Reception", systemImage: "house")
            }
        }
        .displayName("Reception board")
        .description("Open the reception board.")
    }
}
