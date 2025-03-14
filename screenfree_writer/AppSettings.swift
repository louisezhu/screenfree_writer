import Foundation

// 文本修正服务类型
enum TextCorrectionServiceType: String {
    case doubao = "doubao" // 原有的Python修正服务
    case deepseek = "deepseek" // 新的CoreML模型服务
}

// 创建AppSettings单例来管理应用设置
class AppSettings {
    static let shared = AppSettings()
    private let defaults = UserDefaults.standard
    
    // 定义设置键
    private enum Keys {
        static let enableTextCorrection = "enableTextCorrection"
        static let textCorrectionService = "textCorrectionService"
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
    
    // 当前使用的文本修正服务类型
    var textCorrectionService: TextCorrectionServiceType {
        get {
            if let rawValue = defaults.string(forKey: Keys.textCorrectionService),
               let serviceType = TextCorrectionServiceType(rawValue: rawValue) {
                return serviceType
            }
            return .doubao // 默认使用python修正服务
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.textCorrectionService)
        }
    }
    
    private init() {
        // 确保默认设置
        if defaults.object(forKey: Keys.enableTextCorrection) == nil {
            enableTextCorrection = true
        }
        
        if defaults.object(forKey: Keys.textCorrectionService) == nil {
            textCorrectionService = .doubao
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