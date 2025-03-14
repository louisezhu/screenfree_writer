import Foundation

// 原来的AutoCorrectService重命名为PyCorrectService以区分不同的实现
class PyCorrectService: AutoCorrectServiceProtocol {
    static let shared = PyCorrectService()
    private let apiKey = "9667e284-a981-4366-b39c-ff5ab943fb97"
    private let baseURL = "https://ark.cn-beijing.volces.com/api/v3/chat/completions"
    
    private init() {}
    
    func checkText(_ text: String) async throws -> [Suggestion] {
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
        
        guard let url = URL(string: baseURL) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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
                return try self.extractSuggestionsFromContent(content)
            }
            
            // 等待并返回结果
            return try await group.next() ?? []
        }
    }
    
    private func extractSuggestionsFromContent(_ content: String) throws -> [Suggestion] {
        // 从文本中识别和提取JSON
        guard let jsonData = findJSONInString(content) else {
            throw NSError(domain: "com.screenfree.writer", code: 1002, 
                         userInfo: [NSLocalizedDescriptionKey: "无法从响应中提取JSON数据"])
        }
        
        // 解析提取的JSON
        let decoder = JSONDecoder()
        let doubaoResponse = try decoder.decode(DoubaoResponse.self, from: jsonData)
        
        // 如果状态为"perfect"或没有建议，返回空数组
        if doubaoResponse.status == "perfect" || doubaoResponse.suggestions == nil || doubaoResponse.suggestions!.isEmpty {
            return []
        }
        
        // 返回建议数组
        return doubaoResponse.suggestions ?? []
    }
    
    private func findJSONInString(_ text: String) -> Data? {
        let pattern = "\\{[^{]*?\"status\"\\s*:\\s*\"[^\"]*\"[^}]*\\}"
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let nsString = text as NSString
            let range = NSRange(location: 0, length: nsString.length)
            
            if let match = regex.firstMatch(in: text, options: [], range: range) {
                let matchedString = nsString.substring(with: match.range)
                
                // 将字符串转换为数据
                return matchedString.data(using: .utf8)
            }
        } catch {
            print("正则表达式错误: \(error)")
        }
        
        return nil
    }
}

// 为了向后兼容，提供一个AutoCorrectService类，它使用工厂方法获取当前配置的服务
class AutoCorrectService {
    static let shared = AutoCorrectService()
    
    private init() {}
    
    func checkText(_ text: String) async throws -> [Suggestion] {
        return try await AutoCorrectServiceFactory.getService().checkText(text)
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