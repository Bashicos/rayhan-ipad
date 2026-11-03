import AppIntents
import Foundation

/// Opens a screen of the app (used by widgets, Control Center and Shortcuts).
struct OpenRayhanIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Rayhan"
    static let description = IntentDescription("Opens a screen of Rayhan X-Ray.")

    @Parameter(title: "Screen", default: "reception")
    var screen: String

    init() {}
    init(screen: String) { self.screen = screen }

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(URL(string: "rayhan://\(screen)")!))
    }
}
