import AVFoundation
import Combine
import Observation
import UIKit

@MainActor
@Observable
final class SpeechPlayer: NSObject, AVSpeechSynthesizerDelegate {
    private(set) var isSpeaking = false
    var errorMessage: String?

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var activeUtteranceID: ObjectIdentifier?
    @ObservationIgnored private var ownsAudioSession = false
    @ObservationIgnored private var observers: Set<AnyCancellable> = []

    override init() {
        super.init()
        synthesizer.delegate = self
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { @Sendable [weak self] _ in
                Task { @MainActor [weak self] in self?.stop() }
            }
            .store(in: &observers)
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { @Sendable [weak self] _ in
                Task { @MainActor [weak self] in self?.stop() }
            }
            .store(in: &observers)
    }

    func speak(_ text: String, rate: Double) {
        stop()
        errorMessage = nil
        let instruction = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !instruction.isEmpty else { return }
        guard let voice = AVSpeechSynthesisVoice(language: "ko-KR") else {
            errorMessage = "한국어 음성을 사용할 수 없어요. 기기의 음성 설정을 확인해주세요."
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
            ownsAudioSession = true
            let utterance = AVSpeechUtterance(string: instruction)
            utterance.voice = voice
            utterance.rate = Float(min(max(rate.isFinite ? rate : 0.45, 0.35), 0.6))
            activeUtteranceID = ObjectIdentifier(utterance)
            isSpeaking = true
            synthesizer.speak(utterance)
        } catch {
            errorMessage = "안내 음성을 재생할 수 없어요. 잠시 후 다시 시도해주세요."
            stop()
        }
    }

    func stop() {
        activeUtteranceID = nil
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        deactivateAudioSession()
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in self?.finish(utteranceID: id) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in self?.finish(utteranceID: id) }
    }

    private func finish(utteranceID: ObjectIdentifier) {
        // A cancelled utterance can finish after a new instruction has started.
        guard activeUtteranceID == utteranceID else { return }
        activeUtteranceID = nil
        isSpeaking = false
        deactivateAudioSession()
    }

    private func deactivateAudioSession() {
        guard ownsAudioSession else { return }
        ownsAudioSession = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
