import SwiftUI
import AVKit
import MediaPlayer

// Apple Music 风格全屏播放器
struct PlayerView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var player: MusicPlayer
    @Environment(\.dismiss) var dismiss
    @State private var isDragging = false
    @State private var showLyrics = false

    var body: some View {
        ZStack {
            // 封面模糊背景
            coverBackground
                .ignoresSafeArea()

            // 毛玻璃叠加
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(theme.glassIntensity * 0.6)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部拖动条
                Capsule()
                    .fill(.white.opacity(0.5))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)
                    .onTapGesture { dismiss() }

                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(theme.textColor)
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
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer(minLength: 20)

                // 大封面（Apple Music 风格圆角方）
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
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
                                Image(systemName: "music.note")
                                    .font(.system(size: 80))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: theme.primaryColor.opacity(0.35), radius: 30, y: 12)
                }
                .frame(width: 300, height: 300)
                .padding(.horizontal, 40)
                .rotation3DEffect(.degrees(isDragging ? 3 : 0), axis: (x: 0, y: 1, z: 0))

                Spacer(minLength: 20)

                // 歌名/歌手
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(player.currentSong?.name ?? "")
                            .font(.title2).bold()
                            .foregroundColor(theme.textColor)
                            .lineLimit(1)
                        Spacer()
                        Button {} label: {
                            Image(systemName: "heart")
                                .font(.system(size: 22))
                                .foregroundColor(theme.textSecondaryColor)
                        }
                    }
                    Text(player.currentSong?.artist ?? "")
                        .font(.subheadline)
                        .foregroundColor(theme.textSecondaryColor)
                        .lineLimit(1)
                }
                .padding(.horizontal, 24)

                // 歌词
                if showLyrics, !player.currentSong!.name.isEmpty {
                    Text("歌词加载中…")
                        .font(.caption)
                        .foregroundColor(theme.textSecondaryColor)
                        .padding(.vertical, 8)
                }

                // 进度条
                VStack(spacing: 4) {
                    Slider(
                        value: Binding(
                            get: { player.progress },
                            set: { newVal in
                                isDragging = true
                                player.progress = newVal
                            }
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
                .padding(.top, 10)

                // 控制按钮（Apple Music 布局）
                HStack(spacing: 40) {
                    Button { } label: {
                        Image(systemName: "shuffle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(theme.textSecondaryColor)
                    }
                    Button { player.prev() } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(theme.textColor)
                    }
                    Button { player.togglePlay() } label: {
                        ZStack {
                            Circle().fill(theme.textColor).frame(width: 64, height: 64)
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundColor(theme.bgColor)
                                .offset(x: player.isPlaying ? 0 : 2)
                        }
                    }
                    Button { player.next() } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(theme.textColor)
                    }
                    Button { } label: {
                        Image(systemName: "repeat")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(theme.textSecondaryColor)
                    }
                }
                .padding(.top, 14)
                .padding(.bottom, 8)

                // 底部工具条：音量 + 歌词 + AirPlay 投屏
                HStack(spacing: 20) {
                    Image(systemName: "speaker.fill")
                        .font(.system(size: 13))
                        .foregroundColor(theme.textSecondaryColor)

                    VolumeSlider()
                        .frame(maxWidth: .infinity)

                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 13))
                        .foregroundColor(theme.textSecondaryColor)

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showLyrics.toggle()
                        }
                    } label: {
                        Image(systemName: "text.quote")
                            .font(.system(size: 15))
                            .foregroundColor(showLyrics ? theme.primaryColor : theme.textSecondaryColor)
                    }

                    // AirPlay 投屏按钮
                    AirPlayButton(tintColor: UIColor(theme.primaryColor))
                        .frame(width: 24, height: 24)
                }
                .padding(.horizontal, 28)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
        }
        .onAppear { setupAudioRouteMonitoring() }
        .onDisappear { player.stopLiveActivity() }
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

// 音量滑条
struct VolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> UISlider {
        let slider = UISlider()
        slider.minimumValueImage = UIImage(systemName: "speaker.fill")
        slider.maximumValueImage = UIImage(systemName: "speaker.wave.3.fill")
        slider.tintColor = .systemOrange
        if let view = MPVolumeView().subviews.first(where: { $0 is UISlider }) as? UISlider {
            slider.value = view.value
        }
        return slider
    }
    func updateUIView(_ uiView: UISlider, context: Context) {}
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
