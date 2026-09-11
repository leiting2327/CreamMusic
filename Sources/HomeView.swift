import SwiftUI

struct HomeView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var player: MusicPlayer

    let banners = ["每日推荐", "私人FM", "排行榜", "歌单"]
    let playlists = [
        ("🔥", "华语流行", "100万+"),
        ("💧", "治愈轻音乐", "50万+"),
        ("🌙", "深夜电台", "30万+"),
        ("⚡", "电子节拍", "80万+"),
        ("🎸", "摇滚经典", "60万+"),
        ("☕", "咖啡馆BGM", "40万+")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 标题
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("奶油音乐").font(.largeTitle).bold().foregroundColor(theme.textColor)
                        Text("发现好音乐").font(.subheadline).foregroundColor(theme.textSecondaryColor)
                    }
                    Spacer()
                }
                .padding(.top, 20)

                // 快捷入口
                LazyHGrid(rows: [GridItem(.flexible())], spacing: 16) {
                    ForEach(banners, id: \.self) { b in
                        VStack(spacing: 8) {
                            Circle()
                                .fill(theme.primaryColor.opacity(0.15))
                                .frame(width: 52, height: 52)
                                .overlay(Image(systemName: iconFor(b)).foregroundColor(theme.primaryColor))
                            Text(b).font(.caption2).foregroundColor(theme.textColor)
                        }
                    }
                }
                .frame(height: 90)

                // 推荐歌单
                Text("推荐歌单").font(.headline).foregroundColor(theme.textColor)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(playlists, id: \.1) { emoji, name, count in
                        VStack(alignment: .leading, spacing: 6) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LinearGradient(colors: [theme.primaryColor.opacity(0.6), theme.primaryColor.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(height: 100)
                                .overlay(Text(emoji).font(.largeTitle))
                            Text(name).font(.caption).bold().foregroundColor(theme.textColor).lineLimit(1)
                            Text("\(count) 播放").font(.system(size: 10)).foregroundColor(theme.textSecondaryColor)
                        }
                    }
                }

                // 正在播放
                if player.currentSong != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("正在播放").font(.headline).foregroundColor(theme.textColor)
                        HStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(theme.primaryColor.opacity(0.3))
                                .frame(width: 50, height: 50)
                                .overlay(Image(systemName: "music.note").foregroundColor(theme.primaryColor))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(player.currentSong?.name ?? "").font(.subheadline).bold().foregroundColor(theme.textColor).lineLimit(1)
                                Text(player.currentSong?.artist ?? "").font(.caption).foregroundColor(theme.textSecondaryColor)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .glassCard()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private func iconFor(_ name: String) -> String {
        switch name {
        case "每日推荐": return "calendar"
        case "私人FM": return "radio"
        case "排行榜": return "chart.bar"
        case "歌单": return "list.bullet"
        default: return "music.note"
        }
    }
}
