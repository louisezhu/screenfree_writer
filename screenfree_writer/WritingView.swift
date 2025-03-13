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
        VStack(alignment: .leading) {
            AspectRatio(3/4) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.2))
                    .overlay(
                        Image(systemName: "book")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                    )
            }
            
            Text(book.title ?? "无标题")
                .font(.headline)
                .lineLimit(1)
            
            Text("章节: \(book.chapters?.count ?? 0)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Text("上次同步时间： \(book.updatedAt?.formatted(.dateTime.month().day().year()) ?? "未同步")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let syncTime = lastSyncTime {
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark.icloud")
                            .font(.caption2)
                        Text(syncTime.formatted(.dateTime.hour().minute()))
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
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
    
    private var backgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
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
