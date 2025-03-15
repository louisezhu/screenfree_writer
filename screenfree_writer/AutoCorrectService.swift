import Foundation
import Security

class DoubaoCorrectService {
    static let shared = DoubaoCorrectService()
    private var apiKey: String {
        return AppSettings.shared.getSecureAPIKey() ?? ""
    }
    private let baseURL = "https://ark.cn-beijing.volces.com/api/v3/chat/completions"
    
    private init() {}
    
    static func checkText(_ text: String) async throws -> [Suggestion] {
        let prompt = """
        请仔细检查以下文本，找出可能的别字和用词不当的地方。表达不准确的不需要修改。请只针对有问题的具体词语提供修改建议，不要修改整句。"original" 字段必须是原文中确实存在的词语或短语，可以在文本中精确找到        
        如果文本没有任何问题，请返回如下 JSON：{"status": "perfect","message": "文本没有任何问题"}
        如果发现问题（可能有多个词语有问题，则返回多个suggestions），请以JSON格式返回，格式如下：{"status": "has_suggestions","suggestions": [{"original": "有问题的词语","suggestion": "建议修改为","reason": "修改原因"}]}
        文本内容：\(text)
        """
        
        let requestBody: [String: Any] = [
            "model": "ep-20250314213504-tcrr5",
            "messages": [
                ["role": "system", "content": "你是人工智能助手，专注于中文文本校对和修改建议。"],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7
        ]
        
        guard let url = URL(string: shared.baseURL) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(shared.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // 增加超时时间为30秒，给API更多处理时间
        request.timeoutInterval = 30
        
        // 添加优化的请求头
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        
        // 将request变量转换为不可变常量
        let finalRequest = request
        
        // 使用 TaskGroup 创建一个可取消的任务组，添加超时控制
        return try await withThrowingTaskGroup(of: [Suggestion].self) { group in
            // 添加主API请求任务
            group.addTask {
                let (data, response) = try await URLSession.shared.data(for: finalRequest)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                // 检查响应状态码
                if httpResponse.statusCode != 200 {
                    // 尝试解析API错误
                    if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                        throw NSError(domain: "com.screenfree.writer", 
                                     code: httpResponse.statusCode, 
                                     userInfo: [NSLocalizedDescriptionKey: apiError.error.message])
                    }
                    
                    // 如果不能解析为API错误，则抛出通用HTTP错误
                    throw URLError(.badServerResponse)
                }
                
                // 打印API响应以便调试
                if let responseString = String(data: data, encoding: .utf8) {
                    print("API响应: \(responseString)")
                }
                
                // 解析JSON响应
                let decoder = JSONDecoder()
                let apiResponse = try decoder.decode(APIResponseData.self, from: data)
                
                // 确认有消息内容
                guard let firstChoice = apiResponse.choices.first,
                      let content = firstChoice.message.content else {
                    // 如果没有内容，则返回空数组
                    return []
                }
                
                // 从内容中提取JSON，并转换为建议
                return try extractSuggestionsFromContent(content)
            }
            
            // 等待并返回结果
            return try await group.next() ?? []
        }
    }
    
    private static func extractSuggestionsFromContent(_ content: String) throws -> [Suggestion] {
        print("开始从API响应内容中提取建议...")
        print("输入内容长度: \(content.count)字符")
        
        // 1. 首先尝试直接将content作为JSON字符串解析
        do {
            if let data = content.data(using: .utf8) {
                let decoder = JSONDecoder()
                let response = try decoder.decode(DoubaoResponse.self, from: data)
                print("✅ 直接解析内容成功!")
                return response.suggestions ?? []
            }
        } catch {
            print("❌ 直接解析失败: \(error)")
        }
        
        // 2. 尝试提取嵌套的JSON字符串
        // 查找格式为 {"status": "has_suggestions", ... } 的字符串
        let pattern = "\\{\\s*\"status\"[^}]*\\}\\s*"
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
            let nsString = content as NSString
            let range = NSRange(location: 0, length: nsString.length)
            
            if let match = regex.firstMatch(in: content, options: [], range: range) {
                let matchString = nsString.substring(with: match.range)
                print("✅ 找到匹配的JSON字符串: \(matchString.prefix(50))...")
                
                // 尝试解析匹配的字符串
                if let jsonData = matchString.data(using: .utf8) {
                    let decoder = JSONDecoder()
                    let response = try decoder.decode(DoubaoResponse.self, from: jsonData)
                    print("✅ 解析匹配的JSON成功!")
                    return response.suggestions ?? []
                }
            } else {
                print("❌ 没有找到匹配的JSON格式")
            }
        } catch {
            print("❌ 正则匹配或解析失败: \(error)")
        }
        
        // 3. 尝试更简单直接的方式提取具体字段
        if let jsonStart = content.range(of: "{\"status\":"),
           let jsonEnd = findMatchingBrace(in: content, startFrom: jsonStart.lowerBound) {
            let jsonString = String(content[jsonStart.lowerBound...jsonEnd])
            print("✅ 提取到可能的JSON: \(jsonString.prefix(50))...")
            
            do {
                if let jsonData = jsonString.data(using: .utf8) {
                    let decoder = JSONDecoder()
                    let response = try decoder.decode(DoubaoResponse.self, from: jsonData)
                    print("✅ 解析提取的JSON成功!")
                    return response.suggestions ?? []
                }
            } catch {
                print("❌ 解析提取的JSON失败: \(error)")
            }
        }
        
        // 4. 最后使用正则表达式直接提取各个字段值
        print("尝试使用正则表达式直接提取字段...")
        do {
            let originalPattern = "\"original\"\\s*:\\s*\"([^\"]*)\"" 
            let suggestionPattern = "\"suggestion\"\\s*:\\s*\"([^\"]*)\"" 
            let reasonPattern = "\"reason\"\\s*:\\s*\"([^\"]*)\"" 
            
            let originalRegex = try NSRegularExpression(pattern: originalPattern, options: [])
            let suggestionRegex = try NSRegularExpression(pattern: suggestionPattern, options: [])
            let reasonRegex = try NSRegularExpression(pattern: reasonPattern, options: [])
            
            let range = NSRange(location: 0, length: content.count)
            
            var suggestions: [Suggestion] = []
            
            // 查找所有匹配项
            let originalMatches = originalRegex.matches(in: content, options: [], range: range)
            let suggestionMatches = suggestionRegex.matches(in: content, options: [], range: range)
            let reasonMatches = reasonRegex.matches(in: content, options: [], range: range)
            
            // 确保找到的匹配数量一致
            let minMatchCount = min(originalMatches.count, suggestionMatches.count, reasonMatches.count)
            
            for i in 0..<minMatchCount {
                if let originalRange = Range(originalMatches[i].range(at: 1), in: content),
                   let suggestionRange = Range(suggestionMatches[i].range(at: 1), in: content),
                   let reasonRange = Range(reasonMatches[i].range(at: 1), in: content) {
                    
                    let original = String(content[originalRange])
                    let suggestion = String(content[suggestionRange])
                    let reason = String(content[reasonRange])
                    
                    suggestions.append(Suggestion(
                        original: original,
                        suggestion: suggestion,
                        reason: reason
                    ))
                    
                    print("✅ 成功提取第\(i+1)个建议: \(original) -> \(suggestion)")
                }
            }
            
            if !suggestions.isEmpty {
                return suggestions
            }
        } catch {
            print("❌ 直接提取字段失败: \(error)")
        }
        return []
    }
    
