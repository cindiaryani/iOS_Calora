import AVFoundation
import SwiftUI

struct ExerciseFeedbackView: View {
    /// When set, the form check opens straight onto this exercise (used by the workout player).
    let initialExercise: ExerciseType?

    @StateObject private var camera = CameraSessionController()
    @StateObject private var speech = SpeechFeedbackController()
    @AppStorage("voiceFeedbackEnabled") private var voiceEnabled = true
    @Environment(\.dismiss) private var dismiss
    private let accent = Color.appPrimary

    init(initialExercise: ExerciseType? = nil) {
        self.initialExercise = initialExercise
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    formHeader

                    ZStack {
                        if camera.permissionState == .granted {
                            CameraPreview(session: camera.session)
                                .overlay {
                                    PoseSkeletonView(skeleton: camera.poseSkeleton)
                                }
                                .overlay(alignment: .topLeading) {
                                    cameraBadge
                                }
                                .overlay(alignment: .topTrailing) {
                                    repCounterOverlay
                                }
                                .overlay(alignment: .bottom) {
                                    phaseBanner
                                }
                        } else {
                            permissionStateView
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(3 / 4, contentMode: .fit)
                    .background(Color.appSurfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(.horizontal)

                    exercisePicker
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 14) {
                        Label("Exercise feedback", systemImage: "figure.strengthtraining.traditional")
                            .font(.headline)

                        Text(camera.statusMessage)
                            .font(.subheadline)
                            .foregroundStyle(Color.appTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        feedbackPanel

                        HStack(spacing: 10) {
                            if camera.permissionState != .granted {
                                Button {
                                    Task {
                                        await camera.requestPermission()
                                    }
                                } label: {
                                    Label("Allow Camera", systemImage: "camera.fill")
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(camera.permissionState == .requesting)
                            } else {
                                Button {
                                    camera.switchCamera()
                                } label: {
                                    Label("Flip", systemImage: "arrow.triangle.2.circlepath.camera")
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.appBorder, lineWidth: 1)
                    }
                    .padding(.horizontal)

                    formGuidancePanel
                        .padding(.horizontal)
                        .padding(.bottom)
                }
                .padding(.top, 18)
            }
            .background(Color.appBackground)
            .toolbar(.hidden, for: .navigationBar)
            .task {
                speech.configureSession()
                if let initialExercise {
                    camera.selectExercise(initialExercise)
                }
                if camera.permissionState == .granted {
                    camera.startSession()
                }
            }
            .onDisappear {
                camera.stopSession()
                speech.stop()
            }
            .onChange(of: camera.formFeedback) { feedback in
                guard voiceEnabled, let text = voiceCueText(for: feedback) else { return }
                speech.speakCue(text)
            }
            .onChange(of: camera.completedReps) { reps in
                guard voiceEnabled, reps > 0 else { return }
                speech.announceRep(reps)
            }
            .onChange(of: voiceEnabled) { enabled in
                if !enabled { speech.stop() }
            }
        }
    }

    private var formHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Form")
                    .font(.title2.weight(.bold))

                Text("Live posture feedback")
                    .font(.subheadline)
                    .foregroundStyle(Color.appTextSecondary)
            }

            Spacer()

            Button {
                voiceEnabled.toggle()
            } label: {
                Image(systemName: voiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(voiceEnabled ? accent : Color.appTextSecondary)
                    .frame(width: 44, height: 44)
                    .background(Color.appSurfaceMuted, in: Circle())
                    .overlay { Circle().stroke(Color.appBorder, lineWidth: 1) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(voiceEnabled ? "Mute voice feedback" : "Enable voice feedback")

            Button {
                speech.stop()
                camera.stopSession()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.appTextPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.appSurfaceMuted, in: Circle())
                    .overlay { Circle().stroke(Color.appBorder, lineWidth: 1) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal)
    }

    /// The form feedback to speak aloud: the most important cue (fix-now → adjust → positive),
    /// spoken as the full "title + detailed instruction" — not just a short label — so the
    /// voice coaching is as detailed as the on-screen text.
    private func voiceCueText(for feedback: ExerciseFormFeedback) -> String? {
        guard feedback.isPersonDetected else { return nil }
        // Prefer the AI form-check result so the voice matches the on-screen Core ML badge.
        if let label = feedback.detectedExercise, label.hasPrefix("squat_") {
            return squatFormInfo(label).title
        }
        // Otherwise fall back to the most important heuristic cue (full detailed instruction).
        let cue = feedback.cues.first(where: { $0.severity == .critical })
            ?? feedback.cues.first(where: { $0.severity == .warning })
            ?? feedback.cues.first
        return cue.map { "\($0.title). \($0.message)" }
    }

    private var cameraBadge: some View {
        Label(camera.selectedPosition == .front ? "Front camera" : "Back camera", systemImage: "camera.viewfinder")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.black.opacity(0.58), in: Capsule())
            .foregroundStyle(.white)
            .padding(12)
    }

    private var repCounterOverlay: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Label(camera.selectedExercise.rawValue, systemImage: camera.selectedExercise.systemImage)
                .font(.caption.weight(.bold))
                .labelStyle(.titleAndIcon)
                .foregroundStyle(Color.appPrimary)

            Text("\(camera.completedReps)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.2), value: camera.completedReps)

            Text(camera.completedReps == 1 ? "rep done" : "reps done")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(12)
    }

    private var phaseBanner: some View {
        Text(camera.formFeedback.isPersonDetected ? camera.formFeedback.repPhase : "Position yourself in frame")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.black.opacity(0.55), in: Capsule())
            .padding(12)
    }

    private var exercisePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What are you scanning?")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.appTextPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(camera.exerciseOptions) { exercise in
                        exercisePill(exercise)
                    }
                }
                .padding(.vertical, 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.appBorder, lineWidth: 1)
        }
    }

    private func exercisePill(_ exercise: ExerciseType) -> some View {
        let selected = camera.selectedExercise == exercise
        return Button {
            camera.selectExercise(exercise)
        } label: {
            Label(exercise.rawValue, systemImage: exercise.systemImage)
                .font(.subheadline.weight(.bold))
                .labelStyle(.titleAndIcon)
                .foregroundStyle(selected ? Color.appOnPrimary : Color.appTextSecondary)
                .padding(.horizontal, 14)
                .frame(minHeight: 42)
                .background(selected ? Color.appPrimary : Color.appSurfaceMuted, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(selected ? Color.clear : Color.appBorder, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private var permissionStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: permissionIcon)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(accent)

            Text(permissionTitle)
                .font(.headline)

            Text(permissionMessage)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.appTextSecondary)
                .padding(.horizontal)
        }
    }

    /// Friendly label, colour, and icon for each of the action classifier's 5 classes.
    private func squatFormInfo(_ label: String) -> (title: String, color: Color, icon: String) {
        switch label {
        case "squat_correct":
            return ("Correct squat", .appPrimary, "checkmark.seal.fill")
        case "squat_too_shallow":
            return ("Too shallow — go deeper", .appIntensityModerate, "arrow.down.circle.fill")
        case "squat_torso_lean":
            return ("Torso leaning — chest up", .appIntensityHigh, "figure.core.training")
        case "none":
            return ("No squat detected", .appTextSecondary, "scope")
        case "other":
            return ("Other movement", .appTextSecondary, "questionmark.circle")
        default:
            return (label, .appTextSecondary, "cpu")
        }
    }

    private func formClassCard(_ label: String, confidence: Double) -> some View {
        let info = squatFormInfo(label)
        return HStack(spacing: 12) {
            Image(systemName: info.icon)
                .font(.title3.weight(.bold))
                .foregroundStyle(info.color)
                .frame(width: 44, height: 44)
                .background(info.color.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("AI form check (Core ML)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.appTextSecondary)
                Text(info.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(info.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer()

            Text("\(Int((confidence * 100).rounded()))%")
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color.appTextSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(info.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(info.color.opacity(0.4), lineWidth: 1)
        }
    }

    private var feedbackPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let detected = camera.formFeedback.detectedExercise {
                formClassCard(detected, confidence: camera.formFeedback.detectionConfidence)
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: camera.formFeedback.isPersonDetected ? "figure.strengthtraining.traditional" : "scope")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(camera.formFeedback.isPersonDetected ? accent : Color.appIntensityModerate)
                    .frame(width: 30, height: 30)
                    .background((camera.formFeedback.isPersonDetected ? accent : Color.appIntensityModerate).opacity(0.18), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(camera.formFeedback.statusTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(camera.formFeedback.summary)
                        .font(.footnote)
                        .foregroundStyle(Color.appTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                feedbackChip(camera.formFeedback.exerciseName, systemImage: "figure.mixed.cardio")
                feedbackChip(camera.formFeedback.repPhase, systemImage: "waveform.path.ecg")
            }

            if camera.formFeedback.isPersonDetected {
                coachScoreCard
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(camera.formFeedback.cues) { cue in
                    feedbackCueRow(cue)
                }
            }

            if camera.formFeedback.isPersonDetected {
                ProgressView(value: camera.formFeedback.confidence, total: 1) {
                    Text("Pose confidence")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.appTextSecondary)
                } currentValueLabel: {
                    Text("\(Int(camera.formFeedback.confidence * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color.appTextSecondary)
                }
                .tint(accent)
            }
        }
    }

    /// Live form score + a single prioritized coaching focus + rep tally,
    /// so the feedback reads like a coach, not just a list of states.
    private var coachScoreCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(Color.appBorder, lineWidth: 7)
                    Circle()
                        .trim(from: 0, to: CGFloat(formScore) / 100)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.3), value: formScore)
                    Text("\(formScore)")
                        .font(.headline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Color.appTextPrimary)
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Form score")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.appTextSecondary)
                    Text(scoreVerdict)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(scoreColor)
                    Text("\(camera.completedReps) reps • \(camera.formFeedback.repPhase)")
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer()
            }

            if let focus = topCue {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: focus.severity == .good ? "hand.thumbsup.fill" : "scope")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(color(for: focus.severity))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(focus.severity == .good ? "Keep it up" : "Focus on this")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(color(for: focus.severity))
                        Text(focus.message)
                            .font(.footnote)
                            .foregroundStyle(Color.appTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(color(for: focus.severity).opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(12)
        .background(Color.appSurfaceMuted, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// 0–100 score: starts from pose confidence and is reduced for each warning/critical cue.
    private var formScore: Int {
        let feedback = camera.formFeedback
        guard feedback.isPersonDetected else { return 0 }
        var score = 55 + Int(feedback.confidence * 45)
        for cue in feedback.cues {
            switch cue.severity {
            case .warning: score -= 12
            case .critical: score -= 24
            case .good: break
            }
        }
        return max(10, min(100, score))
    }

    private var scoreColor: Color {
        switch formScore {
        case 80...: return .appIntensityLow
        case 55..<80: return .appIntensityModerate
        default: return .appIntensityHigh
        }
    }

    private var scoreVerdict: String {
        switch formScore {
        case 80...: return "Clean form"
        case 55..<80: return "Almost there"
        default: return "Needs work"
        }
    }

    /// The most important cue to act on: worst severity first, otherwise the positive one.
    private var topCue: ExerciseFormCue? {
        let cues = camera.formFeedback.cues
        return cues.first(where: { $0.severity == .critical })
            ?? cues.first(where: { $0.severity == .warning })
            ?? cues.first
    }

    private func feedbackChip(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.appSurfaceMuted, in: Capsule())
            .foregroundStyle(Color.appTextSecondary)
    }

    private func feedbackCueRow(_ cue: ExerciseFormCue) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: cue.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color(for: cue.severity))
                .frame(width: 28, height: 28)
                .background(color(for: cue.severity).opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(cue.title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(cue.severity.label)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(color(for: cue.severity).opacity(0.14), in: Capsule())
                        .foregroundStyle(color(for: cue.severity))
                }

                Text(cue.message)
                    .font(.footnote)
                    .foregroundStyle(Color.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func color(for severity: ExerciseFormCue.Severity) -> Color {
        switch severity {
        case .good:
            return .appIntensityLow
        case .warning:
            return .appIntensityModerate
        case .critical:
            return .appIntensityHigh
        }
    }

    private var formGuidancePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Quick form checks", systemImage: "list.bullet.clipboard")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                guidanceRow("Camera at chest height", systemImage: "camera.viewfinder")
                guidanceRow("Full body in frame", systemImage: "figure.stand")
                guidanceRow("Bright, open space", systemImage: "sun.max.fill")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.appBorder, lineWidth: 1)
        }
    }

    private func guidanceRow(_ text: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accent)
                .frame(width: 28, height: 28)
                .background(accent.opacity(0.18), in: Circle())

            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)
        }
    }

    private var permissionIcon: String {
        switch camera.permissionState {
        case .requesting:
            return "camera.metering.center.weighted"
        case .denied:
            return "camera.badge.ellipsis"
        case .unavailable:
            return "camera.fill"
        default:
            return "camera.viewfinder"
        }
    }

    private var permissionTitle: String {
        switch camera.permissionState {
        case .requesting:
            return "Requesting camera access"
        case .denied:
            return "Camera permission needed"
        case .unavailable:
            return "Camera unavailable"
        default:
            return "Camera feedback ready"
        }
    }

    private var permissionMessage: String {
        switch camera.permissionState {
        case .denied:
            return "Enable camera access in Settings to try front and back camera feedback on iPhone."
        case .unavailable:
            return "This device does not expose a camera that the app can use."
        default:
            return "Use your iPhone camera to preview exercise form feedback."
        }
    }
}

