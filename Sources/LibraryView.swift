import SwiftUI

// P4 音乐库：本地下载 + 我喜欢的音乐
struct LibraryView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var player: MusicPlayer
    @EnvironmentObject var local: LocalAudioManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 标题
                Text("音乐库")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(theme.textColor)
                    .padding(.top, 6)
                Text("我的歌单 · 本地下载")
                    .font(.system(size: 11))
                    .foregroundColor(theme.textSecondaryColor)
                    .padding(.top, 2)
                    .padding(.bottom, 14)

                // 我的歌单
                HStack {
                    Text("🎧 我的歌单").font(.system(size: 15, weight: .bold)).foregroundColor(theme.textColor)
                    Spacer()
                    Text("新建").font(.system(size: 12)).foregroundColor(theme.primaryColor)
                }
                .padding(.bottom, 8)

                // 本地下载卡片
                Button {
                    // 展示下载列表
                } label: {
                    libraryCard(icon: "⬇️", iconBg: theme.primaryColor.opacity(0.15),
                                title: "本地下载",
                                sub: "\(local.localSongs.count)首",
                                accent: theme.primaryColor)
                }
                .buttonStyle(.plain)

                // 我喜欢的音乐
                Button {
                    // 登录后同步
                } label: {
                    libraryCard(icon: "❤️", iconBg: Color.pink.opacity(0.15),
                                title: "我喜欢的音乐",
                                sub: userNick() + " 的歌单",
                                accent: Color.pink)
                }
                .buttonStyle(.plain)

                // 下载列表
                Text("⬇️ 下载列表")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.textColor)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                if local.localSongs.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 34))
                            .foregroundColor(theme.textSecondaryColor.opacity(0.6))
                        Text("暂无下载歌曲")
                            .font(.system(size: 14))
                            .foregroundColor(theme.textSecondaryColor)
                        Text("在播放页点 ⬇️ 下载音乐")
                            .font(.system(size: 11))
                            .foregroundColor(theme.textSecondaryColor.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    ForEach(local.localSongs) { ls in
                        Button {
                            player.playLocal(fileURL: local.fileURL(for: ls.fileName), song: ls.song)
                        } label: {
                            HStack(spacing: 12) {
                                AsyncImage(url: URL(string: ls.song.coverUrl ?? "")) { img in
                                    img.resizable().scaledToFill()
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 6).fill(theme.primaryColor.opacity(0.3))
                                }
                                .frame(width: 42, height: 42)
                                .clipShape(RoundedRectangle(cornerRadius: 6))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(ls.song.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(theme.textColor)
                                        .lineLimit(1)
                                    Text("\(ls.song.artist) · \(ls.quality.rawValue)")
                                        .font(.system(size: 11))
                                        .foregroundColor(theme.textSecondaryColor)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text(local.sizeString(of: ls))
                                    .font(.system(size: 10))
                                    .foregroundColor(theme.textSecondaryColor)
                            }
                            .padding(.vertical, 7)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .background(theme.bgColor.ignoresSafeArea())
        .onAppear { local.loadForUI() }
    }

    private func libraryCard(icon: String, iconBg: Color, title: String, sub: String, accent: Color) -> some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.system(size: 20))
                .frame(width: 44, height: 44)
                .background(iconBg)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .bold)).foregroundColor(theme.textColor)
                Text(sub).font(.system(size: 11)).foregroundColor(theme.textSecondaryColor)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondaryColor.opacity(0.6))
        }
        .padding(12)
        .background(theme.cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.bottom, 10)
    }

    private func userNick() -> String {
        let json = UserDefaults.standard.string(forKey: "user_json") ?? ""
        if let data = json.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let nick = obj["nickname"] as? String {
            return nick
        }
        return "未登录"
    }
}

extension LocalAudioManager {
    func loadForUI() {
        loadIndex()
    }
}