    // 辅助方法：查找与提供位置的左大括号匹配的右大括号
    private static func findMatchingBrace(in text: String, startFrom position: String.Index) -> String.Index? {
        guard position < text.endIndex, text[position] == "{" else {
            return nil
        }
        
        var stack = 1 // 已经找到一个左大括号
        var currentPos = text.index(after: position)
        
        while currentPos < text.endIndex && stack > 0 {
            let char = text[currentPos]
            if char == "{" {
                stack += 1
            } else if char == "}" {
                stack -= 1
            }
            
            // 如果找到匹配的右大括号，返回位置
            if stack == 0 {
                return currentPos
            }
            
            currentPos = text.index(after: currentPos)
        }
        
        return nil // 没有找到匹配的右大括号
    }
}

struct APIResponseData: Codable {
    let id: String
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
        
        struct Message: Codable {
            let content: String?
        }
    }
}

struct DoubaoResponse: Codable {
    let status: String
    let suggestions: [Suggestion]?
    let message: String?
    
    var hasSuggestions: Bool {
        return status == "has_suggestions" && suggestions != nil && !suggestions!.isEmpty
    }
}

struct Suggestion: Codable, Identifiable, Equatable {
    let id = UUID()
    let original: String
    let suggestion: String
    let reason: String
    // 用于定位原文段落的上下文信息
    var contextStartPosition: Int = 0
    var contextText: String = ""
    var confidence: Double = 1.0 // 可信度，DeepseekCoreMLService可能需要
    
    static func == (lhs: Suggestion, rhs: Suggestion) -> Bool {
        return lhs.id == rhs.id && 
               lhs.original == rhs.original && 
               lhs.suggestion == rhs.suggestion &&
               lhs.reason == rhs.reason
    }
}

struct APIError: Codable, Error {
    let error: ErrorDetail
    
    struct ErrorDetail: Codable {
        let message: String
        let type: String
        let code: String
    }
}

// 添加KeychainManager类
class KeychainManager {
    static let shared = KeychainManager()
    
    private init() {}
    
    // 从Keychain获取API密钥
    func getAPIKey() -> String? {
        // 第一次使用时，尝试从Info.plist加载并存储到Keychain
        if let apiKey = retrieveAPIKey(), !apiKey.isEmpty {
            return apiKey
        } else if let apiKeyFromPlist = Bundle.main.infoDictionary?["API_KEY"] as? String, 
                  !apiKeyFromPlist.isEmpty {
            // 存储到Keychain
            storeAPIKey(apiKeyFromPlist)
            return apiKeyFromPlist
        }
        return nil
    }
    
    // 存储API密钥到Keychain
    func storeAPIKey(_ apiKey: String) {
        let keychainQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "ApiKey",
            kSecAttrService as String: "com.screenfree.writer",
            kSecValueData as String: apiKey.data(using: .utf8)!
        ]
        
        // 先删除可能存在的旧值
        SecItemDelete(keychainQuery as CFDictionary)
        
        // 添加新值
        SecItemAdd(keychainQuery as CFDictionary, nil)
    }
    
    // 从Keychain读取API密钥
    func retrieveAPIKey() -> String? {
        let keychainQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "ApiKey",
            kSecAttrService as String: "com.screenfree.writer",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(keychainQuery as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let retrievedData = dataTypeRef as? Data {
            return String(data: retrievedData, encoding: .utf8)
        }
        
        return nil
    }
}

// 扩展Data用于JSON格式化输出
extension Data {
    var prettyPrintedJSONString: String? {
        guard let object = try? JSONSerialization.jsonObject(with: self, options: []),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
              let prettyPrintedString = String(data: data, encoding: .utf8) else { return nil }

        return prettyPrintedString
    }
} 