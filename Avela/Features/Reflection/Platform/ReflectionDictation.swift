import AVFoundation
import Foundation
import Observation
import Speech

/// Audio is ephemeral. Only the reviewed text can reach the reflection draft.
@MainActor
protocol ReflectionSpeechCapture: AnyObject {
    var supportsOnDeviceRecognition: Bool { get }
    func authorize() async -> Bool
    func start(onText: @escaping @MainActor (String) -> Void,
               onEnd: @escaping @MainActor (Bool) -> Void) throws
    func stop()
}

@MainActor
@Observable
final class ReflectionDictationModel {
    enum Phase { case ready, authorizing, listening, review }
    private(set) var phase = Phase.ready
    var transcript = ""
    private(set) var message: String?
    private let capture: ReflectionSpeechCapture
    private var sessionID: UUID?
    private var timeout: Task<Void, Never>?

    init(capture: ReflectionSpeechCapture? = nil) {
        self.capture = capture ?? AppleReflectionSpeechCapture()
    }

    var canInsert: Bool {
        phase != .authorizing && phase != .listening &&
        !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func start() async {
        guard phase != .authorizing && phase != .listening else { return }
        message = nil
        guard capture.supportsOnDeviceRecognition else {
            message = "On-device dictation isn't available for this device or language. You can still type your reflection."
            return
        }
        let id = UUID()
        sessionID = id
        phase = .authorizing
        let authorized = await capture.authorize()
        guard sessionID == id else { return }
        guard authorized else {
            sessionID = nil
            phase = .ready
            message = "Dictation needs microphone and speech recognition access. You can enable them in iPhone Settings, or keep typing."
            return
        }
        transcript = ""
        phase = .listening
        do {
            try capture.start(onText: { [weak self] text in
                guard let self, self.sessionID == id else { return }
                self.transcript = text
            }, onEnd: { [weak self] failed in
                guard let self, self.sessionID == id else { return }
                self.stop()
                if failed { self.message = "Dictation stopped. Review any captured text or try again." }
            })
            // Short reflections have a visible 55-second capture limit.
            timeout = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(55)) } catch { return }
                guard let self, self.sessionID == id else { return }
                self.stop()
                self.message = "Recording stopped after 55 seconds. Review your text before adding it."
            }
        } catch {
            stop()
            message = "Couldn't start dictation. Your reflection is unchanged; you can keep typing."
        }
    }

    func stop() {
        sessionID = nil
        timeout?.cancel()
        timeout = nil
        capture.stop()
        phase = transcript.isEmpty ? .ready : .review
    }

    func discard() { stop(); transcript = ""; message = nil; phase = .ready }

    /// Preserve existing typed text; do not truncate or replace it silently.
    static func appended(_ spoken: String, to existing: String) -> String {
        let addition = spoken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !addition.isEmpty else { return existing }
        return existing.isEmpty ? addition : existing + "\n\n" + addition
    }
}

@MainActor
final class AppleReflectionSpeechCapture: ReflectionSpeechCapture {
    private let recognizer = SFSpeechRecognizer(locale: .current)
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognition: SFSpeechRecognitionTask?
    private var hasTap = false
    private var audioSessionActive = false
    private var interruptionObserver: NSObjectProtocol?

    var supportsOnDeviceRecognition: Bool {
        recognizer?.supportsOnDeviceRecognition == true && recognizer?.isAvailable == true
    }

    func authorize() async -> Bool {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in continuation.resume(returning: status) }
        }
        guard status == .authorized else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    func start(onText: @escaping @MainActor (String) -> Void,
               onEnd: @escaping @MainActor (Bool) -> Void) throws {
        stop()
        guard supportsOnDeviceRecognition, let recognizer else { throw CaptureError.unavailable }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true)
        audioSessionActive = true
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        self.request = request
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 && format.channelCount > 0 else { throw CaptureError.unavailable }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        hasTap = true
        recognition = recognizer.recognitionTask(with: request) { result, error in
            let text = result?.bestTranscription.formattedString
            let ended = result?.isFinal == true || error != nil
            let failed = error != nil
            Task { @MainActor in
                if let text { onText(text) }
                if ended { onEnd(failed) }
            }
        }
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { _ in Task { @MainActor in onEnd(true) } }
        engine.prepare()
        try engine.start()
    }

    func stop() {
        engine.stop()
        if hasTap { engine.inputNode.removeTap(onBus: 0); hasTap = false }
        request?.endAudio()
        recognition?.cancel()
        recognition = nil
        request = nil
        if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }
        interruptionObserver = nil
        if audioSessionActive {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            audioSessionActive = false
        }
    }

    private enum CaptureError: Error { case unavailable }
}
