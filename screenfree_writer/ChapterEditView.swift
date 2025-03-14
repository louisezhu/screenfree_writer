import SwiftUI
import UIKit

struct CustomTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange
    var suggestions: [Suggestion]
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = .systemFont(ofSize: 16)
        textView.backgroundColor = UIColor(AppTheme.cardBackground)
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        textView.isScrollEnabled = true
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .yes
        
        // 设置初始文本和光标位置
        textView.text = text
        if !text.isEmpty {
            textView.selectedRange = NSRange(location: text.count, length: 0)
        }
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        // 检查文本是否变化
        let textChanged = uiView.text != text
        
        // 检查建议是否变化 - 比较数组长度和内容
        let suggestionsChanged = areArraysDifferent(context.coordinator.lastSuggestions, suggestions)
        
        // 设置当前光标位置
        let currentSelectedRange = selectedRange.location < text.count ? selectedRange : NSRange(location: text.count, length: 0)
        
        // 如果文本或建议变化，需要更新
        if textChanged || suggestionsChanged {
            // 记录当前光标位置
            let viewSelectedRange = uiView.selectedRange.location < uiView.text.count ? uiView.selectedRange : NSRange(location: uiView.text.count, length: 0)
            
            // 创建富文本
            let attributedString = NSMutableAttributedString(string: text)
            
            // 设置基本样式
            attributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 16), range: NSRange(location: 0, length: text.count))
            
            // 高亮所有需要修改的文本，但限制在各自的上下文范围内
            for suggestion in suggestions {
                if !suggestion.contextText.isEmpty {
                    // 使用上下文信息限制高亮范围
                    let segmentStartIndex = max(0, suggestion.contextStartPosition)
                    let segmentEndIndex = min(text.count, segmentStartIndex + suggestion.contextText.count)
                    
                    if segmentStartIndex < segmentEndIndex && segmentEndIndex <= text.count {
                        // 构建段落范围的NSRange
                        let segmentRange = NSRange(location: segmentStartIndex, length: segmentEndIndex - segmentStartIndex)
                        
                        // 在段落范围内查找匹配项
                        let nsText = text as NSString
                        var searchRange = segmentRange
                        var foundRange = nsText.range(of: suggestion.original, options: [], range: searchRange)
                        
                        while foundRange.location != NSNotFound && NSLocationInRange(foundRange.location, segmentRange) {
                            // 使用黄色背景和红色下划线突出显示
                            attributedString.addAttribute(.backgroundColor, value: UIColor.yellow.withAlphaComponent(0.3), range: foundRange)
                            attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: foundRange)
                            attributedString.addAttribute(.underlineColor, value: UIColor.red, range: foundRange)
                            
                            // 更新搜索范围，继续查找下一个匹配项，但仍限制在段落内
                            let newLocation = foundRange.location + foundRange.length
                            let newLength = segmentRange.location + segmentRange.length - newLocation
                            if newLength > 0 {
                                searchRange = NSRange(location: newLocation, length: newLength)
                                foundRange = nsText.range(of: suggestion.original, options: [], range: searchRange)
                            } else {
                                break
                            }
                        }
                    }
                } else {
                    // 向后兼容：如果没有上下文信息，使用原来的方法
                    let nsText = text as NSString
                    var searchRange = NSRange(location: 0, length: nsText.length)
                    var foundRange = nsText.range(of: suggestion.original, options: [], range: searchRange)
                    
                    while foundRange.location != NSNotFound {
                        attributedString.addAttribute(.backgroundColor, value: UIColor.yellow.withAlphaComponent(0.3), range: foundRange)
                        attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: foundRange)
                        attributedString.addAttribute(.underlineColor, value: UIColor.red, range: foundRange)
                        
                        searchRange = NSRange(location: foundRange.location + foundRange.length, length: nsText.length - (foundRange.location + foundRange.length))
                        foundRange = nsText.range(of: suggestion.original, options: [], range: searchRange)
                    }
                }
            }
            
            // 更新文本视图
            uiView.attributedText = attributedString
            
            // 恢复光标位置 - 优先使用视图中的选择位置
            if textChanged {
                // 如果是文本改变，使用传入的选择范围
                uiView.selectedRange = currentSelectedRange
            } else {
                // 如果只是建议改变，保持当前编辑位置
                uiView.selectedRange = viewSelectedRange
            }
            
            // 更新上次的建议记录
            context.coordinator.lastSuggestions = suggestions
        } else if uiView.selectedRange.location != currentSelectedRange.location {
            // 如果只是光标位置需要更新
            uiView.selectedRange = currentSelectedRange
        }
    }
    
    // 辅助方法：比较两个数组是否不同
    private func areArraysDifferent<T: Identifiable>(_ array1: [T], _ array2: [T]) -> Bool {
        // 首先比较长度
        if array1.count != array2.count {
            return true
        }
        
        // 然后比较每个元素的 ID
        let ids1 = Set(array1.map { $0.id })
        let ids2 = Set(array2.map { $0.id })
        
        return ids1 != ids2
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: CustomTextEditor
        var lastSuggestions: [Suggestion] = []
        
        init(_ parent: CustomTextEditor) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            // 更新绑定的文本值
            parent.text = textView.text
            
            // 更新光标位置
            parent.selectedRange = textView.selectedRange
            
            // 如果有建议，应用高亮
            if !lastSuggestions.isEmpty {
                // 记录当前光标位置
                let selectedRange = textView.selectedRange
                
                // 创建富文本
                let attributedString = NSMutableAttributedString(string: textView.text)
                
                // 设置基本样式
                attributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 16), range: NSRange(location: 0, length: textView.text.count))
                
                // 高亮所有需要修改的文本，但限制在各自的上下文范围内
                for suggestion in lastSuggestions {
                    if !suggestion.contextText.isEmpty {
                        // 使用上下文信息限制高亮范围
                        let segmentStartIndex = max(0, suggestion.contextStartPosition)
                        let segmentEndIndex = min(textView.text.count, segmentStartIndex + suggestion.contextText.count)
                        
                        if segmentStartIndex < segmentEndIndex && segmentEndIndex <= textView.text.count {
                            // 构建段落范围的NSRange
                            let segmentRange = NSRange(location: segmentStartIndex, length: segmentEndIndex - segmentStartIndex)
                            
                            // 在段落范围内查找匹配项
                            let nsText = textView.text as NSString
                            var searchRange = segmentRange
                            var foundRange = nsText.range(of: suggestion.original, options: [], range: searchRange)
                            
                            while foundRange.location != NSNotFound && NSLocationInRange(foundRange.location, segmentRange) {
                                // 使用黄色背景和红色下划线突出显示
                                attributedString.addAttribute(.backgroundColor, value: UIColor.yellow.withAlphaComponent(0.3), range: foundRange)
                                attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: foundRange)
                                attributedString.addAttribute(.underlineColor, value: UIColor.red, range: foundRange)
                                
                                // 更新搜索范围，继续查找下一个匹配项，但仍限制在段落内
                                let newLocation = foundRange.location + foundRange.length
                                let newLength = segmentRange.location + segmentRange.length - newLocation
                                if newLength > 0 {
                                    searchRange = NSRange(location: newLocation, length: newLength)
                                    foundRange = nsText.range(of: suggestion.original, options: [], range: searchRange)
                                } else {
                                    break
                                }
                            }
                        }
                    } else {
                        // 向后兼容：如果没有上下文信息，使用原来的方法
                        let nsText = textView.text as NSString
                        var searchRange = NSRange(location: 0, length: nsText.length)
                        var foundRange = nsText.range(of: suggestion.original, options: [], range: searchRange)
                        
                        while foundRange.location != NSNotFound {
                            attributedString.addAttribute(.backgroundColor, value: UIColor.yellow.withAlphaComponent(0.3), range: foundRange)
                            attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: foundRange)
                            attributedString.addAttribute(.underlineColor, value: UIColor.red, range: foundRange)
                            
                            searchRange = NSRange(location: foundRange.location + foundRange.length, length: nsText.length - (foundRange.location + foundRange.length))
                            foundRange = nsText.range(of: suggestion.original, options: [], range: searchRange)
                        }
                    }
                }
                
                // 更新文本视图
                textView.attributedText = attributedString
                
                // 恢复光标位置，确保不会超出文本长度
                if selectedRange.location <= textView.text.count {
                    textView.selectedRange = selectedRange
                } else if !textView.text.isEmpty {
                    textView.selectedRange = NSRange(location: textView.text.count, length: 0)
                }
            }
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.selectedRange = textView.selectedRange
        }
    }
}

