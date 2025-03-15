import SwiftUI

struct BookDetailView: View {
    @StateObject private var viewModel = BookViewModel()
    @State private var showingNewChapterSheet = false
    @State private var selectedChapter: ChapterEntity?
    @State private var showingChapterOptions = false
    @State private var showingEditBookSheet = false
    @State private var editingBookTitle: String = ""
    @State private var showingDeleteAlert = false
    @State private var showingRenameSheet = false
    @State private var newChapterTitle: String = ""
    @State private var refreshID = UUID()
    @State private var hasAppeared = false
    @Environment(\.dismiss) private var dismiss
    let book: BookEntity
    
    var body: some View {
        ZStack {
            // 背景
            AppTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 书籍信息头部
                VStack(spacing: 0) {
                    HStack(spacing: 20) {
                        // 方形书籍封面
                        AspectRatio(3/4) {
                            ZStack {
                                // 渐变背景
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        AppTheme.primary.opacity(0.7),
                                        AppTheme.secondary.opacity(0.5)
                                    ]),
                                    startPoint: .topLeading,
                                endPoint: .bottomTrailing
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: AppTheme.primary.opacity(0.3), radius: 10, x: 0, y: 5)
                    
                            // 书籍图标
                            VStack {
                                Image(systemName: "book.closed")
                                    .font(.system(size: 40, weight: .light))
                                    .foregroundColor(.white)
                            }
                            }
                        }
                        .frame(width: 160)
                        
                        // 书籍信息
            VStack(alignment: .leading, spacing: 6) {
                // 标题
                Text(book.title ?? "无标题")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.text)
                    .lineLimit(1)
                
                // 章节信息和字数
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet")
                            .font(.caption2)
                        Text("\(book.chapters?.count ?? 0)章")
                            .font(.caption)
                    }
                    .foregroundColor(AppTheme.secondaryText)
                }
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.fill")
                            .font(.caption2)
                        Text("\(totalWordCount)字")
                            .font(.caption)
                    }
                    .foregroundColor(AppTheme.secondaryText)
                }
                
                // 创建和更新时间
                if let createdAt = book.createdAt {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.caption2)
                        Text("创建: \(formattedShortDate(createdAt))")
                            .font(.caption2)
                    }
                    .foregroundColor(AppTheme.secondaryText)
                }
                
                if let updatedAt = book.updatedAt {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption2)
                        Text("更新: \(formattedShortDate(updatedAt))")
                            .font(.caption2)
                    }
                    .foregroundColor(AppTheme.secondaryText)
                }
            }
                        
                        
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                    
                    
                }
                
                // 章节列表
                VStack(alignment: .leading, spacing: 12) {
                    Text("章节列表")
                        .font(.headline)
                        .foregroundColor(AppTheme.text)
                        .padding(.horizontal)
                        .padding(.top, 16)
            
            // 章节列表
                    if let chapters = getSortedChapters(), !chapters.isEmpty {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(chapters) { chapter in
                    ChapterRow(chapter: chapter)
                                        .background(AppTheme.cardBackground)
                                        .cornerRadius(12)
                                        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                                        .padding(.horizontal)
                        .contextMenu {
                            Button(action: {
                                selectedChapter = chapter
                                newChapterTitle = chapter.title ?? ""
                                showingRenameSheet = true
                            }) {
                                Label("重命名", systemImage: "pencil")
                            }
                            Button(role: .destructive, action: {
                                viewModel.deleteChapter(chapter)
                                refreshID = UUID()
                            }) {
                                Label("删除", systemImage: "trash")
                            }
                        }
                }
                            }
                            .padding(.bottom, 100) // 留出底部空间给FAB
                            .id(refreshID)
                        }
                    } else {
                        // 空状态
                        VStack(spacing: 16) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 48))
                                .foregroundColor(AppTheme.secondary.opacity(0.5))
                            
                            Text("还没有章节")
                                .font(.headline)
                                .foregroundColor(AppTheme.secondaryText)
                            
                            Text("点击右下角的+按钮创建第一个章节")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .id(refreshID)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(AppTheme.background)
                .cornerRadius(24, corners: [.topLeft, .topRight])
                .padding(.top, 16)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        // 只设置标题
                        editingBookTitle = book.title ?? ""
                        showingEditBookSheet = true
                    }) {
                        Label("编辑书籍", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive, action: {
                        showingDeleteAlert = true
                    }) {
                        Label("删除书籍", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(AppTheme.primary)
                }
            }
        }
        .overlay(
            // 悬浮添加按钮
            Button(action: { showingNewChapterSheet = true }) {
                Image(systemName: "plus")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [AppTheme.primary, AppTheme.secondary]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                    .shadow(color: AppTheme.primary.opacity(0.4), radius: 10, x: 0, y: 5)
            }
            .padding(20),
            alignment: .bottomTrailing
        )
        .sheet(isPresented: $showingNewChapterSheet, onDismiss: {
            refreshID = UUID()
        }) {
            NewChapterView(book: book, viewModel: viewModel)
        }
        .sheet(isPresented: $showingEditBookSheet) {
            EditBookView(book: book, bookTitle: $editingBookTitle, viewModel: viewModel)
        }
        .sheet(isPresented: $showingRenameSheet, onDismiss: {
            refreshID = UUID()
        }) {
            RenameChapterView(chapter: selectedChapter, chapterTitle: $newChapterTitle, viewModel: viewModel)
        }
        .alert("确定删除此书籍？", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                viewModel.deleteBook(book)
                dismiss()
            }
        } message: {
            Text("此操作不可撤销，书籍中的所有章节将被永久删除。")
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
            }
        }
        .onDisappear {
            if hasAppeared && book.chapters?.count ?? 0 > 0 {
                viewModel.updateBookTimestamp(book)
            }
        }
    }
    
    private func getSortedChapters() -> [ChapterEntity]? {
        if let chapters = book.chapters?.allObjects as? [ChapterEntity] {
            return chapters.sorted { 
                ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast) 
            }
        }
        return nil
    }
    
    private var totalWordCount: Int {
        let chapters = book.chapters?.allObjects as? [ChapterEntity] ?? []
        return chapters.reduce(0) { $0 + countWords($1.content ?? "") }
    }
    
    // 辅助函数：准确计算中文和英文字数（不包括标点、空格和换行）
    private func countWords(_ text: String) -> Int {
        // 移除所有标点符号、空格和换行
        let pattern = "[\\p{P}\\p{Z}\\p{C}]"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: text.utf16.count)
        let cleanText = regex?.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
        
        // 返回清理后的文本长度
        return cleanText?.count ?? 0
    }
    
    // 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }
    
    // 格式化短日期
    private func formattedShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

