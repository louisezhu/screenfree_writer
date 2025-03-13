import SwiftUI

struct BookDetailView: View {
    @StateObject private var viewModel = BookViewModel()
    @State private var showingNewChapterSheet = false
    @State private var selectedChapter: ChapterEntity?
    @State private var showingChapterOptions = false
    let book: BookEntity
    
    var body: some View {
        List {
            // 统计信息部分
            Section {
                HStack {
                    StatCard(title: "总字数", value: "\(totalWordCount)", icon: "chart.bar.fill")
                    StatCard(title: "章节数", value: "\(book.chapters?.count ?? 0)", icon: "list.bullet")
                }
            }
            
            // 章节列表
            Section("章节列表") {
                ForEach(book.chapters?.allObjects as? [ChapterEntity] ?? []) { chapter in
                    ChapterRow(chapter: chapter)
                        .contextMenu {
                            Button(action: {}) {
                                Label("重命名", systemImage: "pencil")
                            }
                            Button(role: .destructive, action: {
                                viewModel.deleteChapter(chapter)
                            }) {
                                Label("删除", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .navigationTitle(book.title ?? "未命名")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingNewChapterSheet = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewChapterSheet) {
            NewChapterView(book: book, viewModel: viewModel)
        }
    }
    
    private var totalWordCount: Int {
        book.chapters?.reduce(0) { $0 + (($1 as? ChapterEntity)?.content?.count ?? 0) } ?? 0
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct ChapterRow: View {
    let chapter: ChapterEntity
    
    var body: some View {
        NavigationLink(destination: ChapterEditView(chapter: chapter)) {
            HStack {
                Text(chapter.title ?? "未命名")
                    .font(.body)
                
                Spacer()
                
                Text("\(chapter.content?.count ?? 0) 字")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    NavigationView {
        let context = CoreDataManager.shared.context
        let book = BookEntity(context: context)
        book.id = UUID()
        book.title = "示例书籍"
        book.createdAt = Date()
        book.updatedAt = Date()
        
        let chapter1 = ChapterEntity(context: context)
        chapter1.id = UUID()
        chapter1.title = "第一章"
        chapter1.content = "这是第一章的内容"
        chapter1.createdAt = Date()
        chapter1.updatedAt = Date()
        chapter1.book = book
        
        let chapter2 = ChapterEntity(context: context)
        chapter2.id = UUID()
        chapter2.title = "第二章"
        chapter2.content = "这是第二章的内容"
        chapter2.createdAt = Date()
        chapter2.updatedAt = Date()
        chapter2.book = book
        
        return BookDetailView(book: book)
    }
} 