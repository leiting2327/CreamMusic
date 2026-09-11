import SwiftUI

struct ContentView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var player: MusicPlayer
    @State private var selectedTab = 0
    @State private var showPlayer = false

    var body: some View {
        ZStack {
            theme.bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $selectedTab) {
                    HomeView().tag(0)
                    SearchView().tag(1)
                    MeView().tag(2)
                    SettingsView().tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // 迷你播放器
                if player.currentSong != nil {
                    MiniPlayerView()
                        .onTapGesture { showPlayer = true }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 4)
                }

                // 底部导航
                BottomNavView(selected: $selectedTab)
            }
        }
        .fullScreenCover(isPresented: $showPlayer) {
            PlayerView()
                .environmentObject(theme)
                .environmentObject(player)
        }
    }
}

struct MiniPlayerView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var player: MusicPlayer

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.primaryColor.opacity(0.3))
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: "music.note").foregroundColor(theme.primaryColor))

            VStack(alignment: .leading, spacing: 2) {
                Text(player.currentSong?.name ?? "")
                    .font(.caption).bold()
                    .foregroundColor(theme.textColor)
                    .lineLimit(1)
                Text(player.currentSong?.artist ?? "")
                    .font(.system(size: 10))
                    .foregroundColor(theme.textSecondaryColor)
                    .lineLimit(1)
            }
            Spacer()
            Button { player.togglePlay() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .foregroundColor(theme.primaryColor)
            }
            Button { player.next() } label: {
                Image(systemName: "forward.fill")
                    .foregroundColor(theme.primaryColor)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassCard()
    }
}

struct BottomNavView: View {
    @EnvironmentObject var theme: ThemeManager
    @Binding var selected: Int

    let items = [
        ("house.fill", "首页"),
        ("magnifyingglass", "搜索"),
        ("person.fill", "我的"),
        ("gearshape.fill", "设置")
    ]

    var body: some View {
        HStack {
            ForEach(0..<4, id: \.self) { i in
                Button { selected = i } label: {
                    VStack(spacing: 3) {
                        Image(systemName: items[i].0)
                            .font(.system(size: 18))
                        Text(items[i].1).font(.system(size: 10))
                    }
                    .foregroundColor(selected == i ? theme.primaryColor : theme.textSecondaryColor)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 10)
        .background(theme.cardColor)
    }
}
