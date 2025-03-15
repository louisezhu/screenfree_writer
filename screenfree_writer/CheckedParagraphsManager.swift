import Foundation

class CheckedParagraphsManager {
    static let shared = CheckedParagraphsManager()
    
    private init() {}
    
    // 存储已检查段落的键前缀
    private let userDefaultsKeyPrefix = "checked_paragraphs_"
    
    // 保存检查过的段落
    func saveCheckedParagraph(paragraphText: String, chapterId: UUID) {
        let key = userDefaultsKeyPrefix + chapterId.uuidString
        
        // 获取当前章节的所有检查过的段落
        var checkedParagraphs = fetchAllCheckedParagraphs(chapterId: chapterId)
        
        // 添加新的段落
        checkedParagraphs.insert(paragraphText)
        
        // 存储回UserDefaults
        if let data = try? JSONEncoder().encode(Array(checkedParagraphs)) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    // 检查段落是否已经检查过
    func isParagraphChecked(paragraphText: String, chapterId: UUID) -> Bool {
        let checkedParagraphs = fetchAllCheckedParagraphs(chapterId: chapterId)
        return checkedParagraphs.contains(paragraphText)
    }
    
    // 获取章节的所有已检查段落
    func fetchAllCheckedParagraphs(chapterId: UUID) -> Set<String> {
        let key = userDefaultsKeyPrefix + chapterId.uuidString
        
        if let data = UserDefaults.standard.data(forKey: key),
           let paragraphs = try? JSONDecoder().decode([String].self, from: data) {
            return Set(paragraphs)
        }
        
        return []
    }
    
    // 清除章节的所有已检查段落
    func clearCheckedParagraphs(chapterId: UUID) {
        let key = userDefaultsKeyPrefix + chapterId.uuidString
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    // 清除所有章节的已检查段落
    func clearAllCheckedParagraphs() {
        for key in UserDefaults.standard.dictionaryRepresentation().keys {
            if key.starts(with: userDefaultsKeyPrefix) {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
} 