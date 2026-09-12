import SwiftUI
import AVKit
import MediaPlayer

// 网易云风格全屏播放器（参考用户参考图）
struct PlayerView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var player: MusicPlayer
    @Environment(\.dismiss) var dismiss
    @State private var isDragging = false
    @State private var showLyrics = true
    @State private var lyricText = "歌词加载中…"
    @State private var showDownloadSheet = false
    @State private var showCloseConfirm = false
    @State private var downloadError: String?

    var body: some View {
        ZStack {
            // 封面模糊背景
            coverBackground.ignoresSafeArea()

            // 毛玻璃叠加
            Rectangle().fill(.ultraThinMaterial).opacity(theme.glassIntensity * 0.55).ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部拖动条 + 关闭按钮（可关掉播放器）
                HStack(spacing: 12) {
                    Button {
                        showCloseConfirm = true
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(theme.textColor)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .confirmationDialog("关闭播放器？", isPresented: $showCloseConfirm, titleVisibility: .visible) {
                        Button("停止播放并关闭", role: .destructive) {
                            player.stop()
                            dismiss()
                        }
                        Button("保留歌曲，仅关闭页面") { dismiss() }
                        Button("取消", role: .cancel) {}
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text("正在播放").font(.caption).foregroundColor(theme.textSecondaryColor)
                        Text(player.currentSong?.album ?? "").font(.subheadline).bold().foregroundColor(theme.textColor).lineLimit(1)
                    }
                    Spacer()
                    Button {} label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(theme.textColor)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                // 播放错误提示
                if let err = player.playError {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.red.opacity(0.75))
                        .cornerRadius(12)
                        .padding(.top, 4)
                }

                ScrollView {
                    VStack(spacing: 18) {
                        // 封面
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [theme.primaryColor.opacity(0.55), theme.primaryColor.opacity(0.25)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    AsyncImage(url: URL(string: player.currentSong?.coverUrl ?? "")) { img in
                                        img.resizable().scaledToFill()
                                    } placeholder: {
                                        Image(systemName: "music.note").font(.system(size: 80)).foregroundColor(.white.opacity(0.85))
                                    }
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: theme.primaryColor.opacity(0.35), radius: 30, y: 12)
                        }
                        .frame(width: 290, height: 290)
                        .rotation3DEffect(.degrees(isDragging ? 3 : 0), axis: (x: 0, y: 1, z: 0))

                        // 歌名/歌手/专辑
                        VStack(spacing: 5) {
                            HStack(spacing: 8) {
                                Text(player.currentSong?.name ?? "")
                                    .font(.title2).bold()
                                    .foregroundColor(theme.textColor)
                                    .lineLimit(1)
                                // 来源标注
                                Text(player.currentSong?.sourceLabel ?? "")
                                    .font(.system(size: 9))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(theme.primaryColor)
                                    .cornerRadius(4)
                                Spacer()
                                // 下载按钮
                                Button {
                                    showDownloadSheet = true
                                } label: {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.system(size: 22))
                                        .foregroundColor(theme.primaryColor)
                                }
                                Button {} label: {
                                    Image(systemName: "heart")
                                        .font(.system(size: 22))
                                        .foregroundColor(theme.textSecondaryColor)
                                }
                            }
                            Text("\(player.currentSong?.artist ?? "") · \(player.currentSong?.album ?? "")")
                                .font(.subheadline)
                                .foregroundColor(theme.textSecondaryColor)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 24)

                        // 歌词（网易云风格，滚动区）
                        if showLyrics, let song = player.currentSong {
                            ScrollViewReader { proxy in
                                ScrollView {
                                    Text(lyricText)
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundColor(theme.textSecondaryColor)
                                        .lineSpacing(8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 10)
                                }
                                .frame(height: 110)
                            }
                        }
                    }
                    .padding(.top, 6)
                }

                Spacer(minLength: 0)

                // 进度条
                VStack(spacing: 4) {
                    Slider(
                        value: Binding(
                            get: { player.progress },
                            set: { newVal in isDragging = true; player.progress = newVal }
                        ),
                        in: 0...1,
                        onEditingChanged: { editing in
                            isDragging = editing
                            if !editing { player.seek(to: player.progress) }
                        }
                    )
                    .tint(theme.primaryColor)

                    HStack {
                        Text(formatTime(player.progress * (player.player?.currentItem?.duration.seconds ?? 0)))
                        Spacer()
                        Text(formatTime(player.player?.currentItem?.duration.seconds ?? 0))
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textSecondaryColor)
                }
                .padding(.horizontal, 24)

                // 控制按钮（参考图：上一首/播放/下一首）
                HStack(spacing: 42) {
                    Button { player.prev() } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(theme.textColor)
                    }
                    Button { player.togglePlay() } label: {
                        ZStack {
                            Circle().fill(theme.textColor).frame(width: 62, height: 62)
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 25, weight: .semibold))
                                .foregroundColor(theme.bgColor)
                                .offset(x: player.isPlaying ? 0 : 2)
                        }
                    }
                    Button { player.next() } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(theme.textColor)
                    }
                }
                .padding(.top, 12)

                // 底部工具条：评论/循环/歌单/音量/AirPlay
                HStack(spacing: 24) {
                    Button {} label: {
                        Image(systemName: "bubble.left").font(.system(size: 15)).foregroundColor(theme.textSecondaryColor)
                    }
                    Button {} label: {
                        Image(systemName: "repeat").font(.system(size: 15)).foregroundColor(theme.textSecondaryColor)
                    }
                    Button {} label: {
                        Image(systemName: "list.bullet").font(.system(size: 15)).foregroundColor(theme.textSecondaryColor)
                    }
                    Spacer()
                    Button {
                        withAnimation { showLyrics.toggle() }
                    } label: {
                        Image(systemName: "text.quote")
                            .font(.system(size: 15))
                            .foregroundColor(showLyrics ? theme.primaryColor : theme.textSecondaryColor)
                    }
                    AirPlayButton(tintColor: UIColor(theme.primaryColor)).frame(width: 22, height: 22)
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 14)
                .padding(.bottom, 6)
            }
        }
        .onAppear {
            loadLyric()
            setupAudioRouteMonitoring()
        }
        .onDisappear { player.stopLiveActivity() }
        .sheet(isPresented: $showDownloadSheet) {
            if let song = player.currentSong {
                DownloadSheet(song: song)
                    .presentationDetents([.medium])
            }
        }
    }

    private var coverBackground: some View {
        ZStack {
            AsyncImage(url: URL(string: player.currentSong?.coverUrl ?? "")) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                LinearGradient(
                    colors: [theme.primaryColor.opacity(0.5), theme.primaryColor.opacity(0.2)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            }
            Rectangle().fill(.white.opacity(0.3))
        }
        .blur(radius: 40)
    }

    private func loadLyric() {
        guard let song = player.currentSong else { return }
        lyricText = "歌词加载中…"
        Task {
            do {
                let lrc = try await MusicAPI.shared.getLyric(source: song.source, id: song.id)
                if !lrc.isEmpty {
                    await MainActor.run { lyricText = lrc }
                } else {
                    await MainActor.run { lyricText = "暂无歌词" }
                }
            } catch {
                await MainActor.run { lyricText = "暂无歌词" }
            }
        }
    }

    private func setupAudioRouteMonitoring() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil, queue: .main
        ) { _ in
            let route = AVAudioSession.sharedInstance().currentRoute
            player.isAirPlayActive = route.outputs.contains { $0.portType == .airPlay }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "00:00" }
        let s = Int(seconds)
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}

