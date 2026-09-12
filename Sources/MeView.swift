import SwiftUI

// 我的：三平台登录 + 歌单
struct MeView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var player: MusicPlayer

    @State private var user: User?
    @State private var playlists: [[String: Any]] = []
    @State private var showLogin = false
    @State private var isLoadingPlaylists = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 用户信息
                if let user = user {
                    HStack(spacing: 14) {
                        AsyncImage(url: URL(string: user.avatarUrl)) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(theme.primaryColor.opacity(0.3))
                        }
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 5) {
                            Text(user.nickname).font(.title3).bold().foregroundColor(theme.textColor)
                            HStack(spacing: 6) {
                                Text(user.platform == "netease" ? "网易云" : (user.platform == "tencent" ? "QQ音乐" : "酷我音乐"))
                                    .font(.system(size: 9)).foregroundColor(.white)
                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(theme.primaryColor).cornerRadius(4)
                                Text(user.vipName)
                                    .font(.system(size: 10)).foregroundColor(user.isVip ? .orange : theme.textSecondaryColor)
                                Text("Lv.\(user.level)")
                                    .font(.system(size: 10)).foregroundColor(theme.textSecondaryColor)
                            }
                        }
                        Spacer()
                        Button("切换") { showLogin = true }
                            .font(.caption).foregroundColor(theme.primaryColor)
                    }
                    .padding(16)
                    .background {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial).opacity(theme.glassIntensity)
                    }
                } else {
                    Button { showLogin = true } label: {
                        VStack(spacing: 10) {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 40))
                                .foregroundColor(theme.primaryColor)
                            Text("登录以查看歌单")
                                .font(.subheadline).foregroundColor(theme.textColor)
                            Text("支持 网易云 / QQ音乐 / 酷我音乐")
                                .font(.caption).foregroundColor(theme.textSecondaryColor)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .background {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial).opacity(theme.glassIntensity)
                        }
                    }
                    .buttonStyle(.plain)
                }

                // 歌单
                if user != nil {
                    HStack {
                        Text("我的歌单").font(.headline).foregroundColor(theme.textColor)
                        Spacer()
                        if isLoadingPlaylists {
                            ProgressView().tint(theme.primaryColor)
                        }
                    }
                    .padding(.top, 8)

                    if playlists.isEmpty && !isLoadingPlaylists {
                        Text("点击刷新加载歌单")
                            .font(.caption).foregroundColor(theme.textSecondaryColor)
                            .padding(.vertical, 20)
                    } else {
                        ForEach(playlists.indices, id: \.self) { i in
                            let pl = playlists[i]
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(theme.primaryColor.opacity(0.2))
                                    .frame(width: 46, height: 46)
                                    .overlay(Image(systemName: "music.note.list").foregroundColor(theme.primaryColor))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(pl["name"] as? String ?? "").font(.subheadline).foregroundColor(theme.textColor).lineLimit(1)
                                    Text("\(pl["count"] as? Int ?? 0) 首").font(.caption).foregroundColor(theme.textSecondaryColor)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundColor(theme.textSecondaryColor)
                            }
                            .padding(12)
                            .background(theme.cardColor)
                            .cornerRadius(14)
                        }
                    }
                }
            }
            .padding(.horizontal, 20).padding(.top, 24)
        }
        .background(theme.bgColor.ignoresSafeArea())
        .sheet(isPresented: $showLogin) {
            LoginView(user: $user, playlists: $playlists, isLoading: $isLoadingPlaylists)
                .environmentObject(theme)
                .presentationDetents([.large])
        }
    }
}

