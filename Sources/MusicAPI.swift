import Foundation

// 歌曲模型
struct Song: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let artist: String
    let album: String
    let coverUrl: String
    let source: String // netease / tencent / kugou / kuwo
    let duration: Int
    var songmid: String = ""
    var hash: String = ""
    var kuwoRid: String = ""
    var kuwoPic: String = ""
    var isVip: Bool = false // VIP 歌曲标注

    var sourceLabel: String {
        switch source {
        case "netease": return "网易云"
        case "tencent": return "QQ音乐"
        case "kugou": return "酷狗"
        case "kuwo": return "酷我"
        default: return "音乐"
        }
    }
}

// 评论模型
struct MusicComment: Identifiable, Hashable {
    let id: String
    let user: String
    let avatar: String
    let content: String
    let likedCount: Int
    let time: Int
    var timeText: String {
        let d = Date(timeIntervalSince1970: TimeInterval(time))
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }
}

// 用户模型（含会员等级）
struct User: Codable {
    let uid: String
    let nickname: String
    let avatarUrl: String
    let vipType: Int
    let vipLevel: Int
    let level: Int
    var platform: String = "netease" // 网易云/QQ/酷我

    var vipName: String {
        switch vipType {
        case 11: return "音乐包"
        case 1: return "黑胶VIP"
        default: return "普通用户"
        }
    }
    var isVip: Bool { vipType > 0 }
}

// 音质档位
enum AudioQuality: String, CaseIterable, Identifiable, Codable {
    case standard = "标准音质"
    case high = "高清音质"
    case lossless = "无损音质"

    var id: String { rawValue }

    var bitrate: String {
        switch self {
        case .standard: return "128kbps"
        case .high: return "320kbps"
        case .lossless: return "FLAC"
        }
    }

    // 每 MB/分钟 估算
    func sizeEstimate(durationSec: Int) -> String {
        let minutes = Double(max(durationSec, 60)) / 60.0
        let mbPerMin: Double
        switch self {
        case .standard: mbPerMin = 0.94
        case .high: mbPerMin = 2.4
        case .lossless: mbPerMin = 9.0
        }
        let mb = minutes * mbPerMin
        return String(format: "约%.1fMB", mb)
    }
}

// 音乐 API 层
class MusicAPI {
    static let shared = MusicAPI()

    var metingBase = "https://api.injahow.cn/meting/"
    var neteaseBase = "https://music.163.com"

