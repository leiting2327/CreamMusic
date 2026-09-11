import SwiftUI

// 主题管理器：奶油风 / WinUI 双主题 + 液态玻璃强度
class ThemeManager: ObservableObject {
    @Published var theme: Theme = .cream
    @Published var glassIntensity: Double = 0.6 // 0~1

    enum Theme: String {
        case cream, winui
    }

    var colorScheme: ColorScheme? {
        theme == .cream ? .light : .light
    }

    // 奶油风配色
    struct CreamColors {
        static let bg = Color(red: 1.0, green: 0.96, blue: 0.90)
        static let card = Color.white.opacity(0.8)
        static let primary = Color(red: 0.91, green: 0.66, blue: 0.49)
        static let text = Color(red: 0.36, green: 0.25, blue: 0.20)
        static let textSecondary = Color(red: 0.55, green: 0.45, blue: 0.33)
    }

    // WinUI 配色
    struct WinUIColors {
        static let bg = Color(red: 0.95, green: 0.95, blue: 0.95)
        static let card = Color.white.opacity(0.75)
        static let primary = Color(red: 0.0, green: 0.47, blue: 0.83)
        static let text = Color(red: 0.11, green: 0.11, blue: 0.11)
        static let textSecondary = Color(red: 0.38, green: 0.38, blue: 0.38)
    }

    var bgColor: Color { theme == .cream ? CreamColors.bg : WinUIColors.bg }
    var cardColor: Color { theme == .cream ? CreamColors.card : WinUIColors.card }
    var primaryColor: Color { theme == .cream ? CreamColors.primary : WinUIColors.primary }
    var textColor: Color { theme == .cream ? CreamColors.text : WinUIColors.text }
    var textSecondaryColor: Color { theme == .cream ? CreamColors.textSecondary : WinUIColors.textSecondary }
    var cornerRadius: CGFloat { theme == .cream ? 24 : 8 }
}

// 液态玻璃修饰符
struct GlassModifier: ViewModifier {
    @EnvironmentObject var theme: ThemeManager
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .fill(.ultraThinMaterial)
                    .opacity(theme.glassIntensity)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .stroke(.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08 * theme.glassIntensity), radius: 12, x: 0, y: 4)
    }
}

extension View {
    func glassCard() -> some View { modifier(GlassModifier()) }
}
