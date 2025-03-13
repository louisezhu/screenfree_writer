import CoreData
import Foundation

class CoreDataManager {
    static let shared = CoreDataManager()
    
    private init() {}
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "ScreenFreeWriter")
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("无法加载Core Data存储: \(error)")
            }
        }
        return container
    }()
    
    var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("保存Core Data上下文失败: \(error)")
            }
        }
    }
    
    // MARK: - Book Operations
    
    func createBook(title: String, description: String = "") -> BookEntity {
        let book = BookEntity(context: context)
        book.id = UUID()
        book.title = title
        book.createdAt = Date()
        book.updatedAt = Date()
        saveContext()
        return book
    }
    
    func fetchBooks() -> [BookEntity] {
        let request: NSFetchRequest<BookEntity> = BookEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \BookEntity.updatedAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("获取书籍列表失败: \(error)")
            return []
        }
    }
    
    func deleteBook(_ book: BookEntity) {
        context.delete(book)
        saveContext()
    }
    
    // MARK: - Chapter Operations
    
    func createChapter(title: String, content: String = "", book: BookEntity) -> ChapterEntity {
        let chapter = ChapterEntity(context: context)
        chapter.id = UUID()
        chapter.title = title
        chapter.content = content
        chapter.createdAt = Date()
        chapter.updatedAt = Date()
        chapter.book = book
        saveContext()
        return chapter
    }
    
    func updateChapter(_ chapter: ChapterEntity, title: String? = nil, content: String? = nil) {
        if let title = title {
            chapter.title = title
        }
        if let content = content {
            chapter.content = content
        }
        chapter.updatedAt = Date()
        saveContext()
    }
    
    func deleteChapter(_ chapter: ChapterEntity) {
        context.delete(chapter)
        saveContext()
    }
} 