/// Draws the detected body pose as a stickman over the camera preview.
private struct PoseSkeletonView: View {
    let skeleton: PoseSkeleton

    private static let bones: [(String, String)] = [
        ("nose", "neck"),
        ("neck", "leftShoulder"),
        ("neck", "rightShoulder"),
        ("leftShoulder", "rightShoulder"),
        ("leftShoulder", "leftElbow"),
        ("leftElbow", "leftWrist"),
        ("rightShoulder", "rightElbow"),
        ("rightElbow", "rightWrist"),
        ("leftShoulder", "leftHip"),
        ("rightShoulder", "rightHip"),
        ("leftHip", "rightHip"),
        ("leftHip", "leftKnee"),
        ("leftKnee", "leftAnkle"),
        ("rightHip", "rightKnee"),
        ("rightKnee", "rightAnkle")
    ]

    var body: some View {
        Canvas { context, size in
            guard !skeleton.joints.isEmpty else { return }

            let positions = Dictionary(
                uniqueKeysWithValues: skeleton.joints.map { ($0.name, place($0.location, in: size)) }
            )

            var bonePath = Path()
            for (start, end) in Self.bones {
                guard let from = positions[start], let to = positions[end] else { continue }
                bonePath.move(to: from)
                bonePath.addLine(to: to)
            }
            context.stroke(
                bonePath,
                with: .color(.appPrimary),
                style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
            )

            for position in positions.values {
                let radius: CGFloat = 5
                let dot = Path(ellipseIn: CGRect(x: position.x - radius, y: position.y - radius, width: radius * 2, height: radius * 2))
                context.fill(dot, with: .color(.white))
                context.stroke(dot, with: .color(.appPrimary), lineWidth: 2)
            }
        }
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.12), value: skeleton)
    }

    /// Maps a normalized top-left point into the preview, emulating `.resizeAspectFill` cropping.
    private func place(_ normalized: CGPoint, in size: CGSize) -> CGPoint {
        let imageAspect = skeleton.imageAspectRatio
        let viewAspect = size.height > 0 ? size.width / size.height : 1
        var drawWidth = size.width
        var drawHeight = size.height
        var offsetX: CGFloat = 0
        var offsetY: CGFloat = 0

        if imageAspect > viewAspect {
            // Source is wider than the box: match height and crop the sides.
            drawHeight = size.height
            drawWidth = size.height * imageAspect
            offsetX = (size.width - drawWidth) / 2
        } else {
            // Source is narrower/taller than the box: match width and crop top/bottom.
            drawWidth = size.width
            drawHeight = imageAspect > 0 ? size.width / imageAspect : size.height
            offsetY = (size.height - drawHeight) / 2
        }

        return CGPoint(x: offsetX + normalized.x * drawWidth, y: offsetY + normalized.y * drawHeight)
    }
}

struct ExerciseFeedbackView_Previews: PreviewProvider {
    static var previews: some View {
        ExerciseFeedbackView()
    }
}
