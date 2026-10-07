import XCTest
@testable import Avela

@MainActor
final class ReflectionDictationTests: XCTestCase {
    func testUnavailableOnDeviceRecognitionNeverRequestsPermissionOrCaptures() async {
        let capture = SpeechCaptureStub()
        capture.supportsOnDeviceRecognition = false
        let model = ReflectionDictationModel(capture: capture)
        await model.start()
        XCTAssertEqual(capture.authorizationCalls, 0)
        XCTAssertEqual(capture.startCalls, 0)
        XCTAssertNotNil(model.message)
    }

    func testDeniedPermissionLeavesTypingAvailableAndDoesNotCapture() async {
        let capture = SpeechCaptureStub()
        capture.authorized = false
        let model = ReflectionDictationModel(capture: capture)
        await model.start()
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(capture.startCalls, 0)
        XCTAssertNotNil(model.message)
    }

    func testStopKeepsPreviewAndRejectsLateRecognitionCallbacks() async {
        let capture = SpeechCaptureStub()
        let model = ReflectionDictationModel(capture: capture)
        await model.start()
        XCTAssertEqual(model.phase, .listening)
        capture.onText?("Walking helped me unwind")
        XCTAssertFalse(model.canInsert)
        model.stop()
        XCTAssertTrue(model.canInsert)
        capture.onText?("late replacement")
        capture.onEnd?(true)
        XCTAssertEqual(model.transcript, "Walking helped me unwind")
        XCTAssertEqual(model.phase, .review)
        XCTAssertEqual(capture.stopCalls, 1)
    }

    func testCancelDuringPermissionWaitCannotStartMicrophoneLater() async {
        let capture = SpeechCaptureStub()
        capture.waitsForAuthorization = true
        let model = ReflectionDictationModel(capture: capture)
        let task = Task { await model.start() }
        while capture.authorizationContinuation == nil { await Task.yield() }
        model.discard()
        capture.authorizationContinuation?.resume(returning: true)
        await task.value
        XCTAssertEqual(capture.startCalls, 0)
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(model.transcript, "")
    }

    func testCaptureFailureStopsAndPreservesAnyPreview() async {
        let capture = SpeechCaptureStub()
        let model = ReflectionDictationModel(capture: capture)
        await model.start()
        capture.onText?("I made time to read")
        capture.onEnd?(true)
        XCTAssertEqual(model.transcript, "I made time to read")
        XCTAssertTrue(model.canInsert)
        XCTAssertNotNil(model.message)
        XCTAssertEqual(capture.stopCalls, 1)
    }

    func testStartupFailureReleasesCaptureAndKeepsDraftSeparate() async {
        let capture = SpeechCaptureStub()
        capture.failsOnStart = true
        let model = ReflectionDictationModel(capture: capture)
        await model.start()
        XCTAssertEqual(capture.stopCalls, 1)
        XCTAssertFalse(model.canInsert)
        XCTAssertNotNil(model.message)
    }

    func testTranscriptAppendsWithoutReplacingTypedWordsOrTruncating() {
        XCTAssertEqual(ReflectionDictationModel.appended("  I walked  ", to: "I read"), "I read\n\nI walked")
        XCTAssertEqual(ReflectionDictationModel.appended(" \n", to: "Keep this"), "Keep this")
        XCTAssertEqual(ReflectionDictationModel.appended(" Spoken ", to: ""), "Spoken")
        let longText = String(repeating: "a", count: 501)
        XCTAssertEqual(ReflectionDictationModel.appended(longText, to: ""), longText)
        XCTAssertFalse(ReflectionDraft(whatHelped: longText).isValid)
    }
}

@MainActor
private final class SpeechCaptureStub: ReflectionSpeechCapture {
    var supportsOnDeviceRecognition = true
    var authorized = true
    var waitsForAuthorization = false
    var failsOnStart = false
    var authorizationCalls = 0
    var startCalls = 0
    var stopCalls = 0
    var authorizationContinuation: CheckedContinuation<Bool, Never>?
    var onText: (@MainActor (String) -> Void)?
    var onEnd: (@MainActor (Bool) -> Void)?

    func authorize() async -> Bool {
        authorizationCalls += 1
        if waitsForAuthorization {
            return await withCheckedContinuation { authorizationContinuation = $0 }
        }
        return authorized
    }
    func start(onText: @escaping @MainActor (String) -> Void, onEnd: @escaping @MainActor (Bool) -> Void) throws {
        startCalls += 1
        if failsOnStart { throw NSError(domain: "test", code: 1) }
        self.onText = onText
        self.onEnd = onEnd
    }
    func stop() { stopCalls += 1 }
}
