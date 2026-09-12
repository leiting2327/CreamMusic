import SwiftUI

// 设置：免费模式开关 + 内存管理 + 音质升级/降级 + 主题
struct SettingsView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var player: MusicPlayer
    @State private var freeMode = false
    @State private var showFreeModeAlert = false
    @State private var showDownloadList = false
    @State private var cacheCleared = false
    @State private var clearingCache = false
    @ObservedObject private var local = LocalAudioManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("设置").font(.largeTitle).bold().foregroundColor(theme.textColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 20)

                // ===== 一键全歌曲免费模式 =====
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Toggle(isOn: $freeMode) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("一键全歌曲免费模式").font(.subheadline).bold().foregroundColor(theme.textColor)
                                Text("免费播放全歌曲 · 收藏歌单 · 下载音乐")
                                    .font(.system(size: 10)).foregroundColor(theme.textSecondaryColor)
                            }
                        }
                        .tint(theme.primaryColor)
                        .onChange(of: freeMode) { value in
                            if value { showFreeModeAlert = true }
                        }
                    }
                    Text("⚠️ 打开后将无法使用账号功能（登录/歌单/会员权益）")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(8)
                }
                .padding(16)
                .background {
                    RoundedRectangle(cornerRadius: 18).fill(.ultraThinMaterial).opacity(theme.glassIntensity)
                }
                .alert("开启免费模式", isPresented: $showFreeModeAlert) {
                    Button("开启", role: .destructive) {
                        freeMode = true
                        // 清空账号状态
                        UserDefaults.standard.set(true, forKey: "freeMode")
                    }
                    Button("取消", role: .cancel) { freeMode = false }
                } message: {
                    Text("开启后将无法使用账号功能，但可以免费播放全歌曲、收藏歌单、下载音乐。确定开启？")
                }

                // ===== 本地音乐 / 内存管理 =====
                VStack(alignment: .leading, spacing: 12) {
                    Text("本地音乐").font(.headline).foregroundColor(theme.textColor)

                    // 已占内存
                    HStack {
                        Image(systemName: "internaldrive")
                            .foregroundColor(theme.primaryColor)
                        Text("已占用内存")
                            .font(.subheadline).foregroundColor(theme.textColor)
                        Spacer()
                        Text(local.totalSizeString)
                            .font(.subheadline).bold().foregroundColor(theme.primaryColor)
                    }
                    .padding(14)
                    .background(theme.primaryColor.opacity(0.1))
                    .cornerRadius(12)

                    // 管理按钮
                    HStack(spacing: 10) {
                        Button { showDownloadList = true } label: {
                            Label("管理歌曲", systemImage: "music.note.list")
                                .font(.caption).bold()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(theme.primaryColor)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)

                        Button {
                            clearingCache = true
                            Task {
                                let freed = local.clearCache()
                                await MainActor.run {
                                    cacheCleared = true
                                    clearingCache = false
                                }
                            }
                        } label: {
                            Label(clearingCache ? "清理中…" : "清理缓存", systemImage: "trash")
                                .font(.caption).bold()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(theme.primaryColor.opacity(0.15))
                                .foregroundColor(theme.primaryColor)
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }

                    if cacheCleared {
                        Text("缓存已清理 ✓").font(.caption).foregroundColor(.green)
                    }
                }
                .padding(16)
                .background {
                    RoundedRectangle(cornerRadius: 18).fill(.ultraThinMaterial).opacity(theme.glassIntensity)
                }

                // ===== 主题 =====
                VStack(alignment: .leading, spacing: 12) {
                    Text("外观").font(.headline).foregroundColor(theme.textColor)
                    Picker("风格", selection: $theme.theme) {
                        Text("奶油风").tag(ThemeManager.Theme.cream)
                        Text("WinUI").tag(ThemeManager.Theme.winui)
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("液态玻璃强度: \(Int(theme.glassIntensity * 100))%")
                            .font(.caption).foregroundColor(theme.textSecondaryColor)
                        Slider(value: $theme.glassIntensity, in: 0.1...1.0)
                            .tint(theme.primaryColor)
                    }
                }
                .padding(16)
                .background {
                    RoundedRectangle(cornerRadius: 18).fill(.ultraThinMaterial).opacity(theme.glassIntensity)
                }

                // ===== 关于 =====
                VStack(alignment: .leading, spacing: 8) {
                    Text("关于").font(.headline).foregroundColor(theme.textColor)
                    Text("奶油音乐 v3.0")
                        .font(.caption).foregroundColor(theme.textSecondaryColor)
                    Text("支持：网易云 / QQ音乐 / 酷我音乐 · 聚合搜索 · 本地下载 · 免费模式")
                        .font(.system(size: 10)).foregroundColor(theme.textSecondaryColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background {
                    RoundedRectangle(cornerRadius: 18).fill(.ultraThinMaterial).opacity(theme.glassIntensity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .background(theme.bgColor.ignoresSafeArea())
        .sheet(isPresented: $showDownloadList) {
            LocalMusicListView()
                .environmentObject(theme)
                .environmentObject(player)
                .presentationDetents([.large])
        }
    }
}

// 本地音乐管理：删除 / 升级降级音质
struct LocalMusicListView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var player: MusicPlayer
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var local = LocalAudioManager.shared
    @State private var operatingId: String?

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("本地歌曲").font(.headline).foregroundColor(theme.textColor)
                Spacer()
                Text("共 \(local.localSongs.count) 首 · \(local.totalSizeString)")
                    .font(.caption).foregroundColor(theme.textSecondaryColor)
            }
            .padding(.horizontal, 20).padding(.top, 16)

            if local.localSongs.isEmpty {
                Spacer()
                Text("还没有下载的歌曲\n在播放页点下载按钮即可下载")
                    .font(.caption).foregroundColor(theme.textSecondaryColor)
                    .multilineTextAlignment(.center)
                Spacer()
            } else {
                List {
                    ForEach(local.localSongs) { ls in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(theme.primaryColor.opacity(0.2))
                                    .frame(width: 42, height: 42)
                                    .overlay(AsyncImage(url: URL(string: ls.song.coverUrl)) { img in
                                        img.resizable().scaledToFill()
                                    } placeholder: {
                                        Image(systemName: "music.note").foregroundColor(theme.primaryColor)
                                    })
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ls.song.name).font(.subheadline).bold().foregroundColor(theme.textColor).lineLimit(1)
                                    Text("\(ls.song.artist) · \(ls.quality.rawValue)")
                                        .font(.caption).foregroundColor(theme.textSecondaryColor)
                                }
                                Spacer()
                                // 本地播放
                                Button {
                                    player.playLocal(fileURL: local.fileURL(for: ls.fileName), song: ls.song)
                                } label: {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 22)).foregroundColor(theme.primaryColor)
                                }
                            }

                            HStack {
                                Text("占用 \(local.sizeString(of: ls))")
                                    .font(.system(size: 10)).foregroundColor(theme.textSecondaryColor)
                                Spacer()
                                // 音质升降级
                                Menu {
                                    ForEach(AudioQuality.allCases) { q in
                                        if q != ls.quality {
                                            Button("\(q.rawValue)（\(q.sizeEstimate(durationSec: ls.song.duration))）") {
                                                upgrade(ls, to: q)
                                            }
                                        }
                                    }
                                } label: {
                                    Text("切换音质")
                                        .font(.system(size: 10)).foregroundColor(theme.primaryColor)
                                }
                                Button(role: .destructive) {
                                    local.delete(ls)
                                } label: {
                                    Text("删除")
                                        .font(.system(size: 10)).foregroundColor(.red)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { idxs in
                        for i in idxs {
                            local.delete(local.localSongs[i])
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(theme.bgColor)
    }

    private func upgrade(_ ls: LocalSong, to q: AudioQuality) {
        operatingId = ls.id
        Task {
            do {
                let _ = try await local.reDownload(ls, to: q)
                await MainActor.run { operatingId = nil }
            } catch {
                await MainActor.run { operatingId = nil }
            }
        }
    }
}
