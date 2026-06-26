import AVFoundation

/// Speaks live form-feedback aloud during a camera session, so coaching isn't text-only.
/// Form cues are throttled (the analyzer emits feedback ~12×/sec) so the voice behaves like
/// an occasional coach instead of narrating every frame; rep counts interrupt to stay in time.
@MainActor
final class SpeechFeedbackController: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    private var lastCueText = ""
    private var lastCueAt = Date.distantPast

    /// Minimum gap between spoken coaching cues.
    private let cueInterval: TimeInterval = 4.5

    /// Routes speech through the playback session and ducks other audio while talking.
    func configureSession() {
        #if canImport(UIKit)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .mixWithOthers])
        try? session.setActive(true)
        #endif
    }

    /// Speaks a coaching cue, but not more often than `cueInterval` and not the same cue twice
    /// in a row, so a persistent correction isn't repeated every frame.
    func speakCue(_ text: String) {
        let now = Date()
        guard now.timeIntervalSince(lastCueAt) >= cueInterval, text != lastCueText else { return }
        guard !synthesizer.isSpeaking else { return }
        lastCueText = text
        lastCueAt = now
        enqueue(text)
    }

    /// Announces the current rep count, but never interrupts a coaching cue in progress —
    /// detailed form feedback takes priority, and rep numbers fill the gaps.
    func announceRep(_ count: Int) {
        guard !synthesizer.isSpeaking else { return }
        enqueue("\(count)")
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        lastCueText = ""
        lastCueAt = .distantPast
    }

    private func enqueue(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.postUtteranceDelay = 0.05
        synthesizer.speak(utterance)
    }
}
