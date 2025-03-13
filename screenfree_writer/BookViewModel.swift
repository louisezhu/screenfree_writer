import Foundation
import CoreData
import SwiftUI
import CloudKit

class BookViewModel: ObservableObject {
    private let context = CoreDataManager.shared.context
    private let cloudKitService = CloudKitService.shared
    
    @Published var books: [BookEntity] = []
    
    init() {
        fetchBooks()
        syncWithCloud()
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
                try await cloudKitService.syncBook(book)
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
} 