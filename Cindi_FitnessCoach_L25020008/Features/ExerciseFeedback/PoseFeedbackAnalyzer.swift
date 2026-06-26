import AVFoundation
import CoreGraphics
import CoreVideo
import ImageIO
import QuartzCore
import Vision

final class PoseFeedbackAnalyzer: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var onFeedback: (@MainActor (ExerciseFormFeedback) -> Void)?
    var onPose: (@MainActor (PoseSkeleton) -> Void)?

    private let request = VNDetectHumanBodyPoseRequest()
    private let minimumConfidence: VNConfidence = 0.28
    private let drawingConfidence: VNConfidence = 0.2
    private var lastAnalysisTime: CFTimeInterval = 0

    /// On-device Create ML action classifier that scores squat form over a rolling pose window.
    private let actionClassifier = SquatActionClassifier()
    /// Most recent action-classifier result, kept between predictions so the readout is stable.
    private var lastAction: SquatActionClassifier.Prediction?
    /// Frames in a row with no detected body; the AI result is only forgotten after a real gap.
    private var consecutiveMisses = 0

    /// Clean joint names (used for both drawing and the bone connections in the overlay).
    private let drawableJoints: [(String, VNHumanBodyPoseObservation.JointName)] = [
        ("nose", .nose),
        ("neck", .neck),
        ("leftShoulder", .leftShoulder),
        ("rightShoulder", .rightShoulder),
        ("leftElbow", .leftElbow),
        ("rightElbow", .rightElbow),
        ("leftWrist", .leftWrist),
        ("rightWrist", .rightWrist),
        ("leftHip", .leftHip),
        ("rightHip", .rightHip),
        ("leftKnee", .leftKnee),
        ("rightKnee", .rightKnee),
        ("leftAnkle", .leftAnkle),
        ("rightAnkle", .rightAnkle)
    ]

    // Read and written only on the video-output delegate queue, so no extra locking is needed.
    private var exercise: ExerciseType = .squat

    /// Must be called on the same queue the capture delegate runs on.
    func setExercise(_ exercise: ExerciseType) {
        self.exercise = exercise
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = CACurrentMediaTime()
        // ~30 fps to match the action classifier's training frame rate (60-frame / ~2 s window).
        guard now - lastAnalysisTime > 0.033 else { return }
        lastAnalysisTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // The capture connection already rotates buffers to portrait and mirrors the front
        // camera, so the buffer is upright and matches the preview — analyze it as-is (.up).
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let aspectRatio: CGFloat = height > 0 ? CGFloat(width) / CGFloat(height) : 3.0 / 4.0

        do {
            let handler = VNImageRequestHandler(
                cvPixelBuffer: pixelBuffer,
                orientation: .up,
                options: [:]
            )
            try handler.perform([request])

            guard let observation = request.results?.first else {
                // Tolerate brief detection gaps: only forget the AI result after ~1.5 s with
                // no body, so a single missed frame doesn't wipe the rolling pose window.
                consecutiveMisses += 1
                if consecutiveMisses > 45 {
                    actionClassifier.reset()
                    lastAction = nil
                }
                var miss = ExerciseFormFeedback.noPose
                miss.detectedExercise = lastAction?.label
                miss.detectionConfidence = lastAction?.confidence ?? 0
                publish(miss)
                publishPose(PoseSkeleton(joints: [], imageAspectRatio: aspectRatio))
                return
            }
            consecutiveMisses = 0

            // Run the action classifier for every exercise: it labels squats (correct / too
            // shallow / torso lean) and reports `other` / `none` for anything else.
            if let prediction = actionClassifier.add(observation: observation) {
                lastAction = prediction
            }

            let points = try observation.recognizedPoints(.all)
            var feedback = makeFeedback(from: points)
            feedback.detectedExercise = lastAction?.label
            feedback.detectionConfidence = lastAction?.confidence ?? 0
            publish(feedback)
            publishPose(makeSkeleton(from: points, aspectRatio: aspectRatio))
        } catch {
            publish(.noPose)
            publishPose(PoseSkeleton(joints: [], imageAspectRatio: aspectRatio))
        }
    }

    private func publish(_ feedback: ExerciseFormFeedback) {
        let callback = onFeedback
        Task { @MainActor in
            callback?(feedback)
        }
    }

    private func publishPose(_ skeleton: PoseSkeleton) {
        let callback = onPose
        Task { @MainActor in
            callback?(skeleton)
        }
    }

    private func makeSkeleton(
        from points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint],
        aspectRatio: CGFloat
    ) -> PoseSkeleton {
        let joints: [BodyJoint] = drawableJoints.compactMap { name, jointName in
            guard let point = points[jointName], point.confidence >= drawingConfidence else { return nil }
            // Vision points are normalized with a bottom-left origin; flip Y for screen space.
            return BodyJoint(
                name: name,
                location: CGPoint(x: point.location.x, y: 1 - point.location.y),
                confidence: Double(point.confidence)
            )
        }
        return PoseSkeleton(joints: joints, imageAspectRatio: aspectRatio)
    }

    private func makeFeedback(from points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) -> ExerciseFormFeedback {
        let pose = BodyPose(points: points, minimumConfidence: minimumConfidence)

        guard pose.detectedPointCount >= exercise.minimumDetectedPoints else {
            return .noPose
        }

        var cues: [ExerciseFormCue] = []

        if exercise.needsFullBodyInFrame && !pose.hasFullBody {
            cues.append(
                ExerciseFormCue(
                    severity: .critical,
                    title: "Full body not in frame",
                    message: "Step back until your shoulders, hips, knees, and ankles are visible.",
                    systemImage: "figure.stand"
                )
            )
        }

        let analysis: ExerciseAnalysis
        switch exercise {
        case .squat:
            analysis = analyzeSquat(pose)
        case .pushUp:
            analysis = analyzePushUp(pose)
        case .jumpingJack:
            analysis = analyzeJumpingJack(pose)
        case .sitUp:
            analysis = analyzeSitUp(pose)
        case .pullUp:
            analysis = analyzePullUp(pose)
        case .lunge:
            analysis = analyzeLunge(pose)
        case .bicepCurl:
            analysis = analyzeBicepCurl(pose)
        }

        cues.append(contentsOf: analysis.cues)

        if cues.filter({ $0.severity != .good }).isEmpty {
            cues.insert(
                ExerciseFormCue(
                    severity: .good,
                    title: "Form looks safe",
                    message: "Your alignment looks clean. Keep the tempo controlled and breathe steadily.",
                    systemImage: "checkmark.circle.fill"
                ),
                at: 0
            )
        }

        let attentionCount = cues.filter { $0.severity != .good }.count
        let status = attentionCount == 0 ? "Form good" : "\(attentionCount) cue needs attention"

        // The Core ML action-classifier result is attached by `captureOutput` (it needs the
        // pose observation, not just the points), so it isn't set here.
        return ExerciseFormFeedback(
            statusTitle: status,
            summary: analysis.summary,
            exerciseName: "\(exercise.rawValue) check",
            repPhase: analysis.phaseTitle,
            repState: analysis.repState,
            confidence: pose.averageConfidence,
            isPersonDetected: true,
            cues: Array(cues.prefix(5))
        )
    }

    // MARK: - Squat

    private func analyzeSquat(_ pose: BodyPose) -> ExerciseAnalysis {
        var cues = uprightPostureCues(for: pose)
        let phase = pose.squatPhase
        let repState: RepState
        let title: String

        switch phase {
        case .standing:
            repState = .rest
            title = "Standing"
            cues.append(
                ExerciseFormCue(
                    severity: .good,
                    title: "Ready to squat",
                    message: "Set your feet around hip width, lift your chest, then send your hips back before lowering.",
                    systemImage: "figure.strengthtraining.traditional"
                )
            )
        case .descending:
            repState = .transition
            title = "Squat descent"
            cues.append(contentsOf: squatCues(for: pose))
        case .bottom:
            repState = .active
            title = "Bottom position"
            cues.append(contentsOf: squatCues(for: pose))
        case .unknown:
            repState = .unknown
            title = "Reading pose"
            cues.append(
                ExerciseFormCue(
                    severity: .warning,
                    title: "Pose is not stable yet",
                    message: "Hold still for a moment so the camera can read your knees and hips more clearly.",
                    systemImage: "scope"
                )
            )
        }

        let attention = cues.filter { $0.severity != .good }.count
        return ExerciseAnalysis(repState: repState, phaseTitle: title, cues: cues, summary: squatSummary(for: phase, attentionCount: attention))
    }

    private func uprightPostureCues(for pose: BodyPose) -> [ExerciseFormCue] {
        var cues: [ExerciseFormCue] = []

        if let torsoLean = pose.torsoLeanDegrees {
            if torsoLean > 32 {
                cues.append(
                    ExerciseFormCue(
                        severity: .critical,
                        title: "Torso leaning too far",
                        message: "Brace your core, open your chest, and keep your shoulders stacked over your hips.",
                        systemImage: "figure.core.training"
                    )
                )
            } else if torsoLean > 20 {
                cues.append(
                    ExerciseFormCue(
                        severity: .warning,
                        title: "Torso angle needs control",
                        message: "Pull your ribs down and keep your spine long as you move.",
                        systemImage: "figure.cooldown"
                    )
                )
            }
        }

        if let shoulderTilt = pose.shoulderTilt, shoulderTilt > 0.08 {
            cues.append(
                ExerciseFormCue(
                    severity: .warning,
                    title: "Shoulders are uneven",
                    message: "Level your left and right shoulders so the load does not shift to one side.",
                    systemImage: "arrow.left.and.right"
                )
            )
        }

        return cues
    }

    private func squatCues(for pose: BodyPose) -> [ExerciseFormCue] {
        var cues: [ExerciseFormCue] = []

        if let kneeAngle = pose.averageKneeAngle {
            if kneeAngle > 118 {
                cues.append(
                    ExerciseFormCue(
                        severity: .critical,
                        title: "Squat depth is too shallow",
                        message: "Lower your hips until your thighs are closer to parallel, without bouncing at the bottom.",
                        systemImage: "arrow.down.to.line.compact"
                    )
                )
            } else if kneeAngle > 102 {
                cues.append(
                    ExerciseFormCue(
                        severity: .warning,
                        title: "Depth is almost there",
                        message: "Add a little more depth while keeping your heels pressed into the floor.",
                        systemImage: "arrow.down"
                    )
                )
            } else {
                cues.append(
                    ExerciseFormCue(
                        severity: .good,
                        title: "Squat depth looks good",
                        message: "Your depth looks solid. Drive up by pushing the floor through your heels.",
                        systemImage: "checkmark.circle.fill"
                    )
                )
            }
        }

        if let kneeDrift = pose.kneeAnkleDrift, kneeDrift > 0.14 {
            cues.append(
                ExerciseFormCue(
                    severity: .warning,
                    title: "Knees are not tracking well",
                    message: "Point your knees in the same direction as your toes and avoid letting them cave inward.",
                    systemImage: "figure.walk.motion"
                )
            )
        }

        if let stanceRatio = pose.stanceRatio, stanceRatio < 0.78 {
            cues.append(
                ExerciseFormCue(
                    severity: .warning,
                    title: "Stance is too narrow",
                    message: "Widen your stance slightly so your hips have enough room to lower.",
                    systemImage: "arrow.left.and.right.circle"
                )
            )
        }

        if let hipDrop = pose.hipToKneeDrop, hipDrop > 0.16 {
            cues.append(
                ExerciseFormCue(
                    severity: .critical,
                    title: "Hips are still too high",
                    message: "Sit lower by sending your hips back instead of only folding your torso forward.",
                    systemImage: "figure.flexibility"
                )
            )
        }

        return cues
    }

    private func squatSummary(for phase: SquatPhase, attentionCount: Int) -> String {
        switch phase {
        case .standing:
            return "Standing position detected. Start the squat slowly so I can check depth, knees, and posture."
        case .descending:
            return attentionCount == 0
                ? "Your descent looks controlled. Keep your chest lifted and knees tracking cleanly."
                : "Squat movement detected, with a few form details to clean up before the next rep."
        case .bottom:
            return attentionCount == 0
                ? "Bottom position looks solid. Stand up smoothly without letting your knees cave in."
                : "Bottom position detected. Focus on the main cue first, especially depth and knee alignment."
        case .unknown:
            return "Some body points are visible, but the movement phase is unclear. Keep your full body in frame."
        }
    }

    // MARK: - Shared movement helpers

    private enum ActiveSide {
        case low   // a small value means the "active" end of the rep (e.g. a bent joint)
        case high  // a large value means the "active" end of the rep (e.g. wide legs)
    }

    /// Maps a movement signal to a rep state with a gap between the active and rest
    /// thresholds (hysteresis) so sensor noise does not bounce the count.
    private func movementState(_ value: CGFloat?, active: CGFloat, rest: CGFloat, activeSide: ActiveSide) -> RepState {
        guard let value else { return .unknown }
        switch activeSide {
        case .low:
            if value <= active { return .active }
            if value >= rest { return .rest }
        case .high:
            if value >= active { return .active }
            if value <= rest { return .rest }
        }
        return .transition
    }

    private func phaseTitle(_ state: RepState, rest: String, active: String) -> String {
        switch state {
        case .rest: return rest
        case .active: return active
        case .transition: return "Moving"
        case .unknown: return "Reading pose"
        }
    }

    private func phaseSummary(_ state: RepState, rest: String, active: String, moving: String) -> String {
        switch state {
        case .rest: return rest
        case .active: return active
        case .transition: return moving
        case .unknown: return "Keep your whole body in frame so I can read the movement clearly."
        }
    }

    private func cue(_ severity: ExerciseFormCue.Severity, _ title: String, _ message: String, _ image: String) -> ExerciseFormCue {
        ExerciseFormCue(severity: severity, title: title, message: message, systemImage: image)
    }

    // MARK: - Push-up

    private func analyzePushUp(_ pose: BodyPose) -> ExerciseAnalysis {
        // Primary signal: elbow angle (scale-invariant). Thresholds are loosened with a
        // wide hysteresis gap so the "top" still registers even when the arm foreshortens
        // toward the camera and never projects to a fully straight angle.
        let elbowState = movementState(pose.averageElbowAngle, active: 120, rest: 148, activeSide: .low)

        // Fallback signal: how high the shoulders sit above the hands, normalized by torso
        // length. Large at the top of a push-up, small at the bottom. This keeps reps
        // counting from a side view even when the elbow angle stalls or drops out.
        let liftState = movementState(pose.pushUpLiftRatio, active: 0.42, rest: 0.72, activeSide: .low)

        // Trust the elbow reading when it commits to a top/bottom; otherwise use the lift.
        let state: RepState
        switch elbowState {
        case .active, .rest:
            state = elbowState
        case .transition, .unknown:
            state = liftState
        }

        var cues: [ExerciseFormCue] = []

        if let bodyLine = pose.bodyLineAngle, bodyLine < 150 {
            cues.append(cue(.critical, "Keep a straight body line", "Brace your core and glutes so your hips do not sag or pike — stay flat from head to heels.", "figure.core.training"))
        }

        switch state {
        case .rest:
            cues.append(cue(.good, "Arms locked out", "Top of the push-up. Lower your chest until your elbows bend to about 90°.", "arrow.up.circle.fill"))
        case .active:
            cues.append(cue(.good, "Good depth", "Chest is low with elbows bent. Press the floor away to finish the rep.", "checkmark.circle.fill"))
        case .transition:
            cues.append(cue(.warning, "Reach full depth", "Bend your elbows until your chest is near the floor, then press all the way up.", "arrow.down"))
        case .unknown:
            cues.append(cue(.warning, "Film from the side", "Place the phone to your side at chest height so it can see your shoulders, elbows, and wrists.", "camera.metering.center.weighted"))
        }

        return ExerciseAnalysis(
            repState: state,
            phaseTitle: phaseTitle(state, rest: "Top position", active: "Bottom position"),
            cues: cues,
            summary: phaseSummary(
                state,
                rest: "Top of the push-up. Lower with control until your elbows reach about 90°.",
                active: "Nice depth. Press all the way up and lock your elbows to count the rep.",
                moving: "Mid push-up. Lower to about 90° then press fully up for each rep."
            )
        )
    }

    // MARK: - Jumping jack

    private func analyzeJumpingJack(_ pose: BodyPose) -> ExerciseAnalysis {
        let armsUp = pose.wristsAboveShoulders || pose.raisedWristCount > 0
        let armsDown = pose.wristsBelowShoulders || pose.raisedWristCount == 0
        let spread = pose.ankleSpreadRatio

        let repState: RepState
        let title: String
        let summary: String
        var cues: [ExerciseFormCue] = []

        if let spread, (spread >= 1.45 && armsUp) || spread >= 1.85 {
            repState = .active
            title = "Open"
            summary = "Full jumping-jack extension. Jump your feet back together and lower your arms to reset."
            cues.append(
                ExerciseFormCue(
                    severity: .good,
                    title: "Full extension",
                    message: "Arms overhead and legs wide. Keep a soft bend in your knees as you land.",
                    systemImage: "checkmark.circle.fill"
                )
            )
        } else if let spread, spread <= 1.15, armsDown {
            repState = .rest
            title = "Closed"
            summary = "Feet together, arms down. Jump out wide and raise your arms overhead for the next rep."
            cues.append(
                ExerciseFormCue(
                    severity: .good,
                    title: "Reset position",
                    message: "Good closed stance. Explode into the next jack with a full range of motion.",
                    systemImage: "arrow.up.and.down.and.arrow.left.and.right"
                )
            )
        } else {
            repState = .transition
            title = "Mid jump"
            summary = "Mid jumping jack. Open your arms and legs fully, then snap them back together each rep."
            if !armsUp {
                cues.append(
                    ExerciseFormCue(
                        severity: .warning,
                        title: "Raise your arms",
                        message: "Bring both wrists above your shoulders so each jack reaches full extension.",
                        systemImage: "arrow.up"
                    )
                )
            }
            if let spread, spread < 1.35 {
                cues.append(
                    ExerciseFormCue(
                        severity: .warning,
                        title: "Jump your feet wider",
                        message: "Land with your feet wider than your shoulders to complete the movement.",
                        systemImage: "arrow.left.and.right"
                    )
                )
            }
            if spread == nil {
                cues.append(
                    ExerciseFormCue(
                        severity: .warning,
                        title: "Feet not clear",
                        message: "Step back so the camera can see both ankles while you jump.",
                        systemImage: "figure.stand"
                    )
                )
            }
        }

        return ExerciseAnalysis(repState: repState, phaseTitle: title, cues: cues, summary: summary)
    }

    // MARK: - Sit-up

    private func analyzeSitUp(_ pose: BodyPose) -> ExerciseAnalysis {
        guard let hipAngle = pose.hipAngle else {
            return ExerciseAnalysis(
                repState: .unknown,
                phaseTitle: "Reading pose",
                cues: [
                    ExerciseFormCue(
                        severity: .warning,
                        title: "Torso not clear yet",
                        message: "Lie sideways to the camera so it can see your shoulders, hips, and knees.",
                        systemImage: "camera.metering.center.weighted"
                    )
                ],
                summary: "Place the phone to your side on the floor so I can read your torso as you curl up."
            )
        }

        let repState: RepState
        let title: String
        let summary: String
        var cues: [ExerciseFormCue] = []

        if hipAngle > 140 {
            repState = .rest
            title = "Lying back"
            summary = "Lying position detected. Curl up through your core until your torso is upright."
            cues.append(
                ExerciseFormCue(
                    severity: .good,
                    title: "Reset on the floor",
                    message: "Keep your knees bent and feet planted, then lead with your chest as you rise.",
                    systemImage: "figure.flexibility"
                )
            )
        } else if hipAngle < 95 {
            repState = .active
            title = "Up"
            summary = "Top of the sit-up. Lower back down with control instead of dropping flat."
            cues.append(
                ExerciseFormCue(
                    severity: .good,
                    title: "Strong curl-up",
                    message: "Nice range of motion. Avoid pulling on your neck — keep the work in your core.",
                    systemImage: "checkmark.circle.fill"
                )
            )
        } else {
            repState = .transition
            title = "Curling up"
            summary = "Mid sit-up. Keep curling until your torso is upright for a full rep."
            cues.append(
                ExerciseFormCue(
                    severity: .warning,
                    title: "Finish the curl",
                    message: "Lift a little higher until your chest comes toward your knees, then lower slowly.",
                    systemImage: "arrow.up"
                )
            )
        }

        return ExerciseAnalysis(repState: repState, phaseTitle: title, cues: cues, summary: summary)
    }

    // MARK: - Pull-up

    private func analyzePullUp(_ pose: BodyPose) -> ExerciseAnalysis {
        guard pose.raisedWristCount > 0 else {
            return ExerciseAnalysis(
                repState: .unknown,
                phaseTitle: "Find the bar",
                cues: [
                    cue(.warning, "Hands not visible overhead", "Step back so the camera can see your hands, elbows, shoulders, and face while you hang.", "camera.metering.center.weighted")
                ],
                summary: "Keep your upper body and hands visible so I can read the pull-up."
            )
        }

        let state = movementState(pose.averageElbowAngle, active: 95, rest: 150, activeSide: .low)
        var cues: [ExerciseFormCue] = []

        switch state {
        case .rest:
            cues.append(cue(.good, "Dead hang detected", "Arms are extended. Pull your chest up and drive your elbows down.", "arrow.down.circle.fill"))
        case .active:
            if pose.noseNearHands {
                cues.append(cue(.good, "Top position", "Strong pull. Lower with control until your arms are straight again.", "checkmark.circle.fill"))
            } else {
                cues.append(cue(.warning, "Pull a little higher", "Keep pulling until your chin is near or above your hands.", "arrow.up"))
            }
        case .transition:
            cues.append(cue(.warning, "Finish the range", "Move from a straight-arm hang to a high pull before lowering.", "arrow.up.and.down"))
        case .unknown:
            cues.append(cue(.warning, "Elbows not clear", "Angle the camera so it can see your shoulders, elbows, and wrists.", "scope"))
        }

        return ExerciseAnalysis(
            repState: state,
            phaseTitle: phaseTitle(state, rest: "Dead hang", active: "Top pull"),
            cues: cues,
            summary: phaseSummary(
                state,
                rest: "Dead hang detected. Pull until your elbows bend and your chin rises toward your hands.",
                active: "Top of the pull-up. Lower under control to a full hang to count the rep.",
                moving: "Pull-up motion detected. Keep the path smooth and avoid swinging."
            )
        )
    }

    // MARK: - Lunge

    private func analyzeLunge(_ pose: BodyPose) -> ExerciseAnalysis {
        let state = movementState(pose.minimumKneeAngle, active: 112, rest: 155, activeSide: .low)
        var cues = uprightPostureCues(for: pose)

        if let kneeDifference = pose.kneeAngleDifference, kneeDifference < 12, state == .active {
            cues.append(cue(.warning, "Take a longer step", "One knee should bend deeply while the other leg trails behind. Step longer and drop straight down.", "figure.walk"))
        }

        switch state {
        case .rest:
            cues.append(cue(.good, "Standing reset", "Stand tall, then step into the next lunge with control.", "figure.stand"))
        case .active:
            cues.append(cue(.good, "Lunge depth detected", "Front knee is bending well. Push through the front foot to stand back up.", "checkmark.circle.fill"))
        case .transition:
            cues.append(cue(.warning, "Drop lower", "Lower until the front knee is near 90 degrees and the back knee moves toward the floor.", "arrow.down"))
        case .unknown:
            cues.append(cue(.warning, "Legs not clear", "Keep hips, knees, and ankles visible so I can read the lunge.", "scope"))
        }

        return ExerciseAnalysis(
            repState: state,
            phaseTitle: phaseTitle(state, rest: "Standing", active: "Bottom lunge"),
            cues: cues,
            summary: phaseSummary(
                state,
                rest: "Standing reset detected. Step forward and lower with your chest tall.",
                active: "Bottom of the lunge detected. Push back to standing to complete the rep.",
                moving: "Lunge movement detected. Keep the front knee tracking over the toes."
            )
        )
    }

    // MARK: - Bicep curl

    private func analyzeBicepCurl(_ pose: BodyPose) -> ExerciseAnalysis {
        let state = movementState(pose.averageElbowAngle, active: 70, rest: 145, activeSide: .low)
        var cues: [ExerciseFormCue] = []

        if let elbowDrift = pose.elbowShoulderDrift, elbowDrift > 0.16 {
            cues.append(cue(.warning, "Keep elbows tucked", "Pin your elbows near your ribs instead of letting them swing forward.", "figure.strengthtraining.traditional"))
        }

        switch state {
        case .rest:
            cues.append(cue(.good, "Arms extended", "Start position detected. Curl the weight up without swinging your torso.", "arrow.up.circle"))
        case .active:
            cues.append(cue(.good, "Top curl", "Good curl height. Lower slowly until your arms are extended again.", "checkmark.circle.fill"))
        case .transition:
            cues.append(cue(.warning, "Complete the curl", "Curl all the way up, then lower all the way down for a clean rep.", "arrow.up.and.down"))
        case .unknown:
            cues.append(cue(.warning, "Arms not clear", "Face the camera or turn slightly so shoulders, elbows, and wrists are visible.", "camera.metering.center.weighted"))
        }

        return ExerciseAnalysis(
            repState: state,
            phaseTitle: phaseTitle(state, rest: "Arms down", active: "Curl top"),
            cues: cues,
            summary: phaseSummary(
                state,
                rest: "Arms extended. Curl up while keeping your elbows pinned near your sides.",
                active: "Top of the curl. Lower under control to complete the rep.",
                moving: "Curl movement detected. Avoid using momentum."
            )
        )
    }
}