struct ChapterEditView: View {
    @StateObject private var viewModel = BookViewModel()
    @State private var showingSidebar = false
    @State private var content: String = ""
    @State private var previousContentLength: Int = 0
    @FocusState private var isEditing: Bool
    @State private var undoManager: UndoManager?
    @State private var showingSearch = false
    @State private var searchText = ""
    @State private var replaceText = ""
    @State private var isReplacing = false
    @State private var currentMatchIndex = 0
    @State private var matches: [Range<String.Index>] = []
    @State private var suggestions: [Suggestion] = []
    @State private var isChecking = false
    @State private var acceptedSuggestions: Set<UUID> = []
    @State private var lastCheckedParagraph: String = ""
    @State private var checkedParagraphs: Set<String> = []
    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)
    @State private var currentTextIsPerfect: Bool = false
    @State private var checkTextTask: Task<Void, Never>? = nil
    @State private var isTyping: Bool = false
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
                ZStack {
                    // 背景色
                    AppTheme.cardBackground.ignoresSafeArea()
                    
                    CustomTextEditor(text: $content, selectedRange: $selectedRange, suggestions: suggestions)
                        .focused($isEditing)
                        .textInputAutocapitalization(.never)
                        .onChange(of: content) { newValue in
                            // 更新章节内容和更新时间
                            chapter.updatedAt = Date()
                            viewModel.updateChapter(chapter, content: newValue)
                            if !searchText.isEmpty {
                                findMatches()
                            }
                        
                            previousContentLength = newValue.count
                            
                            // 取消之前的延迟检测任务
                            checkTextTask?.cancel()
                            isTyping = true
                            
                            // 检查是否刚刚输入了标点符号
                            let justEnteredPunctuation = didJustEnterPunctuation(in: newValue)
                            
                            // 创建新的延迟检测任务
                            checkTextTask = Task {
                                // 根据是否输入标点符号决定延迟时间
                                // 如果刚输入标点符号，我们可以立即检查或稍微等待一下
                                let delayTime = justEnteredPunctuation ? 500_000_000 : 1_000_000_000 // 0.5秒或1秒
                                try? await Task.sleep(nanoseconds: UInt64(delayTime))
                                isTyping = false
                                
                                if !Task.isCancelled {
                                    await checkText()
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                .background(AppTheme.background)
                
                // 底部工具栏
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(countWords(content))字")
                            .foregroundColor(AppTheme.secondaryText)
                            .font(.caption)
                        
                        // 添加创建时间和更新时间
                        if let createdAt = chapter.createdAt, let updatedAt = chapter.updatedAt {
                            Text("创建: \(formattedShortDate(createdAt))")
                                .foregroundColor(AppTheme.secondaryText)
                                .font(.caption2)
                            Text("更新: \(formattedShortDate(updatedAt))")
                                .foregroundColor(AppTheme.secondaryText)
                                .font(.caption2)
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Button(action: {
                            undoManager?.undo()
                        }) {
                            Image(systemName: "arrow.uturn.backward")
                                .foregroundColor(AppTheme.secondaryText)
                        }
                        .disabled(!(undoManager?.canUndo ?? false))
                        
                        Button(action: {
                            undoManager?.redo()
                        }) {
                            Image(systemName: "arrow.uturn.forward")
                                .foregroundColor(AppTheme.secondaryText)
                        }
                        .disabled(!(undoManager?.canRedo ?? false))
                        
                        Button(action: { showingSearch.toggle() }) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(AppTheme.secondaryText)
                        }
                    
                    Button(action: { showingSidebar.toggle() }) {
                            Image(systemName: "checkmark.bubble")
                                .foregroundColor(!suggestions.isEmpty ? AppTheme.accent : AppTheme.primary)
                        }
                    }
                }
                .padding()
                .background(AppTheme.cardBackground)
                .shadow(radius: 1)
            }
            
            // 侧边栏
            if showingSidebar {
                SidebarView(
                    suggestions: $suggestions,
                    isChecking: $isChecking,
                    acceptedSuggestions: $acceptedSuggestions,
                    content: $content,
                    checkedParagraphs: $checkedParagraphs,
                    currentTextIsPerfect: currentTextIsPerfect
                )
                .frame(width: 300)
                .background(AppTheme.cardBackground)
                .overlay(
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(width: 1),
                    alignment: .leading
                )
            }
        }
        .navigationTitle(chapter.title ?? "未命名")
        .navigationBarTitleDisplayMode(.inline)
        .background(AppTheme.background)
        .onAppear {
            content = chapter.content ?? ""
            previousContentLength = content.count
            isEditing = true
            undoManager = UndoManager()
            
            // 设置光标位置到文本末尾
            selectedRange = NSRange(location: content.count, length: 0)
            
            Task {
                await checkText()
            }
        }
        .onDisappear {
            undoManager?.removeAllActions()
            checkTextTask?.cancel()
        }
    }
    
    private func checkText() async {
        guard !content.isEmpty else { return }
        
        // 获取当前光标位置之前的内容
        let currentIndex = selectedRange.location
        let textBeforeCursor = currentIndex > 0 ? String(content.prefix(currentIndex)) : ""
        
        // 查找最后一个标点符号的位置
        let punctuations = "，。！？,.!?"
        var lastSegmentStart = 0
        var lastPunctuationIndex = -1
        
        // 从光标位置向前查找最近的两个标点符号
        for (index, char) in textBeforeCursor.enumerated().reversed() {
            if punctuations.contains(char) {
                if lastPunctuationIndex == -1 {
                    // 找到第一个标点符号（最近的）
                    lastPunctuationIndex = index
                } else {
                    // 找到第二个标点符号
                    lastSegmentStart = index + 1
                    break
                }
            }
        }
        
        // 如果没有找到两个标点符号，使用内容开头作为段落起始
        if lastPunctuationIndex == -1 {
            // 没有找到任何标点符号，检查全部内容
            lastSegmentStart = 0
            lastPunctuationIndex = textBeforeCursor.count - 1
        } else if lastSegmentStart == 0 && lastPunctuationIndex != -1 {
            // 只找到一个标点符号，从开头到该标点符号
            lastSegmentStart = 0
        }
        
        // 提取要检查的段落
        let startIndex = textBeforeCursor.index(textBeforeCursor.startIndex, offsetBy: lastSegmentStart)
        let endIndex = textBeforeCursor.index(textBeforeCursor.startIndex, offsetBy: min(lastPunctuationIndex + 1, textBeforeCursor.count))
        var segmentToCheck = String(textBeforeCursor[startIndex..<endIndex])
        
        // 记录段落在整个文本中的起始位置，用于后续定位替换
        let segmentStartPosition = lastSegmentStart
        
        // 移除段落末尾的标点符号和空白
        if !segmentToCheck.isEmpty {
            // 移除尾部的标点符号
            while !segmentToCheck.isEmpty && punctuations.contains(segmentToCheck.last!) {
                segmentToCheck.removeLast()
            }
            
            // 移除尾部的空白
            segmentToCheck = segmentToCheck.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 移除开头的标点符号（如果有的话）
            while !segmentToCheck.isEmpty && punctuations.contains(segmentToCheck.first!) {
                segmentToCheck.removeFirst()
            }
        }
        
        // 如果这个段落已经检查过，内容没有变化，或者太短，则跳过
        if checkedParagraphs.contains(segmentToCheck) || segmentToCheck.isEmpty || segmentToCheck.count < 2 {
            if checkedParagraphs.contains(segmentToCheck) {
                print("段落已检查过，跳过: \"\(segmentToCheck)\"")
            }
            return
        }

        print("检查段落: \"\(segmentToCheck)\"") // 调试用，可以在发布版中删除
        

        isChecking = true
        currentTextIsPerfect = false
        
        do {
            // 创建一个检测任务，并赋予它一个变量，这样可以在任务取消时捕获到
            let task = Task {
                try await DeepseekService.shared.checkText(segmentToCheck)
            }
            
            // 设置一个超时控制
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30秒超时
                task.cancel()
                return []
            }
            
            // 等待任务完成并获取结果
            let newSuggestions = try await task.value
            
            // 取消超时任务
            timeoutTask.cancel()
            
            // 如果任务已经被取消，提前返回
            if Task.isCancelled {
                isChecking = false
                return
            }
            
            // 如果没有建议，可能文本是完美的
            if newSuggestions.isEmpty {
                currentTextIsPerfect = true
                // 如果当前句子没有问题，我们可以选择自动关闭侧边栏
                if showingSidebar {
                    // 可选：自动关闭侧边栏（取消注释此行）
                    // showingSidebar = false
                }
            } else {
                // 过滤掉已接受的建议
                let filteredSuggestions = newSuggestions.filter { !acceptedSuggestions.contains($0.id) }
                // 为每个建议添加上下文信息
                let contextualisedSuggestions = filteredSuggestions.map { suggestion -> Suggestion in
                    var mutableSuggestion = suggestion
                    mutableSuggestion.contextStartPosition = segmentStartPosition
                    mutableSuggestion.contextText = segmentToCheck
                    return mutableSuggestion
                }
                // 更新建议列表，保留其他句子的建议
                suggestions = suggestions.filter { suggestion in
                    !segmentToCheck.contains(suggestion.original)
                } + contextualisedSuggestions
            }
            
            // 将段落添加到已检查集合中
            checkedParagraphs.insert(segmentToCheck)
            lastCheckedParagraph = segmentToCheck
        } catch {
            // 处理错误，但如果是取消错误则忽略
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == -999 {
                print("请求被取消，这是正常的")
            } else {
                print("检查文本时出错：\(error)")
            }
        }
        
        isChecking = false
    }
    
    // 辅助函数：检测是否刚输入了标点符号
    private func didJustEnterPunctuation(in newValue: String) -> Bool {
        guard let lastChar = newValue.last else { return false }
        return "，。！？,.!?".contains(lastChar)
    }
    
    // 辅助函数：格式化日期
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
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
    
    // 辅助函数：格式化短日期
    private func formattedShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
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
    @Binding var suggestions: [Suggestion]
    @Binding var isChecking: Bool
    @Binding var acceptedSuggestions: Set<UUID>
    @Binding var content: String
    @Binding var checkedParagraphs: Set<String>
    let currentTextIsPerfect: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
            Text("修改建议")
                .font(.headline)
                    .foregroundColor(AppTheme.text)
                Spacer()
                
                // 添加重置检查记录的按钮
                Button(action: {
                    checkedParagraphs.removeAll()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(AppTheme.primary)
                        .font(.system(size: 14))
                }
                .buttonStyle(BorderlessButtonStyle())
                .help("重新检查所有内容")
                
                if isChecking {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(AppTheme.cardBackground)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    
            // 内容区域
            if suggestions.isEmpty {
                VStack {
                    Spacer()
                    if isChecking {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            
                            Text("正在检查...")
                                .foregroundColor(AppTheme.secondaryText)
                        }
                    } else if currentTextIsPerfect {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.green)
                            
                            Text("当前文本无误")
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "text.bubble")
                                .font(.system(size: 36))
                                .foregroundColor(AppTheme.secondaryText.opacity(0.6))
                            
                            Text("暂无修改建议")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.secondaryText)
                        }
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(suggestions.filter { !acceptedSuggestions.contains($0.id) }) { suggestion in
                            SuggestionRow(
                                suggestion: suggestion,
                                content: $content,
                                acceptedSuggestions: $acceptedSuggestions
                            )
                            .background(AppTheme.cardBackground)
                            .cornerRadius(10)
                            .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
                            .padding(.horizontal, 8)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .background(AppTheme.background)
    }
}

