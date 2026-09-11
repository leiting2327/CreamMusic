import Foundation
import AVFoundation
import MediaPlayer
import ActivityKit

// 播放器管理器
class MusicPlayer: ObservableObject {
    @Published var currentSong: Song?
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var playlist: [Song] = []
    @Published var currentIndex: Int = -1
    @Published var isAirPlayActive = false

    var player: AVPlayer?
    private var timer: Timer?
    private var activity: Activity<MusicActivityAttributes>?
    private var nowPlayingInfo = [String: Any]()
    private var airPlayStatusTimer: Timer?

    init() {
        setupRemoteCommands()
        setupAudioSession()
    }

    // ===== 音频会话（后台播放 + AirPlay） =====
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("AVAudioSession 设置失败: \(error)")
        }
    }

    // ===== 远程控制（锁屏/控制中心） =====
    private func setupRemoteCommands() {
        let cmd = MPRemoteCommandCenter.shared()
        cmd.playCommand.addTarget { [weak self] _ in
            self?.togglePlay()
            return .success
        }
        cmd.pauseCommand.addTarget { [weak self] _ in
            self?.togglePlay()
            return .success
        }
        cmd.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlay()
            return .success
        }
        cmd.nextTrackCommand.addTarget { [weak self] _ in
            self?.next()
            return .success
        }
        cmd.previousTrackCommand.addTarget { [weak self] _ in
            self?.prev()
            return .success
        }
        cmd.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let dur = self?.player?.currentItem?.duration.seconds ?? 0
            guard dur > 0 else { return .commandFailed }
            self?.seek(to: e.positionTime / dur)
            return .success
        }
    }

    // ===== 控制中心信息 =====
    private func updateNowPlaying() {
        guard let song = currentSong else { return }
        nowPlayingInfo = [:]
        nowPlayingInfo[MPMediaItemPropertyTitle] = song.name
        nowPlayingInfo[MPMediaItemPropertyArtist] = song.artist
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = song.album
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = player?.currentItem?.duration.seconds ?? 0
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player?.currentTime().seconds ?? 0
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue

        // 封面
        if !song.coverUrl.isEmpty, let url = URL(string: song.coverUrl) {
            Task {
                if let (data, _) = try? await URLSession.shared.data(from: url),
                   let img = UIImage(data: data) {
                    var info = self.nowPlayingInfo
                    info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
                    DispatchQueue.main.async {
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                    }
                }
            }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    // ===== 播放控制 =====
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
                let urlStr = try await MusicAPI.shared.getSongUrl(source: song.source, song: song)
                guard let url = URL(string: urlStr), !urlStr.isEmpty else {
                    await MainActor.run { isPlaying = false }
                    return
                }
                await MainActor.run {
                    player = AVPlayer(url: url)
                    player?.play()
                    isPlaying = true
                    startTimer()
                    startLiveActivity()
                    updateNowPlaying()
                    startAirPlayMonitor()
                }
            } catch {
                await MainActor.run {
                    isPlaying = false
                    nowPlayingError = error.localizedDescription
                }
            }
        }
    }

    @Published var nowPlayingError = ""

    func togglePlay() {
        if isPlaying {
            player?.pause()
            isPlaying = false
        } else {
            player?.play()
            isPlaying = true
        }
        updateLiveActivity()
        updateNowPlaying()
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
        guard let duration = player?.currentItem?.duration.seconds, duration > 0 else { return }
        let time = CMTime(seconds: duration * min(max(percent, 0), 1), preferredTimescale: 600)
        player?.seek(to: time)
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = duration * min(max(percent, 0), 1)
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self,
                  let current = self.player?.currentTime().seconds,
                  let duration = self.player?.currentItem?.duration.seconds,
                  duration > 0 else { return }
            self.progress = current / duration
            if current >= duration - 0.3 { self.next() }
            // 每 5 秒刷新控制中心
            if Int(current) % 5 == 0 { self.updateNowPlaying() }
        }
    }

    // ===== AirPlay 监控 =====
    private func startAirPlayMonitor() {
        airPlayStatusTimer?.invalidate()
        airPlayStatusTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            let active = player.isExternalPlaybackActive
            if active != self.isAirPlayActive {
                DispatchQueue.main.async {
                    self.isAirPlayActive = active
                }
            }
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
