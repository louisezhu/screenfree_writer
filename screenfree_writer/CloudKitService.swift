import CloudKit
import CoreData

class CloudKitService {
    static let shared = CloudKitService()
    private let container = CKContainer.default()
    private let database: CKDatabase
    
    private init() {
        self.database = container.privateCloudDatabase
    }
    
    // MARK: - 同步书籍
    func syncBook(_ book: BookEntity) async throws {
        let record = try createBookRecord(from: book)
        try await database.save(record)
    }
    
    func fetchBooks() async throws -> [CKRecord] {
        let query = CKQuery(recordType: "Book", predicate: NSPredicate(value: true))
        let result = try await database.records(matching: query)
        return result.matchResults.compactMap { try? $0.1.get() }
    }
    
    // MARK: - 同步章节
    func syncChapter(_ chapter: ChapterEntity) async throws {
        let record = try createChapterRecord(from: chapter)
        try await database.save(record)
    }
    
    func fetchChapters(for bookId: UUID) async throws -> [CKRecord] {
        let predicate = NSPredicate(format: "bookId == %@", bookId as CVarArg)
        let query = CKQuery(recordType: "Chapter", predicate: predicate)
        let result = try await database.records(matching: query)
        return result.matchResults.compactMap { try? $0.1.get() }
    }
    
    // MARK: - 删除记录
    func deleteBook(_ bookId: UUID) async throws {
        let predicate = NSPredicate(format: "id == %@", bookId as CVarArg)
        let query = CKQuery(recordType: "Book", predicate: predicate)
        let result = try await database.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        for record in records {
            try await database.deleteRecord(withID: record.recordID)
        }
    }
    
    func deleteChapter(_ chapterId: UUID) async throws {
        let predicate = NSPredicate(format: "id == %@", chapterId as CVarArg)
        let query = CKQuery(recordType: "Chapter", predicate: predicate)
        let result = try await database.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        for record in records {
            try await database.deleteRecord(withID: record.recordID)
        }
    }
    
    // MARK: - 辅助方法
    private func createBookRecord(from book: BookEntity) throws -> CKRecord {
        let record = CKRecord(recordType: "Book")
        record.setValue(book.id?.uuidString, forKey: "id")
        record.setValue(book.title, forKey: "title")
        record.setValue(book.createdAt, forKey: "createdAt")
        record.setValue(book.updatedAt, forKey: "updatedAt")
        return record
    }
    
    private func createChapterRecord(from chapter: ChapterEntity) throws -> CKRecord {
        let record = CKRecord(recordType: "Chapter")
        record.setValue(chapter.id?.uuidString, forKey: "id")
        record.setValue(chapter.title, forKey: "title")
        record.setValue(chapter.content, forKey: "content")
        record.setValue(chapter.createdAt, forKey: "createdAt")
        record.setValue(chapter.updatedAt, forKey: "updatedAt")
        record.setValue(chapter.book?.id?.uuidString, forKey: "bookId")
        return record
    }
} 