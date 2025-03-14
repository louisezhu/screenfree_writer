import SwiftUI

struct NewChapterView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var chapterTitle: String = ""
    let book: BookEntity
    @ObservedObject var viewModel: BookViewModel
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景色
                AppTheme.background.ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 24) {
                    // 标题部分
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("章节标题")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.secondaryText)
                            
                            TextField("请输入章节标题", text: $chapterTitle)
                                .padding(12)
                                .background(AppTheme.cardBackground)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(AppTheme.secondary.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .padding()
                        .background(AppTheme.cardBackground)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle("新建章节")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.secondaryText)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        viewModel.addChapter(to: book, title: chapterTitle)
                        dismiss()
                    }
                    .foregroundColor(chapterTitle.isEmpty ? AppTheme.secondaryText.opacity(0.5) : AppTheme.primary)
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