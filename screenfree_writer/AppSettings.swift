import Foundation
import ObjectiveC  // 添加此导入以支持objc_sync_enter/exit


// 创建AppSettings单例来管理应用设置
class AppSettings {
    static let shared = AppSettings()
    private let defaults = UserDefaults.standard
    
    // 定义设置键
    private enum Keys {
        static let enableTextCorrection = "enableTextCorrection"
        static let voiceShortcutRead = "voiceShortcutRead"
        static let voiceShortcutAccept = "voiceShortcutAccept"
        static let voiceShortcutIgnore = "voiceShortcutIgnore"
    }
    
    // 是否启用文本修正功能
    var enableTextCorrection: Bool {
        get {
            // 默认开启
            return defaults.bool(forKey: Keys.enableTextCorrection, defaultValue: true)
        }
        set {
            defaults.set(newValue, forKey: Keys.enableTextCorrection)
        }
    }
    
    // 语音朗读快捷键设置
    var voiceShortcutRead: String {
        get {
            return safeShortcut(defaults.string(forKey: Keys.voiceShortcutRead) ?? "V")
        }
        set {
            defaults.set(safeShortcut(newValue), forKey: Keys.voiceShortcutRead)
        }
    }
    
    // 接受建议快捷键设置
    var voiceShortcutAccept: String {
        get {
            return safeShortcut(defaults.string(forKey: Keys.voiceShortcutAccept) ?? "Y")
        }
        set {
            defaults.set(safeShortcut(newValue), forKey: Keys.voiceShortcutAccept)
        }
    }
    
    // 忽略建议快捷键设置
    var voiceShortcutIgnore: String {
        get {
            return safeShortcut(defaults.string(forKey: Keys.voiceShortcutIgnore) ?? "N")
        }
        set {
            defaults.set(safeShortcut(newValue), forKey: Keys.voiceShortcutIgnore)
        }
    }
    
    // 确保快捷键是单个字符并确保线程安全
    private func safeShortcut(_ value: String) -> String {
        // 使用同步锁防止多线程同时访问和修改
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        
        if value.isEmpty {
            return "V" // 默认返回V
        }
        
        // 更安全地处理字符
        guard let firstChar = value.first else {
            return "V"
        }
        
        // 取第一个字符并转换为大写
        return String(firstChar).uppercased()
    }
    
    // API密钥管理
    func getAPIKey() -> String? {
        return KeychainManager.shared.getAPIKey()
    }
    
    func setAPIKey(_ key: String) {
        KeychainManager.shared.storeAPIKey(key)
    }
    
    // 更安全的获取API密钥的方法，用于开发/生产环境
    func getSecureAPIKey() -> String? {
        #if DEBUG
        // 开发环境使用Info.plist中的密钥
        return Bundle.main.infoDictionary?["API_KEY"] as? String
        #else
        // 生产环境使用Keychain中的密钥
        return KeychainManager.shared.retrieveAPIKey()
        #endif
    }
    
    private init() {
        // 确保默认设置
        if defaults.object(forKey: Keys.enableTextCorrection) == nil {
            enableTextCorrection = true
        }
        
        // 设置默认快捷键
        if defaults.object(forKey: Keys.voiceShortcutRead) == nil {
            voiceShortcutRead = "V"
        }
        if defaults.object(forKey: Keys.voiceShortcutAccept) == nil {
            voiceShortcutAccept = "Y"
        }
        if defaults.object(forKey: Keys.voiceShortcutIgnore) == nil {
            voiceShortcutIgnore = "N"
        }
        
        // 第一次运行时，尝试从Info.plist导入API密钥到Keychain
        migrateAPIKeyToKeychain()
    }
    
    // 将API密钥从Info.plist迁移到Keychain
    private func migrateAPIKeyToKeychain() {
        if KeychainManager.shared.retrieveAPIKey() == nil,
           let apiKeyFromPlist = Bundle.main.infoDictionary?["API_KEY"] as? String,
           !apiKeyFromPlist.isEmpty {
            KeychainManager.shared.storeAPIKey(apiKeyFromPlist)
        }
    }
}

// 为UserDefaults添加扩展，方便处理默认值
extension UserDefaults {
    func bool(forKey key: String, defaultValue: Bool) -> Bool {
        if object(forKey: key) == nil {
            return defaultValue
        }
        return bool(forKey: key)
    }
} 