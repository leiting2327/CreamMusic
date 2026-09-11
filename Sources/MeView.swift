import SwiftUI

struct MeView: View {
    @EnvironmentObject var theme: ThemeManager
    @State private var user: User?
    @State private var showLogin = false
    @State private var phone = ""
    @State private var password = ""
    @State private var loginMsg = ""
    @State private var isLoggingIn = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let user = user {
                    // 已登录 - 用户信息卡片
                    HStack(spacing: 16) {
                        Circle()
                            .fill(theme.primaryColor.opacity(0.3))
                            .frame(width: 64, height: 64)
                            .overlay(Image(systemName: "person.fill").foregroundColor(theme.primaryColor))
                        VStack(alignment: .leading, spacing: 6) {
                            Text(user.nickname).font(.title3).bold().foregroundColor(theme.textColor)
                            HStack(spacing: 8) {
                                if user.isVip {
                                    Label("👑 \(user.vipName)", systemImage: "")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(red: 0.72, green: 0.53, blue: 0.04))
                                        .padding(.horizontal, 8).padding(.vertical, 3)
                                        .background(Color(red: 1.0, green: 0.95, blue: 0.80))
                                        .cornerRadius(6)
                                }
                                Text("Lv.\(user.level)").font(.caption).foregroundColor(theme.textSecondaryColor)
                            }
                        }
                        Spacer()
                    }
                    .padding(20)
                    .glassCard()

                    // 会员等级详情
                    VStack(alignment: .leading, spacing: 6) {
                        Text("会员状态").font(.subheadline).foregroundColor(theme.textSecondaryColor)
                        Text(user.vipName)
                            .font(.title).bold()
                            .foregroundColor(user.isVip ? Color(red: 0.72, green: 0.53, blue: 0.04) : theme.textColor)
                        Text(user.isVip ? "尊享无损音质、免广告、专属曲库等特权" : "开通黑胶VIP享受无损音质、免广告等特权")
                            .font(.caption).foregroundColor(theme.textSecondaryColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .glassCard()

                    // 功能列表
                    VStack(spacing: 0) {
                        MeRow(icon: "folder.fill", text: "我的歌单")
                        Divider().padding(.horizontal, 16)
                        MeRow(icon: "heart.fill", text: "我喜欢的音乐")
                        Divider().padding(.horizontal, 16)
                        MeRow(icon: "clock.fill", text: "最近播放")
                        Divider().padding(.horizontal, 16)
                        MeRow(icon: "arrow.down.circle.fill", text: "本地下载")
                    }
                    .glassCard()

                    Button("退出登录") {
                        user = nil
                        UserDefaults.standard.removeObject(forKey: "user")
                    }
                    .font(.subheadline)
                    .foregroundColor(Color(red: 0.76, green: 0.55, blue: 0.62))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(theme.cardColor)
                    .cornerRadius(theme.cornerRadius)
                } else {
                    // 未登录
                    VStack(spacing: 16) {
                        Circle()
                            .fill(theme.primaryColor.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .overlay(Image(systemName: "person.fill").font(.largeTitle).foregroundColor(theme.primaryColor))
                        Text("登录后同步歌单和会员").font(.subheadline).foregroundColor(theme.textSecondaryColor)
                        Button("登录网易云音乐") { showLogin = true }
                            .font(.headline).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(theme.primaryColor)
                            .cornerRadius(theme.cornerRadius)
                    }
                    .padding(.top, 60)
                }
            }
            .padding(20)
        }
        .sheet(isPresented: $showLogin) {
            loginSheet
        }
        .onAppear { loadUser() }
    }

    private var loginSheet: some View {
        VStack(spacing: 16) {
            Text("登录网易云音乐").font(.title2).bold().foregroundColor(theme.textColor)
            Text("登录后可查看会员等级和同步歌单").font(.caption).foregroundColor(theme.textSecondaryColor)
            TextField("手机号", text: $phone)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.phonePad)
            SecureField("密码", text: $password)
                .textFieldStyle(.roundedBorder)
            if !loginMsg.isEmpty {
                Text(loginMsg).font(.caption).foregroundColor(.red)
            }
            Button(isLoggingIn ? "登录中..." : "登录") {
                guard !phone.isEmpty, !password.isEmpty else { loginMsg = "请输入手机号和密码"; return }
                isLoggingIn = true
                loginMsg = ""
                Task {
                    do {
                        let u = try await MusicAPI.shared.loginPhone(phone: phone, password: password)
                        await MainActor.run {
                            user = u
                            if let data = try? JSONEncoder().encode(u) {
                                UserDefaults.standard.set(data, forKey: "user")
                            }
                            showLogin = false
                            isLoggingIn = false
                        }
                    } catch {
                        await MainActor.run {
                            loginMsg = error.localizedDescription
                            isLoggingIn = false
                        }
                    }
                }
            }
            .font(.headline).foregroundColor(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(theme.primaryColor)
            .cornerRadius(theme.cornerRadius)
            .disabled(isLoggingIn)
        }
        .padding(24)
        .presentationDetents([.medium])
    }

    private func loadUser() {
        if let data = UserDefaults.standard.data(forKey: "user"),
           let u = try? JSONDecoder().decode(User.self, from: data) {
            user = u
        }
    }
}

struct MeRow: View {
    let icon: String
    let text: String
    @EnvironmentObject var theme: ThemeManager
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(theme.primaryColor).frame(width: 24)
            Text(text).font(.subheadline).foregroundColor(theme.textColor)
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(theme.textSecondaryColor)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }
}