struct SuggestionRow: View {
    let suggestion: Suggestion
    @Binding var content: String
    @Binding var acceptedSuggestions: Set<UUID>
    @State private var isExpanded = true  // 默认展开
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏 - 原始文本和展开/折叠按钮
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Text(suggestion.original)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppTheme.text)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(AppTheme.secondaryText)
                        .font(.caption)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.clear)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    // 建议内容
                    VStack(alignment: .leading, spacing: 6) {
                        Text("建议：")
                            .font(.caption)
                            .foregroundColor(AppTheme.secondaryText)
                        
                        Text(suggestion.suggestion)
                .font(.body)
                            .foregroundColor(AppTheme.primary)
                            .padding(8)
                            .background(AppTheme.primary.opacity(0.1))
                            .cornerRadius(6)
                    }
                    
                    // 原因
                    VStack(alignment: .leading, spacing: 6) {
                        Text("原因：")
                            .font(.caption)
                            .foregroundColor(AppTheme.secondaryText)
                        
                        Text(suggestion.reason)
                            .font(.caption)
                            .foregroundColor(AppTheme.text)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(6)
                    }
                    
                    // 操作按钮
                    HStack(spacing: 12) {
                        Button(action: {
                            // 只在当前段落中替换文本
                            if !suggestion.contextText.isEmpty {
                                // 使用上下文信息限制替换范围
                                let segmentStartIndex = max(0, suggestion.contextStartPosition)
                                let segmentEndIndex = min(content.count, segmentStartIndex + suggestion.contextText.count)
                                
                                if segmentStartIndex < segmentEndIndex && segmentEndIndex <= content.count {
                                    // 获取段落文本
                                    let segmentText = String(content[content.index(content.startIndex, offsetBy: segmentStartIndex)..<content.index(content.startIndex, offsetBy: segmentEndIndex)])
                                    
                                    // 在段落中查找原始文本
                                    if let range = segmentText.range(of: suggestion.original) {
                                        // 计算在完整文本中的位置
                                        let fullTextStartIndex = content.index(content.startIndex, offsetBy: segmentStartIndex)
                                        let actualStartIndex = content.index(fullTextStartIndex, offsetBy: range.lowerBound.utf16Offset(in: segmentText))
                                        let actualEndIndex = content.index(fullTextStartIndex, offsetBy: range.upperBound.utf16Offset(in: segmentText))
                                        
                                        // 替换文本
                                        var newContent = content
                                        newContent.replaceSubrange(actualStartIndex..<actualEndIndex, with: suggestion.suggestion)
                                        content = newContent
                                        
                                        // 标记为已接受
                                        acceptedSuggestions.insert(suggestion.id)
                                    }
                                }
                            } else {
                                // 向后兼容：如果没有上下文信息，使用原来的方法
                                if let range = content.range(of: suggestion.original) {
                                    var newContent = content
                                    newContent.replaceSubrange(range, with: suggestion.suggestion)
                                    content = newContent
                                    
                                    // 标记为已接受
                                    acceptedSuggestions.insert(suggestion.id)
                                }
                            }
                        }) {
                    Text("采纳")
                                .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                                .background(AppTheme.primary)
                                .cornerRadius(6)
                }
                
                        Button(action: {
                            // 标记为已忽略
                            acceptedSuggestions.insert(suggestion.id)
                        }) {
                    Text("忽略")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.secondaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                        }
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(Color.white)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
        .id(suggestion.id) // 添加稳定 ID 避免重新渲染时消失
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
