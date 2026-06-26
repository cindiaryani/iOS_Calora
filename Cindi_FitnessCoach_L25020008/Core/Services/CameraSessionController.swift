import AVFoundation
import CoreVideo
import Foundation

enum CameraPermissionState: Equatable {
    case notDetermined
    case requesting
    case granted
    case denied
    case unavailable
}

enum ExerciseType: String, CaseIterable, Identifiable {
    case squat = "Squat"
    case pushUp = "Push-up"
    case jumpingJack = "Jumping jack"
    case sitUp = "Sit-up"
    case pullUp = "Pull-up"
    case lunge = "Lunge"
    case bicepCurl = "Bicep curl"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .squat:
            return "figure.strengthtraining.traditional"
        case .pushUp:
            return "figure.wave"
        case .jumpingJack:
            return "figure.mixed.cardio"
        case .sitUp:
            return "figure.core.training"
        case .pullUp:
            return "figure.strengthtraining.functional"
        case .lunge:
            return "figure.walk"
        case .bicepCurl:
            return "dumbbell.fill"
        }
    }

    var guidanceText: String {
        switch self {
        case .squat:
            return "Stand tall, hips back, chest up."
        case .pushUp:
            return "Film from the side. Keep your body straight from head to heels."
        case .jumpingJack:
            return "Jump your feet wide and bring your arms overhead each rep."
        case .sitUp:
            return "Lie sideways to the camera and lift through your core, not your neck."
        case .pullUp:
            return "Hang with arms straight, then pull your chin above your hands."
        case .lunge:
            return "Step forward and drop your back knee toward the floor."
        case .bicepCurl:
            return "Pin your elbows at your sides and curl all the way up."
        }
    }
}