private extension ExerciseType {
    var minimumDetectedPoints: Int {
        switch self {
        case .bicepCurl, .pullUp:
            return 5
        case .pushUp:
            return 4
        case .sitUp:
            return 6
        case .squat, .jumpingJack, .lunge:
            return 8
        }
    }

    var needsFullBodyInFrame: Bool {
        switch self {
        case .squat, .jumpingJack, .lunge:
            return true
        case .pushUp, .sitUp, .pullUp, .bicepCurl:
            return false
        }
    }
}

private struct ExerciseAnalysis {
    let repState: RepState
    let phaseTitle: String
    let cues: [ExerciseFormCue]
    let summary: String
}

private enum SquatPhase {
    case standing
    case descending
    case bottom
    case unknown

    var title: String {
        switch self {
        case .standing:
            return "Standing"
        case .descending:
            return "Squat descent"
        case .bottom:
            return "Bottom position"
        case .unknown:
            return "Reading pose"
        }
    }
}

private struct BodyPose {
    let points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]
    let minimumConfidence: VNConfidence

    var detectedPointCount: Int {
        points.values.filter { $0.confidence >= minimumConfidence }.count
    }

    var averageConfidence: Double {
        let valid = points.values.filter { $0.confidence >= minimumConfidence }
        guard !valid.isEmpty else { return 0 }
        return Double(valid.map(\.confidence).reduce(0, +) / Float(valid.count))
    }

    var hasFullBody: Bool {
        point(.leftShoulder) != nil
            && point(.rightShoulder) != nil
            && point(.leftHip) != nil
            && point(.rightHip) != nil
            && point(.leftKnee) != nil
            && point(.rightKnee) != nil
            && point(.leftAnkle) != nil
            && point(.rightAnkle) != nil
    }

    var squatPhase: SquatPhase {
        guard let kneeAngle = averageKneeAngle else { return .unknown }

        if kneeAngle > 148 {
            return .standing
        } else if kneeAngle > 103 {
            return .descending
        } else {
            return .bottom
        }
    }

    var averageKneeAngle: CGFloat? {
        average(
            angle(a: point(.leftHip), b: point(.leftKnee), c: point(.leftAnkle)),
            angle(a: point(.rightHip), b: point(.rightKnee), c: point(.rightAnkle))
        )
    }

    var minimumKneeAngle: CGFloat? {
        minimum(
            angle(a: point(.leftHip), b: point(.leftKnee), c: point(.leftAnkle)),
            angle(a: point(.rightHip), b: point(.rightKnee), c: point(.rightAnkle))
        )
    }

    var kneeAngleDifference: CGFloat? {
        guard let left = angle(a: point(.leftHip), b: point(.leftKnee), c: point(.leftAnkle)),
              let right = angle(a: point(.rightHip), b: point(.rightKnee), c: point(.rightAnkle)) else { return nil }
        return abs(left - right)
    }

    var averageElbowAngle: CGFloat? {
        average(
            angle(a: point(.leftShoulder), b: point(.leftElbow), c: point(.leftWrist)),
            angle(a: point(.rightShoulder), b: point(.rightElbow), c: point(.rightWrist))
        )
    }

    /// Shoulder → hip → ankle angle. Close to 180° when the body is a straight plank line.
    var bodyLineAngle: CGFloat? {
        average(
            angle(a: point(.leftShoulder), b: point(.leftHip), c: point(.leftAnkle)),
            angle(a: point(.rightShoulder), b: point(.rightHip), c: point(.rightAnkle))
        )
    }

    /// Vertical gap between the shoulders and the wrists, normalized by torso length so it
    /// is scale-invariant. Large at the top of a push-up (shoulders well above the hands on
    /// the floor) and small near the bottom. Used as a fallback rep signal for push-ups when
    /// the elbow angle is unreliable (e.g. arms foreshortened toward the camera).
    /// Points use a bottom-left origin (y grows upward), so a higher shoulder gives a larger value.
    var pushUpLiftRatio: CGFloat? {
        guard let shoulder = midpoint(point(.leftShoulder), point(.rightShoulder)),
              let wrist = midpoint(point(.leftWrist), point(.rightWrist)),
              let hip = midpoint(point(.leftHip), point(.rightHip)) else { return nil }
        let torsoLength = max(hypot(shoulder.x - hip.x, shoulder.y - hip.y), 0.05)
        return (shoulder.y - wrist.y) / torsoLength
    }

    /// Shoulder → hip → knee angle. Large when lying flat, small when curled up in a sit-up.
    var hipAngle: CGFloat? {
        average(
            angle(a: point(.leftShoulder), b: point(.leftHip), c: point(.leftKnee)),
            angle(a: point(.rightShoulder), b: point(.rightHip), c: point(.rightKnee))
        )
    }

    var shoulderWidth: CGFloat? {
        guard let left = point(.leftShoulder), let right = point(.rightShoulder) else { return nil }
        return max(abs(left.x - right.x), 0.001)
    }

    /// Horizontal foot spread relative to shoulder width (1 ≈ shoulder-width stance).
    var ankleSpreadRatio: CGFloat? {
        guard let leftAnkle = point(.leftAnkle),
              let rightAnkle = point(.rightAnkle),
              let width = shoulderWidth else { return nil }
        return abs(leftAnkle.x - rightAnkle.x) / width
    }

    var wristsAboveShoulders: Bool {
        guard let leftWrist = point(.leftWrist),
              let rightWrist = point(.rightWrist),
              let leftShoulder = point(.leftShoulder),
              let rightShoulder = point(.rightShoulder) else { return false }
        return leftWrist.y > leftShoulder.y && rightWrist.y > rightShoulder.y
    }

    var wristsBelowShoulders: Bool {
        let leftIsDown = wrist(.leftWrist, isBelow: .leftShoulder)
        let rightIsDown = wrist(.rightWrist, isBelow: .rightShoulder)
        return leftIsDown == true || rightIsDown == true
    }

    var raisedWristCount: Int {
        [
            wrist(.leftWrist, isAbove: .leftShoulder),
            wrist(.rightWrist, isAbove: .rightShoulder)
        ].filter { $0 == true }.count
    }

    var noseNearHands: Bool {
        guard let nose = point(.nose),
              let wrist = midpoint(point(.leftWrist), point(.rightWrist)) ?? point(.leftWrist) ?? point(.rightWrist) else { return false }
        return nose.y >= wrist.y - 0.08
    }

    var torsoLeanDegrees: CGFloat? {
        guard let shoulder = midpoint(point(.leftShoulder), point(.rightShoulder)),
              let hip = midpoint(point(.leftHip), point(.rightHip)) else { return nil }

        let dx = abs(shoulder.x - hip.x)
        let dy = max(abs(shoulder.y - hip.y), 0.001)
        return atan(dx / dy) * 180 / .pi
    }

    var shoulderTilt: CGFloat? {
        guard let left = point(.leftShoulder), let right = point(.rightShoulder) else { return nil }
        return abs(left.y - right.y)
    }

    var kneeAnkleDrift: CGFloat? {
        average(
            horizontalDistance(point(.leftKnee), point(.leftAnkle)),
            horizontalDistance(point(.rightKnee), point(.rightAnkle))
        )
    }

    var stanceRatio: CGFloat? {
        guard let leftAnkle = point(.leftAnkle),
              let rightAnkle = point(.rightAnkle),
              let leftHip = point(.leftHip),
              let rightHip = point(.rightHip) else { return nil }

        let hipWidth = max(abs(leftHip.x - rightHip.x), 0.001)
        return abs(leftAnkle.x - rightAnkle.x) / hipWidth
    }

    var hipToKneeDrop: CGFloat? {
        guard let hip = midpoint(point(.leftHip), point(.rightHip)),
              let knee = midpoint(point(.leftKnee), point(.rightKnee)) else { return nil }

        return hip.y - knee.y
    }

    var elbowShoulderDrift: CGFloat? {
        average(
            horizontalDistance(point(.leftElbow), point(.leftShoulder)),
            horizontalDistance(point(.rightElbow), point(.rightShoulder))
        )
    }

    func point(_ joint: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
        guard let point = points[joint], point.confidence >= minimumConfidence else { return nil }
        return point.location
    }

    private func horizontalDistance(_ first: CGPoint?, _ second: CGPoint?) -> CGFloat? {
        guard let first, let second else { return nil }
        return abs(first.x - second.x)
    }

    private func midpoint(_ first: CGPoint?, _ second: CGPoint?) -> CGPoint? {
        guard let first, let second else { return nil }
        return CGPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
    }

    private func wrist(
        _ wrist: VNHumanBodyPoseObservation.JointName,
        isAbove shoulder: VNHumanBodyPoseObservation.JointName
    ) -> Bool? {
        guard let wristPoint = point(wrist), let shoulderPoint = point(shoulder) else { return nil }
        return wristPoint.y > shoulderPoint.y - 0.03
    }

    private func wrist(
        _ wrist: VNHumanBodyPoseObservation.JointName,
        isBelow shoulder: VNHumanBodyPoseObservation.JointName
    ) -> Bool? {
        guard let wristPoint = point(wrist), let shoulderPoint = point(shoulder) else { return nil }
        return wristPoint.y < shoulderPoint.y + 0.04
    }

    private func angle(a: CGPoint?, b: CGPoint?, c: CGPoint?) -> CGFloat? {
        guard let a, let b, let c else { return nil }

        let vectorA = CGVector(dx: a.x - b.x, dy: a.y - b.y)
        let vectorC = CGVector(dx: c.x - b.x, dy: c.y - b.y)
        let dot = vectorA.dx * vectorC.dx + vectorA.dy * vectorC.dy
        let magnitudeA = hypot(vectorA.dx, vectorA.dy)
        let magnitudeC = hypot(vectorC.dx, vectorC.dy)
        guard magnitudeA > 0, magnitudeC > 0 else { return nil }

        let cosine = max(-1, min(1, dot / (magnitudeA * magnitudeC)))
        return acos(cosine) * 180 / .pi
    }

    private func average(_ first: CGFloat?, _ second: CGFloat?) -> CGFloat? {
        switch (first, second) {
        case let (.some(first), .some(second)):
            return (first + second) / 2
        case let (.some(value), .none), let (.none, .some(value)):
            return value
        case (.none, .none):
            return nil
        }
    }

    private func minimum(_ first: CGFloat?, _ second: CGFloat?) -> CGFloat? {
        switch (first, second) {
        case let (.some(first), .some(second)):
            return min(first, second)
        case let (.some(value), .none), let (.none, .some(value)):
            return value
        case (.none, .none):
            return nil
        }
    }
}
