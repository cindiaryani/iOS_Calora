import CoreGraphics
import Foundation

/// A single detected body joint, normalized with origin at the top-left (x → right, y → down)
/// so it can be drawn directly over the camera preview.
struct BodyJoint: Equatable {
    let name: String
    let location: CGPoint
    let confidence: Double
}

/// The set of joints for the currently detected person, plus the oriented source aspect ratio
/// so the overlay can match the preview's `.resizeAspectFill` cropping.
struct PoseSkeleton: Equatable {
    let joints: [BodyJoint]
    let imageAspectRatio: CGFloat

    static let empty = PoseSkeleton(joints: [], imageAspectRatio: 3.0 / 4.0)
}

struct ExerciseFormCue: Identifiable, Equatable {
    enum Severity: Equatable {
        case good
        case warning
        case critical

        var label: String {
            switch self {
            case .good:
                return "Good"
            case .warning:
                return "Adjust"
            case .critical:
                return "Fix now"
            }
        }
    }

    let id = UUID()
    let severity: Severity
    let title: String
    let message: String
    let systemImage: String
}

/// Normalized movement state used to count one repetition per rest → active → rest cycle.
enum RepState: Equatable {
    case rest      // standing / arms straight / legs together / lying flat
    case active    // squat bottom / push-up down / jumping-jack open / sit-up top
    case transition
    case unknown
}

struct ExerciseFormFeedback: Equatable {
    let statusTitle: String
    let summary: String
    let exerciseName: String
    let repPhase: String
    let repState: RepState
    let confidence: Double
    let isPersonDetected: Bool
    let cues: [ExerciseFormCue]
    /// Exercise predicted by the bundled Core ML model (`ExercisePoseClassifier`), if available.
    var detectedExercise: String? = nil
    /// Confidence (0…1) of the Core ML prediction above.
    var detectionConfidence: Double = 0

    static let waiting = ExerciseFormFeedback(
        statusTitle: "Position yourself in frame",
        summary: "Stand far enough back so the camera can see your shoulders, hips, knees, and ankles.",
        exerciseName: "Bodyweight form check",
        repPhase: "Scanning",
        repState: .unknown,
        confidence: 0,
        isPersonDetected: false,
        cues: [
            ExerciseFormCue(
                severity: .warning,
                title: "Full body needed",
                message: "Put the iPhone at chest height and keep your whole body visible.",
                systemImage: "figure.stand"
            )
        ]
    )

    static let noPose = ExerciseFormFeedback(
        statusTitle: "Looking for posture",
        summary: "I cannot read enough body points yet. Improve lighting or step back slightly.",
        exerciseName: "Bodyweight form check",
        repPhase: "Scanning",
        repState: .unknown,
        confidence: 0,
        isPersonDetected: false,
        cues: [
            ExerciseFormCue(
                severity: .critical,
                title: "Body not detected",
                message: "Keep your full body in frame with clear contrast from the background.",
                systemImage: "camera.metering.center.weighted"
            )
        ]
    )
}
