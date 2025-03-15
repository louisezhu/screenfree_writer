import AVFoundation

class SpeechManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = SpeechManager()
    
    private let synthesizer = AVSpeechSynthesizer()
    @Published var isSpeaking = false
    @Published var currentWordRange: NSRange = .init(location: 0, length: 0)
    
    // 配置音频会话（支持后台播放）
    override init() {
        super.init()
        configureAudioSession()
        synthesizer.delegate = self
    }
    
    private func configureAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(
            .playback,
            mode: .spokenAudio,
            options: [.duckOthers, .allowBluetooth, .allowAirPlay]
        )
    }
    
    // 开始/停止朗读
    func speak(text: String, language: String = "zh-CN") {
        guard !text.isEmpty else { return }
        
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = 0.45 // 默认语速 (0.0~1.0)
        utterance.pitchMultiplier = 1.1 // 音调调整 (0.5~2.0)
        utterance.postUtteranceDelay = 0.3 // 句间停顿
        
        synthesizer.speak(utterance)
        isSpeaking = true
    }
    
    func togglePlayback() {
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
        } else if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .word)
        }
        isSpeaking = synthesizer.isSpeaking && !synthesizer.isPaused
    }
    
    // 实时高亮当前朗读词句
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                          willSpeak range: NSRange,
                          of utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.currentWordRange = range
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                          didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.currentWordRange = .init(location: 0, length: 0)
        }
    }
    // 在 SpeechManager 中添加
private func setupNotifications() {
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleInterruption),
        name: AVAudioSession.interruptionNotification,
        object: nil
    )
}
}
@objc private func handleInterruption(notification: Notification) {
    guard let info = notification.userInfo,
          let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
    
    switch type {
    case .began: // 来电等中断开始
        pause()
    case .ended: // 中断结束
        guard let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
        if options.contains(.shouldResume) {
            resume()
        }
    @unknown default:
        break
    }
}