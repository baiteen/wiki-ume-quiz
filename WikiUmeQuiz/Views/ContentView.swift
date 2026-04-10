import SwiftUI
import SwiftData

/// アプリのルート View
///
/// Phase 5 以降はホーム画面をルートとする。
struct ContentView: View {
    var body: some View {
        HomeView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: PlayHistory.self, inMemory: true)
}
