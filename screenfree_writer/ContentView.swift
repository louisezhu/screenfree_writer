import SwiftUI

// 应用颜色主题
struct AppTheme {
    static let primary = Color(hex: "5E7CE2")    // 主色调：柔和的靛蓝色
    static let secondary = Color(hex: "72A1E5")  // 次要色调：淡蓝色
    static let accent = Color(hex: "FFAA5B")     // 强调色：温暖的橙色
    static let background = Color(hex: "F9F7F7") // 背景色：淡灰白色
    static let cardBackground = Color.white      // 卡片背景：纯白色
    static let text = Color(hex: "333333")       // 主文本色：深灰色
    static let secondaryText = Color(hex: "888888") // 次要文本色：中灰色
}

// 帮助实现十六进制颜色代码
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            WritingView()
                .tabItem {
                    Label("写作", systemImage: "book.fill")
                }
            
            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
        }
        .tint(AppTheme.primary) // 设置应用主色调
        .accentColor(AppTheme.primary)
    }
}

#Preview {
    ContentView()
} 
