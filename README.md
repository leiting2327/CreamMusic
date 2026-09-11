# 奶油音乐 iOS 版（SwiftUI 源码）

## 功能
- 🍦 奶油风 / 🪟 WinUI 双主题切换
- 💧 液态玻璃效果可调（0~100%）
- 🎵 网易云 / QQ音乐 / 酷狗 三平台搜索播放（Meting 公共接口）
- 👤 网易云登录 + 会员等级展示（黑胶VIP/音乐包/普通用户）
- 📱 全屏播放器 + 迷你播放条
- 🏝️ 灵动岛 Live Activity（播放时上岛显示歌曲名/歌手/播放状态）

## 编译方法（需要 Mac + Xcode 15+ + Apple 开发者账号）

### 1. 创建 Xcode 项目
1. 打开 Xcode → File → New → Project → iOS App
2. Product Name: `CreamMusic`，Interface: SwiftUI，Language: Swift
3. 把 `Sources/` 目录下所有 `.swift` 文件拖进项目（勾选 Copy items if needed）

### 2. 添加 Widget Extension（灵动岛必需）
1. File → New → Target → Widget Extension
2. Product Name: `MusicWidget`，取消勾选 Include Configuration App Intent
3. 把 `MusicActivityWidget.swift` 里的代码替换到 Widget 的 swift 文件中
4. 在主项目和 Widget Extension 的 Info.plist 中都不需要额外配置（ActivityKit 自动支持）

### 3. 配置 Info.plist（主项目）
- 添加 `NSAppTransportSecurity` → `NSAllowsArbitraryLoads` = YES（允许 HTTP 接口）
- 支持的方向：Portrait

### 4. 签名与打包
1. 项目设置 → Signing & Capabilities → 选择你的 Apple Developer Team
2. 主项目和 Widget Extension 都要选同一个 Team
3. 连接 iPhone（iOS 16.1+ 支持灵动岛）
4. Product → Archive → Distribute App → 导出 IPA

### 5. 灵动岛说明
- 需要 iPhone 14 Pro 及以上机型
- 播放音乐时自动上岛，显示歌曲名、歌手、播放/暂停状态
- 点击灵动岛可回到 App

## 文件说明
| 文件 | 作用 |
|------|------|
| CreamMusicApp.swift | App 入口 |
| ThemeManager.swift | 双主题 + 液态玻璃 |
| MusicAPI.swift | 三平台 API + 登录 |
| MusicPlayer.swift | 播放器 + Live Activity 控制 |
| MusicActivity.swift | 灵动岛数据模型 |
| MusicActivityWidget.swift | 灵动岛 UI（放 Widget Extension） |
| ContentView.swift | 主框架 + 底部导航 + 迷你播放器 |
| HomeView.swift | 首页 |
| SearchView.swift | 搜索页（三平台切换） |
| MeView.swift | 我的页（登录+会员等级） |
| SettingsView.swift | 设置页（主题+玻璃+API） |
| PlayerView.swift | 全屏播放器 |
