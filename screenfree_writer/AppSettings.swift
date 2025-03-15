import Foundation


// 创建AppSettings单例来管理应用设置
class AppSettings {
    static let shared = AppSettings()
    private let defaults = UserDefaults.standard
    
    // 定义设置键
    private enum Keys {
        static let enableTextCorrection = "enableTextCorrection"
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