    private var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        return URLSession(configuration: config)
    }()

    private var neteaseCookie = "os=pc; osver=Microsoft-Windows-10-Professional-build-10586-64bit; appver=2.0.3.131777; channel=netease; __remember_me=true"

    // ===== 聚合搜索（三平台并行，标注来源） =====
    func searchAll(keyword: String) async throws -> [Song] {
        async let netease = try? searchNetease(keyword: keyword)
        async let tencent = try? searchQQ(keyword: keyword)
        async let kuwo = try? searchKuwo(keyword: keyword)
        let (n, q, k) = await (netease, tencent, kuwo)
        return (n ?? []) + (q ?? []) + (k ?? [])
    }

    // ===== 单平台搜索 =====
    func search(source: String, keyword: String) async throws -> [Song] {
        switch source {
        case "tencent": return try await searchQQ(keyword: keyword)
        case "kugou": return try await searchKugou(keyword: keyword)
        case "kuwo": return try await searchKuwo(keyword: keyword)
        default: return try await searchNetease(keyword: keyword)
        }
    }

    // 网易云官方搜索
    private func searchNetease(keyword: String) async throws -> [Song] {
        var req = URLRequest(url: URL(string: "\(neteaseBase)/api/cloudsearch/pc")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue(UserAgent, forHTTPHeaderField: "User-Agent")
        req.httpBody = "s=\(urlEnc(keyword))&type=1&limit=30&offset=0".data(using: .utf8)
        let (data, _) = try await session.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let songs = result["songs"] as? [[String: Any]] else {
            throw NSError(domain: "Search", code: -1, userInfo: [NSLocalizedDescriptionKey: "网易云搜索失败"])
        }
        return songs.map { s in
            let al = s["al"] as? [String: Any] ?? [:]
            let ar = s["ar"] as? [[String: Any]] ?? []
            let artists = ar.compactMap { $0["name"] as? String }.joined(separator: "/")
            let dur = s["dt"] as? Int ?? 0
            let fee = s["fee"] as? Int ?? 0
            return Song(
                id: "\(s["id"] as? Int ?? 0)",
                name: s["name"] as? String ?? "未知",
                artist: artists,
                album: al["name"] as? String ?? "",
                coverUrl: al["picUrl"] as? String ?? "",
                source: "netease",
                duration: dur / 1000,
                isVip: fee > 0
            )
        }
    }

    // QQ 音乐官方搜索
    private func searchQQ(keyword: String) async throws -> [Song] {
        var comps = URLComponents(string: "https://c.y.qq.com/soso/fcgi-bin/client_search_cp")!
        comps.queryItems = [
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "w", value: keyword),
            URLQueryItem(name: "p", value: "1"),
            URLQueryItem(name: "n", value: "30"),
            URLQueryItem(name: "cr", value: "1"),
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue(UserAgent, forHTTPHeaderField: "User-Agent")
        let (data, _) = try await session.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let song = dataObj["song"] as? [String: Any],
              let list = song["list"] as? [[String: Any]] else {
            throw NSError(domain: "Search", code: -1, userInfo: [NSLocalizedDescriptionKey: "QQ音乐搜索失败"])
        }
        return list.map { s in
            let singers = (s["singer"] as? [[String: Any]]) ?? []
            let artists = singers.compactMap { $0["name"] as? String }.joined(separator: "/")
            // QQ 付费标记：pay 1=付费
            let pay = s["pay"] as? Int ?? 0
            let payPlay = (s["pay_play"] as? Int) ?? 0
            return Song(
                id: "\(s["songmid"] as? String ?? "")",
                name: s["songname"] as? String ?? "未知",
                artist: artists,
                album: s["albumname"] as? String ?? "",
                coverUrl: "https://y.gtimg.cn/music/photo_new/T002R300x300M000\(s["albummid"] as? String ?? "").jpg",
                source: "tencent",
                duration: (s["interval"] as? Int) ?? 0,
                songmid: s["songmid"] as? String ?? "",
                isVip: pay > 0 || payPlay > 0
            )
        }
    }

    // 酷狗搜索（保留）
    private func searchKugou(keyword: String) async throws -> [Song] {
        var comps = URLComponents(string: "http://mobilecdn.kugou.com/api/v3/search/song")!
        comps.queryItems = [
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "keyword", value: keyword),
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "pagesize", value: "30"),
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue(UserAgent, forHTTPHeaderField: "User-Agent")
        let (data, _) = try await session.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let list = dataObj["info"] as? [[String: Any]] else {
            throw NSError(domain: "Search", code: -1, userInfo: [NSLocalizedDescriptionKey: "酷狗搜索失败"])
        }
        return list.map { s in
            let hash = s["hash"] as? String ?? ""
            let cover = s["imgUrl"] as? String ?? s["img"] as? String ?? ""
            let dur = s["duration"] as? Int ?? 0
            return Song(
                id: hash,
                name: s["songname"] as? String ?? "未知",
                artist: s["singername"] as? String ?? "",
                album: s["album_name"] as? String ?? "",
                coverUrl: cover.replacingOccurrences(of: "{size}", with: "400"),
                source: "kugou",
                duration: dur,
                hash: hash
            )
        }
    }

    // 酷我搜索（r.s 老接口）
    private func searchKuwo(keyword: String) async throws -> [Song] {
        var comps = URLComponents(string: "http://search.kuwo.cn/r.s")!
        comps.queryItems = [
            URLQueryItem(name: "client", value: "kt"),
            URLQueryItem(name: "all", value: keyword),
            URLQueryItem(name: "pn", value: "0"),
            URLQueryItem(name: "rn", value: "30"),
            URLQueryItem(name: "uid", value: "0"),
            URLQueryItem(name: "ver", value: "kwplayer_9.2.2.1"),
            URLQueryItem(name: "vipver", value: "1"),
            URLQueryItem(name: "show_copyright_off", value: "1"),
            URLQueryItem(name: "newver", value: "1"),
            URLQueryItem(name: "ft", value: "music"),
            URLQueryItem(name: "encoding", value: "utf8"),
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue(UserAgent, forHTTPHeaderField: "User-Agent")
        let (data, _) = try await session.data(for: req)
        let text = String(data: data, encoding: .utf8) ?? ""
        // 解析 key=value 格式，每首歌以 "-----" 分隔
        let blocks = text.components(separatedBy: "-----").filter { $0.contains("MUSICRID") }
        var songs: [Song] = []
        for block in blocks.prefix(30) {
            let lines = block.components(separatedBy: "\n")
            var rid = "", name = "", artist = "", album = "", pic = "", dur = 0, mp3size = 0, isVip = false
            for line in lines {
                let kv = line.split(separator: "=", maxSplits: 1).map(String.init)
                guard kv.count == 2 else { continue }
                let key = kv[0].trimmingCharacters(in: .whitespaces)
                let val = kv[1].trimmingCharacters(in: .whitespaces)
                switch key {
                case "MUSICRID": rid = val.replacingOccurrences(of: "MUSIC_", with: "")
                case "SONGNAME": name = val
                case "ARTIST": artist = val
                case "ALBUM": album = val
                case "web_albumpic_short": pic = "https://img1.kuwo.cn/star/albumcover/\(val)"
                case "web_artistpic_short": if pic.isEmpty { pic = "https://img1.kuwo.cn/star/artistcover/\(val)" }
                case "MP3SIZE": mp3size = Int(val) ?? 0
                case "PAY": isVip = val.contains("1") || val.lowercased().contains("vip")
                default: break
                }
            }
            guard !rid.isEmpty else { continue }
            songs.append(Song(
                id: rid,
                name: name,
                artist: artist,
                album: album,
                coverUrl: pic,
                source: "kuwo",
                duration: mp3size > 0 ? mp3size / 15000 : 0,
                kuwoRid: rid,
                kuwoPic: pic,
                isVip: isVip
            ))
        }
        return songs
    }

    // ===== 获取播放地址（免费模式自动兜底：原平台失败→酷我同名） =====
    func getSongUrl(source: String, song: Song, quality: AudioQuality = .standard) async throws -> String {
        let freeMode = UserDefaults.standard.bool(forKey: "freeMode")
        do {
            switch source {
            case "tencent": return try await songUrlQQ(song: song)
            case "kugou": return try await songUrlKugou(song: song)
            case "kuwo": return try await songUrlKuwo(song: song)
            default: return try await songUrlNetease(id: song.id)
            }
        } catch {
            // 免费模式：原平台失败自动跨平台兜底（酷我是唯一稳定免费通道）
            if freeMode {
                if let fallback = try? await fallbackKuwo(name: song.name, artist: song.artist) {
                    return fallback
                }
            }
            throw error
        }
    }

    // 兜底：搜索酷我同名歌曲并取播放地址
    private func fallbackKuwo(name: String, artist: String) async throws -> String {
        let kw = (try? await searchKuwo(keyword: name)) ?? []
        // 优先匹配歌手，否则取第一条
        let match = kw.first(where: { $0.artist.contains(artist) && !$0.artist.isEmpty }) ?? kw.first
        guard let song = match else {
            throw NSError(domain: "Play", code: -1, userInfo: [NSLocalizedDescriptionKey: "免费模式兜底失败"])
        }
        return try await songUrlKuwo(song: song)
    }

    // 网易云：官方接口（避免失效的 Meting），风控/VIP 时自动走酷我兜底
    private func songUrlNetease(id: String) async throws -> String {
        var comps = URLComponents(string: "https://music.163.com/api/song/enhance/player/url")!
        comps.queryItems = [
            URLQueryItem(name: "ids", value: "[\(id)]"),
            URLQueryItem(name: "br", value: "128000")
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue(UserAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("https://music.163.com/", forHTTPHeaderField: "Referer")
        let (data, _) = try await session.data(for: req)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let arr = json["data"] as? [[String: Any]],
           let first = arr.first,
           let u = first["url"] as? String, u.hasPrefix("http") {
            return u
        }
        throw NSError(domain: "Play", code: -1, userInfo: [NSLocalizedDescriptionKey: "该歌曲为VIP歌曲或播放受限，请开启免费模式"])
    }

    // QQ 播放
    private func songUrlQQ(song: Song) async throws -> String {
        guard !song.songmid.isEmpty else { throw NSError(domain: "Play", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的QQ音乐歌曲"]) }
        let body = """
        {"req_0":{"module":"vkey.GetVkeyServer","method":"CgiGetVkey","param":{"guid":"10000","songmid":["\(song.songmid)"],"songtype":[0],"uin":"0","loginflag":1,"platform":"20"}},"comm":{"uin":0,"format":"json","ct":24,"cv":0}}
        """
        var req = URLRequest(url: URL(string: "https://u.y.qq.com/cgi-bin/musicu.fcg")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(UserAgent, forHTTPHeaderField: "User-Agent")
        req.httpBody = body.data(using: .utf8)
        let (data, _) = try await session.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let req0 = json["req_0"] as? [String: Any],
              let d = req0["data"] as? [String: Any],
              let midUrlInfo = d["midurlinfo"] as? [[String: Any]],
              let first = midUrlInfo.first,
              let purl = first["purl"] as? String, !purl.isEmpty,
              let sip = d["sip"] as? [String], let host = sip.first else {
            throw NSError(domain: "Play", code: -1, userInfo: [NSLocalizedDescriptionKey: "该歌曲为VIP歌曲，请开启免费模式或登录"])
        }
        return purl.hasPrefix("http") ? purl : "\(host)\(purl)"
    }

    // 酷狗播放
    private func songUrlKugou(song: Song) async throws -> String {
        guard !song.hash.isEmpty else { throw NSError(domain: "Play", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的酷狗歌曲"]) }
        let mid = "10000"
        let salt = "57ae12eb6890223e355ccfcb74edf70d"
        let appid = "1005"
        let uid = "0"
        let fileHash = song.hash.lowercased()
        let key = Data("\(fileHash)\(salt)\(appid)\(mid)\(uid)".utf8).md5Hex()
        var comps = URLComponents(string: "https://gateway.kugou.com/v5/url")!
        comps.queryItems = [
            URLQueryItem(name: "album_id", value: "0"),
            URLQueryItem(name: "area_code", value: "1"),
            URLQueryItem(name: "hash", value: fileHash),
            URLQueryItem(name: "quality", value: "128"),
            URLQueryItem(name: "behavior", value: "play"),
            URLQueryItem(name: "pid", value: "2"),
            URLQueryItem(name: "cmd", value: "26"),
            URLQueryItem(name: "page_id", value: "151369488"),
            URLQueryItem(name: "clientver", value: "11430"),
            URLQueryItem(name: "key", value: key),
            URLQueryItem(name: "appid", value: appid),
            URLQueryItem(name: "mid", value: mid),
            URLQueryItem(name: "uid", value: uid),
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue(UserAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("trackercdn.kugou.com", forHTTPHeaderField: "x-router")
        let (data, _) = try await session.data(for: req)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let d = (json["data"] as? [String: Any]) ?? json
            if let playUrl = d["play_url"] as? String, !playUrl.isEmpty { return playUrl }
            if let url = d["url"] as? String, !url.isEmpty { return url }
        }
        throw NSError(domain: "Play", code: -1, userInfo: [NSLocalizedDescriptionKey: "该歌曲为VIP歌曲，请开启免费模式或登录"])
    }

    // 酷我播放（anti.s）
    private func songUrlKuwo(song: Song) async throws -> String {
        guard !song.kuwoRid.isEmpty else { throw NSError(domain: "Play", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的酷我歌曲"]) }
        var comps = URLComponents(string: "http://antiserver.kuwo.cn/anti.s")!
        comps.queryItems = [
            URLQueryItem(name: "type", value: "convert_url3"),
            URLQueryItem(name: "rid", value: "MUSIC_\(song.kuwoRid)"),
            URLQueryItem(name: "format", value: "mp3"),
            URLQueryItem(name: "response", value: "url"),
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue(UserAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("http://www.kuwo.cn/", forHTTPHeaderField: "Referer")
        let (data, _) = try await session.data(for: req)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let url = json["url"] as? String, !url.isEmpty,
           url.hasPrefix("http"),
           !url.contains("kuwo.cn/") || url.contains("kw-bj") || url.contains("antiserver") {
            return url
        }
        throw NSError(domain: "Play", code: -1, userInfo: [NSLocalizedDescriptionKey: "该歌曲暂不支持试听，已自动切换其他音源"])
    }

    // ===== 歌词（各平台官方接口） =====
    func getLyric(source: String, id: String, songmid: String = "", kuwoRid: String = "") async throws -> String {
        switch source {
        case "tencent":
            return try await lyricQQ(songmid: songmid)
        case "kuwo":
            return try await lyricKuwo(rid: kuwoRid)
        default:
            return try await lyricNetease(id: id)
        }
    }

    private func lyricNetease(id: String) async throws -> String {
        var comps = URLComponents(string: "https://music.163.com/api/song/lyric")!
        comps.queryItems = [
            URLQueryItem(name: "id", value: id),
            URLQueryItem(name: "lv", value: "1"),
            URLQueryItem(name: "kv", value: "1"),
            URLQueryItem(name: "tv", value: "-1")
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue(UserAgent, forHTTPHeaderField: "User-Agent")
        let (data, _) = try await session.data(for: req)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let lrc = json["lrc"] as? [String: Any],
           let lyric = lrc["lyric"] as? String, !lyric.isEmpty {
            return lyric
        }
        throw NSError(domain: "Lyric", code: -1, userInfo: [NSLocalizedDescriptionKey: "暂无歌词"])
    }

    private func lyricQQ(songmid: String) async throws -> String {
        var comps = URLComponents(string: "https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg")!
        comps.queryItems = [
            URLQueryItem(name: "songmid", value: songmid),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "g_tk", value: "5381")
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue(UserAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("https://y.qq.com/", forHTTPHeaderField: "Referer")
        let (data, _) = try await session.data(for: req)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let b64 = json["lyric"] as? String, !b64.isEmpty,
           let decoded = Data(base64Encoded: b64),
           let lyric = String(data: decoded, encoding: .utf8), !lyric.isEmpty {
            return lyric
        }
        throw NSError(domain: "Lyric", code: -1, userInfo: [NSLocalizedDescriptionKey: "暂无歌词"])
    }

    private func lyricKuwo(rid: String) async throws -> String {
        guard !rid.isEmpty else { throw NSError(domain: "Lyric", code: -1, userInfo: [NSLocalizedDescriptionKey: "暂无歌词"]) }
        var comps = URLComponents(string: "http://m.kuwo.cn/newh5/singles/songinfoandlrc")!
        comps.queryItems = [
            URLQueryItem(name: "musicId", value: rid),
            URLQueryItem(name: "httpsStatus", value: "1")
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue(UserAgent, forHTTPHeaderField: "User-Agent")
        let (data, _) = try await session.data(for: req)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let d = json["data"] as? [String: Any],
           let lrclist = d["lrclist"] as? [String: Any] {
            let lines = lrclist.keys.sorted().compactMap { t in
                let text = lrclist[t] as? String ?? ""
                return text.isEmpty ? nil : "\(t) \(text)"
            }
            if !lines.isEmpty { return lines.joined(separator: "\n") }
        }
        throw NSError(domain: "Lyric", code: -1, userInfo: [NSLocalizedDescriptionKey: "暂无歌词"])
    }

    // ===== 网易云登录 =====
    func loginPhone(phone: String, password: String) async throws -> User {
        let payload: [String: Any] = [
            "phone": phone,
            "password": Data(password.utf8).md5Hex(),
            "rememberLogin": true,
            "csrf_token": "",
        ]
        // 通道1：明文接口（部分网络可用）
        var comps = URLComponents(string: "\(neteaseBase)/api/login/cellphone")!
        comps.queryItems = [
            URLQueryItem(name: "phone", value: phone),
            URLQueryItem(name: "password", value: Data(password.utf8).md5Hex()),
            URLQueryItem(name: "rememberLogin", value: "true"),
            URLQueryItem(name: "timestamp", value: "\(Int(Date().timeIntervalSince1970 * 1000))")
        ]
        var plainReq = URLRequest(url: comps.url!)
        plainReq.httpMethod = "POST"
        plainReq.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        plainReq.setValue(UserAgent, forHTTPHeaderField: "User-Agent")
        do {
            let (data, resp) = try await session.data(for: plainReq)
            if let http = resp as? HTTPURLResponse,
               let setCookie = http.allHeaderFields["Set-Cookie"] as? String, !setCookie.isEmpty {
                neteaseCookie = setCookie
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               (json["code"] as? Int) == 200 {
                return try parseNeteaseLogin(data: data)
            }
        } catch {}
        // 通道2：weapi 加密接口（住宅网络通常可用）
        let enc = NetEaseCrypto.weapi(payload)
        var req = URLRequest(url: URL(string: "\(neteaseBase)/weapi/login/cellphone")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue(UserAgent, forHTTPHeaderField: "User-Agent")
        req.setValue(neteaseCookie, forHTTPHeaderField: "Cookie")
        var wComps = URLComponents()
        wComps.queryItems = enc.map { URLQueryItem(name: $0.key, value: $0.value) }
        req.httpBody = wComps.query?.data(using: .utf8)
        let (data, resp2) = try await session.data(for: req)
        if let http = resp2 as? HTTPURLResponse,
           let setCookie = http.allHeaderFields["Set-Cookie"] as? String, !setCookie.isEmpty {
            neteaseCookie = setCookie
        }
        if data.isEmpty {
            throw NSError(domain: "Login", code: -2, userInfo: [NSLocalizedDescriptionKey: "登录接口被拦截，请切换网络或改用扫码登录"])
        }
        return try parseNeteaseLogin(data: data)
    }

    // ===== QQ 扫码登录 =====
    func qqQRCodeURL() async throws -> (imageURL: String, qrsig: String) {
        var req = URLRequest(url: URL(string: "https://ssl.ptlogin2.qq.com/ptqrshow?appid=716027609&e=2&l=M&s=3&d=72&v=4&t=0.5&daid=383&pt_3rd_aid=100497308")!)
        req.setValue(UserAgent, forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw NSError(domain: "Login", code: -1, userInfo: [NSLocalizedDescriptionKey: "获取二维码失败"]) }
        // 从 Set-Cookie 提取 qrsig
        var qrsig = ""
        if let cookies = http.allHeaderFields["Set-Cookie"] as? String {
            let parts = cookies.components(separatedBy: ";")
            for p in parts where p.hasPrefix("qrsig=") { qrsig = String(p.dropFirst(6)) }
        }
        guard !qrsig.isEmpty else { throw NSError(domain: "Login", code: -1, userInfo: [NSLocalizedDescriptionKey: "二维码签名获取失败"]) }
        // 保存二维码图片到临时文件返回 data URL
        let b64 = data.base64EncodedString()
        return ("data:image/png;base64,\(b64)", qrsig)
    }

    // ===== 网易云验证码登录 =====
    // 发送短信验证码
    func sendSmsCaptcha(phone: String) async throws {
        var req = URLRequest(url: URL(string: "\(neteaseBase)/api/sms/captcha/sent")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue(UserAgent, forHTTPHeaderField: "User-Agent")
        req.httpBody = "cellphone=\(urlEnc(phone))&ctcode=86".data(using: .utf8)
        let (data, _) = try await session.data(for: req)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let code = json["code"] as? Int, code != 200 {
            let msg = json["message"] as? String ?? "验证码发送失败"
            throw NSError(domain: "Login", code: code, userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }

    // 验证码登录（明文 + weapi 双通道，避免单一通道被风控）
    func loginPhoneCaptcha(phone: String, captcha: String) async throws -> User {
        // 通道1：明文接口
        var comps = URLComponents(string: "\(neteaseBase)/api/login/cellphone")!
        comps.queryItems = [
            URLQueryItem(name: "phone", value: phone),
            URLQueryItem(name: "captcha", value: captcha),
            URLQueryItem(name: "rememberLogin", value: "true"),
            URLQueryItem(name: "timestamp", value: "\(Int(Date().timeIntervalSince1970 * 1000))")
        ]
        var plainReq = URLRequest(url: comps.url!)
        plainReq.httpMethod = "POST"
        plainReq.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        plainReq.setValue(UserAgent, forHTTPHeaderField: "User-Agent")
        do {
            let (data, resp) = try await session.data(for: plainReq)
            if let http = resp as? HTTPURLResponse,
               let setCookie = http.allHeaderFields["Set-Cookie"] as? String, !setCookie.isEmpty {
                neteaseCookie = setCookie
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               (json["code"] as? Int) == 200 {
                return try parseNeteaseLogin(data: data)
            }
        } catch {}
        // 通道2：weapi 加密接口（住宅网络通常可用）
        let payload: [String: Any] = [
            "phone": phone,
            "captcha": captcha,
            "rememberLogin": true,
            "csrf_token": "",
        ]
        let enc = NetEaseCrypto.weapi(payload)
        var req = URLRequest(url: URL(string: "\(neteaseBase)/weapi/login/cellphone")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue(UserAgent, forHTTPHeaderField: "User-Agent")
        req.setValue(neteaseCookie, forHTTPHeaderField: "Cookie")
        var wComps = URLComponents()
        wComps.queryItems = enc.map { URLQueryItem(name: $0.key, value: $0.value) }
        req.httpBody = wComps.query?.data(using: .utf8)
        let (data, resp2) = try await session.data(for: req)
        if let http = resp2 as? HTTPURLResponse,
           let setCookie = http.allHeaderFields["Set-Cookie"] as? String, !setCookie.isEmpty {
            neteaseCookie = setCookie
        }
        if data.isEmpty {
            throw NSError(domain: "Login", code: -2, userInfo: [NSLocalizedDescriptionKey: "登录接口被拦截，请切换网络或改用扫码登录"])
        }
        return try parseNeteaseLogin(data: data)
    }

    // 网易云扫码登录：获取 unikey
    func neteaseQRCode() async throws -> String {
        var req = URLRequest(url: URL(string: "\(neteaseBase)/api/login/qrcode/unikey?timestamp=\(Int(Date().timeIntervalSince1970 * 1000))")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue(UserAgent, forHTTPHeaderField: "User-Agent")
        req.httpBody = "type=1".data(using: .utf8)
        let (data, _) = try await session.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let unikey = json["unikey"] as? String, !unikey.isEmpty else {
            throw NSError(domain: "Login", code: -1, userInfo: [NSLocalizedDescriptionKey: "获取二维码失败"])
        }
        return unikey
    }

    // 网易云扫码登录：轮询检查（801等待扫码 802已扫码待确认 803成功）
    func neteaseQRCheck(unikey: String) async throws -> (code: Int, user: User?) {
        var req = URLRequest(url: URL(string: "\(neteaseBase)/api/login/qrcode/client/login?timestamp=\(Int(Date().timeIntervalSince1970 * 1000))")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue(UserAgent, forHTTPHeaderField: "User-Agent")
        req.httpBody = "key=\(urlEnc(unikey))&type=1".data(using: .utf8)
        let (data, resp) = try await session.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = json["code"] as? Int else {
            return (0, nil)
        }
        if code == 803, let http = resp as? HTTPURLResponse,
           let setCookie = http.allHeaderFields["Set-Cookie"] as? String, !setCookie.isEmpty {
            neteaseCookie = setCookie
            // 用 cookie 拉取用户信息
            let user = try? await fetchNeteaseProfile()
            return (803, user)
        }
        return (code, nil)
    }

    // 用当前 cookie 拉取网易云用户信息
    func fetchNeteaseProfile() async throws -> User {
        var req = URLRequest(url: URL(string: "\(neteaseBase)/api/nuser/account/get")!)
        req.setValue(UserAgent, forHTTPHeaderField: "User-Agent")
        req.setValue(neteaseCookie, forHTTPHeaderField: "Cookie")
        let (data, _) = try await session.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profile = json["profile"] as? [String: Any] else {
            throw NSError(domain: "Login", code: -1, userInfo: [NSLocalizedDescriptionKey: "获取用户信息失败"])
        }
        return User(
            uid: "\(profile["userId"] as? Int ?? 0)",
            nickname: profile["nickname"] as? String ?? "用户",
            avatarUrl: profile["avatarUrl"] as? String ?? "",
            vipType: profile["vipType"] as? Int ?? 0,
            vipLevel: profile["vipLevel"] as? Int ?? 0,
            level: profile["level"] as? Int ?? 0,
            platform: "netease"
        )
    }

    // ===== 评论（各平台评论数据接口） =====
    func getComments(song: Song, limit: Int = 20, offset: Int = 0) async throws -> [MusicComment] {
        switch song.source {
        case "netease":
            return try await commentsNetease(id: song.id, limit: limit, offset: offset)
        case "tencent":
            return try await commentsQQ(song: song, limit: limit)
        case "kuwo":
            return try await commentsKuwo(song: song, limit: limit)
        default:
            return try await commentsNetease(id: song.id, limit: limit, offset: offset)
        }
    }

    // 网易云评论
    private func commentsNetease(id: String, limit: Int, offset: Int) async throws -> [MusicComment] {
        var req = URLRequest(url: URL(string: "\(neteaseBase)/api/v1/resource/comments/R_SO_4_\(id)?limit=\(limit)&offset=\(offset)")!)
        req.setValue(UserAgent, forHTTPHeaderField: "User-Agent")
        let (data, _) = try await session.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        let hot = (json["hotComments"] as? [[String: Any]]) ?? []
        let new = (json["comments"] as? [[String: Any]]) ?? []
        var result: [MusicComment] = []
        for c in hot {
            let user = c["user"] as? [String: Any] ?? [:]
            result.append(MusicComment(
                id: "\(c["commentId"] as? Int ?? 0)",
                user: user["nickname"] as? String ?? "匿名",
                avatar: user["avatarUrl"] as? String ?? "",
                content: c["content"] as? String ?? "",
                likedCount: c["likedCount"] as? Int ?? 0,
                time: c["time"] as? Int ?? 0
            ))
        }
        for c in new {
            let user = c["user"] as? [String: Any] ?? [:]
            result.append(MusicComment(
                id: "\(c["commentId"] as? Int ?? 0)",
                user: user["nickname"] as? String ?? "匿名",
                avatar: user["avatarUrl"] as? String ?? "",
                content: c["content"] as? String ?? "",
                likedCount: c["likedCount"] as? Int ?? 0,
                time: c["time"] as? Int ?? 0
            ))
        }
        return result
    }

    // QQ 评论（fcg_global_comment_h5）
    private func commentsQQ(song: Song, limit: Int) async throws -> [MusicComment] {
        var req = URLRequest(url: URL(string: "https://c.y.qq.com/base/fcgi-bin/fcg_global_comment_h5.fcg?reqtype=2&biztype=1&topid=\(song.id)&cmd=6&pagenum=0&pagesize=\(limit)&format=json")!)
        req.setValue(UserAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("https://y.qq.com/", forHTTPHeaderField: "Referer")
        let (data, _) = try await session.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        let comment = (json["comment"] as? [String: Any]) ?? [:]
        let list = (comment["commentlist"] as? [[String: Any]]) ?? []
        var result: [MusicComment] = []
        for c in list {
            let user = c["userinfo"] as? [String: Any] ?? c["user"] as? [String: Any] ?? [:]
            result.append(MusicComment(
                id: "\(c["commentid"] as? String ?? UUID().uuidString)",
                user: user["nick"] as? String ?? user["nickname"] as? String ?? "匿名",
                avatar: user["avatar"] as? String ?? "",
                content: c["rootcommentcontent"] as? String ?? c["commentcontent"] as? String ?? "",
                likedCount: c["praisenum"] as? Int ?? 0,
                time: c["time"] as? Int ?? 0
            ))
        }
        return result
    }

    // 酷我评论
    private func commentsKuwo(song: Song, limit: Int) async throws -> [MusicComment] {
        var req = URLRequest(url: URL(string: "https://www.kuwo.cn/comment/get_comments?type=get_comment&rid=\(song.id)&page=1&rows=\(limit)")!)
        req.setValue(UserAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("https://www.kuwo.cn/", forHTTPHeaderField: "Referer")
        let (data, _) = try await session.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let comments = json["comments"] as? [[String: Any]] else { return [] }
        var result: [MusicComment] = []
        for c in comments {
            let user = c["user"] as? [String: Any] ?? [:]
            result.append(MusicComment(
                id: "\(c["id"] as? Int ?? 0)",
                user: user["userName"] as? String ?? user["nickname"] as? String ?? "匿名",
                avatar: user["pic"] as? String ?? "",
                content: c["msg"] as? String ?? c["content"] as? String ?? "",
                likedCount: c["likeNum"] as? Int ?? 0,
                time: (c["time"] as? Int) ?? 0
            ))
        }
        return result
    }

    // ===== 工具 =====
    private var UserAgent: String {
        "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"
    }

    // 解析网易云登录响应（密码/验证码共用）
    private func parseNeteaseLogin(data: Data) throws -> User {
        var json: [String: Any]?
        do {
            json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch {
            throw NSError(domain: "Login", code: -1, userInfo: [NSLocalizedDescriptionKey: "登录响应异常，请切换网络或改用扫码登录"])
        }
        guard let json else {
            throw NSError(domain: "Login", code: -1, userInfo: [NSLocalizedDescriptionKey: "登录失败，请检查网络"])
        }
        let code = json["code"] as? Int ?? -1
        guard code == 200 else {
            let msg = json["message"] as? String ?? (code == 400 ? "验证码错误或已过期" : "登录失败")
            throw NSError(domain: "Login", code: code, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        guard let profile = json["profile"] as? [String: Any] else {
            throw NSError(domain: "Login", code: -1, userInfo: [NSLocalizedDescriptionKey: "登录响应异常"])
        }
        if let resp = json["cookie"] as? String, !resp.isEmpty { neteaseCookie = resp }
        return User(
            uid: "\(profile["userId"] as? Int ?? 0)",
            nickname: profile["nickname"] as? String ?? "用户",
            avatarUrl: profile["avatarUrl"] as? String ?? "",
            vipType: profile["vipType"] as? Int ?? 0,
            vipLevel: profile["vipLevel"] as? Int ?? 0,
            level: profile["level"] as? Int ?? 0,
            platform: "netease"
        )
    }

    private func urlEnc(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s
    }
}
