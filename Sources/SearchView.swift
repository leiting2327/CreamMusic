import SwiftUI

// 聚合搜索：一次搜三个平台，结果标注来源
struct SearchView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var player: MusicPlayer
    @State private var keyword = ""
    @State private var results: [Song] = []
    @State private var isLoading = false
    @State private var errorMsg: String?
    @State private var showPlayer = false

    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Text("搜索").font(.largeTitle).bold().foregroundColor(theme.textColor)
                Spacer()
            }
            .padding(.horizontal, 20).padding(.top, 20)

            // 搜索框
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(theme.textSecondaryColor)
                TextField("搜索歌曲、歌手（网易云/QQ/酷我）", text: $keyword)
                    .font(.subheadline)
                    .foregroundColor(theme.textColor)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { doSearch() }
                if !keyword.isEmpty {
                    Button {
                        keyword = ""
                        results = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(theme.textSecondaryColor)
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .opacity(theme.glassIntensity)
            }
            .padding(.horizontal, 20).padding(.top, 10)

            // 聚合提示
            HStack(spacing: 6) {
                Text("聚合搜索")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(theme.primaryColor).cornerRadius(4)
                Text("一次搜索 网易云 · QQ音乐 · 酷我音乐，结果已标注来源")
                    .font(.system(size: 10))
                    .foregroundColor(theme.textSecondaryColor)
                Spacer()
            }
            .padding(.horizontal, 20).padding(.top, 8)

            if isLoading {
                Spacer()
                ProgressView("搜索中…").tint(theme.primaryColor)
                Spacer()
            } else if let err = errorMsg {
                Spacer()
                Text(err).font(.caption).foregroundColor(.red)
                Spacer()
            } else {
                List(results) { song in
                    Button {
                        player.play(results, at: results.firstIndex(where: { $0.id == song.id }) ?? 0)
                        showPlayer = true
                    } label: {
                        SongRow(song: song)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(theme.textSecondaryColor.opacity(0.15))
                }
                .listStyle(.plain)
                .padding(.top, 4)
            }
        }
        .background(theme.bgColor.ignoresSafeArea())
        .fullScreenCover(isPresented: $showPlayer) {
            PlayerView().environmentObject(theme).environmentObject(player)
        }
    }

    private func doSearch() {
        let kw = keyword.trimmingCharacters(in: .whitespaces)
        guard !kw.isEmpty else { return }
        isLoading = true
        errorMsg = nil
        Task {
            do {
                let songs = try await MusicAPI.shared.searchAll(keyword: kw)
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

// 歌曲行（带封面预览 + 来源标注）
struct SongRow: View {
    @EnvironmentObject var theme: ThemeManager
    let song: Song

    var body: some View {
        HStack(spacing: 12) {
            // 封面预览
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.primaryColor.opacity(0.2))
                .frame(width: 46, height: 46)
                .overlay(
                    AsyncImage(url: URL(string: song.coverUrl)) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "music.note")
                            .foregroundColor(theme.primaryColor.opacity(0.6))
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(song.name).font(.subheadline).bold().foregroundColor(theme.textColor).lineLimit(1)
                    // VIP 标注
                    if song.isVip {
                        Text("VIP")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
                            .cornerRadius(3)
                    }
                }
                Text(song.artist).font(.caption).foregroundColor(theme.textSecondaryColor).lineLimit(1)
                // 专辑显示
                if !song.album.isEmpty {
                    Text("专辑：\(song.album)")
                        .font(.system(size: 9))
                        .foregroundColor(theme.textSecondaryColor.opacity(0.7))
                        .lineLimit(1)
                }
            }
            Spacer()

            // 来源标注（不切换平台，只标注）
            Text(song.sourceLabel)
                .font(.system(size: 9))
                .foregroundColor(theme.primaryColor)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(theme.primaryColor.opacity(0.15))
                .cornerRadius(4)

            Image(systemName: "play.circle")
                .foregroundColor(theme.textSecondaryColor)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