@MainActor
final class CameraSessionController: ObservableObject {
    @Published private(set) var permissionState: CameraPermissionState
    @Published private(set) var selectedPosition: AVCaptureDevice.Position = .front
    @Published private(set) var selectedExercise: ExerciseType = .squat
    @Published private(set) var exerciseOptions: [ExerciseType] = ExerciseType.allCases
    @Published private(set) var completedReps: Int = 0
    @Published private(set) var repCountText: String = "0 reps completed"
    @Published private(set) var countdownTimerText: String = "Ready"
    @Published private(set) var exerciseActionMessage: String = "Pick an exercise and step into camera frame."
    @Published private(set) var statusMessage: String
    @Published private(set) var formFeedback: ExerciseFormFeedback = .waiting
    @Published private(set) var poseSkeleton: PoseSkeleton = .empty

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "calora.camera.session")
    private let videoOutputQueue = DispatchQueue(label: "calora.camera.video-output")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let poseAnalyzer = PoseFeedbackAnalyzer()

    init() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionState = .granted
            statusMessage = "Camera ready for exercise feedback."
        case .notDetermined:
            permissionState = .notDetermined
            statusMessage = "Allow camera access to preview exercise form."
        case .denied, .restricted:
            permissionState = .denied
            statusMessage = "Camera permission is off. Enable it in Settings to use form feedback."
        @unknown default:
            permissionState = .unavailable
            statusMessage = "Camera is unavailable on this device."
        }

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(poseAnalyzer, queue: videoOutputQueue)

        poseAnalyzer.onFeedback = { [weak self] feedback in
            self?.formFeedback = feedback
            self?.processFeedback(feedback)
        }

        poseAnalyzer.onPose = { [weak self] skeleton in
            self?.poseSkeleton = skeleton
        }

        let analyzer = poseAnalyzer
        let initialExercise = selectedExercise
        videoOutputQueue.async {
            analyzer.setExercise(initialExercise)
        }
    }

    func selectExercise(_ exercise: ExerciseType) {
        selectedExercise = exercise
        completedReps = 0
        repCountText = "0 reps completed"
        countdownTimerText = "Ready"
        exerciseActionMessage = "Start moving for \(exercise.rawValue)."
        statusMessage = "\(exercise.rawValue) selected. Keep your full body in frame."
        formFeedback = .waiting
        repArmed = false

        let analyzer = poseAnalyzer
        videoOutputQueue.async {
            analyzer.setExercise(exercise)
        }
    }

    func startCountdown(seconds: Int = 5) {
        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            guard let self = self else { return }
            for remaining in stride(from: seconds, through: 1, by: -1) {
                if Task.isCancelled { return }
                await MainActor.run {
                    self.countdownTimerText = "Starting in \(remaining)"
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            await MainActor.run {
                self.countdownTimerText = "Go!"
                self.exerciseActionMessage = "Now perform \(self.selectedExercise.rawValue)."
            }
        }
    }

    private func processFeedback(_ feedback: ExerciseFormFeedback) {
        updateExerciseStatus(with: feedback)
        trackRepetition(from: feedback)
    }

    private func updateExerciseStatus(with feedback: ExerciseFormFeedback) {
        if feedback.isPersonDetected {
            exerciseActionMessage = selectedExercise.guidanceText
        } else {
            exerciseActionMessage = "Position yourself in frame so I can count reps."
        }

        statusMessage = "\(selectedExercise.rawValue) mode — \(completedReps) reps counted"
    }

    /// Counts one rep per full rest → active → rest cycle for the selected exercise,
    /// so a sit-up is never counted while squat is selected (the analyzer only emits
    /// the active state for the currently selected movement).
    private func trackRepetition(from feedback: ExerciseFormFeedback) {
        guard feedback.isPersonDetected else { return }

        switch feedback.repState {
        case .active:
            repArmed = true
        case .rest:
            if repArmed {
                completedReps += 1
                repArmed = false
                repCountText = completedReps == 1 ? "1 rep completed" : "\(completedReps) reps completed"
                statusMessage = "Nice \(selectedExercise.rawValue)! Count: \(completedReps)"
            }
        case .transition, .unknown:
            break
        }
    }

    private var countdownTask: Task<Void, Never>?
    private var repArmed = false

    func requestPermission() async {
        guard AVCaptureDevice.default(for: .video) != nil else {
            permissionState = .unavailable
            statusMessage = "Camera is unavailable on this device."
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionState = .granted
            statusMessage = "Camera ready for exercise feedback."
            configureSession(position: selectedPosition)
            startSession()
        case .notDetermined:
            permissionState = .requesting
            statusMessage = "Requesting camera permission..."

            let granted = await AVCaptureDevice.requestAccess(for: .video)
            permissionState = granted ? .granted : .denied
            statusMessage = granted
                ? "Camera ready for exercise feedback."
                : "Camera permission is off. Enable it in Settings to use form feedback."

            if granted {
                configureSession(position: selectedPosition)
                startSession()
            }
        case .denied, .restricted:
            permissionState = .denied
            statusMessage = "Camera permission is off. Enable it in Settings to use form feedback."
        @unknown default:
            permissionState = .unavailable
            statusMessage = "Camera is unavailable on this device."
        }
    }

    func startSession() {
        guard permissionState == .granted else { return }
        configureSession(position: selectedPosition)

        sessionQueue.async { [session] in
            if !session.isRunning {
                session.startRunning()
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [session] in
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    func switchCamera() {
        selectedPosition = selectedPosition == .front ? .back : .front
        statusMessage = selectedPosition == .front
            ? "Using front camera for self-check form feedback."
            : "Using back camera for assisted coaching feedback."
        formFeedback = .waiting
        poseSkeleton = .empty
        repArmed = false
        configureSession(position: selectedPosition)
    }

    private func configureSession(position: AVCaptureDevice.Position) {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            permissionState = .unavailable
            statusMessage = "Selected camera is unavailable on this device."
            return
        }

        let session = session
        let videoOutput = videoOutput

        sessionQueue.async { [session, input, videoOutput, position] in
            session.beginConfiguration()
            session.sessionPreset = .high

            for currentInput in session.inputs {
                session.removeInput(currentInput)
            }

            if session.canAddInput(input) {
                session.addInput(input)
            }

            if !session.outputs.contains(videoOutput), session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }

            if let connection = videoOutput.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }

                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = position == .front
                }
            }

            session.commitConfiguration()
        }
    }
}
