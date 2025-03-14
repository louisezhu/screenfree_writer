import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct ProfileView: View {
    @StateObject private var viewModel = BookViewModel()
    @State private var enableTextCorrection: Bool = AppSettings.shared.enableTextCorrection
    @State private var textCorrectionService: TextCorrectionServiceType = AppSettings.shared.textCorrectionService
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 顶部用户头像和信息
                    HStack(spacing: 20) {
                        // 用户头像
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [AppTheme.primary, AppTheme.secondary]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                                .shadow(color: AppTheme.primary.opacity(0.3), radius: 10, x: 0, y: 4)
                            
                            Image(systemName: "person.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("专注的作家")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.text)
                            
                            Text("创作不受打扰")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.secondaryText)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    // 写作统计 - 使用卡片形式
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(AppTheme.primary)
                            Text("写作统计")
                                .font(.headline)
                                .foregroundColor(AppTheme.text)
                            Spacer()
                        }
                        
                        // 统计卡片
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            StatCard(title: "书籍", value: formattedNumber(viewModel.books.count), icon: "book.closed.fill")
                            StatCard(title: "章节", value: formattedNumber(totalChaptersCount), icon: "list.bullet")
                            StatCard(title: "字数", value: formattedNumber(totalWordsCount), icon: "chart.bar.fill")
                        }
                    }
                    .padding()
                    .background(AppTheme.cardBackground)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)
                    
                    // 设置选项
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "gear")
                                .foregroundColor(AppTheme.primary)
                            Text("设置")
                                .font(.headline)
                                .foregroundColor(AppTheme.text)
                            Spacer()
                        }
                        
                        VStack(spacing: 0) {
                            NavigationLink(destination: Text("iCloud设置")) {
                                SettingRow(title: "iCloud同步", icon: "icloud", showDivider: true)
                            }
                            
                            HStack {
                                Image(systemName: "pencil.and.outline")
                                    .foregroundColor(AppTheme.primary)
                                    .frame(width: 30)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("文本修正")
                                        .foregroundColor(AppTheme.text)
                                    
                                    Text("实时修正文字错误")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.secondaryText)
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: $enableTextCorrection)
                                    .toggleStyle(SwitchToggleStyle(tint: AppTheme.primary))
                                    .onChange(of: enableTextCorrection) { newValue in
                                        AppSettings.shared.enableTextCorrection = newValue
                                    }
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal)
                            
                            Divider()
                                .padding(.leading, 56)
                                
                            // 文本修正服务选择
                            if enableTextCorrection {
                                HStack {
                                    Image(systemName: "gear.circle")
                                        .foregroundColor(AppTheme.primary)
                                        .frame(width: 30)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("修正服务")
                                            .foregroundColor(AppTheme.text)
                                        
                                        Text("选择文本修正引擎")
                                            .font(.caption)
                                            .foregroundColor(AppTheme.secondaryText)
                                    }
                                    
                                    Spacer()
                                    
                                    Picker("", selection: $textCorrectionService) {
                                        Text("在线API").tag(TextCorrectionServiceType.doubao)
                                        Text("本地模型").tag(TextCorrectionServiceType.deepseek)
                                    }
                                    .pickerStyle(SegmentedPickerStyle())
                                    .frame(width: 160)
                                    .onChange(of: textCorrectionService) { newValue in
                                        AppSettings.shared.textCorrectionService = newValue
                                    }
                                }
                                .padding(.vertical, 14)
                                .padding(.horizontal)
                                
                                Divider()
                                    .padding(.leading, 56)
                    }
                    
                    NavigationLink(destination: Text("快捷键设置")) {
                                SettingRow(title: "快捷键设置", icon: "keyboard", showDivider: true)
                    }
                    
                    NavigationLink(destination: Text("语音设置")) {
                                SettingRow(title: "语音设置", icon: "waveform", showDivider: false)
                            }
                        }
                        .background(AppTheme.cardBackground)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .padding()
                    .background(AppTheme.cardBackground)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)
                    
                    // 关于
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(AppTheme.primary)
                            Text("关于")
                                .font(.headline)
                                .foregroundColor(AppTheme.text)
                            Spacer()
                        }
                        
                        VStack(spacing: 0) {
                    NavigationLink(destination: Text("使用帮助")) {
                                SettingRow(title: "使用帮助", icon: "questionmark.circle", showDivider: true)
                    }
                    
                    NavigationLink(destination: Text("关于我们")) {
                                SettingRow(title: "关于我们", icon: "info.circle", showDivider: false)
                            }
                        }
                        .background(AppTheme.cardBackground)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .padding()
                    .background(AppTheme.cardBackground)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)
                }
                .padding(.bottom, 24)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // 计算总章节数
    private var totalChaptersCount: Int {
        var count = 0
        for book in viewModel.books {
            count += book.chapters?.count ?? 0
        }
        return count
    }
    
    // 计算总字数
    private var totalWordsCount: Int {
        var count = 0
        for book in viewModel.books {
            if let chapters = book.chapters?.allObjects as? [ChapterEntity] {
                for chapter in chapters {
                    count += chapter.content?.count ?? 0
                }
            }
        }
        return count
    }
    
    // 格式化数字，使大数字更易读
    private func formattedNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(AppTheme.primary.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(AppTheme.primary)
            }
            
            // 数值
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AppTheme.text)
            
            // 标题
            Text(title)
                .font(.caption)
                .foregroundColor(AppTheme.secondaryText)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
}

struct SettingRow: View {
    let title: String
    let icon: String
    let showDivider: Bool
    
    var body: some View {
        VStack(spacing: 0) {
        HStack {
            Image(systemName: icon)
                    .foregroundColor(AppTheme.primary)
                .frame(width: 30)
            
            Text(title)
                    .foregroundColor(AppTheme.text)
            
            Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(AppTheme.secondaryText)
                    .font(.system(size: 14))
            }
            .padding(.vertical, 14)
            .padding(.horizontal)
            
            if showDivider {
                Divider()
                    .padding(.leading, 56)
            }
        }
    }
}

#Preview {
    ProfileView()
} 