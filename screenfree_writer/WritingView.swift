import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct WritingView: View {
    @StateObject private var viewModel = BookViewModel()
    @State private var showingNewBookSheet = false
    @State private var sortOption: SortOption = .name
    
    enum SortOption: String, CaseIterable {
        case name = "名称"
        case date = "日期"
        case wordCount = "字数"
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.books.isEmpty {
                    ContentUnavailableView("还没有书籍", systemImage: "book.closed")
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 20) {
                            ForEach(viewModel.books) { book in
                                NavigationLink(destination: BookDetailView(book: book)) {
                                    BookCard(book: book)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("我的书籍")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingNewBookSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewBookSheet) {
                NewBookView(viewModel: viewModel)
            }
            .alert("iCloud 同步错误", isPresented: $viewModel.showICloudAlert) {
                Button("确定") {
                    viewModel.showICloudAlert = false
                }
                
                Button("打开设置") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } message: {
                Text(viewModel.iCloudErrorMessage ?? "无法连接到 iCloud。请检查您的 iCloud 账户设置。")
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct BookCard: View {
    let book: BookEntity
    @StateObject private var viewModel = BookViewModel()
    @State private var isSyncing = false
    @State private var lastSyncTime: Date? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 书籍封面
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
                
                // 云同步信息
                HStack(spacing: 4) {
                    Image(systemName: lastSyncTime != nil ? "checkmark.icloud" : "icloud")
                        .font(.caption2)
                    Text(lastSyncTime != nil ? "同步于\(formattedTime(lastSyncTime!))" : "未同步")
                        .font(.caption2)
                }
                .foregroundColor(lastSyncTime != nil ? AppTheme.accent : AppTheme.secondaryText)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.secondary.opacity(0.2), lineWidth: 1)
        )
        .contextMenu {
            Button(action: {
                if viewModel.iCloudStatus != .available {
                    viewModel.iCloudErrorMessage = "您需要登录 iCloud 账户才能同步。请在设置中登录 iCloud 账户。"
                    viewModel.showICloudAlert = true
                    return
                }
                
                isSyncing = true
                Task {
                    do {
                        try await viewModel.syncBookToCloud(book)
                        // 同步成功后更新显示的同步时间
                        lastSyncTime = Date()
                    } catch {
                        print("Error syncing book to cloud: \(error)")
                    }
                    isSyncing = false
                }
            }) {
                if isSyncing {
                    ProgressView()
                } else {
                    Label("同步到云端", systemImage: "arrow.triangle.2.circlepath")
                }
            }
            .disabled(isSyncing || viewModel.iCloudStatus != .available)
            
            Button(role: .destructive, action: {
                viewModel.deleteBook(book)
            }) {
                Label("删除书籍", systemImage: "trash")
            }
        }
        .onAppear {
            // 加载上次同步时间
            if let bookId = book.id {
                lastSyncTime = SyncStatusManager.shared.getLastSyncTime(for: bookId)
            }
        }
    }
    
    private var totalWordCount: Int {
        let chapters = book.chapters?.allObjects as? [ChapterEntity] ?? []
        return chapters.reduce(0) { $0 + ($1.content?.count ?? 0) }
    }
    
    // 辅助函数：格式化日期为短格式
    private func formattedShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }
    
    // 辅助函数：仅显示时间
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    // 辅助函数：标准日期格式
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
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
}

#Preview {
    WritingView()
} 
