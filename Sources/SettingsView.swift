import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var theme: ThemeManager
    @State private var metingApi = "https://api.injahow.cn/meting/"
    @State private var neteaseApi = "https://netease-cloud-music-api-five-roan-88.vercel.app"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("设置").font(.largeTitle).bold().foregroundColor(theme.textColor).padding(.top, 20)

                // 界面风格
                VStack(alignment: .leading, spacing: 12) {
                    Text("界面风格").font(.headline).foregroundColor(theme.textColor)
                    Picker("风格", selection: $theme.theme) {
                        Text("🍦 奶油风").tag(ThemeManager.Theme.cream)
                        Text("🪟 WinUI").tag(ThemeManager.Theme.winui)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(18)
                .glassCard()

                // 液态玻璃
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("液态玻璃效果").font(.headline).foregroundColor(theme.textColor)
                        Spacer()
                        Text("\(Int(theme.glassIntensity * 100))%").font(.caption).foregroundColor(theme.textSecondaryColor)
                    }
                    Slider(value: $theme.glassIntensity, in: 0...1)
                        .tint(theme.primaryColor)
                }
                .padding(18)
                .glassCard()

                // API 配置
                VStack(alignment: .leading, spacing: 12) {
                    Text("接口配置").font(.headline).foregroundColor(theme.textColor)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("音乐搜索接口").font(.caption).foregroundColor(theme.textSecondaryColor)
                        TextField("Meting API", text: $metingApi)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("网易云登录接口").font(.caption).foregroundColor(theme.textSecondaryColor)
                        TextField("Netease API", text: $neteaseApi)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                    }
                    Button("保存配置") {
                        UserDefaults.standard.set(metingApi, forKey: "metingApi")
                        UserDefaults.standard.set(neteaseApi, forKey: "neteaseApi")
                    }
                    .font(.subheadline).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(theme.primaryColor)
                    .cornerRadius(theme.cornerRadius)
                }
                .padding(18)
                .glassCard()

                // 关于
                VStack(alignment: .leading, spacing: 6) {
                    Text("关于").font(.headline).foregroundColor(theme.textColor)
                    Text("奶油音乐 v1.0").font(.subheadline).foregroundColor(theme.textColor)
                    Text("支持网易云 / QQ音乐 / 酷狗搜索播放").font(.caption).foregroundColor(theme.textSecondaryColor)
                    Text("灵动岛实时显示播放状态").font(.caption).foregroundColor(theme.textSecondaryColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .glassCard()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .onAppear {
            if let m = UserDefaults.standard.string(forKey: "metingApi") { metingApi = m }
            if let n = UserDefaults.standard.string(forKey: "neteaseApi") { neteaseApi = n }
        }
    }
}