// 扩展视图，支持单独设置某些角的圆角
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// 统计数据视图组件
struct StatisticView: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(AppTheme.primary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.text)
            
            Text(title)
                .font(.caption)
                .foregroundColor(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

// 时间信息视图组件
struct TimeInfoView: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.primary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(AppTheme.secondaryText)
                
                Text(value)
                    .font(.caption)
                    .foregroundColor(AppTheme.text)
            }
        }
    }
}

struct ChapterRow: View {
    let chapter: ChapterEntity
    @State private var navigateToChapter = false
    
    var body: some View {
        Button(action: {
            navigateToChapter = true
        }) {
            HStack {
                // 左侧图标和标题
                HStack(spacing: 12) {
                    // 章节图标
                    ZStack {
                        Circle()
                            .fill(AppTheme.primary.opacity(0.1))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "doc.text")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.primary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(chapter.title ?? "未命名")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.text)
                        
                        // 最后更新时间
                        if let updatedAt = chapter.updatedAt {
                            Text("更新于 \(formattedShortDate(updatedAt))")
                                .font(.caption)
                                .foregroundColor(AppTheme.secondaryText)
                        }
                    }
                }
                
                Spacer()
                
                // 右侧字数和指示器
                HStack(spacing: 8) {
                    Text("\(countWords(chapter.content ?? "")) 字")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle()) // 确保整个区域都可点击
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            NavigationLink(destination: ChapterEditView(chapter: chapter), isActive: $navigateToChapter) {
                EmptyView()
            }
            .opacity(0)
        )
    }
    
    // 辅助函数：准确计算中文和英文字数（不包括标点、空格和换行）
    private func countWords(_ text: String) -> Int {
        // 移除所有标点符号、空格和换行
        let pattern = "[\\p{P}\\p{Z}\\p{C}]"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: text.utf16.count)
        let cleanText = regex?.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
        
        // 返回清理后的文本长度
        return cleanText?.count ?? 0
    }
    
    // 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }
    
    // 格式化短日期
    private func formattedShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

// 编辑书籍视图（简化版，移除description相关内容）
struct EditBookView: View {
    @Environment(\.dismiss) private var dismiss
    let book: BookEntity
    @Binding var bookTitle: String
    @ObservedObject var viewModel: BookViewModel
    @FocusState private var isTitleFocused: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景色
                AppTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // 基本信息部分
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "book")
                                    .foregroundColor(AppTheme.primary)
                            }
                            .padding(.horizontal)
                            
                            VStack(alignment: .leading, spacing: 20) {
                                // 书籍名称
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("书籍名称")
                                        .font(.subheadline)
                                        .foregroundColor(AppTheme.secondaryText)
                                    
                                    TextField("请输入书籍名称", text: $bookTitle)
                                        .focused($isTitleFocused)
                                        .textInputAutocapitalization(.never)
                                        .padding(12)
                                        .background(AppTheme.cardBackground)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(AppTheme.secondary.opacity(0.3), lineWidth: 1)
                                        )
                                }
                            }
                            .padding()
                            .background(AppTheme.cardBackground)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("编辑书籍")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.secondaryText)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        // 更新书籍，不使用description
                        viewModel.updateBook(book, title: bookTitle, description: "")
                        dismiss()
                    }
                    .foregroundColor(bookTitle.isEmpty ? AppTheme.secondaryText.opacity(0.5) : AppTheme.primary)
                    .disabled(bookTitle.isEmpty)
                }
            }
            .onAppear {
                isTitleFocused = true
            }
        }
        .frame(minWidth: 400, minHeight: 200)
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


// 宽高比容器视图
struct AspectRatio<Content: View>: View {
    private let ratio: CGFloat
    private let content: Content
    
    init(_ ratio: CGFloat, @ViewBuilder content: () -> Content) {
        self.ratio = ratio
        self.content = content()
    }
    
    var body: some View {
        content
            .aspectRatio(ratio, contentMode: .fit)
    }
} 

// 章节重命名视图
struct RenameChapterView: View {
    @Environment(\.dismiss) private var dismiss
    let chapter: ChapterEntity?
    @Binding var chapterTitle: String
    @ObservedObject var viewModel: BookViewModel
    @FocusState private var isTitleFocused: Bool
    
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
                                .focused($isTitleFocused)
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
            .navigationTitle("重命名章节")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.secondaryText)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if let chapter = chapter, !chapterTitle.isEmpty {
                            // 调用更新章节标题的方法
                            viewModel.updateChapterTitle(chapter, title: chapterTitle)
                        }
                        dismiss()
                    }
                    .foregroundColor(chapterTitle.isEmpty ? AppTheme.secondaryText.opacity(0.5) : AppTheme.primary)
                    .disabled(chapterTitle.isEmpty)
                }
            }
            .onAppear {
                isTitleFocused = true
            }
        }
    }
} 
