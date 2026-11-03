import AppIntents

struct RayhanShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OpenRayhanIntent(screen: "reception"), phrases: ["Who's waiting in \(.applicationName)", "Open the reception board in \(.applicationName)"], shortTitle: "Reception", systemImageName: "sofa")
        AppShortcut(intent: OpenRayhanIntent(screen: "walkin"), phrases: ["Walk-in in \(.applicationName)", "New walk-in in \(.applicationName)"], shortTitle: "Walk-in", systemImageName: "figure.walk")
        AppShortcut(intent: OpenRayhanIntent(screen: "labs"), phrases: ["Show lab work in \(.applicationName)"], shortTitle: "Lab work", systemImageName: "flask")
    }
}
