import AVFoundation
import Combine
import Observation
import Speech
import UIKit

@MainActor
@Observable
final class DictationService {
    private(set) var transcript = ""
    private(set) var isRecording = false
    var errorMessage: String?

    @ObservationIgnored private let audioEngine = AVAudioEngine()
    @ObservationIgnored private var recognitionTask: SFSpeechRecognitionTask?
    @ObservationIgnored private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var hasInputTap = false
    @ObservationIgnored private var ownsAudioSession = false
    @ObservationIgnored private var sessionID = UUID()
    @ObservationIgnored private var observers: Set<AnyCancellable> = []

    init() {
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

    func start() async {
        guard !Task.isCancelled else { return }
        stop()
        transcript = ""
        errorMessage = nil
        let token = UUID()
        sessionID = token
        let permission = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { @Sendable status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard sessionID == token, !Task.isCancelled else { return }
        guard permission else {
            errorMessage = "음성 인식 권한이 필요해요. 설정에서 권한을 허용하거나 글로 입력해주세요."
            return
        }
        let microphoneAllowed = await AVAudioApplication.requestRecordPermission()
        guard sessionID == token, !Task.isCancelled else { return }
        guard microphoneAllowed else {
            errorMessage = "마이크 권한이 필요해요. 설정에서 권한을 허용하거나 글로 입력해주세요."
            return
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR")), recognizer.isAvailable else {
            errorMessage = "지금은 한국어 음성 인식을 사용할 수 없어요. 글로 입력해주세요."
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true)
            ownsAudioSession = true
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.taskHint = .dictation
            // Keep the recording on device when this recognizer supports it.
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
            recognitionRequest = request
            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                throw DictationFailure.noMicrophone
            }
            inputNode.installTap(
                onBus: 0, bufferSize: 1_024, format: format,
                block: Self.makeInputTap(request: request)
            )
            hasInputTap = true
            recognitionTask = recognizer.recognitionTask(with: request) { @Sendable [weak self] result, error in
                let text = result?.bestTranscription.formattedString
                let isFinal = result?.isFinal ?? false
                let didFail = error != nil
                Task { @MainActor [weak self] in
                    guard let self, self.sessionID == token else { return }
                    if let text { self.transcript = text }
                    if isFinal || didFail {
                        if didFail && self.transcript.isEmpty {
                            self.errorMessage = "음성을 인식하지 못했어요. 다시 시도하거나 글로 입력해주세요."
                        }
                        self.stop()
                    }
                }
            }
            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
        } catch {
            stop()
            errorMessage = "마이크를 시작할 수 없어요. 다른 녹음을 종료하고 다시 시도하거나 글로 입력해주세요."
        }
    }

    /// AVAudioNodeTapBlock is a legacy non-Sendable callback invoked on the audio
    /// thread. Build it outside MainActor so Swift does not insert an executor
    /// assertion. The callback only feeds Speech's audio request, never UI state.
    private nonisolated static func makeInputTap(request: SFSpeechAudioBufferRecognitionRequest) -> AVAudioNodeTapBlock {
        { buffer, _ in request.append(buffer) }
    }

    /// Retains the most recent transcript so the caller can copy it into the editor.
    func stop() {
        sessionID = UUID()
        audioEngine.stop()
        if hasInputTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInputTap = false
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false
        if ownsAudioSession {
            ownsAudioSession = false
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}

private enum DictationFailure: Error {
    case noMicrophone
}
