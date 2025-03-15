import Foundation
import CoreData
import SwiftUI

class BookViewModel: ObservableObject {
    private let context = CoreDataManager.shared.context
    
    @Published var books: [BookEntity] = []
    
    init() {
        fetchBooks()
    }
    
    // MARK: - 本地数据操作
    func fetchBooks() {
        let request = NSFetchRequest<BookEntity>(entityName: "BookEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \BookEntity.updatedAt, ascending: false)]
        
        do {
            books = try context.fetch(request)
        } catch {
            print("Error fetching books: \(error)")
        }
    }
    
    func addBook(title: String, description: String) {
        let book = BookEntity(context: context)
        book.id = UUID()
        book.title = title
        book.createdAt = Date()
        book.updatedAt = Date()
        
        saveContext()
    }
    
    func updateBook(_ book: BookEntity, title: String, description: String) {
        book.title = title
        book.updatedAt = Date()
        
        saveContext()
    }
    
    func deleteBook(_ book: BookEntity) {
        context.delete(book)
        saveContext()
    }
    
    func addChapter(to book: BookEntity, title: String) {
        let chapter = ChapterEntity(context: context)
        chapter.id = UUID()
        // 如果没有提供标题，则根据已有章节数量自动生成"第N章"形式的标题
        if title.isEmpty {
            // 获取书籍当前的章节数量
            let currentChapters = book.chapters?.allObjects as? [ChapterEntity] ?? []
            let chapterNumber = currentChapters.count + 1
            chapter.title = "第\(numberToChinese(chapterNumber))章"
        } else {
            chapter.title = title
        }
        chapter.content = ""
        chapter.createdAt = Date()
        chapter.updatedAt = Date()
        chapter.book = book
        
        saveContext()
    }
    
    func updateChapter(_ chapter: ChapterEntity, content: String) {
        chapter.content = content
        chapter.updatedAt = Date()
        
        saveContext()
    }
    
    func updateChapterTitle(_ chapter: ChapterEntity, title: String) {
        chapter.title = title
        chapter.updatedAt = Date()
        
        saveContext()
    }
    
    func deleteChapter(_ chapter: ChapterEntity) {
        context.delete(chapter)
        saveContext()
    }
    
    // MARK: - 辅助方法
    private func saveContext() {
        do {
            try context.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
    
    // 数字转中文数字
    private func numberToChinese(_ num: Int) -> String {
        let digits = ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
        let units = ["", "十", "百", "千", "万", "十", "百", "千", "亿"]
        
        if num < 0 {
            return "负" + numberToChinese(-num)
        }
        
        if num < 10 {
            return digits[num]
        }
        
        if num < 20 {
            return num == 10 ? "十" : "十" + digits[num % 10]
        }
        
        var result = ""
        var temp = num
        var count = 0
        
        while temp > 0 {
            let digit = temp % 10
            if digit != 0 {
                result = digits[digit] + units[count] + result
            } else if !result.isEmpty && !result.hasPrefix(digits[0]) {
                // 避免多个零
                if temp / 10 > 0 {
                    result = digits[0] + result
                }
            }
            temp /= 10
            count += 1
        }
        
        return result
    }
} 