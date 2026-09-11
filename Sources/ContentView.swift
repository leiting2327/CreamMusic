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
                ZStack(alignment: .bottom) {
                    Group {
                        switch selectedTab {
                        case 0: HomeView()
                        case 1: SearchView()
                        case 2: MeView()
                        default: SettingsView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // 迷你播放器（液态玻璃）
                    if player.currentSong != nil {
                        MiniPlayerBar(showPlayer: $showPlayer)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 70)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .zIndex(10)
                    }
                }

                // 底部液态玻璃导航栏
                GlassTabBar(selected: $selectedTab)
            }
        }
        .fullScreenCover(isPresented: $showPlayer) {
            PlayerView()
                .environmentObject(theme)
                .environmentObject(player)
        }
    }
}

// ===== 迷你播放器（液态玻璃） =====
struct MiniPlayerBar: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var player: MusicPlayer
    @Binding var showPlayer: Bool
    @State private var isExpanding = false

    var body: some View {
        Button {
            isExpanding = true
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                showPlayer = true
            }
        } label: {
            HStack(spacing: 12) {
                // 封面
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.primaryColor.opacity(0.35))
                        .frame(width: 44, height: 44)
                    AsyncImage(url: URL(string: player.currentSong?.coverUrl ?? "")) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "music.note").foregroundColor(theme.primaryColor)
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(player.currentSong?.name ?? "")
                        .font(.subheadline).bold()
                        .foregroundColor(theme.textColor)
                        .lineLimit(1)
                    Text(player.currentSong?.artist ?? "")
                        .font(.caption)
                        .foregroundColor(theme.textSecondaryColor)
                        .lineLimit(1)
                }
                Spacer()

                // 控制
                Button { player.togglePlay() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(theme.textColor)
                        .frame(width: 36, height: 36)
                        .contentShape(Circle())
                }
                Button { player.next() } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.textColor)
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 8)
            .padding(.vertical, 8)
            .background {
                // 液态玻璃背景
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(theme.glassIntensity)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.5), .white.opacity(0.1)],
                                    startPoint: .top, endPoint: .bottom
                                ),
                                lineWidth: 0.8
                            )
                    }
            }
            .shadow(color: .black.opacity(0.15 * theme.glassIntensity), radius: 12, y: 5)
            .scaleEffect(showPlayer ? 0.96 : 1)
        }
        .buttonStyle(.plain)
    }
}

// ===== 底部液态玻璃导航栏 =====
struct GlassTabBar: View {
    @EnvironmentObject var theme: ThemeManager
    @Binding var selected: Int

    let items = [
        ("house.fill", "首页"),
        ("magnifyingglass", "搜索"),
        ("person.fill", "我的"),
        ("gearshape.fill", "设置")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<items.count, id: \.self) { i in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selected = i
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: items[i].0)
                            .font(.system(size: 19, weight: selected == i ? .semibold : .regular))
                            .scaleEffect(selected == i ? 1.12 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selected)
                        Text(items[i].1).font(.system(size: 10, weight: selected == i ? .semibold : .regular))
                    }
                    .foregroundColor(selected == i ? theme.primaryColor : theme.textSecondaryColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .padding(.bottom, 2)
        .background {
            // 液态玻璃背景
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(theme.glassIntensity + 0.2)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.5), .white.opacity(0.1)],
                                startPoint: .top, endPoint: .bottom
                            ),
                            lineWidth: 0.8
                        )
                }
                .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
