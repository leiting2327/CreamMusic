import SwiftUI
import AVKit
import MediaPlayer

// Apple Music 风格全屏播放器（参考用户需求：和苹果一模一样）
struct PlayerView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var player: MusicPlayer
    @Environment(\.dismiss) var dismiss
    @State private var isDragging = false
    @State private var showLyrics = false
    @State private var lyricText = "歌词加载中…"
    @State private var showDownloadSheet = false
    @State private var showCloseConfirm = false
    @State private var downloadError: String?
    @State private var showComments = false
    @State private var comments: [MusicComment] = []
    @State private var commentsLoading = false

    var body: some View {
        ZStack {
            // 封面模糊背景（Apple Music 风格）
            coverBackground.ignoresSafeArea()

            // 毛玻璃叠加
            Rectangle().fill(.ultraThinMaterial).opacity(theme.glassIntensity * 0.55).ignoresSafeArea()

            VStack(spacing: 0) {
                // ===== 顶部栏（Apple Music：左关闭 / 中歌名歌手 / 右更多） =====
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
                        Text(player.currentSong?.name ?? "未在播放")
                            .font(.subheadline).bold()
                            .foregroundColor(theme.textColor)
                            .lineLimit(1)
                        Text("\(player.currentSong?.artist ?? "") · \(player.currentSong?.album ?? "")")
                            .font(.caption2)
                            .foregroundColor(theme.textSecondaryColor)
                            .lineLimit(1)
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

                // ===== 中部：大封面（Apple Music 风格，居中大图带投影） =====
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
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
                                Image(systemName: "music.note").font(.system(size: 90)).foregroundColor(.white.opacity(0.85))
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.3), radius: 24, y: 10)
                }
                .frame(width: 340, height: 340)
                .padding(.top, 26)
                .rotation3DEffect(.degrees(isDragging ? 3 : 0), axis: (x: 0, y: 1, z: 0))

                // ===== 歌名 / 歌手（Apple Music：居中） =====
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        // 来源标注
                        if let src = player.currentSong?.sourceLabel, !src.isEmpty {
                            Text(src)
                                .font(.system(size: 9))
                                .foregroundColor(theme.primaryColor)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(theme.primaryColor.opacity(0.15))
                                .cornerRadius(4)
                        }
                        // VIP 标注
                        if player.currentSong?.isVip == true {
                            Text("VIP")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
                                .cornerRadius(4)
                        }
                    }
                    Text(player.currentSong?.name ?? "")
                        .font(.title2).bold()
                        .foregroundColor(theme.textColor)
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                    Text(player.currentSong?.artist ?? "")
                        .font(.subheadline)
                        .foregroundColor(theme.textSecondaryColor)
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)

                // 歌词按钮（点击弹出歌词）
                Button {
                    withAnimation { showLyrics.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "text.quote")
                        Text("歌词")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(showLyrics ? theme.primaryColor : theme.textSecondaryColor)
                }
                .padding(.top, 8)

                Spacer(minLength: 0)

                // ===== 进度条（Apple Music：Slider + 时间） =====
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

                // ===== 播放控制（Apple Music：backward / play / forward） =====
                HStack(spacing: 46) {
                    Button { player.prev() } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(theme.textColor)
                    }
                    Button { player.togglePlay() } label: {
                        ZStack {
                            Circle().fill(theme.textColor).frame(width: 66, height: 66)
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundColor(theme.bgColor)
                                .offset(x: player.isPlaying ? 0 : 2)
                        }
                    }
                    Button { player.next() } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(theme.textColor)
                    }
                }
                .padding(.top, 14)

                // ===== 音量条（Apple Music 特色） =====
                HStack(spacing: 10) {
                    Image(systemName: "speaker.fill").font(.system(size: 12)).foregroundColor(theme.textSecondaryColor)
                    Slider(
                        value: Binding(
                            get: { player.volume },
                            set: { player.setVolume($0) }
                        ),
                        in: 0...1
                    )
                    .tint(theme.textSecondaryColor)
                    Image(systemName: "speaker.wave.3.fill").font(.system(size: 12)).foregroundColor(theme.textSecondaryColor)
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)

                // ===== 底部工具条（Apple Music：评论/下载/歌词/AirPlay） =====
                HStack(spacing: 30) {
                    Button {
                        loadComments()
                        showComments = true
                    } label: {
                        Image(systemName: "bubble.left").font(.system(size: 16)).foregroundColor(theme.textSecondaryColor)
                    }
                    Button {
                        showDownloadSheet = true
                    } label: {
                        Image(systemName: "arrow.down.circle").font(.system(size: 17)).foregroundColor(theme.textSecondaryColor)
                    }
                    Spacer()
                    Button {
                        withAnimation { showLyrics.toggle() }
                    } label: {
                        Image(systemName: "text.quote")
                            .font(.system(size: 16))
                            .foregroundColor(showLyrics ? theme.primaryColor : theme.textSecondaryColor)
                    }
                    AirPlayButton(tintColor: UIColor(theme.primaryColor)).frame(width: 24, height: 24)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .padding(.bottom, 6)
            }

            // ===== 歌词弹层（Apple Music 风格） =====
            if showLyrics, let song = player.currentSong {
                VStack {
                    Spacer()
                    VStack(spacing: 10) {
                        HStack {
                            Text("歌词").font(.headline).foregroundColor(theme.textColor)
                            Spacer()
                            Button {
                                withAnimation { showLyrics = false }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(theme.textSecondaryColor)
                            }
                        }
                        .padding(.horizontal, 20).padding(.top, 16)
                        ScrollView {
                            Text(lyricText)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(theme.textColor)
                                .lineSpacing(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20).padding(.vertical, 10)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: 360)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20, corners: [.topLeft, .topRight])
                    .transition(.move(edge: .bottom))
                }
                .ignoresSafeArea()
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
        .sheet(isPresented: $showComments) {
            CommentsView(song: player.currentSong, comments: comments, loading: commentsLoading)
                .presentationDetents([.large])
        }
    }

    private func loadComments() {
        guard let song = player.currentSong else { return }
        commentsLoading = true
        comments = []
        Task {
            do {
                let list = try await MusicAPI.shared.getComments(song: song)
                await MainActor.run {
                    comments = list
                    commentsLoading = false
                }
            } catch {
                await MainActor.run { commentsLoading = false }
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

// 评论列表页（接入各平台评论数据接口）
struct CommentsView: View {
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.dismiss) var dismiss
    let song: Song?
    let comments: [MusicComment]
    let loading: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.down").foregroundColor(theme.textColor)
                }
                Spacer()
                Text("评论").font(.headline).foregroundColor(theme.textColor)
                Spacer()
                Text("\(comments.count)").font(.caption).foregroundColor(theme.textSecondaryColor)
            }
            .padding(.horizontal, 20).padding(.top, 16)

            if let song {
                HStack(spacing: 10) {
                    AsyncImage(url: URL(string: song.coverUrl)) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 6).fill(theme.primaryColor.opacity(0.2))
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.name).font(.subheadline).bold().foregroundColor(theme.textColor).lineLimit(1)
                        Text("\(song.sourceLabel)\(song.isVip ? " · VIP" : "") · \(song.album.isEmpty ? "单曲" : song.album)")
                            .font(.caption).foregroundColor(theme.textSecondaryColor).lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
            }

            if loading {
                Spacer()
                ProgressView("加载评论…")
                Spacer()
            } else if comments.isEmpty {
                Spacer()
                Image(systemName: "bubble.left")
                    .font(.system(size: 40)).foregroundColor(theme.textSecondaryColor.opacity(0.5))
                Text("暂无评论").font(.subheadline).foregroundColor(theme.textSecondaryColor)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(comments) { c in
                            HStack(alignment: .top, spacing: 10) {
                                // 头像
                                if c.avatar.isEmpty {
                                    Circle().fill(theme.primaryColor.opacity(0.3))
                                        .frame(width: 34, height: 34)
                                        .overlay(Image(systemName: "person.fill").font(.system(size: 14)).foregroundColor(.white))
                                } else {
                                    AsyncImage(url: URL(string: c.avatar)) { img in
                                        img.resizable().scaledToFill()
                                    } placeholder: {
                                        Circle().fill(theme.primaryColor.opacity(0.3))
                                    }
                                    .frame(width: 34, height: 34)
                                    .clipShape(Circle())
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(c.user).font(.caption).bold().foregroundColor(theme.primaryColor)
                                        Spacer()
                                        Text(c.timeText).font(.system(size: 10)).foregroundColor(theme.textSecondaryColor)
                                    }
                                    Text(c.content)
                                        .font(.subheadline)
                                        .foregroundColor(theme.textColor)
                                        .lineSpacing(3)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    HStack {
                                        Image(systemName: "hand.thumbsup").font(.system(size: 10)).foregroundColor(theme.textSecondaryColor)
                                        Text("\(c.likedCount)").font(.system(size: 10)).foregroundColor(theme.textSecondaryColor)
                                    }
                                }
                            }
                            .padding(12)
                            .background {
                                RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial).opacity(theme.glassIntensity)
                            }
                        }
                    }
                    .padding(.horizontal, 20).padding(.bottom, 20)
                }
            }
        }
        .background(theme.bgColor)
    }
}

// 指定圆角扩展（Apple Music 歌词弹层用）
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
