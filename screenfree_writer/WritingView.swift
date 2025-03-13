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
        NavigationStack {
            VStack {
                // 顶部工具栏
                HStack {
                    Text("我的书籍")
                        .font(.title)
                        .bold()
                    
                    Spacer()
                    
                    Menu {
                        Button(action: { showingNewBookSheet = true }) {
                            Label("新建书籍", systemImage: "plus")
                        }
                        
                        Menu("排序方式") {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Button(action: { sortOption = option }) {
                                    Label(option.rawValue, systemImage: option == sortOption ? "checkmark" : "")
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                    }
                }
                .padding()
                
                // 书籍网格
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
                    ], spacing: 16) {
                        ForEach(viewModel.books) { book in
                            BookCard(book: book)
                        }
                    }
                    .padding()
                }
            }
            .sheet(isPresented: $showingNewBookSheet) {
                NewBookView(viewModel: viewModel)
            }
        }
    }
}

struct BookCard: View {
    let book: BookEntity
    @StateObject private var viewModel = BookViewModel()
    @State private var isSyncing = false
    
    var body: some View {
        NavigationLink(destination: BookDetailView(book: book)) {
            VStack {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                    .frame(width: 80, height: 80)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Text(book.title ?? "未命名")
                    .font(.headline)
                    .lineLimit(1)
                
                Text("\(totalWordCount) 字")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(backgroundColor)
            .cornerRadius(16)
            .shadow(radius: 2)
            .contextMenu {
                Button(action: {
                    Task {
                        isSyncing = true
                        do {
                            try await CloudKitService.shared.syncBook(book)
                        } catch {
                            print("Error syncing book: \(error)")
                        }
                        isSyncing = false
                    }
                }) {
                    Label("同步到云端", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(isSyncing)
                
                Button(role: .destructive, action: {
                    viewModel.deleteBook(book)
                }) {
                    Label("删除书籍", systemImage: "trash")
                }
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
}

#Preview {
    WritingView()
} 