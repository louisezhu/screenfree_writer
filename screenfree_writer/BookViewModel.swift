import Foundation
import CoreData
import SwiftUI
import CloudKit
import Compression

class BookViewModel: ObservableObject {
    private let context = CoreDataManager.shared.context
    private let cloudKitService = CloudKitService.shared
    
    @Published var books: [BookEntity] = []
    @Published var iCloudStatus: ICloudStatus = .unknown
    @Published var iCloudErrorMessage: String?
    @Published var showICloudAlert = false
    
    init() {
        fetchBooks()
        syncWithCloud()
        checkICloudStatus()
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
        syncBookToCloud(book)
    }
    
    func updateBook(_ book: BookEntity, title: String, description: String) {
        book.title = title
        book.updatedAt = Date()
        
        saveContext()
        syncBookToCloud(book)
    }
    
    func deleteBook(_ book: BookEntity) {
        context.delete(book)
        saveContext()
        deleteBookFromCloud(book.id!)
    }
    
    func addChapter(to book: BookEntity, title: String) {
        let chapter = ChapterEntity(context: context)
        chapter.id = UUID()
        chapter.title = title
        chapter.content = ""
        chapter.createdAt = Date()
        chapter.updatedAt = Date()
        chapter.book = book
        
        saveContext()
        syncChapterToCloud(chapter)
    }
    
    func updateChapter(_ chapter: ChapterEntity, content: String) {
        chapter.content = content
        chapter.updatedAt = Date()
        
        saveContext()
        syncChapterToCloud(chapter)
    }
    
    func updateChapterTitle(_ chapter: ChapterEntity, title: String) {
        chapter.title = title
        chapter.updatedAt = Date()
        
        saveContext()
        syncChapterToCloud(chapter)
    }
    
    func deleteChapter(_ chapter: ChapterEntity) {
        context.delete(chapter)
        saveContext()
        deleteChapterFromCloud(chapter.id!)
    }
    
    // MARK: - 云同步
    private func syncWithCloud() {
        Task {
            do {
                let bookRecords = try await cloudKitService.fetchBooks()
                await MainActor.run {
                    for record in bookRecords {
                        if let bookId = record.value(forKey: "id") as? String,
                           let uuid = UUID(uuidString: bookId),
                           !books.contains(where: { $0.id == uuid }) {
                            createBookFromRecord(record)
                        }
                    }
                }
            } catch {
                print("Error syncing with cloud: \(error)")
            }
        }
    }
    
    private func syncBookToCloud(_ book: BookEntity) {
        Task {
            do {
                try await syncBookToCloud(book)
            } catch {
                print("Error syncing book to cloud: \(error)")
            }
        }
    }
    
    private func syncChapterToCloud(_ chapter: ChapterEntity) {
        Task {
            do {
                try await cloudKitService.syncChapter(chapter)
            } catch {
                print("Error syncing chapter to cloud: \(error)")
            }
        }
    }
    
    private func deleteBookFromCloud(_ bookId: UUID) {
        Task {
            do {
                try await cloudKitService.deleteBook(bookId)
            } catch {
                print("Error deleting book from cloud: \(error)")
            }
        }
    }
    
    private func deleteChapterFromCloud(_ chapterId: UUID) {
        Task {
            do {
                try await cloudKitService.deleteChapter(chapterId)
            } catch {
                print("Error deleting chapter from cloud: \(error)")
            }
        }
    }
    
    // MARK: - 辅助方法
    private func createBookFromRecord(_ record: CKRecord) {
        let book = BookEntity(context: context)
        book.id = UUID(uuidString: record.value(forKey: "id") as? String ?? "")
        book.title = record.value(forKey: "title") as? String
        book.createdAt = record.value(forKey: "createdAt") as? Date
        book.updatedAt = record.value(forKey: "updatedAt") as? Date
        
        saveContext()
    }
    
    private func saveContext() {
        do {
            try context.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
    
    func checkICloudStatus() {
        CKContainer.default().accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    self?.iCloudStatus = .available
                case .noAccount, .restricted, .couldNotDetermine, .temporarilyUnavailable:
                    self?.iCloudStatus = .unavailable
                    self?.iCloudErrorMessage = "您需要登录 iCloud 账户才能使用同步功能。"
                @unknown default:
                    self?.iCloudStatus = .unknown
                }
            }
        }
    }
    
    func syncBookToCloud(_ book: BookEntity) async throws {
        // 检查 iCloud 状态
        if iCloudStatus != .available {
            DispatchQueue.main.async {
                self.iCloudErrorMessage = "您需要登录 iCloud 账户才能同步。请在设置中登录 iCloud 账户。"
                self.showICloudAlert = true
            }
            throw NSError(domain: "com.screenfree.writer", code: 1002, userInfo: [NSLocalizedDescriptionKey: "iCloud 未登录"])
        }
        
        // 创建 CKRecord
        let bookID = book.id?.uuidString ?? UUID().uuidString
        let recordID = CKRecord.ID(recordName: "book-\(bookID)")
        let record = CKRecord(recordType: "Book", recordID: recordID)
        
        // 设置记录的字段
        record["title"] = book.title as CKRecordValue?
        record["createdAt"] = book.createdAt as CKRecordValue?
        record["updatedAt"] = book.updatedAt as CKRecordValue?
        
        // 将内容序列化为 JSON 数据
        if let chapters = book.chapters as? Set<ChapterEntity>, !chapters.isEmpty {
            var chapterDicts: [[String: Any]] = []
            
            for chapter in chapters {
                var chapterDict: [String: Any] = [:]
                chapterDict["id"] = chapter.id?.uuidString
                chapterDict["title"] = chapter.title
                chapterDict["content"] = chapter.content
                chapterDict["createdAt"] = chapter.createdAt?.timeIntervalSince1970
                chapterDict["updatedAt"] = chapter.updatedAt?.timeIntervalSince1970
                chapterDicts.append(chapterDict)
            }
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: chapterDicts)
                let compressedData = try (jsonData as NSData).compressed(using: .lzfse)
                record["chaptersData"] = compressedData as CKRecordValue
            } catch {
                print("Error serializing chapters: \(error)")
            }
        }
        
        // 保存记录到 CloudKit
        do {
            let database = CKContainer.default().privateCloudDatabase
            try await database.save(record)
            
            // 更新本地同步状态
            DispatchQueue.main.async {
                if let bookEntity = CoreDataManager.shared.context.object(with: book.objectID) as? BookEntity {
                    // 使用 SyncStatusManager 记录同步时间
                    if let bookId = book.id {
                        SyncStatusManager.shared.setLastSyncTime(for: bookId, date: Date())
                    }
                    
                    book.updatedAt = Date()
                    CoreDataManager.shared.saveContext()
                }
            }
        } catch let error as CKError {
            print("CloudKit error: \(error.localizedDescription)")
            
            if error.code == .notAuthenticated {
                DispatchQueue.main.async {
                    self.iCloudStatus = .unavailable
                    self.iCloudErrorMessage = "您需要登录 iCloud 账户才能使用同步功能。"
                    self.showICloudAlert = true
                }
            }
            
            throw error
        }
    }
}

enum ICloudStatus {
    case available
    case unavailable
    case unknown
} 