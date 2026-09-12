import SwiftUI

// P2 推荐首页：每日推荐 / 私人漫游 / 排行榜(飙升榜·新歌榜·原创榜) / 推荐歌单
struct HomeView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var player: MusicPlayer
    @State private var searchedKeyword: String?
    @State private var showSearchSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 推荐 + 长按切换平台
                HStack(alignment: .bottom) {
                    Text("推荐")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(theme.textColor)
                    Text("  长按这里可切换平台")
                        .font(.system(size: 11))
                        .foregroundColor(theme.textSecondaryColor)
                        .padding(.bottom, 5)
                    Spacer()
                }
                .padding(.top, 6)
                .padding(.bottom, 14)

                // 每日推荐 + 私人漫游
                HStack(spacing: 10) {
                    homeCard(emoji: "🎧", name: "每日推荐", sub: "32首 · 每天6:00更新",
                             bg: LinearGradient(colors: [Color(.systemGray6), Color(.systemGray5)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .onTapGesture { searchAndPlay("热门歌曲 2026") }
                    homeCard(emoji: "📻", name: "私人漫游", sub: "从喜欢的歌开始漫游",
                             bg: LinearGradient(colors: [Color.purple.opacity(0.25), Color.purple.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .onTapGesture { searchAndPlay("抖音热歌 2026") }
                }
                .frame(height: 92)
                .padding(.bottom, 18)

                // 排行榜
                Text("排行榜")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(theme.textColor)
                    .padding(.bottom, 10)

                HStack(spacing: 8) {
                    rankBox(emoji: "🔥", name: "飙升榜", sub: "今日飙升", bg: Color(red: 1.0, green: 0.91, blue: 0.91))
                        .onTapGesture { searchAndPlay("飙升榜 歌曲") }
                    rankBox(emoji: "🎵", name: "新歌榜", sub: "最新发行", bg: Color(red: 0.92, green: 0.96, blue: 1.0))
                        .onTapGesture { searchAndPlay("新歌榜 歌曲") }
                    rankBox(emoji: "🎤", name: "原创榜", sub: "原创力量", bg: Color(red: 1.0, green: 0.97, blue: 0.88))
                        .onTapGesture { searchAndPlay("原创榜 歌曲") }
                }
                .padding(.bottom, 18)

                // 推荐歌单
                Text("推荐歌单")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(theme.textColor)
                    .padding(.bottom, 10)

                let playlists = [
                    ("🎶", "华语流行", "周杰伦 · 林俊杰 · 陈奕迅", "华语流行 歌曲"),
                    ("🌙", "深夜emo", "薛之谦 · 毛不易 · 李荣浩", "薛之谦 歌曲"),
                    ("⚡", "电音热浪", "抖音热歌 · 电音 · Remix", "电音 歌曲")
                ]
                HStack(spacing: 8) {
                    ForEach(playlists, id: \.0) { emoji, name, desc, kw in
                        Button {
                            searchedKeyword = kw
                            showSearchSheet = true
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(emoji).font(.system(size: 26))
                                Text(name).font(.system(size: 12, weight: .bold)).foregroundColor(theme.textColor)
                                Text(desc).font(.system(size: 9)).foregroundColor(theme.textSecondaryColor)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(cardBg(emoji))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text("长按顶部「推荐」可切换默认平台")
                    .font(.system(size: 10))
                    .foregroundColor(theme.textSecondaryColor.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 22)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
        .background(theme.bgColor.ignoresSafeArea())
        .sheet(isPresented: $showSearchSheet) {
            QuickSearchSheet(keyword: searchedKeyword ?? "周杰伦")
                .environmentObject(theme)
                .environmentObject(player)
                .presentationDetents([.large])
        }
    }

    private func homeCard(emoji: String, name: String, sub: String, bg: LinearGradient) -> some View {
        VStack(spacing: 4) {
            Text(emoji).font(.system(size: 24))
            Text(name).font(.system(size: 14, weight: .bold)).foregroundColor(theme.textColor)
            Text(sub).font(.system(size: 10)).foregroundColor(theme.textSecondaryColor).lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func rankBox(emoji: String, name: String, sub: String, bg: Color) -> some View {
        VStack(spacing: 3) {
            Text(emoji).font(.system(size: 20))
            Text(name).font(.system(size: 12, weight: .bold)).foregroundColor(theme.textColor)
            Text(sub).font(.system(size: 9)).foregroundColor(theme.textSecondaryColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func cardBg(_ emoji: String) -> Color {
        switch emoji {
        case "🎶": return Color(red: 0.99, green: 0.95, blue: 0.89)
        case "🌙": return Color(red: 0.92, green: 0.94, blue: 0.99)
        default: return Color(red: 0.95, green: 0.92, blue: 0.99)
        }
    }

    private func searchAndPlay(_ kw: String) {
        searchedKeyword = kw
        showSearchSheet = true
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
                            Text(song.sourceLabel).font(.system(size: 9))
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
                let songs = try await MusicAPI.shared.searchAll(keyword: keyword)
                results = songs
            } catch {
                errorMsg = "搜索失败: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}
