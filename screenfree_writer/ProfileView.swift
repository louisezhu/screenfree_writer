import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            VStack {
                // 顶部标题
                HStack {
                    Text("我的")
                        .font(.title)
                        .bold()
                    Spacer()
                }
                .padding()
                
                // 内容列表
                ScrollView {
                    VStack(spacing: 20) {
                        // 写作统计
                        VStack(alignment: .leading, spacing: 12) {
                            Text("写作统计")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VStack(spacing: 8) {
                                StatRow(title: "总字数", value: "0", icon: "chart.bar.fill")
                                StatRow(title: "总章节数", value: "0", icon: "list.bullet")
                                StatRow(title: "总书籍数", value: "0", icon: "book.closed.fill")
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(radius: 2)
                        }
                        .padding(.horizontal)
                        
                        // 设置选项
                        VStack(alignment: .leading, spacing: 12) {
                            Text("设置")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VStack(spacing: 0) {
                                NavigationLink(destination: Text("iCloud设置")) {
                                    SettingRow(title: "iCloud同步", icon: "icloud")
                                }
                                
                                NavigationLink(destination: Text("主题设置")) {
                                    SettingRow(title: "主题设置", icon: "paintpalette")
                                }
                                
                                NavigationLink(destination: Text("快捷键设置")) {
                                    SettingRow(title: "快捷键设置", icon: "keyboard")
                                }
                                
                                NavigationLink(destination: Text("语音设置")) {
                                    SettingRow(title: "语音设置", icon: "waveform")
                                }
                            }
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(radius: 2)
                        }
                        .padding(.horizontal)
                        
                        // 关于
                        VStack(alignment: .leading, spacing: 12) {
                            Text("关于")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VStack(spacing: 0) {
                                NavigationLink(destination: Text("使用帮助")) {
                                    SettingRow(title: "使用帮助", icon: "questionmark.circle")
                                }
                                
                                NavigationLink(destination: Text("关于我们")) {
                                    SettingRow(title: "关于我们", icon: "info.circle")
                                }
                            }
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(radius: 2)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
        }
    }
}

struct StatRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            Text(title)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

struct SettingRow: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            Text(title)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .contentShape(Rectangle())
    }
}

#Preview {
    ProfileView()
} 