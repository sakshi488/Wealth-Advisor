import SwiftUI
import SwiftData

@main
struct WealthAdvisorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // This injects the database into your whole app
        .modelContainer(for: [Asset.self, PortfolioSnapshot.self])
    }
}
