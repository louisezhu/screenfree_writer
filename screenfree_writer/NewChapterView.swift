import SwiftUI

struct NewChapterView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var chapterTitle: String = ""
    let book: BookEntity
    @ObservedObject var viewModel: BookViewModel
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("章节标题", text: $chapterTitle)
                }
            }
            .navigationTitle("新建章节")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        viewModel.addChapter(to: book, title: chapterTitle)
                        dismiss()
                    }
                    .disabled(chapterTitle.isEmpty)
                }
            }
        }
    }
}

#Preview {
    let context = CoreDataManager.shared.context
    let book = BookEntity(context: context)
    book.id = UUID()
    book.title = "示例书籍"
    book.createdAt = Date()
    book.updatedAt = Date()
    
    return NewChapterView(book: book, viewModel: BookViewModel())
} 