// 三平台登录页
struct LoginView: View {
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.dismiss) var dismiss
    @Binding var user: User?
    @Binding var playlists: [[String: Any]]
    @Binding var isLoading: Bool

    @State private var selectedPlatform = "netease"
    @State private var phone = ""
    @State private var password = ""
    @State private var isLoadingLogin = false
    @State private var errorMsg: String?
    @State private var qrImageURL: String?
    @State private var qrSig: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("登录").font(.headline).foregroundColor(theme.textColor).padding(.top, 20)

            // 平台选择
            HStack(spacing: 10) {
                platformButton("netease", "网易云")
                platformButton("tencent", "QQ音乐")
                platformButton("kuwo", "酷我")
            }
            .padding(.horizontal, 24)

            if selectedPlatform == "netease" {
                // 网易云：手机号+密码
                VStack(spacing: 12) {
                    TextField("手机号", text: $phone)
                        .keyboardType(.phonePad)
                        .textFieldStyle(.roundedBorder)
                        .font(.subheadline)
                    SecureField("密码", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .font(.subheadline)
                }
                .padding(.horizontal, 24)

                Button {
                    login()
                } label: {
                    Text(isLoadingLogin ? "登录中…" : "登录")
                        .font(.subheadline).bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(theme.primaryColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .disabled(isLoadingLogin)
            } else if selectedPlatform == "tencent" {
                // QQ 音乐：扫码登录
                VStack(spacing: 14) {
                    if let url = qrImageURL {
                        if url.hasPrefix("data:") {
                            let b64 = url.replacingOccurrences(of: "data:image/png;base64,", with: "")
                            if let data = Data(base64Encoded: b64), let img = UIImage(data: data) {
                                Image(uiImage: img)
                                    .interpolation(.none)
                                    .resizable()
                                    .frame(width: 200, height: 200)
                            }
                        }
                        Text("请使用 QQ 扫码登录")
                            .font(.caption).foregroundColor(theme.textSecondaryColor)
                        Text("登录后即可查看 QQ 音乐歌单（扫码后需在本页等待几秒）")
                            .font(.system(size: 10)).foregroundColor(theme.textSecondaryColor)
                    } else {
                        ProgressView("获取二维码…")
                        Button("重新获取") { loadQR() }
                            .font(.caption).foregroundColor(theme.primaryColor)
                    }
                }
                .padding(.top, 30)
                .onAppear { loadQR() }
            } else {
                // 酷我：提示
                VStack(spacing: 14) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 34)).foregroundColor(.orange)
                    Text("酷我音乐登录暂需网页授权\n建议使用网易云或QQ音乐登录")
                        .font(.subheadline).foregroundColor(theme.textSecondaryColor)
                        .multilineTextAlignment(.center)
                    Text("登录成功后可在任意平台查看歌单")
                        .font(.system(size: 10)).foregroundColor(theme.textSecondaryColor)
                }
                .padding(.top, 40)
            }

            if let err = errorMsg {
                Text(err).font(.caption).foregroundColor(.red)
            }

            Spacer()
        }
        .background(theme.bgColor)
    }

    private func platformButton(_ id: String, _ name: String) -> some View {
        Button {
            selectedPlatform = id
            errorMsg = nil
        } label: {
            Text(name)
                .font(.subheadline).bold()
                .padding(.horizontal, 18).padding(.vertical, 8)
                .background(selectedPlatform == id ? theme.primaryColor : theme.primaryColor.opacity(0.12))
                .foregroundColor(selectedPlatform == id ? .white : theme.primaryColor)
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    private func login() {
        guard !phone.isEmpty, !password.isEmpty else {
            errorMsg = "请输入手机号和密码"
            return
        }
        isLoadingLogin = true
        errorMsg = nil
        Task {
            do {
                let u = try await MusicAPI.shared.loginPhone(phone: phone, password: password)
                await MainActor.run {
                    user = u
                    isLoadingLogin = false
                    dismiss()
                }
                await loadPlaylists(platform: "netease")
            } catch {
                await MainActor.run {
                    errorMsg = error.localizedDescription
                    isLoadingLogin = false
                }
            }
        }
    }

    private func loadQR() {
        qrImageURL = nil
        Task {
            do {
                let (url, sig) = try await MusicAPI.shared.qqQRCodeURL()
                await MainActor.run {
                    qrImageURL = url
                    qrSig = sig
                }
            } catch {
                await MainActor.run { errorMsg = error.localizedDescription }
            }
        }
    }

    private func loadPlaylists(platform: String) async {
        isLoading = true
        // 简化：拉取网易云歌单需要 cookie 认证；此处用 uid 尝试
        var items: [[String: Any]] = []
        if platform == "netease", let user = user {
            do {
                var req = URLRequest(url: URL(string: "https://music.163.com/api/user/playlist?uid=\(user.uid)&limit=20&offset=0")!)
                req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
                let (data, _) = try await URLSession.shared.data(for: req)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let pls = json["playlist"] as? [[String: Any]] {
                    items = pls.map { ["name": $0["name"] as? String ?? "未命名", "count": $0["trackCount"] as? Int ?? 0] }
                }
            } catch {}
        }
        await MainActor.run {
            playlists = items
            isLoading = false
        }
    }
}
