import SwiftUI

struct VoiceSettingsView: View {
    // 使用多次读取但较少写入的模式，确保UI更新的稳定性
    @State private var settings = VoiceShortcutSettings()
    @State private var isEditingReadKey = false
    @State private var isEditingAcceptKey = false
    @State private var isEditingIgnoreKey = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // 使用结构体封装设置，避免各属性不一致
    struct VoiceShortcutSettings {
        var readKey: String
        var acceptKey: String
        var ignoreKey: String
        
        init() {
            self.readKey = AppSettings.shared.voiceShortcutRead
            self.acceptKey = AppSettings.shared.voiceShortcutAccept
            self.ignoreKey = AppSettings.shared.voiceShortcutIgnore
        }
    }
    
    let availableKeys = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", 
                         "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", 
                         "1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
    
    var body: some View {
        List {
            Section(header: Text("朗读快捷键")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("当前语音朗读使用的快捷键设置")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText)
                    
                    HStack {
                        Text("开始/停止朗读")
                            .foregroundColor(AppTheme.text)
                        
                        Spacer()
                        
                        if isEditingReadKey {
                            Menu {
                                ForEach(availableKeys, id: \.self) { key in
                                    Button(key) {
                                        updateReadKey(key)
                                    }
                                }
                            } label: {
                                Text("选择按键...")
                                    .foregroundColor(AppTheme.primary)
                            }
                        } else {
                            HStack {
                                Text("⇧⌘\(settings.readKey)")
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(6)
                                
                                Button(action: {
                                    isEditingReadKey = true
                                }) {
                                    Image(systemName: "pencil")
                                        .foregroundColor(AppTheme.primary)
                                }
                            }
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("接受建议")
                            .foregroundColor(AppTheme.text)
                        
                        Spacer()
                        
                        if isEditingAcceptKey {
                            Menu {
                                ForEach(availableKeys, id: \.self) { key in
                                    Button(key) {
                                        updateAcceptKey(key)
                                    }
                                }
                            } label: {
                                Text("选择按键...")
                                    .foregroundColor(AppTheme.primary)
                            }
                        } else {
                            HStack {
                                Text("⌘\(settings.acceptKey)")
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(6)
                                
                                Button(action: {
                                    isEditingAcceptKey = true
                                }) {
                                    Image(systemName: "pencil")
                                        .foregroundColor(AppTheme.primary)
                                }
                            }
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("忽略建议")
                            .foregroundColor(AppTheme.text)
                        
                        Spacer()
                        
                        if isEditingIgnoreKey {
                            Menu {
                                ForEach(availableKeys, id: \.self) { key in
                                    Button(key) {
                                        updateIgnoreKey(key)
                                    }
                                }
                            } label: {
                                Text("选择按键...")
                                    .foregroundColor(AppTheme.primary)
                            }
                        } else {
                            HStack {
                                Text("⌘\(settings.ignoreKey)")
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(6)
                                
                                Button(action: {
                                    isEditingIgnoreKey = true
                                }) {
                                    Image(systemName: "pencil")
                                        .foregroundColor(AppTheme.primary)
                                }
                            }
                        }
                    }
                }
            }
            
            Section(header: Text("关于语音朗读")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("语音朗读功能说明")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.text)
                    
                    Text("• 按下⇧⌘\(settings.readKey)开始语音朗读所有修改建议")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText)
                    
                    Text("• 使用⌘\(settings.acceptKey)接受当前朗读的建议")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText)
                    
                    Text("• 使用⌘\(settings.ignoreKey)忽略当前朗读的建议")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText)
                    
                    Text("• 再次按下⇧⌘\(settings.readKey)停止语音朗读")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText)
                }
                .padding(.vertical, 8)
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("语音设置")
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("快捷键冲突"),
                message: Text(alertMessage),
                dismissButton: .default(Text("确定"))
            )
        }
        .onAppear {
            // 刷新设置
            refreshSettings()
        }
    }
    
    // 刷新设置 - 从AppSettings读取并确保安全
    private func refreshSettings() {
        // 创建新实例以确保数据一致性
        settings = VoiceShortcutSettings()
    }
    
    // 更新功能分离为单独方法，便于维护
    private func updateReadKey(_ key: String) {
        let newKey = safeKey(key)
        settings.readKey = newKey
        AppSettings.shared.voiceShortcutRead = newKey
        isEditingReadKey = false
    }
    
    private func updateAcceptKey(_ key: String) {
        let newKey = safeKey(key)
        
        if newKey == settings.ignoreKey {
            showAlert = true
            alertMessage = "快捷键'\(newKey)'已被'忽略建议'功能使用"
        } else {
            settings.acceptKey = newKey
            AppSettings.shared.voiceShortcutAccept = newKey
            isEditingAcceptKey = false
        }
    }
    
    private func updateIgnoreKey(_ key: String) {
        let newKey = safeKey(key)
        
        if newKey == settings.acceptKey {
            showAlert = true
            alertMessage = "快捷键'\(newKey)'已被'接受建议'功能使用"
        } else {
            settings.ignoreKey = newKey
            AppSettings.shared.voiceShortcutIgnore = newKey
            isEditingIgnoreKey = false
        }
    }
    
    // 辅助函数：确保键是安全的单字符
    private func safeKey(_ key: String) -> String {
        if key.isEmpty {
            return "V" // 默认值
        }
        return String(key.prefix(1).uppercased())
    }
}

#Preview {
    NavigationStack {
        VoiceSettingsView()
    }
} 