// 下载弹窗：选音质 + 标注占用内存
struct DownloadSheet: View {
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.dismiss) var dismiss
    let song: Song
    @State private var downloading = false
    @State private var progress: Double = 0
    @State private var done = false
    @State private var errMsg: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("下载音乐").font(.headline).foregroundColor(theme.textColor).padding(.top, 20)

            // 歌曲信息
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.primaryColor.opacity(0.3))
                    .frame(width: 46, height: 46)
                    .overlay(AsyncImage(url: URL(string: song.coverUrl)) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "music.note").foregroundColor(theme.primaryColor)
                    })
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 3) {
                    Text(song.name).font(.subheadline).bold().foregroundColor(theme.textColor).lineLimit(1)
                    Text("\(song.artist) · \(song.sourceLabel)").font(.caption).foregroundColor(theme.textSecondaryColor)
                }
                Spacer()
            }
            .padding(.horizontal, 24)

            Text("选择下载音质").font(.subheadline).foregroundColor(theme.textSecondaryColor)

            // 音质选项（标注占用内存）
            ForEach(AudioQuality.allCases) { q in
                Button {
                    guard !downloading else { return }
                    downloading = true
                    progress = 0
                    errMsg = nil
                    Task {
                        do {
                            let _ = try await LocalAudioManager.shared.download(song: song, quality: q) { p in
                                DispatchQueue.main.async { progress = p }
                            }
                            await MainActor.run { done = true; downloading = false }
                        } catch {
                            await MainActor.run { errMsg = error.localizedDescription; downloading = false }
                        }
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(q.rawValue).font(.subheadline).bold().foregroundColor(theme.textColor)
                            Text("\(q.bitrate) · 占用内存 \(q.sizeEstimate(durationSec: song.duration))")
                                .font(.caption).foregroundColor(theme.textSecondaryColor)
                        }
                        Spacer()
                        if downloading && progress > 0 {
                            ProgressView(value: progress).frame(width: 60)
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(theme.primaryColor)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(theme.primaryColor.opacity(0.1))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
            }

            if let err = errMsg {
                Text(err).font(.caption).foregroundColor(.red)
            }
            if done {
                Label("下载完成", systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundColor(.green)
            }
            Spacer()
        }
        .background(theme.bgColor)
    }
}

// AirPlay 投屏按钮
struct AirPlayButton: UIViewRepresentable {
    var tintColor: UIColor = .systemOrange

    func makeUIView(context: Context) -> UIView {
        let routePicker = AVRoutePickerView()
        routePicker.tintColor = tintColor
        routePicker.activeTintColor = tintColor
        routePicker.backgroundColor = .clear
        return routePicker
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        if let picker = uiView as? AVRoutePickerView {
            picker.tintColor = tintColor
            picker.activeTintColor = tintColor
        }
    }
}
