import Foundation
import AVFoundation
import ActivityKit

// 播放器管理器
class MusicPlayer: ObservableObject {
    @Published var currentSong: Song?
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var playlist: [Song] = []
    @Published var currentIndex: Int = -1

    private var player: AVPlayer?
    private var timer: Timer?
    private var activity: Activity<MusicActivityAttributes>?

    func play(_ songs: [Song], at index: Int) {
        playlist = songs
        currentIndex = index
        playCurrent()
    }

    func playCurrent() {
        guard currentIndex >= 0, currentIndex < playlist.count else { return }
        let song = playlist[currentIndex]
        currentSong = song
        Task {
            do {
                let urlStr = try await MusicAPI.shared.getSongUrl(source: song.source, id: song.id)
                if let url = URL(string: urlStr) {
                    await MainActor.run {
                        player = AVPlayer(url: url)
                        player?.play()
                        isPlaying = true
                        startTimer()
                        startLiveActivity()
                    }
                }
            } catch {
                await MainActor.run { isPlaying = false }
            }
        }
    }

    func togglePlay() {
        if isPlaying {
            player?.pause()
            isPlaying = false
        } else {
            player?.play()
            isPlaying = true
        }
        updateLiveActivity()
    }

    func next() {
        guard !playlist.isEmpty else { return }
        currentIndex = (currentIndex + 1) % playlist.count
        playCurrent()
    }

    func prev() {
        guard !playlist.isEmpty else { return }
        currentIndex = (currentIndex - 1 + playlist.count) % playlist.count
        playCurrent()
    }

    func seek(to percent: Double) {
        guard let duration = player?.currentItem?.duration.seconds else { return }
        player?.seek(to: CMTime(seconds: duration * percent, preferredTimescale: 600))
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self,
                  let current = self.player?.currentTime().seconds,
                  let duration = self.player?.currentItem?.duration.seconds,
                  duration > 0 else { return }
            self.progress = current / duration
            if current >= duration { self.next() }
        }
    }

    // ===== 灵动岛 Live Activity =====
    private func startLiveActivity() {
        guard let song = currentSong else { return }
        let attributes = MusicActivityAttributes(songName: song.name, artist: song.artist)
        let state = MusicActivityAttributes.ContentState(isPlaying: true, progress: 0)
        do {
            activity = try Activity.request(attributes: attributes, content: .init(state: state, staleDate: nil))
        } catch {
            print("Live Activity 启动失败: \(error)")
        }
    }

    private func updateLiveActivity() {
        guard let activity = activity else { return }
        let state = MusicActivityAttributes.ContentState(isPlaying: isPlaying, progress: progress)
        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    func stopLiveActivity() {
        Task {
            await activity?.end(.init(state: MusicActivityAttributes.ContentState(isPlaying: false, progress: 0), staleDate: nil), dismissalPolicy: .immediate)
        }
    }
}
