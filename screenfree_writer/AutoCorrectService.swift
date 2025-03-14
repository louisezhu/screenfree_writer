import Foundation

class AutoCorrectService {
    static let shared = AutoCorrectService()
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
        return try await withTaskGroup(of: [Suggestion]?.self) { group in
            // 主要请求任务
            group.addTask {
                do {
                    // 添加性能日志
                    let startTime = Date()
                    print("开始API请求：\(startTime)")
                    
                    let (data, response) = try await URLSession.shared.data(for: finalRequest)
                    
                    // 记录请求耗时
                    let endTime = Date()
                    let timeInterval = endTime.timeIntervalSince(startTime)
                    print("API请求完成，耗时: \(String(format: "%.2f", timeInterval))秒")
                    
                    // 检查 HTTP 响应状态
                    guard let httpResponse = response as? HTTPURLResponse else {
                        print("无效的 HTTP 响应")
                        return []
                    }
                    
                    if httpResponse.statusCode != 200 {
                        if let jsonStr = String(data: data, encoding: .utf8) {
                            print("API错误响应: \(jsonStr)")
                        }
                        
                        if let errorResponse = try? JSONDecoder().decode(APIError.self, from: data) {
                            print("API错误: \(errorResponse.error.message)")
                        }
                        return []
                    }
                    
                    // 解析响应数据
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("API Response: \(jsonString)")
                    }
                    
                    let decoder = JSONDecoder()
                    let apiResponse = try decoder.decode(DoubaoAPIResponse.self, from: data)
                    
                    if let content = apiResponse.choices.first?.message.content {
                        // 提取 JSON 部分
                        var jsonContent = content
                        
                        // 移除 markdown 代码块标记 ```json 和 ```
                        if let startIndex = content.range(of: "```json\n")?.upperBound {
                            if let endIndex = content.range(of: "\n```", range: startIndex..<content.endIndex)?.lowerBound {
                                jsonContent = String(content[startIndex..<endIndex])
                            }
                        } else if let startIndex = content.range(of: "```\n")?.upperBound {
                            if let endIndex = content.range(of: "\n```", range: startIndex..<content.endIndex)?.lowerBound {
                                jsonContent = String(content[startIndex..<endIndex])
                            }
                        }
                        
                        // 尝试解析JSON
                        do {
                            let jsonData = jsonContent.data(using: .utf8)!
                            let response = try decoder.decode(DoubaoResponse.self, from: jsonData)
                            
                            if let apiSuggestions = response.suggestions {
                                // 将API返回的建议转换为应用使用的Suggestion格式
                                let suggestions = apiSuggestions.map { apiSuggestion in
                                    return Suggestion(
                                        original: apiSuggestion.original,
                                        suggestion: apiSuggestion.suggestion,
                                        reason: apiSuggestion.reason
                                    )
                                }
                                return suggestions
                            } else {
                                return []
                            }
                        } catch {
                            print("JSON 解析错误: \(error)")
                            
                            // 尝试手动提取
                            let suggestions = self.extractSuggestions(from: jsonContent)
                            if !suggestions.isEmpty {
                                return suggestions
                            }
                        }
                    }
                    
                    return []
                } catch {
                    // 捕获网络错误但不重新抛出，返回空数组
                    if (error as NSError).domain == NSURLErrorDomain && (error as NSError).code == -999 {
                        print("API请求被取消")
                    } else {
                        print("API请求错误: \(error)")
                    }
                    return []
                }
            }
            
            // 等待并返回第一个完成的非空结果
            for await result in group {
                if let suggestions = result, !suggestions.isEmpty {
                    // 取消其他任务
                    group.cancelAll()
                    return suggestions
                }
            }
            
            // 如果所有任务都失败，返回空数组
            return []
        }
    }
    
    // 手动提取建议
    private func extractSuggestions(from jsonContent: String) -> [Suggestion] {
        var suggestions: [Suggestion] = []
        
        // 使用正则表达式提取建议
        let pattern = "\"original\":\\s*\"([^\"]+)\"[^}]*\"suggestion\":\\s*\"([^\"]+)\"[^}]*\"reason\":\\s*\"([^\"]+)\""
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let nsString = jsonContent as NSString
            let matches = regex.matches(in: jsonContent, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for match in matches {
                if match.numberOfRanges >= 4 {
                    let original = nsString.substring(with: match.range(at: 1))
                    let suggestion = nsString.substring(with: match.range(at: 2))
                    let reason = nsString.substring(with: match.range(at: 3))
                    
                    suggestions.append(Suggestion(original: original, suggestion: suggestion, reason: reason))
                }
            }
        } catch {
            print("正则表达式错误: \(error)")
        }
        
        return suggestions
    }
}

struct DoubaoAPIResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
    }
    
    struct Message: Codable {
        let content: String
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