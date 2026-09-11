import Foundation

// 歌曲模型
struct Song: Identifiable, Codable {
    let id: String
    let name: String
    let artist: String
    let album: String
    let coverUrl: String
    let source: String // netease / tencent / kugou
    let duration: Int
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
    var neteaseBase = "https://netease-cloud-music-api-five-roan-88.vercel.app"

    // 搜索（支持 netease/tencent/kugou）
    func search(source: String, keyword: String) async throws -> [Song] {
        let server = source == "tencent" ? "tencent" : (source == "kugou" ? "kugou" : "netease")
        let encoded = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword
        let url = URL(string: "\(metingBase)?server=\(server)&type=search&name=\(encoded)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
        return arr.map { dict in
            Song(
                id: dict["urlid"] as? String ?? dict["id"] as? String ?? "",
                name: dict["name"] as? String ?? "未知",
                artist: dict["artist"] as? String ?? "",
                album: dict["album"] as? String ?? "",
                coverUrl: dict["pic"] as? String ?? "",
                source: source,
                duration: (dict["time"] as? Int ?? 0) / 1000
            )
        }
    }

    // 获取播放地址
    func getSongUrl(source: String, id: String) async throws -> String {
        let server = source == "tencent" ? "tencent" : (source == "kugou" ? "kugou" : "netease")
        let url = URL(string: "\(metingBase)?server=\(server)&type=url&id=\(id)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if str.hasPrefix("{") {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return json["url"] as? String ?? ""
            }
        }
        return str.replacingOccurrences(of: "\"", with: "")
    }

    // 获取歌词
    func getLyric(source: String, id: String) async throws -> String {
        let server = source == "tencent" ? "tencent" : (source == "kugou" ? "kugou" : "netease")
        let url = URL(string: "\(metingBase)?server=\(server)&type=lrc&id=\(id)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return String(data: data, encoding: .utf8) ?? ""
    }

    // 手机号登录网易云
    func loginPhone(phone: String, password: String) async throws -> User {
        let encodedPwd = password.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? password
        let url = URL(string: "\(neteaseBase)/login/cellphone?phone=\(phone)&password=\(encodedPwd)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        guard let code = json["code"] as? Int, code == 200,
              let profile = json["profile"] as? [String: Any] else {
            throw NSError(domain: "Login", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: json["message"] as? String ?? "登录失败"])
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
}
