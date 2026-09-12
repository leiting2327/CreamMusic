import SwiftUI

// 我的：三平台登录 + 歌单
struct MeView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var player: MusicPlayer

    @State private var user: User?
    @State private var playlists: [[String: Any]] = []
    @State private var showLogin = false
    @State private var isLoadingPlaylists = false
    @State private var showSettings = false

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
                // 设置入口
                Button {
                    showSettings = true
                } label: {
                    HStack {
                        Image(systemName: "gearshape")
                            .foregroundColor(theme.primaryColor)
                            .frame(width: 34, height: 34)
                            .background(theme.primaryColor.opacity(0.12))
                            .clipShape(Circle())
                        Text("设置").font(.subheadline).foregroundColor(theme.textColor)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundColor(theme.textSecondaryColor)
                    }
                    .padding(14)
                    .background {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial).opacity(theme.glassIntensity)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20).padding(.top, 24)
        }
        .background(theme.bgColor.ignoresSafeArea())
        .sheet(isPresented: $showLogin) {
            LoginView(user: $user, playlists: $playlists, isLoading: $isLoadingPlaylists)
                .environmentObject(theme)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(theme)
                .environmentObject(player)
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
    @State private var neteaseLoginMode = 0 // 0=密码 1=验证码 2=扫码
    @State private var phone = ""
    @State private var password = ""
    @State private var captcha = ""
    @State private var isLoadingLogin = false
    @State private var errorMsg: String?
    @State private var qrImageURL: String?
    @State private var qrSig: String?
    @State private var neteaseUnikey: String?
    @State private var neteaseQRImage: UIImage?
    @State private var qrPolling = false

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
                // 网易云：登录方式切换
                HStack(spacing: 10) {
                    modeButton(0, "密码登录")
                    modeButton(1, "验证码登录")
                    modeButton(2, "扫码登录")
                }
                .padding(.horizontal, 24)

                if neteaseLoginMode == 0 {
                    // 密码登录
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
                } else if neteaseLoginMode == 1 {
                    // 验证码登录
                    VStack(spacing: 12) {
                        TextField("手机号", text: $phone)
                            .keyboardType(.phonePad)
                            .textFieldStyle(.roundedBorder)
                            .font(.subheadline)
                        HStack {
                            TextField("验证码", text: $captcha)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                                .font(.subheadline)
                            Button("获取验证码") {
                                sendCaptcha()
                            }
                            .font(.system(size: 12))
                            .foregroundColor(theme.primaryColor)
                            .disabled(isLoadingLogin)
                        }
                    }
                    .padding(.horizontal, 24)

                    Button {
                        loginCaptcha()
                    } label: {
                        Text(isLoadingLogin ? "登录中…" : "验证码登录")
                            .font(.subheadline).bold()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(theme.primaryColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)
                    .disabled(isLoadingLogin)
                } else {
                    // 扫码登录
                    VStack(spacing: 14) {
                        if let img = neteaseQRImage {
                            Image(uiImage: img)
                                .interpolation(.none)
                                .resizable()
                                .frame(width: 200, height: 200)
                                .cornerRadius(12)
                            Text("请使用网易云 App 扫码登录")
                                .font(.caption).foregroundColor(theme.textSecondaryColor)
                            if qrPolling {
                                ProgressView("等待扫码…")
                            } else {
                                Button("重新获取二维码") { loadNeteaseQR() }
                                    .font(.caption).foregroundColor(theme.primaryColor)
                            }
                        } else {
                            ProgressView("获取二维码…")
                            Button("重新获取") { loadNeteaseQR() }
                                .font(.caption).foregroundColor(theme.primaryColor)
                        }
                    }
                    .padding(.top, 30)
                    .onAppear { loadNeteaseQR() }
                }
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

    private func modeButton(_ id: Int, _ name: String) -> some View {
        Button {
            neteaseLoginMode = id
            errorMsg = nil
        } label: {
            Text(name)
                .font(.system(size: 12)).bold()
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(neteaseLoginMode == id ? theme.primaryColor : theme.primaryColor.opacity(0.12))
                .foregroundColor(neteaseLoginMode == id ? .white : theme.primaryColor)
                .cornerRadius(8)
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

    // 网易云扫码：获取二维码
    private func loadNeteaseQR() {
        neteaseQRImage = nil
        neteaseUnikey = nil
        qrPolling = false
        Task {
            do {
                let unikey = try await MusicAPI.shared.neteaseQRCode()
                let url = URL(string: "https://music.163.com/login?codekey=\(unikey)")!
                let (data, _) = try await URLSession.shared.data(from: url)
                await MainActor.run {
                    neteaseUnikey = unikey
                    neteaseQRImage = UIImage(data: data)
                    qrPolling = true
                    startQRPolling(unikey: unikey)
                }
            } catch {
                await MainActor.run { errorMsg = error.localizedDescription }
            }
        }
    }

    // 网易云扫码：轮询状态
    private func startQRPolling(unikey: String) {
        Task {
            while qrPolling && neteaseUnikey == unikey {
                do {
                    let (code, u) = try await MusicAPI.shared.neteaseQRCheck(unikey: unikey)
                    await MainActor.run {
                        if code == 803, let u {
                            qrPolling = false
                            user = u
                            dismiss()
                            Task { await loadPlaylists(platform: "netease") }
                        } else if code == 802 {
                            errorMsg = "已扫码，请在手机上确认"
                        }
                    }
                } catch {}
                if qrPolling {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
        }
    }

    // 网易云发送验证码
    private func sendCaptcha() {
        guard !phone.isEmpty else {
            errorMsg = "请输入手机号"
            return
        }
        errorMsg = nil
        Task {
            do {
                try await MusicAPI.shared.sendSmsCaptcha(phone: phone)
                await MainActor.run { errorMsg = "验证码已发送，请注意查收" }
            } catch {
                await MainActor.run { errorMsg = error.localizedDescription }
            }
        }
    }

    // 网易云验证码登录
    private func loginCaptcha() {
        guard !phone.isEmpty, !captcha.isEmpty else {
            errorMsg = "请输入手机号和验证码"
            return
        }
        isLoadingLogin = true
        errorMsg = nil
        Task {
            do {
                let u = try await MusicAPI.shared.loginPhoneCaptcha(phone: phone, captcha: captcha)
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
