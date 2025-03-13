import Foundation

struct Book: Identifiable {
    let id: UUID
    var title: String
    var description: String
    var chapters: [Chapter]
    var createdAt: Date
    var updatedAt: Date
    
    init(id: UUID = UUID(), title: String, description: String = "", chapters: [Chapter] = []) {
        self.id = id
        self.title = title
        self.description = description
        self.chapters = chapters
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

struct Chapter: Identifiable {
    let id: UUID
    var title: String
    var content: String
    var bookId: UUID
    var createdAt: Date
    var updatedAt: Date
    
    init(id: UUID = UUID(), title: String, content: String = "", bookId: UUID) {
        self.id = id
        self.title = title
        self.content = content
        self.bookId = bookId
        self.createdAt = Date()
        self.updatedAt = Date()
    }
} 