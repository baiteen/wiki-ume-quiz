import SwiftUI
import SwiftData

@main
struct WikiUmeQuizApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [PlayHistory.self])
    }
}
