import Foundation

// 文本修正服务协议
protocol AutoCorrectServiceProtocol {
    func checkText(_ text: String) async throws -> [Suggestion]
}

// 文本修正服务工厂
class AutoCorrectServiceFactory {
    static func getService() -> AutoCorrectServiceProtocol {
        switch AppSettings.shared.textCorrectionService {
        case .doubao:
            return PyCorrectService.shared
        case .deepseek:
            return DeepseekAutoCorrectService()
        }
    }
} 