import SwiftUI

struct SearchView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var player: MusicPlayer
    @State private var keyword = ""
    @State private var source = "netease"
    @State private var results: [Song] = []
    @State private var isLoading = false
    @State private var errorMsg = ""

    let sources = [("netease", "网易云"), ("tencent", "QQ音乐"), ("kugou", "酷狗")]

    var body: some View {
        VStack(spacing: 12) {
            // 搜索栏
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(theme.textSecondaryColor)
                TextField("搜索歌曲、歌手、专辑", text: $keyword, onCommit: doSearch)
                    .textFieldStyle(.plain)
                    .foregroundColor(theme.textColor)
                Button("搜索") { doSearch() }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16).padding(.vertical, 6)
                    .background(theme.primaryColor)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .glassCard()
            .padding(.horizontal, 16)

            // 音源切换
            HStack(spacing: 8) {
                ForEach(sources, id: \.0) { s in
                    Button(s.1) {
                        source = s.0
                        if !keyword.isEmpty { doSearch() }
                    }
                    .font(.caption)
                    .foregroundColor(source == s.0 ? .white : theme.textSecondaryColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(source == s.0 ? theme.primaryColor : theme.cardColor)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 16)

            if isLoading {
                ProgressView().padding(.top, 40)
            } else if !errorMsg.isEmpty {
                Text(errorMsg).font(.caption).foregroundColor(.red).padding(.top, 40)
            } else if results.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "music.magnifyingglass").font(.largeTitle).foregroundColor(theme.textSecondaryColor)
                    Text("输入关键词开始搜索\n支持网易云 / QQ音乐 / 酷狗")
                        .font(.caption).foregroundColor(theme.textSecondaryColor)
                        .multilineTextAlignment(.center)
                }.padding(.top, 60)
            } else {
                List(results) { song in
                    Button {
                        player.play(results, at: results.firstIndex(where: { $0.id == song.id }) ?? 0)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(song.name).font(.subheadline).foregroundColor(theme.textColor).lineLimit(1)
                                Text(song.artist).font(.caption).foregroundColor(theme.textSecondaryColor).lineLimit(1)
                            }
                            Spacer()
                            Text(sourceLabel(song.source)).font(.system(size: 9))
                                .foregroundColor(theme.primaryColor)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(theme.primaryColor.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }
                }
                .listStyle(.plain)
            }
            Spacer()
        }
        .padding(.top, 16)
    }

    private func sourceLabel(_ s: String) -> String {
        s == "netease" ? "网易" : (s == "tencent" ? "QQ" : "酷狗")
    }

    private func doSearch() {
        guard !keyword.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isLoading = true
        errorMsg = ""
        Task {
            do {
                let songs = try await MusicAPI.shared.search(source: source, keyword: keyword)
                await MainActor.run {
                    results = songs
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMsg = "搜索失败: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}
