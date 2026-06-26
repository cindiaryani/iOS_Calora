import CoreML
import Vision

/// Wraps the Create ML **action classifier** `SquatFormClassifier.mlmodel`
/// (5 classes: squat_correct / squat_too_shallow / squat_torso_lean / none / other).
///
/// The model classifies a rolling window of 60 body-pose frames (its prediction window —
/// ~2 s at 30 fps). Each frame is the `VNHumanBodyPoseObservation.keypointsMultiArray()`
/// ([1, 3, 18]); 60 of them are concatenated into the [60, 3, 18] `poses` input. Because the
/// model's accuracy is modest, raw predictions are smoothed with a short majority vote.\
final class SquatActionClassifier {
    struct Prediction: Equatable {
        let label: String
        let confidence: Double
    }

    private let model: MLModel?
    private let windowSize = 60
    private let predictionStride = 8     // classify a few times per second, not every frame
    private let smoothingWindow = 5

    private var frames: [MLMultiArray] = []
    private var recentLabels: [String] = []
    private var framesSincePrediction = 0

    init() {
        if let url = Bundle.main.url(forResource: "SquatFormClassifier", withExtension: "mlmodelc") {
            model = try? MLModel(contentsOf: url)
        } else {
            model = nil
        }
    }

    var isAvailable: Bool { model != nil }

    /// Clears the rolling buffer (e.g. when the person leaves the frame), so a new person
    /// starts from a clean window.
    func reset() {
        frames.removeAll()
        recentLabels.removeAll()
        framesSincePrediction = 0
    }

    /// Adds one pose frame; returns a smoothed prediction a few times per second once the
    /// 60-frame window is full. Call only from the capture queue (not thread-safe).
    func add(observation: VNHumanBodyPoseObservation) -> Prediction? {
        guard let model, let keypoints = try? observation.keypointsMultiArray() else { return nil }

        frames.append(keypoints)
        if frames.count > windowSize {
            frames.removeFirst(frames.count - windowSize)
        }
        guard frames.count == windowSize else { return nil }

        framesSincePrediction += 1
        guard framesSincePrediction >= predictionStride else { return nil }
        framesSincePrediction = 0

        guard let poses = try? MLMultiArray(concatenating: frames, axis: 0, dataType: .float32),
              let provider = try? MLDictionaryFeatureProvider(dictionary: ["poses": MLFeatureValue(multiArray: poses)]),
              let output = try? model.prediction(from: provider),
              let label = output.featureValue(for: "label")?.stringValue else {
            return nil
        }

        let probabilities = output.featureValue(for: "labelProbabilities")?.dictionaryValue
        let confidence = probabilities?[label]?.doubleValue ?? 0

        recentLabels.append(label)
        if recentLabels.count > smoothingWindow {
            recentLabels.removeFirst(recentLabels.count - smoothingWindow)
        }
        let smoothedLabel = recentLabels
            .reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
            .max { $0.value < $1.value }?.key ?? label

        return Prediction(label: smoothedLabel, confidence: confidence)
    }
}
