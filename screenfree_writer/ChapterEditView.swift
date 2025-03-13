import SwiftUI

struct ChapterEditView: View {
    @StateObject private var viewModel = BookViewModel()
    @State private var showingSidebar = false
    @State private var content: String = ""
    @FocusState private var isEditing: Bool
    @State private var undoManager: UndoManager?
    @State private var showingSearch = false
    @State private var searchText = ""
    @State private var replaceText = ""
    @State private var isReplacing = false
    @State private var currentMatchIndex = 0
    @State private var matches: [Range<String.Index>] = []
    let chapter: ChapterEntity
    
    var body: some View {
        HStack(spacing: 0) {
            // 主编辑区域
            VStack(spacing: 0) {
                // 搜索工具栏
                if showingSearch {
                    SearchToolbar(
                        searchText: $searchText,
                        replaceText: $replaceText,
                        isReplacing: $isReplacing,
                        currentMatchIndex: $currentMatchIndex,
                        matches: $matches,
                        content: $content
                    )
                }
                
                // 编辑器
                ScrollView {
                    TextEditor(text: $content)
                        .font(.body)
                        .frame(minHeight: 200)
                        .focused($isEditing)
                        .textInputAutocapitalization(.never)
                        .onChange(of: content) { newValue in
                            viewModel.updateChapter(chapter, content: newValue)
                            if !searchText.isEmpty {
                                findMatches()
                            }
                        }
                        .padding()
                }
                
                // 底部工具栏
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(.secondary)
                        Text("\(content.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Button(action: {
                            undoManager?.undo()
                        }) {
                            Image(systemName: "arrow.uturn.backward")
                                .foregroundColor(.secondary)
                        }
                        .disabled(!(undoManager?.canUndo ?? false))
                        
                        Button(action: {
                            undoManager?.redo()
                        }) {
                            Image(systemName: "arrow.uturn.forward")
                                .foregroundColor(.secondary)
                        }
                        .disabled(!(undoManager?.canRedo ?? false))
                        
                        Button(action: { showingSearch.toggle() }) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                        }
                        
                        Button(action: { showingSidebar.toggle() }) {
                            Image(systemName: "sidebar.right")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .shadow(radius: 1)
            }
            
            // 侧边栏
            if showingSidebar {
                SidebarView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .navigationTitle(chapter.title ?? "未命名")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            content = chapter.content ?? ""
            isEditing = true
            undoManager = UndoManager()
        }
        .onDisappear {
            undoManager?.removeAllActions()
        }
    }
    
    private func findMatches() {
        matches = []
        var searchRange = content.startIndex..<content.endIndex
        
        while let range = content.range(of: searchText, options: [.caseInsensitive], range: searchRange) {
            matches.append(range)
            searchRange = range.upperBound..<content.endIndex
        }
        
        if matches.isEmpty {
            currentMatchIndex = 0
        } else if currentMatchIndex >= matches.count {
            currentMatchIndex = matches.count - 1
        }
    }
}

struct SearchToolbar: View {
    @Binding var searchText: String
    @Binding var replaceText: String
    @Binding var isReplacing: Bool
    @Binding var currentMatchIndex: Int
    @Binding var matches: [Range<String.Index>]
    @Binding var content: String
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // 搜索框
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onChange(of: searchText) { _ in
                            findMatches()
                        }
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                // 替换框
                if isReplacing {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.secondary)
                        TextField("替换为", text: $replaceText)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                // 匹配计数
                if !searchText.isEmpty {
                    Text("\(currentMatchIndex + 1)/\(matches.count)")
                        .foregroundColor(.secondary)
                }
                
                // 操作按钮
                HStack(spacing: 8) {
                    Button(action: {
                        if currentMatchIndex > 0 {
                            currentMatchIndex -= 1
                        }
                    }) {
                        Image(systemName: "chevron.up")
                            .foregroundColor(.secondary)
                    }
                    .disabled(currentMatchIndex == 0)
                    
                    Button(action: {
                        if currentMatchIndex < matches.count - 1 {
                            currentMatchIndex += 1
                        }
                    }) {
                        Image(systemName: "chevron.down")
                            .foregroundColor(.secondary)
                    }
                    .disabled(currentMatchIndex == matches.count - 1)
                    
                    Button(action: {
                        isReplacing.toggle()
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(isReplacing ? .blue : .secondary)
                    }
                    
                    if isReplacing {
                        Button(action: replaceCurrent) {
                            Text("替换")
                                .foregroundColor(.blue)
                        }
                        .disabled(matches.isEmpty)
                        
                        Button(action: replaceAll) {
                            Text("全部替换")
                                .foregroundColor(.blue)
                        }
                        .disabled(matches.isEmpty)
                    }
                    
                    Button(action: {
                        searchText = ""
                        replaceText = ""
                        matches = []
                        currentMatchIndex = 0
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemBackground))
            .shadow(radius: 1)
        }
    }
    
    private func findMatches() {
        matches = []
        var searchRange = content.startIndex..<content.endIndex
        
        while let range = content.range(of: searchText, options: [.caseInsensitive], range: searchRange) {
            matches.append(range)
            searchRange = range.upperBound..<content.endIndex
        }
        
        if matches.isEmpty {
            currentMatchIndex = 0
        } else if currentMatchIndex >= matches.count {
            currentMatchIndex = matches.count - 1
        }
    }
    
    private func replaceCurrent() {
        guard !matches.isEmpty else { return }
        let range = matches[currentMatchIndex]
        content = content.replacingCharacters(in: range, with: replaceText)
        findMatches()
    }
    
    private func replaceAll() {
        guard !matches.isEmpty else { return }
        var newContent = content
        for range in matches.reversed() {
            newContent = newContent.replacingCharacters(in: range, with: replaceText)
        }
        content = newContent
        findMatches()
    }
}

struct SidebarView: View {
    var body: some View {
        VStack(spacing: 0) {
            Text("修改建议")
                .font(.headline)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground))
                .shadow(radius: 1)
            
            List {
                ForEach(0..<3) { _ in
                    SuggestionRow()
                }
            }
        }
        .frame(width: 300)
        .background(Color(.systemBackground))
        .shadow(radius: 2)
    }
}

struct SuggestionRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("建议修改")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("原文：这是一个示例文本")
                .font(.body)
            
            Text("建议：这是一个示例文本")
                .font(.body)
                .foregroundColor(.blue)
            
            HStack {
                Button(action: {}) {
                    Text("采纳")
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                
                Button(action: {}) {
                    Text("忽略")
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationView {
        let context = CoreDataManager.shared.context
        let chapter = ChapterEntity(context: context)
        chapter.id = UUID()
        chapter.title = "第一章"
        chapter.content = "这是第一章的内容"
        chapter.createdAt = Date()
        chapter.updatedAt = Date()
        
        return ChapterEditView(chapter: chapter)
    }
} 