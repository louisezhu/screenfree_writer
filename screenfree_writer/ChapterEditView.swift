import SwiftUI
import UIKit
import Foundation
import AVFoundation

// 创建UITextView的子类以自定义输入附件视图
class NoAccessoryTextView: UITextView {
    // 不覆盖inputAccessoryView属性，而是通过初始化后再处理
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        
        // 在初始化后，使用私有API方法清除输入附件视图
        // 通过KVC绕过公共API的限制
        setValue(nil, forKey: "_inputAccessoryView")
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        // 同样在这个初始化方法中也清除
        setValue(nil, forKey: "_inputAccessoryView")
    }
    
    // 此属性会被iOS用来确定是否有inputAccessoryView
    override var inputAccessoryViewController: UIInputViewController? {
        return nil
    }
    
    // 请求重新加载输入视图，例如当键盘出现时
    override var textInputMode: UITextInputMode? {
        // 通过重写此方法使系统认为没有改变输入模式
        return super.textInputMode
    }
    
    // 重写此方法，使系统认为没有输入附件视图
    override func reloadInputViews() {
        // 在重新加载之前再次确保清除
        setValue(nil, forKey: "_inputAccessoryView")
        super.reloadInputViews()
    }
}

struct CustomTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange
    var suggestions: [Suggestion]
    
    func makeUIView(context: Context) -> UITextView {
        // 使用我们的自定义UITextView子类，并设置适当的frame和textContainer
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: .zero)
        
        // 配置文本容器
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        
        // 创建我们的自定义UITextView
        let textView = NoAccessoryTextView(frame: .zero, textContainer: textContainer)
        textView.delegate = context.coordinator
        textView.font = .systemFont(ofSize: 16)
        textView.backgroundColor = UIColor(AppTheme.cardBackground)
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        textView.isScrollEnabled = true
        
        // 修改输入法相关设置，确保中文输入正常工作
        textView.autocapitalizationType = .none // 改为none以避免自动大写干扰中文输入
        textView.autocorrectionType = .no // 关闭自动更正，避免干扰中文输入法
        textView.smartQuotesType = .no // 关闭智能引号
        textView.smartDashesType = .no // 关闭智能破折号
        textView.smartInsertDeleteType = .no // 关闭智能插入删除
        
        // 禁用系统输入助手视图
        if #available(iOS 14.0, *) {
            textView.inputAssistantItem.leadingBarButtonGroups = []
            textView.inputAssistantItem.trailingBarButtonGroups = []
        }
        
        // 自定义输入键盘属性
        textView.keyboardDismissMode = .interactive
        textView.keyboardType = .default
        textView.returnKeyType = .default
        
        // 在多设备和多版本iOS上进一步确保无输入附件视图
        // 使用iOS 15的新API获取窗口
        let keyWindow: UIWindow?
        if #available(iOS 15.0, *) {
            keyWindow = UIApplication.shared.connectedScenes
                .filter { $0.activationState == .foregroundActive }
                .first(where: { $0 is UIWindowScene })
                .flatMap { $0 as? UIWindowScene }?.windows
                .first(where: \.isKeyWindow)
        } else {
            keyWindow = UIApplication.shared.windows.first(where: \.isKeyWindow)
        }
        
        if let window = keyWindow {
            // 移除可能导致崩溃的私有API调用
            // try? textView.perform(Selector(("_updateInputAccessoryView")))
            
            DispatchQueue.main.async {
                // 在下一个主循环重新加载输入视图，确保清除任何自动创建的附件视图
                textView.reloadInputViews()
                
                // 使用正确的方法强制布局更新
                window.rootViewController?.view.setNeedsLayout()
                window.rootViewController?.view.layoutIfNeeded()
            }
        }
        
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
            
            // 只在没有标记文本时更新文本内容
            if uiView.markedTextRange == nil {
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
                
                // 更新文本视图，使用无动画模式避免干扰输入
                UIView.performWithoutAnimation {
                    uiView.attributedText = attributedString
                }
                
                // 更新上次的建议记录
                context.coordinator.lastSuggestions = suggestions
                
                // 恢复光标位置 - 优先使用视图中的选择位置
                if textChanged {
                    // 如果是文本改变，使用传入的选择范围
                    uiView.selectedRange = currentSelectedRange
                } else {
                    // 如果只是建议改变，保持当前编辑位置
                    uiView.selectedRange = viewSelectedRange
                }
            }
        } else if uiView.selectedRange.location != currentSelectedRange.location && uiView.markedTextRange == nil {
            // 如果只是光标位置需要更新，且没有正在组合的文本
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
            // 更新绑定的文本值 - 仅当没有正在组合的文本时才更新
            // 这对于中文输入法非常重要，避免拼音被直接当作最终输入
            if textView.markedTextRange == nil {
                parent.text = textView.text
                
                // 更新光标位置
                parent.selectedRange = textView.selectedRange
            }
            
            // 只有当没有正在组合的文本，并且有建议时才应用高亮
            if textView.markedTextRange == nil && !lastSuggestions.isEmpty {
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
                
                // 更新文本视图，使用无动画模式避免干扰输入
                UIView.performWithoutAnimation {
                    textView.attributedText = attributedString
                }
                
                // 恢复光标位置，确保不会超出文本长度
                if selectedRange.location <= textView.text.count {
                    textView.selectedRange = selectedRange
                } else if !textView.text.isEmpty {
                    textView.selectedRange = NSRange(location: textView.text.count, length: 0)
                }
            }
        }
        
        // 添加对组合输入的特殊处理
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            // 允许所有文本更改，但特殊处理回车键
            if text == "\n" {
                // 如果有标记文本（未完成的组合输入），先结束组合
                if textView.markedTextRange != nil {
                    textView.unmarkText()
                }
                // 进行其他回车键处理...
            }
            
            return true // 允许所有文本变更
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            // 只在没有标记文本时更新选择范围
            if textView.markedTextRange == nil {
                parent.selectedRange = textView.selectedRange
            }
        }
        
        // 设置和取消第一响应者时的处理
        func textViewDidBeginEditing(_ textView: UITextView) {
            // 确保光标位置有效
            if textView.selectedRange.location > textView.text.count {
                textView.selectedRange = NSRange(location: textView.text.count, length: 0)
            }
            
            // 在文本视图获得焦点时清理可能的约束冲突
            DispatchQueue.main.async {
                // 获取根视图控制器并清理键盘约束，使用新的iOS 15+ API
                let keyWindow: UIWindow?
                if #available(iOS 15.0, *) {
                    keyWindow = UIApplication.shared.connectedScenes
                        .filter { $0.activationState == .foregroundActive }
                        .first(where: { $0 is UIWindowScene })
                        .flatMap { $0 as? UIWindowScene }?.windows
                        .first(where: \.isKeyWindow)
                } else {
                    keyWindow = UIApplication.shared.windows.first(where: \.isKeyWindow)
                }
                
                if let window = keyWindow,
                   let rootView = window.rootViewController?.view {
                    rootView.cleanupKeyboardConstraints()
                }
                
                // 再次确保没有输入附件视图 - 使用安全的方式
                if let noAccessoryTextView = textView as? NoAccessoryTextView {
                    noAccessoryTextView.setValue(nil, forKey: "_inputAccessoryView")
                    noAccessoryTextView.reloadInputViews()
                }
            }
            
            // 在Debug模式下监控约束变化
            #if DEBUG
            textView.monitorKeyboardConstraints()
            #endif
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            // 在失去焦点时执行清理工作
            #if DEBUG
            NotificationCenter.default.removeObserver(textView)
            #endif
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
    @State private var keyboardHeight: CGFloat = 0
    // 语音朗读相关
    @State private var speechSynthesizer = AVSpeechSynthesizer()
    @State private var isReadingSuggestions = false
    @State private var currentSuggestionIndex = 0
    @State private var activeSuggestions: [Suggestion] = []
    @State private var speechDelegate: SpeechSynthesizerDelegate?
    @State private var isSpeechPaused = false // 添加状态变量跟踪暂停状态
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
                        // 添加额外的底部 padding 以避免键盘遮挡
                        .padding(.bottom, keyboardHeight > 0 ? keyboardHeight : 0)
                    
                    // 隐藏的快捷键按钮
                    VStack {
                        // 触发语音朗读的按钮
                        Button(action: toggleSpeechReading) {
                            Text("")
                        }
                        .keyboardShortcut(KeyEquivalent(safeCharacter(from: AppSettings.shared.voiceShortcutRead)), modifiers: [.command, .shift])
                        .frame(width: 0, height: 0)
                        .opacity(0)
                        
                        // 接受当前建议的按钮
                        Button(action: acceptCurrentSuggestion) {
                            Text("")
                        }
                        .keyboardShortcut(KeyEquivalent(safeCharacter(from: AppSettings.shared.voiceShortcutAccept)), modifiers: [.command])
                        .frame(width: 0, height: 0)
                        .opacity(0)
                        
                        // 忽略当前建议的按钮
                        Button(action: ignoreCurrentSuggestion) {
                            Text("")
                        }
                        .keyboardShortcut(KeyEquivalent(safeCharacter(from: AppSettings.shared.voiceShortcutIgnore)), modifiers: [.command])
                        .frame(width: 0, height: 0)
                        .opacity(0)
                    }
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
                    isReadingSuggestions: $isReadingSuggestions,
                    currentSuggestionIndex: $currentSuggestionIndex,
                    currentTextIsPerfect: currentTextIsPerfect,
                    chapter: chapter
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
        .ignoresSafeArea(.keyboard, edges: .bottom) // 防止键盘影响布局
        .onAppear {
            content = chapter.content ?? ""
            previousContentLength = content.count
            isEditing = true
            undoManager = UndoManager()
            
            // 设置光标位置到文本末尾
            selectedRange = NSRange(location: content.count, length: 0)
            
            // 从UserDefaults加载已检查的段落
            if let chapterId = chapter.id {
                checkedParagraphs = CheckedParagraphsManager.shared.fetchAllCheckedParagraphs(chapterId: chapterId)
            }
            
            Task {
                await checkText()
            }
            
            // 添加键盘通知监听器，使用主线程更新UI
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { [self] notification in
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.keyboardHeight = keyboardFrame.height
                    }
                }
            }
            
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { [self] _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    self.keyboardHeight = 0
                }
            }
            
            // 更安全的方式设置语音合成器代理
            let delegate = SpeechSynthesizerDelegate(onFinishSpeaking: {
                self.handleFinishSpeakingSuggestion()
            })
            self.speechDelegate = delegate
            speechSynthesizer.delegate = delegate
        }
        .onDisappear {
            undoManager?.removeAllActions()
            checkTextTask?.cancel()
            
            // 移除键盘通知监听器 - 只移除我们在onAppear中添加的观察者
            NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        }
        // 添加轻触手势来关闭键盘
        .gesture(
            TapGesture()
                .onEnded { _ in
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
        )
    }
    
    private func checkText() async {
        guard !content.isEmpty else { return }
        
        // 检查是否启用了文本修正功能
        guard AppSettings.shared.enableTextCorrection else {
            // 功能已禁用，不进行检查
            isChecking = false
            return
        }
        
        // 根据光标位置获取上一个非空自然段
        let cursorPosition = selectedRange.location
        let checktext = findPreviousNonEmptyParagraph(text: content, cursorPosition: cursorPosition)
        var segmentToCheck = checktext
        var segmentStartPosition = content.distance(from: content.startIndex, to: (content.range(of: checktext)?.lowerBound ?? content.startIndex))
        
        // 移除段落末尾的标点符号和空白
        if !segmentToCheck.isEmpty {
            // 移除开头和尾部的空白
            segmentToCheck = segmentToCheck.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 如果段落为空，则跳过
            if segmentToCheck.isEmpty {
                return
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
        checkedParagraphs.insert(segmentToCheck)
        lastCheckedParagraph = segmentToCheck
        isChecking = true
        currentTextIsPerfect = false
        
        do {
            // 延迟0.5秒
            try await Task.sleep(nanoseconds: 500_000_000)
            
            // 创建一个检测任务，并赋予它一个变量，这样可以在任务取消时捕获到
            let task = Task {
                try await DoubaoCorrectService.checkText(segmentToCheck)
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
            
            // 将已检查的段落保存到UserDefaults
            if let chapterId = chapter.id {
                CheckedParagraphsManager.shared.saveCheckedParagraph(paragraphText: segmentToCheck, chapterId: chapterId)
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
    
    // 辅助函数：根据光标位置找到上一个非空自然段的文本
    private func findPreviousNonEmptyParagraph(text: String, cursorPosition: Int) -> String {
        // 将文本按换行符分隔成段落
        let paragraphs = text.components(separatedBy: .newlines)
        
        // 如果文本为空或光标位置不合法，返回空字符串
        guard !text.isEmpty, cursorPosition >= 0, cursorPosition <= text.count else {
            return ""
        }
        
        // 计算光标位置前的文本
        let textBeforeCursor = String(text.prefix(cursorPosition))
        
        // 计算光标所在的段落索引
        var characterCount = 0
        var currentParagraphIndex = -1
        
        for (index, paragraph) in paragraphs.enumerated() {
            let paragraphLength = paragraph.count + 1 // +1 是为了包含换行符
            characterCount += paragraphLength
            
            if characterCount >= cursorPosition {
                currentParagraphIndex = index
                break
            }
        }
        
        // 如果没有找到当前段落，使用最后一个段落
        if currentParagraphIndex == -1 {
            currentParagraphIndex = paragraphs.count - 1
        }
        
        // 从当前段落向前查找非空段落
        for index in stride(from: currentParagraphIndex, through: 0, by: -1) {
            let paragraph = paragraphs[index].trimmingCharacters(in: .whitespacesAndNewlines)
            if !paragraph.isEmpty {
                return paragraphs[index]
            }
        }
        
        return "" // 如果没有找到非空段落，返回空字符串
    }
    
    // 切换语音朗读状态
    private func toggleSpeechReading() {
        if isReadingSuggestions {
            stopSpeechReading()
        } else {
            // 检查是否是暂停后的恢复
            if isSpeechPaused {
                resumeSpeechReading()
            } else {
                startSpeechReading()
            }
        }
    }
    
    // 恢复已暂停的朗读
    private func resumeSpeechReading() {
        DispatchQueue.main.async {
            self.isReadingSuggestions = true
            self.isSpeechPaused = false
            self.speechSynthesizer.continueSpeaking()
        }
    }
    
    // 开始语音朗读
    private func startSpeechReading() {
        // 确保在主线程上执行UI和语音操作
        DispatchQueue.main.async {
            // 停止任何正在进行的朗读
            self.speechSynthesizer.stopSpeaking(at: .immediate)
            
            // 获取过滤后的、未被接受的建议
            self.activeSuggestions = self.suggestions.filter { !self.acceptedSuggestions.contains($0.id) }
            
            if self.activeSuggestions.isEmpty {
                // 如果没有建议，朗读提示信息
                self.speakText("没有找到需要修正的内容")
                return
            }
            
            self.isReadingSuggestions = true
            self.currentSuggestionIndex = 0
            
            // 显示侧边栏以便查看建议
            if !self.showingSidebar {
                self.showingSidebar = true
            }
            
            // 朗读第一个建议
            self.speakCurrentSuggestion()
        }
    }
    
    // 停止语音朗读
    private func stopSpeechReading() {
        // 确保在主线程执行
        DispatchQueue.main.async {
            // 改为使用pauseSpeaking而不是stopSpeaking，这样可以暂停而不是完全停止
            self.speechSynthesizer.pauseSpeaking(at: .immediate)
            self.isReadingSuggestions = false
            self.isSpeechPaused = true
        }
    }
    
    // 朗读当前建议
    private func speakCurrentSuggestion() {
        // 确保在主线程执行UI相关操作
        DispatchQueue.main.async {
            guard self.isReadingSuggestions, 
                  self.currentSuggestionIndex < self.activeSuggestions.count else {
                self.isReadingSuggestions = false
                return
            }
            
            let suggestion = self.activeSuggestions[self.currentSuggestionIndex]
            let textToSpeak = "原文：\(suggestion.original)，建议修改为：\(suggestion.suggestion)，原因：\(suggestion.reason)。按Shift+Command+Y接受，Shift+Command+N忽略。"
            
            self.speakText(textToSpeak)
        }
    }
    
    // 朗读完一个建议后的处理
    private func handleFinishSpeakingSuggestion() {
        // 确保在主线程执行UI相关操作
        DispatchQueue.main.async {
            // 如果不再处于朗读状态，则不继续
            guard self.isReadingSuggestions else { return }
            
            // 重置暂停状态
            self.isSpeechPaused = false
            
            // 等待短暂时间，让用户有时间思考
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { 
                guard self.isReadingSuggestions else { return }
                
                // 移动到下一个建议
                self.currentSuggestionIndex += 1
                
                if self.currentSuggestionIndex < self.activeSuggestions.count {
                    // 还有更多建议，继续朗读
                    self.speakCurrentSuggestion()
                } else {
                    // 所有建议都已朗读完毕
                    self.speakText("所有建议已朗读完毕")
                    // 延迟结束朗读状态，确保最后的提示被完整播放
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.isReadingSuggestions = false
                        self.isSpeechPaused = false
                    }
                }
            }
        }
    }
    
    // 接受当前建议
    private func acceptCurrentSuggestion() {
        guard isReadingSuggestions, 
              currentSuggestionIndex < activeSuggestions.count else { return }
        
        let suggestion = activeSuggestions[currentSuggestionIndex]
        
        // 停止当前朗读
        speechSynthesizer.stopSpeaking(at: .immediate)
        // 重置暂停状态
        isSpeechPaused = false
        
        // 执行替换操作
        applySuggestion(suggestion)
        
        // 标记为已接受
        acceptedSuggestions.insert(suggestion.id)
        
        // 朗读确认信息
        speakText("已接受建议")
        
        // 移动到下一个建议
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { 
            guard self.isReadingSuggestions else { return }
            
            // 更新活跃建议列表
            self.activeSuggestions = self.suggestions.filter { !self.acceptedSuggestions.contains($0.id) }
            
            // 如果当前索引超出范围，重置为0
            if self.currentSuggestionIndex >= self.activeSuggestions.count {
                self.currentSuggestionIndex = 0
            }
            
            if self.activeSuggestions.isEmpty {
                self.speakText("所有建议已处理完毕")
                self.isReadingSuggestions = false
                self.isSpeechPaused = false
            } else {
                self.speakCurrentSuggestion()
            }
        }
    }
    
    // 忽略当前建议
    private func ignoreCurrentSuggestion() {
        guard isReadingSuggestions, 
              currentSuggestionIndex < activeSuggestions.count else { return }
        
        let suggestion = activeSuggestions[currentSuggestionIndex]
        
        // 停止当前朗读
        speechSynthesizer.stopSpeaking(at: .immediate)
        // 重置暂停状态
        isSpeechPaused = false
        
        // 标记为已忽略
        acceptedSuggestions.insert(suggestion.id)
        
        // 朗读确认信息
        speakText("已忽略建议")
        
        // 移动到下一个建议
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { 
            guard self.isReadingSuggestions else { return }
            
            // 更新活跃建议列表
            self.activeSuggestions = self.suggestions.filter { !self.acceptedSuggestions.contains($0.id) }
            
            // 如果当前索引超出范围，重置为0
            if self.currentSuggestionIndex >= self.activeSuggestions.count {
                self.currentSuggestionIndex = 0
            }
            
            if self.activeSuggestions.isEmpty {
                self.speakText("所有建议已处理完毕")
                self.isReadingSuggestions = false
                self.isSpeechPaused = false
            } else {
                self.speakCurrentSuggestion()
            }
        }
    }
    
    // 应用建议修改
    private func applySuggestion(_ suggestion: Suggestion) {
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
                }
            }
        } else {
            // 向后兼容：如果没有上下文信息，使用原来的方法
            if let range = content.range(of: suggestion.original) {
                var newContent = content
                newContent.replaceSubrange(range, with: suggestion.suggestion)
                content = newContent
            }
        }
    }
    
    // 基本文本朗读功能
    private func speakText(_ text: String) {
        DispatchQueue.main.async {
            // 创建一个稳定的引用
            let synthesizer = self.speechSynthesizer
            
            // 检查synthesizer的当前状态
            let isSpeaking = synthesizer.isSpeaking
            
            // 如果正在朗读，先暂停
            if isSpeaking {
                synthesizer.pauseSpeaking(at: .immediate)
            }
            
            // 重置暂停状态
            self.isSpeechPaused = false
            
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN") // 使用中文语音
            utterance.rate = 0.5 // 语速适中
            utterance.pitchMultiplier = 1.0
            utterance.volume = 1.0
            
            // 确保delegate仍然有效
            if synthesizer.delegate == nil && self.speechDelegate != nil {
                synthesizer.delegate = self.speechDelegate
            }
            
            synthesizer.speak(utterance)
        }
    }
    
    // 辅助函数：安全地从字符串转换为字符
    private func safeCharacter(from string: String) -> Character {
        // 更安全的实现方式
        guard let firstChar = string.lowercased().first else {
            return "v" // 默认值
        }
        return firstChar
    }
}

// 语音合成器代理类
class SpeechSynthesizerDelegate: NSObject, AVSpeechSynthesizerDelegate {
    let onFinishSpeaking: () -> Void
    
    init(onFinishSpeaking: @escaping () -> Void) {
        self.onFinishSpeaking = onFinishSpeaking
        super.init()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // 仅当正常结束时才调用回调
        onFinishSpeaking()
    }
    
    // 添加暂停和继续的委托方法
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        // 处理暂停事件
        print("Speech paused")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        // 处理继续事件
        print("Speech continued")
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
    @Binding var isReadingSuggestions: Bool
    @Binding var currentSuggestionIndex: Int
    let currentTextIsPerfect: Bool
    let chapter: ChapterEntity
    
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
                    // 从UserDefaults中清除已检查的段落
                    if let chapterId = chapter.id {
                        CheckedParagraphsManager.shared.clearCheckedParagraphs(chapterId: chapterId)
                    }
                    checkedParagraphs.removeAll()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(AppTheme.primary)
                        .font(.system(size: 14))
                }
                .buttonStyle(BorderlessButtonStyle())
                .help("重新检查所有内容")
                
                // 语音朗读指示器
                if isReadingSuggestions {
                    HStack(spacing: 4) {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundColor(AppTheme.accent)
                        Text("朗读中")
                            .font(.caption)
                            .foregroundColor(AppTheme.accent)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.accent.opacity(0.15))
                    .cornerRadius(4)
                }
                
                if isChecking {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(AppTheme.cardBackground)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            
            // 快捷键提示区域
            if isReadingSuggestions {
                VStack(alignment: .leading, spacing: 4) {
                    Text("快捷键操作：")
                        .font(.caption)
                        .foregroundColor(AppTheme.text)
                    
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Text("⌘\(AppSettings.shared.voiceShortcutAccept)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(4)
                            
                            Text("接受")
                                .font(.caption)
                        }
                        
                        HStack(spacing: 4) {
                            Text("⌘\(AppSettings.shared.voiceShortcutIgnore)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(4)
                            
                            Text("忽略")
                                .font(.caption)
                        }
                        
                        HStack(spacing: 4) {
                            Text("⇧⌘\(AppSettings.shared.voiceShortcutRead)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(4)
                            
                            Text("停止")
                                .font(.caption)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(0)
            }
    
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
                        ForEach(Array(suggestions.filter { !acceptedSuggestions.contains($0.id) }.enumerated()), id: \.element.id) { index, suggestion in
                            SuggestionRow(
                                suggestion: suggestion,
                                content: $content,
                                acceptedSuggestions: $acceptedSuggestions,
                                isCurrentlyReading: isReadingSuggestions && index == currentSuggestionIndex
                            )
                            .background(
                                isReadingSuggestions && index == currentSuggestionIndex 
                                ? AppTheme.accent.opacity(0.15) 
                                : AppTheme.cardBackground
                            )
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
    let isCurrentlyReading: Bool
    @State private var isExpanded = true  // 默认展开
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏 - 原始文本和展开/折叠按钮
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    if isCurrentlyReading {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundColor(AppTheme.accent)
                            .font(.system(size: 14))
                    }
                    
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
            .background(isCurrentlyReading ? AppTheme.accent.opacity(0.1) : Color.clear)
            
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
        .background(isCurrentlyReading ? AppTheme.accent.opacity(0.05) : Color.white)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isCurrentlyReading ? AppTheme.accent.opacity(0.5) : Color.gray.opacity(0.1), lineWidth: isCurrentlyReading ? 2 : 1)
        )
        .id(suggestion.id) // 添加稳定 ID 避免重新渲染时消失
    }
}

// 添加一个UITextView扩展，用于调试和辅助功能
extension UITextView {
    override open var canBecomeFirstResponder: Bool {
        // 确保文本视图可以成为第一响应者（获取焦点）
        return true
    }
    
    override open var canResignFirstResponder: Bool {
        // 确保文本视图可以放弃第一响应者状态（失去焦点）
        return true
    }
    
    // 监听约束冲突的方法，仅在开发阶段会被使用
    #if DEBUG
    func monitorKeyboardConstraints() {
        NotificationCenter.default.addObserver(self, selector: #selector(constraintsDidChange), 
                                      name: NSNotification.Name("UIViewControllerConstraintsDidChangeNotification"), 
                                      object: nil)
    }
    
    @objc private func constraintsDidChange() {
        // 收集可能存在冲突的约束
        var keyboardConstraints: [NSLayoutConstraint] = []
        
        // 获取窗口，使用新的iOS 15+ API
        let keyWindow: UIWindow?
        if #available(iOS 15.0, *) {
            keyWindow = UIApplication.shared.connectedScenes
                .filter { $0.activationState == .foregroundActive }
                .first(where: { $0 is UIWindowScene })
                .flatMap { $0 as? UIWindowScene }?.windows
                .first(where: \.isKeyWindow)
        } else {
            keyWindow = UIApplication.shared.windows.first(where: \.isKeyWindow)
        }
        
        if let window = keyWindow {
            // 查找包含"keyboard"、"input"、"accessory"关键词的约束
            func findKeyboardConstraints(in view: UIView) {
                for constraint in view.constraints {
                    let description = constraint.description.lowercased()
                    if description.contains("keyboard") || 
                       description.contains("input") ||
                       description.contains("accessory") {
                        keyboardConstraints.append(constraint)
                    }
                }
                
                for subview in view.subviews {
                    findKeyboardConstraints(in: subview)
                }
            }
            
            findKeyboardConstraints(in: window)
        }
        
        // 如果找到冲突的约束，可以在控制台打印
        if !keyboardConstraints.isEmpty {
            print("Potential keyboard constraint conflicts: \(keyboardConstraints.count)")
        }
    }
    #endif
}

// 添加UIView扩展以处理约束冲突
extension UIView {
    // 清理相关的约束冲突
    func cleanupKeyboardConstraints() {
        // 查找与键盘相关的约束，但使用更安全的条件
        // 避免使用过于笼统的字符串匹配，专注于已知的问题约束
        let constraintsToRemove = constraints.filter { constraint in
            let description = constraint.description.lowercased()
            // 只移除明确与键盘或输入附件视图相关的约束
            return (description.contains("keyboard") && description.contains("height")) || 
                   (description.contains("inputaccessory") && description.contains("height")) ||
                   (description.contains("bottom") && description.contains("keyboard"))
        }
        
        if !constraintsToRemove.isEmpty {
            // 只在找到约束时打印和停用，避免不必要的操作
            #if DEBUG
            print("移除键盘约束: \(constraintsToRemove.count)个")
            #endif
            
            // 停用这些约束
            NSLayoutConstraint.deactivate(constraintsToRemove)
        }
        
        // 递归处理子视图，但避免处理某些系统视图
        for subview in subviews {
            // 跳过处理系统键盘视图，避免干扰系统行为
            if String(describing: type(of: subview)).contains("Keyboard") ||
               String(describing: type(of: subview)).contains("Input") {
                continue
            }
            subview.cleanupKeyboardConstraints()
        }
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
