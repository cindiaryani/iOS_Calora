import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A guided, live workout session that steps through every exercise block with a
/// countdown timer and short rests between blocks. Each block shows an animated
/// demo of the movement and, for movements the camera can track, a "Form check"
/// button that opens the live pose camera. The workout can only be marked complete
/// after the session actually runs (or the user finishes it on purpose).
struct WorkoutSessionView: View {
    let plan: WorkoutPlan
    /// When resuming from "Continue training", the block to restart at and the elapsed
    /// time carried over; both default to a fresh start.
    var resumeBlockIndex: Int = 0
    var resumeElapsedSeconds: Int = 0
    /// Called once when the session is finished and should be saved to history.
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("restSeconds") private var restSeconds = 20
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    @State private var phase: Phase = .countdown
    @State private var blockIndex = 0
    @State private var secondsRemaining = 3
    @State private var isPaused = false
    @State private var elapsedSeconds = 0
    @State private var showQuitConfirm = false
    @State private var didSave = false
    @State private var showFormCheck = false
    @State private var didConfigure = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let accent = Color.appPrimary

    private enum Phase: Equatable {
        case countdown      // "Get ready" 3-2-1 before the first block
        case exercise
        case rest
        case finished
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if phase == .finished {
                VStack(spacing: 24) {
                    finishedView
                }
                .padding(20)
            } else {
                VStack(spacing: 0) {
                    demoArea
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    controlPanel
                }
            }
        }
        .onAppear { configureIfNeeded() }
        .onReceive(timer) { _ in tick() }
        .confirmationDialog("Leave this workout?", isPresented: $showQuitConfirm, titleVisibility: .visible) {
            Button("Finish & save") { finish(save: true) }
            Button("Save & continue later") { saveProgressAndExit() }
            Button("Discard", role: .destructive) { discardAndExit() }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("You've trained \(formatted(elapsedSeconds)) so far.")
        }
        .fullScreenCover(isPresented: $showFormCheck) {
            ExerciseFeedbackView(initialExercise: currentDemo.trackable)
        }
    }

    // MARK: - Demo area (top)

    private var demoArea: some View {
        ZStack {
            LinearGradient(
                colors: [Color.appSurfaceMuted, Color.appSurface],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)

            // Soft glow behind the figure.
            Circle()
                .fill(accent.opacity(0.18))
                .frame(width: 240, height: 240)
                .blur(radius: 60)

            ExerciseDemoView(symbol: currentDemo.symbol, isAnimating: phase == .exercise && !isPaused)
        }
        .overlay(alignment: .topLeading) { closeButton }
        .overlay(alignment: .topTrailing) { nextExercisePreview }
        .overlay(alignment: .bottom) { demoCaption }
        .clipped()
    }

    private var closeButton: some View {
        Button {
            showQuitConfirm = true
        } label: {
            Image(systemName: "arrow.left")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.appTextPrimary)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
                .overlay { Circle().stroke(Color.appBorder, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var nextExercisePreview: some View {
        if let next = previewBlock {
            let demo = ExerciseDemo.forBlock(next.name)
            VStack(alignment: .trailing, spacing: 6) {
                Image(systemName: demo.symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.appTextPrimary)
                    .frame(width: 54, height: 54)
                    .background(Color.appSurfaceMuted, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 1) }

                Label("Next exercise", systemImage: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(Color.appTextSecondary)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
        }
    }

    private var demoCaption: some View {
        VStack(spacing: 10) {
            Text(phaseLabel)
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(phaseColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(phaseColor.opacity(0.16), in: Capsule())

            Text(headlineText)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.appTextPrimary)

            if phase == .exercise, let block = currentBlock {
                Text(block.muscleGroup)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)

                if currentDemo.trackable != nil {
                    Button {
                        showFormCheck = true
                    } label: {
                        Label("Form check", systemImage: "camera.viewfinder")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.appOnPrimary)
                            .padding(.horizontal, 16)
                            .frame(height: 42)
                            .background(accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            } else if phase == .rest {
                Text("Catch your breath, then keep going.")
                    .font(.subheadline)
                    .foregroundStyle(Color.appTextSecondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 18)
    }

    // MARK: - Control panel (bottom)

    private var controlPanel: some View {
        VStack(spacing: 18) {
            Text(timeText)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.appTextPrimary)
                .contentTransition(.numericText())

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(completedPercent)%")
                        .font(.headline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Color.appTextPrimary)
                    Text("Completed")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.appTextSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatted(totalPlannedSeconds))
                        .font(.headline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Color.appTextPrimary)
                    Text("Total Time")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.appTextSecondary)
                }
            }

            ProgressView(value: overallProgress)
                .tint(accent)

            blockProgress

            controls
        }
        .padding(20)
        .padding(.bottom, 8)
        .background(
            Color.appSurface,
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.appBorder, lineWidth: 1)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    private var blockProgress: some View {
        HStack(spacing: 6) {
            ForEach(plan.exercises.indices, id: \.self) { index in
                Capsule()
                    .fill(index < blockIndex ? accent : (index == blockIndex && phase != .countdown ? accent.opacity(0.5) : Color.appBorder))
                    .frame(height: 6)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 28) {
            secondaryControl("backward.fill", label: "Prev") { previous() }
                .disabled(phase == .countdown)
                .opacity(phase == .countdown ? 0.4 : 1)

            Button {
                isPaused.toggle()
            } label: {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.appOnPrimary)
                    .frame(width: 72, height: 72)
                    .background(accent, in: Circle())
                    .shadow(color: accent.opacity(0.4), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(phase == .countdown)
            .opacity(phase == .countdown ? 0.4 : 1)

            secondaryControl("forward.fill", label: phase == .rest ? "Skip" : "Next") { advance() }
                .disabled(phase == .countdown)
                .opacity(phase == .countdown ? 0.4 : 1)
        }
    }

    private func secondaryControl(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.appTextPrimary)
                    .frame(width: 52, height: 52)
                    .background(Color.appSurfaceMuted, in: Circle())
                    .overlay { Circle().stroke(Color.appBorder, lineWidth: 1) }

                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.appTextSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Finished

    private var finishedView: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 12)

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(accent)

            Text("Workout complete!")
                .font(.title.weight(.bold))
                .foregroundStyle(Color.appTextPrimary)

            Text("Nice work finishing \(plan.title).")
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)

            HStack(spacing: 12) {
                summaryStat("clock", formatted(elapsedSeconds), "time")
                summaryStat("flame", "\(plan.estimatedCalories)", "kcal")
                summaryStat("list.bullet", "\(plan.exercises.count)", "blocks")
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.appOnPrimary)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            if !didSave {
                didSave = true
                onComplete()
            }
        }
    }

    private func summaryStat(_ image: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: image)
                .font(.headline)
                .foregroundStyle(accent)
            Text(value)
                .font(.headline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color.appTextPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 1)
        }
    }

    // MARK: - Timer logic

    private func tick() {
        guard !isPaused, phase != .finished else { return }

        if phase != .countdown {
            elapsedSeconds += 1
        }

        if secondsRemaining > 1 {
            secondsRemaining -= 1
        } else {
            advance()
        }
    }

    /// Moves to the next stage: countdown → exercise → rest → next exercise → … → finished.
    private func advance() {
        haptic()
        switch phase {
        case .countdown:
            startBlock(0)
        case .exercise:
            if blockIndex + 1 < plan.exercises.count {
                if restSeconds > 0 {
                    phase = .rest
                    secondsRemaining = restSeconds
                    blockIndex += 1            // point to the upcoming block during rest
                } else {
                    startBlock(blockIndex + 1)
                }
            } else {
                finish(save: true)
            }
        case .rest:
            startBlock(blockIndex)             // blockIndex already advanced
        case .finished:
            break
        }
    }

    /// Goes back to the previous block (or restarts the first one).
    private func previous() {
        haptic()
        startBlock(max(blockIndex - 1, 0))
    }

    private func startBlock(_ index: Int) {
        guard index < plan.exercises.count else {
            finish(save: true)
            return
        }
        blockIndex = index
        phase = .exercise
        secondsRemaining = max(plan.exercises[index].durationMinutes, 1) * 60
    }

    private func finish(save: Bool) {
        phase = .finished
        isPaused = false
        // A finished workout no longer belongs in the "Continue training" list.
        WorkoutProgressStore.shared.remove(title: plan.title)
        if save, !didSave {
            didSave = true
            onComplete()
        }
    }

    /// Resumes from a saved block when launched from "Continue training".
    private func configureIfNeeded() {
        guard !didConfigure else { return }
        didConfigure = true
        guard resumeBlockIndex > 0 || resumeElapsedSeconds > 0,
              !plan.exercises.isEmpty else { return }
        elapsedSeconds = resumeElapsedSeconds
        startBlock(min(resumeBlockIndex, plan.exercises.count - 1))
    }

    /// Saves current progress so the workout can be picked up later, then closes.
    private func saveProgressAndExit() {
        if phase != .finished {
            WorkoutProgressStore.shared.saveProgress(
                plan: plan,
                blockIndex: blockIndex,
                elapsedSeconds: elapsedSeconds,
                totalSeconds: totalPlannedSeconds
            )
        }
        dismiss()
    }

    private func discardAndExit() {
        WorkoutProgressStore.shared.remove(title: plan.title)
        dismiss()
    }

    private func haptic() {
        #if canImport(UIKit)
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    // MARK: - Derived UI values

    private var currentBlock: ExerciseBlock? {
        guard blockIndex < plan.exercises.count else { return nil }
        return plan.exercises[blockIndex]
    }

    /// The block shown in the top-right "Next exercise" preview.
    private var previewBlock: ExerciseBlock? {
        let idx = blockIndex + 1
        guard idx < plan.exercises.count else { return nil }
        return plan.exercises[idx]
    }

    private var currentDemo: ExerciseDemo {
        ExerciseDemo.forBlock(currentBlock?.name ?? "")
    }

    private var totalPlannedSeconds: Int {
        let work = plan.exercises.reduce(0) { $0 + max($1.durationMinutes, 1) * 60 }
        let rests = max(plan.exercises.count - 1, 0) * max(restSeconds, 0)
        return max(work + rests, 1)
    }

    private var overallProgress: Double {
        min(Double(elapsedSeconds) / Double(totalPlannedSeconds), 1)
    }

    private var completedPercent: Int {
        Int((overallProgress * 100).rounded())
    }

    private var phaseLabel: String {
        switch phase {
        case .countdown: return "Get ready"
        case .exercise: return "Block \(blockIndex + 1) of \(plan.exercises.count)"
        case .rest: return "Rest"
        case .finished: return "Done"
        }
    }

    private var phaseColor: Color {
        switch phase {
        case .rest: return Color.appSecondary
        case .countdown: return Color.appTextSecondary
        default: return accent
        }
    }

    private var headlineText: String {
        switch phase {
        case .countdown: return "Get into position"
        case .exercise: return currentBlock?.name ?? "Exercise"
        case .rest: return "Up next: \(currentBlock?.name ?? "Finish")"
        case .finished: return ""
        }
    }

    private var timeText: String {
        phase == .countdown ? "\(secondsRemaining)" : formatted(secondsRemaining)
    }

    private func formatted(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

// MARK: - Exercise demo

/// Maps a workout block to an animated demo glyph and, when the movement can be
/// tracked by the pose camera, the matching `ExerciseType` for the live form check.
struct ExerciseDemo {
    let symbol: String
    let trackable: ExerciseType?

    static func forBlock(_ name: String) -> ExerciseDemo {
        let n = name.lowercased()
        switch true {
        case n.contains("squat"):
            return ExerciseDemo(symbol: "figure.strengthtraining.traditional", trackable: .squat)
        case n.contains("push"):
            return ExerciseDemo(symbol: "figure.strengthtraining.functional", trackable: .pushUp)
        case n.contains("lunge"):
            return ExerciseDemo(symbol: "figure.walk", trackable: .lunge)
        case n.contains("jumping") || n.contains("jack"):
            return ExerciseDemo(symbol: "figure.mixed.cardio", trackable: .jumpingJack)
        case n.contains("pull"):
            return ExerciseDemo(symbol: "figure.strengthtraining.functional", trackable: .pullUp)
        case n.contains("curl") || n.contains("bicep"):
            return ExerciseDemo(symbol: "dumbbell.fill", trackable: .bicepCurl)
        case n.contains("sit-up") || n.contains("situp") || n.contains("crunch") || n.contains("core"):
            return ExerciseDemo(symbol: "figure.core.training", trackable: .sitUp)
        case n.contains("plank"):
            return ExerciseDemo(symbol: "figure.core.training", trackable: nil)
        case n.contains("run") || n.contains("knee") || n.contains("burpee") || n.contains("mountain"):
            return ExerciseDemo(symbol: "figure.run", trackable: nil)
        case n.contains("walk") || n.contains("step"):
            return ExerciseDemo(symbol: "figure.walk", trackable: nil)
        case n.contains("bridge") || n.contains("glute") || n.contains("flex"):
            return ExerciseDemo(symbol: "figure.flexibility", trackable: nil)
        case n.contains("yoga") || n.contains("stretch") || n.contains("mobility") || n.contains("cool") || n.contains("warm") || n.contains("rotation"):
            return ExerciseDemo(symbol: "figure.cooldown", trackable: nil)
        case n.contains("row"):
            return ExerciseDemo(symbol: "figure.rower", trackable: nil)
        case n.contains("box") || n.contains("punch") || n.contains("shadow"):
            return ExerciseDemo(symbol: "figure.boxing", trackable: nil)
        default:
            return ExerciseDemo(symbol: "figure.strengthtraining.traditional", trackable: nil)
        }
    }
}

/// A lightweight animated stand-in for an exercise demo clip: the movement glyph
/// gently pulses and bobs while the block is active. Real GIF/video clips can be
/// dropped in later without changing the player layout.
private struct ExerciseDemoView: View {
    let symbol: String
    let isAnimating: Bool

    @State private var animate = false

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 132, weight: .regular))
            .foregroundStyle(Color.appPrimary)
            .symbolRenderingMode(.hierarchical)
            .scaleEffect(animate ? 1.06 : 0.94)
            .offset(y: animate ? -8 : 8)
            .animation(
                isAnimating
                    ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true)
                    : .easeInOut(duration: 0.3),
                value: animate
            )
            .onAppear { animate = isAnimating }
            .onChange(of: isAnimating) { animate = $0 }
            .onChange(of: symbol) { _ in
                // Re-seed the bob so a new block starts from the rest pose.
                animate = false
                if isAnimating {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { animate = true }
                }
            }
    }
}
