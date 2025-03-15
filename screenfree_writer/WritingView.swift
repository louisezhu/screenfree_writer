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
    @State private var refreshID = UUID()
    
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
                        .id(refreshID)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 20) {
                            ForEach(viewModel.books) { book in
                                NavigationLink(destination: BookDetailView(book: book)
                                    .onDisappear {
                                        self.viewModel.fetchBooks()
                                    }
                                ) {
                                    BookCard(book: book)
                                        .id("\(book.id?.uuidString ?? "")-\(refreshID)")
                                }
                            }
                        }
                        .padding()
                        .id(refreshID)
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
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        refreshID = UUID()
                        viewModel.fetchBooks()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showingNewBookSheet, onDismiss: {
                refreshID = UUID()
                viewModel.fetchBooks()
            }) {
                NewBookView(viewModel: viewModel)
            }
            .onAppear {
                refreshID = UUID()
                viewModel.fetchBooks()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct BookCard: View {
    let book: BookEntity
    @StateObject private var viewModel = BookViewModel()
    @State private var localRefreshID = UUID()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AspectRatio(3/4) {
                ZStack {
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
                    
                    VStack {
                        Image(systemName: "book.closed")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(.white)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(book.title ?? "无标题")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.text)
                    .lineLimit(1)
                
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
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.secondary.opacity(0.2), lineWidth: 1)
        )
        .contextMenu {
            Button(role: .destructive, action: {
                viewModel.deleteBook(book)
            }) {
                Label("删除书籍", systemImage: "trash")
            }
        }
        .id(localRefreshID)
        .onAppear {
            localRefreshID = UUID()
        }
    }
    
    private var totalWordCount: Int {
        let chapters = book.chapters?.allObjects as? [ChapterEntity] ?? []
        return chapters.reduce(0) { $0 + countWords($1.content ?? "") }
    }
    
    private func countWords(_ text: String) -> Int {
        let pattern = "[\\p{P}\\p{Z}\\p{C}]"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: text.utf16.count)
        let cleanText = regex?.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
        
        return cleanText?.count ?? 0
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

public func formattedShortDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    return formatter.string(from: date)
}