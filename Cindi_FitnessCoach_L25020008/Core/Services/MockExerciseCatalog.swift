import Foundation

struct MockExerciseCatalog: ExerciseCatalogProviding {
    let warmUp = CatalogExercise(
        name: "Joint Prep Warm-up",
        category: .mobility,
        intensity: .low,
        metValue: 2.5,
        muscleGroup: "Full body",
        instructions: "Move through shoulder circles, hip hinges, knee bends, and light marching.",
        safetyNote: "Keep the pace easy and pain-free."
    )

    let cooldown = CatalogExercise(
        name: "Cooldown Stretch",
        category: .mobility,
        intensity: .low,
        metValue: 2.0,
        muscleGroup: "Full body",
        instructions: "Slow your breathing and hold gentle stretches for hips, calves, chest, and back.",
        safetyNote: "Ease out of any stretch that causes sharp discomfort."
    )

    var exercises: [CatalogExercise] {
        [
            CatalogExercise(name: "Brisk Walk", category: .cardio, intensity: .moderate, metValue: 4.3, muscleGroup: "Lower body", instructions: "Walk at a pace where talking is possible but focused.", safetyNote: "Choose flat ground if balance or fatigue becomes an issue."),
            CatalogExercise(name: "Easy Walk", category: .cardio, intensity: .low, metValue: 3.0, muscleGroup: "Lower body", instructions: "Walk smoothly with relaxed shoulders and an even stride.", safetyNote: "Slow down if breathing becomes uncomfortable."),
            CatalogExercise(name: "Jumping Jacks", category: .cardio, intensity: .high, metValue: 8.0, muscleGroup: "Full body", instructions: "Jump feet wide while raising arms overhead, then return to center.", safetyNote: "Use step jacks if impact feels uncomfortable."),
            CatalogExercise(name: "High Knees", category: .cardio, intensity: .high, metValue: 8.5, muscleGroup: "Core and legs", instructions: "Drive knees up while keeping posture tall and arms active.", safetyNote: "Keep landings quiet and reduce speed if form slips."),
            CatalogExercise(name: "Mountain Climbers", category: .cardio, intensity: .high, metValue: 8.0, muscleGroup: "Core and shoulders", instructions: "Hold a plank and alternate knees toward the chest.", safetyNote: "Keep wrists under shoulders and stop if wrists hurt."),
            CatalogExercise(name: "Step-ups", category: .cardio, intensity: .moderate, metValue: 6.0, muscleGroup: "Glutes and legs", instructions: "Step onto a stable surface, stand tall, and alternate lead legs.", safetyNote: "Use a low, stable step and avoid rushing."),
            CatalogExercise(name: "Bodyweight Squats", category: .strength, intensity: .moderate, metValue: 5.0, muscleGroup: "Quads and glutes", instructions: "Send hips back, bend knees, then stand tall with control.", safetyNote: "Keep knees tracking with toes."),
            CatalogExercise(name: "Push-ups", category: .strength, intensity: .moderate, metValue: 4.0, muscleGroup: "Chest and triceps", instructions: "Lower as one line, then press the floor away.", safetyNote: "Use incline push-ups if the full version strains form."),
            CatalogExercise(name: "Lunges", category: .strength, intensity: .moderate, metValue: 4.5, muscleGroup: "Glutes and legs", instructions: "Step forward, lower under control, then push back to standing.", safetyNote: "Shorten range if knees feel irritated."),
            CatalogExercise(name: "Glute Bridges", category: .strength, intensity: .low, metValue: 3.5, muscleGroup: "Glutes and hamstrings", instructions: "Press through heels and lift hips until knees, hips, and shoulders align.", safetyNote: "Avoid over-arching the lower back."),
            CatalogExercise(name: "Plank Hold", category: .strength, intensity: .moderate, metValue: 3.8, muscleGroup: "Core", instructions: "Brace from shoulders to heels and breathe steadily.", safetyNote: "Drop knees if your lower back sags."),
            CatalogExercise(name: "Bicep Curls", category: .strength, intensity: .low, metValue: 3.0, muscleGroup: "Arms", equipment: "Dumbbells", instructions: "Keep elbows tucked and curl with control.", safetyNote: "Use a load you can lower slowly."),
            CatalogExercise(name: "Bent-over Rows", category: .strength, intensity: .moderate, metValue: 4.0, muscleGroup: "Back", equipment: "Dumbbells", instructions: "Hinge at hips and pull elbows toward ribs.", safetyNote: "Keep spine long and reduce load if your back rounds."),
            CatalogExercise(name: "Pull-ups", category: .strength, intensity: .high, metValue: 8.0, muscleGroup: "Back and arms", equipment: "Pull-up bar", instructions: "Start from a hang and pull chin toward the bar.", safetyNote: "Use assistance if reps become uncontrolled."),
            CatalogExercise(name: "Burpees", category: .cardio, intensity: .high, metValue: 10.0, muscleGroup: "Full body", instructions: "Squat, step or jump to plank, return to standing, and reach tall.", safetyNote: "Step the feet instead of jumping if impact is too high."),
            CatalogExercise(name: "Yoga Flow", category: .mobility, intensity: .low, metValue: 2.8, muscleGroup: "Full body", instructions: "Move slowly through lunges, folds, and gentle rotations.", safetyNote: "Keep each shape comfortable and controlled."),
            CatalogExercise(name: "Hip Mobility Flow", category: .mobility, intensity: .low, metValue: 2.5, muscleGroup: "Hips", instructions: "Alternate hip circles, 90/90 switches, and gentle lunges.", safetyNote: "Stay within a smooth range of motion."),
            CatalogExercise(name: "Thoracic Rotations", category: .mobility, intensity: .low, metValue: 2.0, muscleGroup: "Upper back", instructions: "Rotate slowly through the upper back while hips stay steady.", safetyNote: "Avoid forcing the neck."),
            CatalogExercise(name: "Calf and Hamstring Reset", category: .mobility, intensity: .low, metValue: 2.3, muscleGroup: "Posterior chain", instructions: "Alternate calf raises, hamstring sweeps, and gentle holds.", safetyNote: "Keep stretches mild and breathable."),
            CatalogExercise(name: "Shadow Boxing", category: .cardio, intensity: .moderate, metValue: 6.0, muscleGroup: "Full body", instructions: "Punch lightly in combinations while moving your feet.", safetyNote: "Keep shoulders relaxed and avoid locking elbows."),
            CatalogExercise(name: "Wall Sit", category: .strength, intensity: .moderate, metValue: 3.8, muscleGroup: "Quads", instructions: "Hold a seated position against a wall and breathe steadily.", safetyNote: "Stand up if your knees feel uncomfortable.")
        ]
    }
}
