import Foundation

// 本地歌曲记录
struct LocalSong: Identifiable, Codable {
    var id: String { "\(song.id)_\(quality.rawValue)" }
    var song: Song
    var quality: AudioQuality
    var fileName: String
    var fileSize: Int64
    var downloadDate: Date
}

// 本地音频管理：下载/存储/统计/删除/音质管理
class LocalAudioManager: ObservableObject {
    static let shared = LocalAudioManager()

    @Published var localSongs: [LocalSong] = []

    private let fileManager = FileManager.default

    private var libraryURL: URL {
        let dir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MusicLibrary", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private var indexURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("music_index.json")
    }

    init() {
        loadIndex()
    }

    // 本地文件 URL（用文件名定位）
    func fileURL(for fileName: String) -> URL {
        libraryURL.appendingPathComponent(fileName)
    }

    // 下载歌曲到本地
    func download(song: Song, quality: AudioQuality, progress: @escaping (Double) -> Void) async throws -> LocalSong {
        // 获取对应音质播放地址
        let urlStr = try await MusicAPI.shared.getSongUrl(source: song.source, song: song, quality: quality)
        guard let url = URL(string: urlStr) else { throw NSError(domain: "Download", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的下载地址"]) }

        let fileName = "\(song.source)_\(song.id)_\(quality.rawValue).mp3"
        let dest = libraryURL.appendingPathComponent(fileName)

        // 已存在则跳过
        if fileManager.fileExists(atPath: dest.path) {
            let size = (try? fileManager.attributesOfItem(atPath: dest.path)[.size] as? Int64) ?? 0
            let ls = LocalSong(song: song, quality: quality, fileName: fileName, fileSize: size, downloadDate: Date())
            save(ls)
            return ls
        }

        let (data, _) = try await downloadData(from: url, progress: progress)
        try data.write(to: dest)
        let size = Int64(data.count)
        let ls = LocalSong(song: song, quality: quality, fileName: fileName, fileSize: size, downloadDate: Date())
        save(ls)
        return ls
    }

    // 流式下载（带进度）
    private func downloadData(from url: URL, progress: @escaping (Double) -> Void) async throws -> Data {
        let req = URLRequest(url: url)
        let (bytes, response) = try await URLSession.shared.bytes(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "Download", code: -1, userInfo: [NSLocalizedDescriptionKey: "下载失败"])
        }
        let total = Int64(http.expectedContentLength > 0 ? http.expectedContentLength : 0)
        var data = Data()
        data.reserveCapacity(Int(total > 0 ? total : 4_000_000))
        for try await chunk in bytes {
            data.append(chunk)
            if total > 0 {
                progress(Double(data.count) / Double(total))
            }
        }
        return data
    }

    // 保存索引
    private func save(_ ls: LocalSong) {
        // 同源同质去重
        localSongs.removeAll { $0.song.id == ls.song.id && $0.quality == ls.quality }
        localSongs.append(ls)
        saveIndex()
    }

    private func saveIndex() {
        if let data = try? JSONEncoder().encode(localSongs) {
            try? data.write(to: indexURL)
        }
    }

    private func loadIndex() {
        if let data = try? Data(contentsOf: indexURL),
           let list = try? JSONDecoder().decode([LocalSong].self, from: data) {
            localSongs = list
        }
    }

    // 删除一首本地歌曲
    func delete(_ ls: LocalSong) {
        let file = fileURL(for: ls.fileName)
        try? fileManager.removeItem(at: file)
        localSongs.removeAll { $0.id == ls.id }
        saveIndex()
    }

    // 清除所有本地歌曲
    func deleteAll() {
        for ls in localSongs {
            try? fileManager.removeItem(at: fileURL(for: ls.fileName))
        }
        localSongs.removeAll()
        saveIndex()
    }

    // 清理缓存（临时文件 + 非当前歌曲缓存）
    func clearCache() -> Int64 {
        let tmp = fileManager.temporaryDirectory
        var freed: Int64 = 0
        if let items = try? fileManager.contentsOfDirectory(at: tmp, includingPropertiesForKeys: nil) {
            for item in items {
                let size = (try? fileManager.attributesOfItem(atPath: item.path)[.size] as? Int64) ?? 0
                try? fileManager.removeItem(at: item)
                freed += size
            }
        }
        return freed
    }

    // 已占用总大小
    var totalSize: Int64 {
        localSongs.reduce(0) { $0 + $1.fileSize }
    }

    var totalSizeString: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    // 单曲文件大小字符串
    func sizeString(of ls: LocalSong) -> String {
        ByteCountFormatter.string(fromByteCount: ls.fileSize, countStyle: .file)
    }

    // 升级/降级音质（重新下载覆盖）
    func reDownload(_ ls: LocalSong, to newQuality: AudioQuality) async throws -> LocalSong {
        // 删除旧的
        delete(ls)
        // 用新音质重新下载
        return try await download(song: ls.song, quality: newQuality) { _ in }
    }
}
