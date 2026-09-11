import SwiftUI

struct PlayerView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var player: MusicPlayer
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            theme.bgColor.ignoresSafeArea()
            VStack(spacing: 0) {
                // 顶部栏
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down").font(.title2).foregroundColor(theme.textColor)
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text(player.currentSong?.name ?? "").font(.headline).foregroundColor(theme.textColor).lineLimit(1)
                        Text(player.currentSong?.artist ?? "").font(.caption).foregroundColor(theme.textSecondaryColor)
                    }
                    Spacer()
                    Image(systemName: "ellipsis").font(.title2).foregroundColor(theme.textColor)
                }
                .padding(.horizontal, 20).padding(.top, 16)

                Spacer()

                // 封面
                RoundedRectangle(cornerRadius: 24)
                    .fill(LinearGradient(colors: [theme.primaryColor.opacity(0.6), theme.primaryColor.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 260, height: 260)
                    .overlay(Image(systemName: "music.note").font(.system(size: 80)).foregroundColor(.white.opacity(0.8)))
                    .shadow(radius: 20)

                Spacer()

                // 歌词
                Text("暂无歌词").font(.caption).foregroundColor(theme.textSecondaryColor).padding(.bottom, 8)

                // 进度条
                Slider(value: Binding(get: { player.progress }, set: { player.seek(to: $0) }))
                    .padding(.horizontal, 20)
                HStack {
                    Text(formatTime(player.progress * (player.player?.currentItem?.duration.seconds ?? 0)))
                    Spacer()
                    Text(formatTime(player.player?.currentItem?.duration.seconds ?? 0))
                }
                .font(.caption2).foregroundColor(theme.textSecondaryColor)
                .padding(.horizontal, 24)

                // 控制按钮
                HStack(spacing: 28) {
                    Image(systemName: "shuffle").font(.title2).foregroundColor(theme.textSecondaryColor)
                    Button { player.prev() } label: {
                        Image(systemName: "backward.fill").font(.title).foregroundColor(theme.textColor)
                    }
                    Button { player.togglePlay() } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 36)).foregroundColor(.white)
                            .frame(width: 72, height: 72)
                            .background(theme.primaryColor)
                            .clipShape(Circle())
                    }
                    Button { player.next() } label: {
                        Image(systemName: "forward.fill").font(.title).foregroundColor(theme.textColor)
                    }
                    Image(systemName: "heart").font(.title2).foregroundColor(theme.textSecondaryColor)
                }
                .padding(.vertical, 24)
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let s = Int(seconds)
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}
