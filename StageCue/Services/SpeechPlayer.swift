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
        let replacesActiveSpeech = isSpeaking && ownsAudioSession
        cancelCurrentSpeech()
        errorMessage = nil
        let instruction = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !instruction.isEmpty else {
            deactivateAudioSession()
            return
        }
        guard let voice = AVSpeechSynthesisVoice(language: "ko-KR") else {
            errorMessage = "한국어 음성을 사용할 수 없어요. 기기의 음성 설정을 확인해주세요."
            deactivateAudioSession()
            return
        }
        do {
            // Consecutive helper cues replace the utterance without cycling the
            // audio session or briefly restoring other apps' audio between cues.
            if !replacesActiveSpeech {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
                try session.setActive(true)
                ownsAudioSession = true
            }
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
        cancelCurrentSpeech()
        deactivateAudioSession()
    }

    private func cancelCurrentSpeech() {
        activeUtteranceID = nil
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        complete(utterance)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        complete(utterance)
    }

    private nonisolated func complete(_ utterance: AVSpeechUtterance) {
        let completed = CompletedUtterance(utterance)
        Task { @MainActor [weak self] in
            withExtendedLifetime(completed) {
                self?.finish(utteranceID: completed.id)
            }
        }
    }

    private func finish(utteranceID: ObjectIdentifier) {
        // A cancellation may arrive after stop() or after another cue starts.
        // Only retry stop's cleanup when there is no newer active utterance.
        guard let activeUtteranceID else {
            deactivateAudioSession()
            return
        }
        guard activeUtteranceID == utteranceID else { return }
        self.activeUtteranceID = nil
        isSpeaking = false
        deactivateAudioSession()
    }

    private func deactivateAudioSession() {
        guard ownsAudioSession else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            ownsAudioSession = false
        } catch {
            // Audio can still be winding down after immediate cancellation.
            // Keep ownership so the completion callback can finish cleanup.
        }
    }
}

/// Carries object lifetime across the delegate callback without reading or
/// mutating the utterance across actors. Identity is valid until cleanup ends.
private final class CompletedUtterance: @unchecked Sendable {
    private let utterance: AVSpeechUtterance
    var id: ObjectIdentifier { ObjectIdentifier(utterance) }

    init(_ utterance: AVSpeechUtterance) {
        self.utterance = utterance
    }
}
