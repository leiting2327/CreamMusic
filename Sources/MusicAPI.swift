import Foundation

// 歌曲模型
struct Song: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let artist: String
    let album: String
    let coverUrl: String
    let source: String // netease / tencent / kugou
    let duration: Int
    // QQ 播放所需
    var songmid: String = ""
    // 酷狗播放所需
    var hash: String = ""
}

// 用户模型（含会员等级）
struct User: Codable {
    let uid: String
    let nickname: String
    let avatarUrl: String
    let vipType: Int      // 0=普通 1=VIP 11=音乐包
    let vipLevel: Int
    let level: Int

    var vipName: String {
        switch vipType {
        case 11: return "音乐包"
        case 1: return "黑胶VIP"
        default: return "普通用户"
        }
    }
    var isVip: Bool { vipType > 0 }
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

    // ===== 搜索（三平台官方接口） =====
    func search(source: String, keyword: String) async throws -> [Song] {
        switch source {
        case "tencent":
            return try await searchQQ(keyword: keyword)
        case "kugou":
            return try await searchKugou(keyword: keyword)
        default:
            return try await searchNetease(keyword: keyword)
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
            throw NSError(domain: "Search", code: -1, userInfo: [NSLocalizedDescriptionKey: "网易云搜索失败，请稍后重试"])
        }
        return songs.map { s in
            let al = s["al"] as? [String: Any] ?? [:]
            let ar = s["ar"] as? [[String: Any]] ?? []
            let artists = ar.compactMap { $0["name"] as? String }.joined(separator: "/")
            let dur = s["dt"] as? Int ?? 0
            return Song(
                id: "\(s["id"] as? Int ?? 0)",
                name: s["name"] as? String ?? "未知",
                artist: artists,
                album: al["name"] as? String ?? "",
                coverUrl: al["picUrl"] as? String ?? "",
                source: "netease",
                duration: dur / 1000
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
            throw NSError(domain: "Search", code: -1, userInfo: [NSLocalizedDescriptionKey: "QQ音乐搜索失败，请稍后重试"])
        }
        return list.map { s in
            let singers = (s["singer"] as? [[String: Any]]) ?? []
            let artists = singers.compactMap { $0["name"] as? String }.joined(separator: "/")
            return Song(
                id: "\(s["songmid"] as? String ?? "")",
                name: s["songname"] as? String ?? "未知",
                artist: artists,
                album: s["albumname"] as? String ?? "",
                coverUrl: "https://y.gtimg.cn/music/photo_new/T002R300x300M000\(s["albummid"] as? String ?? "").jpg",
                source: "tencent",
                duration: (s["interval"] as? Int) ?? 0,
                songmid: s["songmid"] as? String ?? ""
            )
        }
    }

    // 酷狗官方搜索
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
            throw NSError(domain: "Search", code: -1, userInfo: [NSLocalizedDescriptionKey: "酷狗搜索失败，请稍后重试"])
        }
        return list.map { s in
            let hash = s["hash"] as? String ?? ""
            let album = s["album_name"] as? String ?? ""
            let cover = s["imgUrl"] as? String ?? s["img"] as? String ?? ""
            let dur = s["duration"] as? Int ?? 0
            return Song(
                id: hash,
                name: s["songname"] as? String ?? "未知",
                artist: s["singername"] as? String ?? "",
                album: album,
                coverUrl: cover.replacingOccurrences(of: "{size}", with: "400"),
                source: "kugou",
                duration: dur,
                hash: hash
            )
        }
    }

    // ===== 获取播放地址 =====
    func getSongUrl(source: String, song: Song) async throws -> String {
        switch source {
        case "tencent":
            return try await songUrlQQ(song: song)
        case "kugou":
            return try await songUrlKugou(song: song)
        default:
            return try await songUrlNetease(id: song.id)
        }
    }

    // 网易云：Meting 接口直接返回音频流
    private func songUrlNetease(id: String) async throws -> String {
        let url = URL(string: "\(metingBase)?server=netease&type=url&id=\(id)")!
        var req = URLRequest(url: url)
        req.setValue(UserAgent, forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode == 200,
           let contentType = http.allHeaderFields["Content-Type"] as? String,
           contentType.contains("audio") || contentType.contains("mpeg") || contentType.contains("octet") {
            return url.absoluteString // 直接返回 Meting 流式地址
        }
        // 如果返回的是 JSON（错误信息）
        if let str = String(data: data, encoding: .utf8), str.contains("\"url\"") {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let u = json["url"] as? String, !u.isEmpty {
                return u
            }
        }
        // 部分歌曲需要 vip，给出明确错误
        throw NSError(domain: "Play", code: -1, userInfo: [NSLocalizedDescriptionKey: "该歌曲暂不支持试听（可能为VIP歌曲）"])
    }

    // QQ 音乐播放地址
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
            throw NSError(domain: "Play", code: -1, userInfo: [NSLocalizedDescriptionKey: "该歌曲暂不支持试听（可能为VIP歌曲）"])
        }
        let p = purl.hasPrefix("http") ? purl : "\(host)\(purl)"
        return p
    }

    // 酷狗播放地址
    private func songUrlKugou(song: Song) async throws -> String {
        guard !song.hash.isEmpty else { throw NSError(domain: "Play", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的酷狗歌曲"]) }
        // 酷狗官方 v5/url 接口（带签名）
        let mid = "10000"
        let salt = "57ae12eb6890223e355ccfcb74edf70d"
        let appid = "1005"
        let uid = "0"
        let fileHash = song.hash.lowercased()
        let key = md5("\(fileHash)\(salt)\(appid)\(mid)\(uid)")
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
        req.setValue(mid, forHTTPHeaderField: "mid")
        req.setValue("-", forHTTPHeaderField: "dfid")
        let (data, _) = try await session.data(for: req)
        if let str = String(data: data, encoding: .utf8), !str.isEmpty {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let d = (json["data"] as? [String: Any]) ?? json
                if let playUrl = d["play_url"] as? String, !playUrl.isEmpty {
                    return playUrl
                }
                if let url = d["url"] as? String, !url.isEmpty {
                    return url
                }
            }
        }
        throw NSError(domain: "Play", code: -1, userInfo: [NSLocalizedDescriptionKey: "该歌曲暂不支持试听（可能为VIP歌曲）"])
    }

    // ===== 歌词 =====
    func getLyric(source: String, id: String) async throws -> String {
        let server = source == "tencent" ? "tencent" : (source == "kugou" ? "kugou" : "netease")
        let url = URL(string: "\(metingBase)?server=\(server)&type=lrc&id=\(id)")!
        var req = URLRequest(url: url)
        req.setValue(UserAgent, forHTTPHeaderField: "User-Agent")
        let (data, _) = try await session.data(for: req)
        return String(data: data, encoding: .utf8) ?? ""
    }

    // ===== 网易云登录（weapi 加密，不依赖第三方实例） =====
    func loginPhone(phone: String, password: String) async throws -> User {
        let payload: [String: Any] = [
            "phone": phone,
            "password": md5(password),
            "rememberLogin": true,
            "csrf_token": "",
        ]
        let enc = NetEaseCrypto.weapi(payload)
        var req = URLRequest(url: URL(string: "\(neteaseBase)/weapi/login/cellphone")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue(UserAgent, forHTTPHeaderField: "User-Agent")
        req.setValue(neteaseCookie, forHTTPHeaderField: "Cookie")
        var comps = URLComponents()
        comps.queryItems = enc.map { URLQueryItem(name: $0.key, value: $0.value) }
        req.httpBody = comps.query?.data(using: .utf8)
        let (data, _) = try await session.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "Login", code: -1, userInfo: [NSLocalizedDescriptionKey: "登录失败，请检查网络"])
        }
        let code = json["code"] as? Int ?? -1
        guard code == 200 else {
            let msg = json["message"] as? String ?? "账号或密码错误"
            throw NSError(domain: "Login", code: code, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        guard let profile = json["profile"] as? [String: Any] else {
            throw NSError(domain: "Login", code: -1, userInfo: [NSLocalizedDescriptionKey: "登录响应异常"])
        }
        // 保存 cookie（用于后续请求）
        if let resp = json["cookie"] as? String, !resp.isEmpty {
            neteaseCookie = resp
        }
        return User(
            uid: "\(profile["userId"] as? Int ?? 0)",
            nickname: profile["nickname"] as? String ?? "用户",
            avatarUrl: profile["avatarUrl"] as? String ?? "",
            vipType: profile["vipType"] as? Int ?? 0,
            vipLevel: profile["vipLevel"] as? Int ?? 0,
            level: profile["level"] as? Int ?? 0
        )
    }

    // ===== 工具 =====
    private var UserAgent: String {
        "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"
    }

    private func urlEnc(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s
    }

    private func md5(_ s: String) -> String {
        Data(s.utf8).md5Hex()
    }
}
