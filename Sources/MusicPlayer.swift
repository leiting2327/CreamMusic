import Foundation
import AVFoundation
import MediaPlayer
import ActivityKit

// 播放器管理器（修复：播放失败释放、可关闭、本地播放、控制中心/锁屏/后台）
class MusicPlayer: ObservableObject {
    @Published var currentSong: Song?
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var playlist: [Song] = []
    @Published var currentIndex: Int = -1
    @Published var isAirPlayActive = false
    @Published var isLocalPlaying = false // 是否在播本地文件
    @Published var playError: String? // 播放错误提示
    @Published var volume: Float = 0.8 // 音量（Apple Music 播放器音量条）

    var player: AVPlayer?
    private var timer: Timer?
    private var activity: Activity<MusicActivityAttributes>?
    private var nowPlayingInfo = [String: Any]()
    private var airPlayStatusTimer: Timer?
    private var isStopping = false

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
        guard index >= 0, index < songs.count else { return }
        playlist = songs
        currentIndex = index
        currentSong = songs[index]
        isLocalPlaying = false
        playError = nil
        playCurrent()
    }

    // 播放本地文件
    func playLocal(fileURL: URL, song: Song) {
        currentSong = song
        playlist = [song]
        currentIndex = 0
        isLocalPlaying = true
        playError = nil
        playItem(url: fileURL)
    }

    private func playCurrent() {
        guard let song = currentSong else { return }
        // 检查本地是否已有该歌曲的任意音质版本，优先本地播放
        let local = LocalAudioManager.shared.localSongs.first { $0.song.id == song.id }
        if let ls = local {
            let url = LocalAudioManager.shared.fileURL(for: ls.fileName)
            if FileManager.default.fileExists(atPath: url.path) {
                isLocalPlaying = true
                playItem(url: url)
                return
            }
        }
        isLocalPlaying = false
        Task {
            do {
                let urlStr = try await MusicAPI.shared.getSongUrl(source: song.source, song: song)
                guard let url = URL(string: urlStr), !urlStr.isEmpty else {
                    await MainActor.run { self.playError = "获取播放地址失败"; self.isPlaying = false }
                    return
                }
                await MainActor.run { self.playItem(url: url) }
            } catch {
                await MainActor.run {
                    self.playError = error.localizedDescription
                    self.isPlaying = false
                    self.stopPlayback() // 失败则彻底释放
                }
            }
        }
    }

    // 真正开始播放
    private func playItem(url: URL) {
        stopPlayback(keepSession: true)
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player?.volume = volume
        player?.play()
        isPlaying = true
        startTimer()
        startLiveActivity()
        updateNowPlaying()
        startAirPlayMonitor()

        // 监听播放失败
        NotificationCenter.default.addObserver(
            forName: AVPlayerItem.failedToPlayToEndTimeNotification,
            object: item, queue: .main
        ) { [weak self] _ in
            self?.playError = "播放失败，请换一首或切换音质"
            self?.stopPlayback()
        }
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemNewErrorLogEntry,
            object: item, queue: .main
        ) { [weak self] _ in
            self?.playError = "播放出现错误"
        }
    }

    // 关闭/停止播放（彻底释放）
    func stopPlayback(keepSession: Bool = false) {
        timer?.invalidate()
        timer = nil
        airPlayStatusTimer?.invalidate()
        airPlayStatusTimer = nil
        player?.pause()
        player = nil
        isPlaying = false
        progress = 0
        stopLiveActivity()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        if !keepSession {
            currentSong = nil
            playlist = []
            currentIndex = -1
        }
    }

    // 停止播放并关闭播放器（保留歌曲信息）
    func stop() {
        stopPlayback()
    }

    func togglePlay() {
        guard player != nil else {
            if currentSong != nil { playCurrent() }
            return
        }
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

    // 音量（Apple Music 音量条实时生效）
    func setVolume(_ v: Float) {
        volume = v
        player?.volume = v
    }

    func next() {
        guard !playlist.isEmpty, !isLocalPlaying else { return }
        currentIndex = (currentIndex + 1) % playlist.count
        currentSong = playlist[currentIndex]
        playError = nil
        playCurrent()
    }

    func prev() {
        guard !playlist.isEmpty, !isLocalPlaying else { return }
        currentIndex = (currentIndex - 1 + playlist.count) % playlist.count
        currentSong = playlist[currentIndex]
        playError = nil
        playCurrent()
    }

    func seek(to percent: Double) {
        guard let duration = player?.currentItem?.duration.seconds, duration > 0 else { return }
        let time = CMTime(seconds: duration * min(max(percent, 0), 1), preferredTimescale: 600)
        player?.seek(to: time)
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
                DispatchQueue.main.async { self.isAirPlayActive = active }
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
        Task { await activity.update(.init(state: state, staleDate: nil)) }
    }

    func stopLiveActivity() {
        Task {
            await activity?.end(.init(state: MusicActivityAttributes.ContentState(isPlaying: false, progress: 0), staleDate: nil), dismissalPolicy: .immediate)
        }
    }
}
