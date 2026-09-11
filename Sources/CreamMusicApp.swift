import SwiftUI

@main
struct CreamMusicApp: App {
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var player = MusicPlayer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .environmentObject(player)
        }
    }
}
