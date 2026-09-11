import SwiftUI

struct HomeView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var player: MusicPlayer

    let quickActions = ["每日推荐", "私人FM", "排行榜", "歌单"]
    let playlists = [
        ("🔥", "华语流行", "100万+", "华语"),
        ("💧", "治愈轻音乐", "50万+", "轻音乐"),
        ("🌙", "深夜电台", "30万+", "电台"),
        ("⚡", "电子节拍", "80万+", "电子"),
        ("🎸", "摇滚经典", "60万+", "摇滚"),
        ("☕", "咖啡馆BGM", "40万+", "咖啡")
    ]
    @State private var searchedKeyword: String?
    @State private var showSearchSheet = false

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
                    Button {
                        searchedKeyword = "周杰伦"
                        showSearchSheet = true
                    } label: {
                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(theme.primaryColor)
                            .frame(width: 40, height: 40)
                            .background(theme.primaryColor.opacity(0.12))
                            .clipShape(Circle())
                    }
                }
                .padding(.top, 20)

                // 快捷入口（可点击 → 直接搜索）
                LazyHGrid(rows: [GridItem(.flexible())], spacing: 16) {
                    ForEach(quickActions, id: \.self) { b in
                        Button {
                            searchedKeyword = keywordFor(b)
                            showSearchSheet = true
                        } label: {
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(theme.primaryColor.opacity(0.15))
                                    .frame(width: 52, height: 52)
                                    .overlay(Image(systemName: iconFor(b)).foregroundColor(theme.primaryColor))
                                Text(b).font(.caption2).foregroundColor(theme.textColor)
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(height: 92)

                // 推荐歌单（可点击 → 搜索该类型）
                Text("推荐歌单").font(.headline).foregroundColor(theme.textColor)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(playlists, id: \.1) { emoji, name, count, kw in
                        Button {
                            searchedKeyword = kw
                            showSearchSheet = true
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(LinearGradient(colors: [theme.primaryColor.opacity(0.6), theme.primaryColor.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(height: 100)
                                    .overlay(Text(emoji).font(.largeTitle))
                                Text(name).font(.caption).bold().foregroundColor(theme.textColor).lineLimit(1)
                                Text("\(count) 播放").font(.system(size: 10)).foregroundColor(theme.textSecondaryColor)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
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
                                .overlay(AsyncImage(url: URL(string: player.currentSong?.coverUrl ?? "")) { img in
                                    img.resizable().scaledToFill()
                                } placeholder: {
                                    Image(systemName: "music.note").foregroundColor(theme.primaryColor)
                                })
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(player.currentSong?.name ?? "").font(.subheadline).bold().foregroundColor(theme.textColor).lineLimit(1)
                                Text(player.currentSong?.artist ?? "").font(.caption).foregroundColor(theme.textSecondaryColor)
                            }
                            Spacer()
                            Button { player.togglePlay() } label: {
                                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                    .foregroundColor(theme.primaryColor)
                            }
                        }
                        .padding(14)
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .opacity(theme.glassIntensity)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .sheet(isPresented: $showSearchSheet) {
            QuickSearchSheet(keyword: searchedKeyword ?? "周杰伦")
                .environmentObject(theme)
                .environmentObject(player)
                .presentationDetents([.large])
        }
    }

    private func keywordFor(_ action: String) -> String {
        switch action {
        case "每日推荐": return "热门"
        case "私人FM": return "随机"
        case "排行榜": return "排行榜"
        case "歌单": return "精选歌单"
        default: return "周杰伦"
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

// 快捷搜索页
struct QuickSearchSheet: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var player: MusicPlayer
    @Environment(\.dismiss) var dismiss
    let keyword: String
    @State private var results: [Song] = []
    @State private var isLoading = true
    @State private var errorMsg = ""

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("「\(keyword)」相关歌曲").font(.headline).foregroundColor(theme.textColor)
                Spacer()
                Button("关闭") { dismiss() }.font(.subheadline).foregroundColor(theme.primaryColor)
            }
            .padding(.horizontal, 20).padding(.top, 16)

            if isLoading {
                ProgressView().padding(.top, 60)
            } else if !errorMsg.isEmpty {
                Text(errorMsg).font(.caption).foregroundColor(.red).padding(.top, 40)
            } else if results.isEmpty {
                Text("没有找到相关歌曲").font(.caption).foregroundColor(theme.textSecondaryColor).padding(.top, 40)
            } else {
                List(results) { song in
                    Button {
                        player.play(results, at: results.firstIndex(where: { $0.id == song.id }) ?? 0)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(song.name).font(.subheadline).foregroundColor(theme.textColor).lineLimit(1)
                                Text(song.artist).font(.caption).foregroundColor(theme.textSecondaryColor).lineLimit(1)
                            }
                            Spacer()
                            Text("网易云").font(.system(size: 9))
                                .foregroundColor(theme.primaryColor)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(theme.primaryColor.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .task {
            do {
                let songs = try await MusicAPI.shared.search(source: "netease", keyword: keyword)
                results = songs
            } catch {
                errorMsg = "搜索失败: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}
