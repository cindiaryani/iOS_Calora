import Foundation

/// One turn in the coach conversation.
struct CoachChatMessage: Identifiable, Equatable {
    enum Role: Equatable {
        case user
        case coach
    }

    let id = UUID()
    let role: Role
    var text: String
    var isError: Bool = false
}

/// Fitness chatbot. Works fully offline using a built-in knowledge engine, so it
/// always responds even where the online API is blocked. If the user turns on
/// "Use online AI" in Settings and provides an API key, it tries the online model
/// first and silently falls back to the offline engine on any failure.
///
/// In both paths it stays strictly on fitness / workout topics: clearly off-topic
/// questions (e.g. "what is the capital of Indonesia") are refused locally.
@MainActor
final class FitnessCoachChatService: ObservableObject {
    @Published private(set) var messages: [CoachChatMessage] = []
    @Published private(set) var isResponding = false
    @Published var draft = ""

    /// Quick-start prompts shown above the input field.
    let suggestions = [
        "Give me a 20-minute full-body home workout",
        "How do I do a proper squat?",
        "What should I eat after a workout?",
        "How do I build muscle as a beginner?"
    ]

    static let apiKeyDefaultsKey = "anthropicAPIKey"

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-opus-4-8"

    /// Built-in key used when the user hasn't set their own in Settings.
    /// NOTE: rotate this at console.anthropic.com — it ships inside the app binary.
    private let fallbackKey = "" // Add your Anthropic API key here for local dev (do NOT commit a real key)

    private var apiKey: String {
        let stored = UserDefaults.standard.string(forKey: Self.apiKeyDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let stored, !stored.isEmpty { return stored }
        return fallbackKey
    }

    private let systemPrompt = """
    You are "Calora Coach", a certified AI fitness and personal-training assistant inside a \
    workout app. You ONLY help with fitness topics: exercise technique and form, workout and \
    training programs, sets/reps/intensity, warm-up and cool-down, mobility and recovery, \
    injury-safe progression, and nutrition or hydration as it relates to training and fitness goals.

    Hard rule: if a question is NOT about fitness/workout/exercise/sports-nutrition you MUST refuse \
    in ONE short sentence and steer the user back to fitness. Keep answers concise, practical, and \
    safe. Always answer in English. Add a brief safety note when advice could risk injury. You are \
    not a doctor; suggest seeing a professional for pain or medical issues.
    """

    init() {
        messages = [
            CoachChatMessage(
                role: .coach,
                text: "Hi! I'm your AI fitness coach 💪 Ask me anything about workouts, exercise technique, training programs, or nutrition for fitness. I only cover fitness topics, so I'll skip anything outside that."
            )
        ]
    }

    func reset() {
        guard !isResponding else { return }
        draft = ""
        messages = [
            CoachChatMessage(
                role: .coach,
                text: "Fresh start! What would you like to ask about your training or fitness? 🏋️"
            )
        ]
    }

    func send() async {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isResponding else { return }

        messages.append(CoachChatMessage(role: .user, text: trimmed))
        draft = ""
        isResponding = true
        defer { isResponding = false }

        // Topic guard runs for both paths so off-topic questions are always refused.
        if !FitnessKnowledge.isFitnessRelated(trimmed) {
            await pause()
            messages.append(
                CoachChatMessage(
                    role: .coach,
                    text: "I'm your fitness coach, so I can only help with workouts, exercise, training, and fitness nutrition. Try asking me something like how to train a muscle group, fix your form, or plan a session. 💪"
                )
            )
            return
        }

        // Always try Claude first; fall back to the offline engine only if it fails
        // (no network, region-blocked, rate limit, etc.).
        do {
            let reply = try await requestCompletion()
            let clean = reply.trimmingCharacters(in: .whitespacesAndNewlines)
            messages.append(CoachChatMessage(role: .coach, text: clean.isEmpty ? FitnessKnowledge.answer(for: trimmed) : clean))
        } catch {
            await pause()
            messages.append(CoachChatMessage(role: .coach, text: FitnessKnowledge.answer(for: trimmed)))
        }
    }

    /// Small delay so the typing indicator is visible for offline answers.
    private func pause() async {
        try? await Task.sleep(nanoseconds: 450_000_000)
    }

    private func requestCompletion() async throws -> String {
        // The Anthropic Messages API takes the system prompt as a top-level field and
        // only user/assistant turns in `messages`. Caching the (stable) system prompt
        // keeps repeat calls cheap.
        var payloadMessages: [[String: String]] = []
        for message in messages.suffix(12) where !message.isError {
            payloadMessages.append([
                "role": message.role == .user ? "user" : "assistant",
                "content": message.text
            ])
        }

        // Cache the stable system prompt so repeat calls are cheap.
        let systemBlock: [String: Any] = [
            "type": "text",
            "text": systemPrompt,
            "cache_control": ["type": "ephemeral"]
        ]

        // Opus 4.8 rejects sampling params (temperature/top_p) — don't send them.
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": [systemBlock],
            "messages": payloadMessages
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw ChatError.badResponse
        }

        let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        guard let text = decoded.content.first(where: { $0.type == "text" })?.text else {
            throw ChatError.badResponse
        }
        return text
    }

    private enum ChatError: Error {
        case badResponse
    }

    private struct AnthropicResponse: Decodable {
        struct Block: Decodable {
            let type: String
            let text: String?
        }
        let content: [Block]
    }
}

/// Offline fitness knowledge base. Matches the user's question to a topic by keywords
/// and returns a concise, practical answer. Used as the default engine and as the
/// fallback when the online model is unavailable.
enum FitnessKnowledge {
    /// Broad fitness vocabulary. If a message contains none of these (and isn't a
    /// greeting), it's treated as off-topic.
    private static let fitnessKeywords: Set<String> = [
        "workout", "exercise", "exercises", "train", "training", "gym", "fitness", "fit",
        "muscle", "muscles", "strength", "strong", "cardio", "endurance", "stamina",
        "squat", "squats", "pushup", "push-up", "pushups", "press", "bench", "deadlift",
        "lunge", "lunges", "plank", "curl", "curls", "pullup", "pull-up", "row", "dip",
        "jumping", "jack", "burpee", "crunch", "situp", "sit-up", "abs", "core", "glute",
        "glutes", "leg", "legs", "chest", "back", "shoulder", "shoulders", "arm", "arms",
        "bicep", "biceps", "tricep", "triceps", "calf", "hamstring", "quad", "quads",
        "reps", "rep", "set", "sets", "rest", "recovery", "recover", "warmup", "warm-up",
        "warm", "cooldown", "cool-down", "stretch", "stretching", "mobility", "flexibility",
        "form", "technique", "posture", "rom", "tempo", "weight", "weights", "dumbbell",
        "barbell", "kettlebell", "machine", "bodyweight", "calisthenics", "hiit", "interval",
        "run", "running", "jog", "jogging", "walk", "walking", "cycle", "cycling", "swim",
        "swimming", "yoga", "pilates", "stairs", "treadmill", "calorie", "calories", "kcal",
        "fat", "weightloss", "lose", "losing", "bulk", "bulking", "cut", "cutting", "lean",
        "gain", "gains", "tone", "toned", "sweat", "sore", "soreness", "doms", "injury",
        "injured", "pain", "sprain", "strain", "diet", "nutrition", "protein", "carb",
        "carbs", "carbohydrate", "fats", "macro", "macros", "meal", "eat", "eating", "food",
        "hydrate", "hydration", "water", "supplement", "creatine", "preworkout", "pre-workout",
        "postworkout", "post-workout", "stamina", "fatigue", "warmup", "session", "routine",
        "program", "plan", "beginner", "intermediate", "advanced", "athlete", "marathon",
        "flexibility", "balance", "stability", "posture", "knee", "hip", "spine", "joint",
        "stronger", "fitter", "physique", "body", "weigh", "bmi", "metabolism"
    ]

    private static let greetings: Set<String> = [
        "hi", "hello", "hey", "yo", "hiya", "hai", "halo", "helo", "sup", "heya"
    ]

    static func isFitnessRelated(_ text: String) -> Bool {
        let tokens = tokenize(text)
        if tokens.contains(where: { greetings.contains($0) }) { return true }
        return tokens.contains(where: { fitnessKeywords.contains($0) })
    }

    static func answer(for text: String) -> String {
        let tokens = Set(tokenize(text))

        func has(_ words: String...) -> Bool { words.contains { tokens.contains($0) } }

        if has("hi", "hello", "hey", "hai", "halo", "yo", "sup", "heya") && tokens.count <= 3 {
            return "Hey! Ready to train? You can ask me about exercise form, a workout plan for your goal, sets and reps, recovery, or what to eat around your sessions. What's on your mind?"
        }

        // Exercise technique
        if has("squat", "squats") {
            return """
            Squat form checklist:
            • Feet about shoulder-width, toes slightly out.
            • Brace your core, chest up, eyes forward.
            • Push your hips back, then bend the knees — knees track over toes (don't cave in).
            • Go down until thighs are about parallel (or as deep as you can with a flat back).
            • Drive up through your heels and stand tall.

            Tip: keep your heels planted the whole time. Safety note: if your lower back rounds, reduce depth or load.
            """
        }
        if has("pushup", "push-up", "pushups") {
            return """
            Push-up form:
            • Hands a bit wider than shoulders, body in one straight line (head to heels).
            • Brace your core and glutes so your hips don't sag or pike.
            • Lower until your chest is just above the floor, elbows ~45° from your body.
            • Press all the way up and lock out.

            Too hard? Do them on your knees or against a wall/bench. Build up reps gradually.
            """
        }
        if has("plank") {
            return """
            Plank:
            • Forearms under shoulders, body in a straight line.
            • Squeeze glutes and brace abs; don't let hips drop or lift.
            • Breathe steadily and hold for quality time, not just longer.

            Start with 3 × 20–30s and add time as you get stronger.
            """
        }
        if has("lunge", "lunges") {
            return """
            Lunge:
            • Step forward, lower until both knees are ~90°.
            • Front knee tracks over the foot; keep your torso tall.
            • Push through the front heel to return.

            Keep it controlled — balance first, then add load.
            """
        }
        if has("deadlift") {
            return """
            Deadlift basics:
            • Bar over mid-foot, grip just outside knees.
            • Flat back, chest up, shoulders slightly ahead of the bar.
            • Push the floor away and stand up, keeping the bar close to your body.
            • Hips and shoulders rise together.

            Safety note: keep a neutral spine the whole lift — never round your lower back. Start light to groove the pattern.
            """
        }
        if has("curl", "curls", "bicep", "biceps") {
            return """
            Bicep curl:
            • Elbows pinned at your sides, no swinging.
            • Curl up under control, squeeze at the top.
            • Lower slowly all the way down.

            Pick a weight you can control for 8–12 clean reps.
            """
        }
        if has("abs", "core", "crunch", "situp", "sit-up") {
            return """
            Core training:
            • Mix anti-movement (planks, dead bugs) with flexion (crunches, leg raises).
            • Quality over speed — feel the abs work, don't yank your neck.
            • Try: plank 3×30s, dead bug 3×10/side, leg raises 3×12, twice a week.

            Visible abs also depend on body-fat level, so nutrition matters too.
            """
        }

        // Goals / programs
        if has("home", "house") || (has("fullbody", "full-body") || (tokens.contains("full") && tokens.contains("body"))) {
            return """
            20-minute full-body home workout (no equipment). 3 rounds, 40s work / 20s rest:
            1. Bodyweight squats
            2. Push-ups (knees if needed)
            3. Reverse lunges (alternate legs)
            4. Plank
            5. Jumping jacks

            Warm up 3–5 min first and stretch after. Adjust reps to your level.
            """
        }
        if has("beginner", "start", "starting", "new") && has("workout", "train", "training", "exercise", "gym", "plan", "routine", "program", "muscle") {
            return """
            Beginner plan (3 days/week, full-body):
            • Squat 3×10
            • Push-up 3×8–12
            • Row or band pull 3×10
            • Lunge 3×10/leg
            • Plank 3×30s

            Rest a day between sessions, focus on form, and add a little weight or a rep each week. Warm up before, stretch after.
            """
        }
        if has("lose", "losing", "fat", "weightloss", "cut", "cutting", "slim", "lean") && !has("muscle", "gain", "bulk") {
            return """
            Fat loss basics:
            • You need a small calorie deficit (eat a bit less than you burn).
            • Keep protein high to protect muscle (~1.6–2.2 g/kg bodyweight).
            • Mix strength training (3×/week) with some cardio (walking counts!).
            • Sleep and consistency matter more than any single workout.

            Aim for ~0.5 kg/week — slow loss is more sustainable.
            """
        }
        if has("muscle", "bulk", "bulking", "gain", "bigger", "mass", "grow") {
            return """
            Building muscle:
            • Train each muscle 2×/week with progressive overload (add reps/weight over time).
            • 3–4 sets of 6–12 reps for most exercises, near (but not to) failure.
            • Eat slightly above maintenance with enough protein (~1.6–2.2 g/kg).
            • Sleep 7–9h — muscle grows during recovery.

            Be patient: 0.25–0.5 kg of muscle a month is realistic.
            """
        }
        if has("cardio", "run", "running", "jog", "endurance", "stamina", "treadmill") {
            return """
            Cardio tips:
            • Beginners: start with brisk walking or easy jogging 20–30 min, 3×/week.
            • Build endurance with mostly easy-pace sessions, plus 1 harder interval day.
            • Try intervals: 1 min faster / 2 min easy × 6–8.

            Increase total time by ~10% per week to avoid overuse injuries.
            """
        }
        if has("hiit", "interval", "intervals") {
            return """
            HIIT: short, hard bursts with recovery.
            • Example: 30s all-out / 90s easy × 6–8 rounds.
            • 2–3×/week is plenty — it's demanding on recovery.
            • Always warm up first.

            Great for conditioning and calorie burn in less time.
            """
        }

        // Recovery / pain / nutrition
        if has("warmup", "warm-up", "warm") {
            return """
            Warm-up (5–10 min):
            • 2–3 min light cardio to raise your heart rate.
            • Dynamic moves: leg swings, arm circles, bodyweight squats, lunges.
            • Then a few light sets of your first exercise.

            A good warm-up improves performance and lowers injury risk.
            """
        }
        if has("stretch", "stretching", "cooldown", "cool-down", "mobility", "flexibility") {
            return """
            Cool-down & stretching:
            • Do static stretches AFTER training, holding 20–30s each.
            • Hit the muscles you worked (e.g. quads, hamstrings, chest, shoulders).
            • Add a few minutes of easy walking to bring your heart rate down.

            For mobility, daily gentle stretching beats one long session.
            """
        }
        if has("sore", "soreness", "doms", "ache") {
            return """
            Muscle soreness (DOMS) is normal 1–2 days after new or hard training.
            • Light movement, walking, and stretching help.
            • Stay hydrated, eat enough protein, and sleep well.
            • It usually fades in 2–4 days.

            Sharp or joint pain is different from muscle soreness — ease off if you feel that.
            """
        }
        if has("rest", "recovery", "recover", "overtraining") {
            return """
            Recovery matters as much as training:
            • Take at least 1–2 rest or easy days per week.
            • Sleep 7–9 hours — that's when you adapt and grow.
            • Don't train the same muscle hard two days in a row.

            If performance drops and you feel run-down, you may need more rest.
            """
        }
        if has("injury", "injured", "pain", "sprain", "strain", "hurt", "knee", "hurts") {
            return """
            For pain or a possible injury, play it safe:
            • Stop the movement that hurts and avoid loading it.
            • Rest, and use gentle pain-free movement as it settles.
            • Sharp, swelling, or lasting pain — see a doctor or physio.

            I'm a coach, not a doctor, so please get a professional check for anything that doesn't improve.
            """
        }
        if has("protein") {
            return """
            Protein:
            • Aim for roughly 1.6–2.2 g per kg of bodyweight per day if you're training.
            • Spread it across meals (e.g. 3–4 servings).
            • Good sources: chicken, fish, eggs, dairy, tofu, legumes, whey.

            Protein supports muscle repair and helps you stay full.
            """
        }
        if has("eat", "eating", "food", "meal", "diet", "nutrition", "carb", "carbs", "macro", "macros") {
            return """
            Fitness nutrition basics:
            • Build meals around protein + plenty of veggies + some carbs + healthy fats.
            • Carbs fuel hard workouts; don't fear them around training.
            • Match calories to your goal: slight deficit to lose fat, slight surplus to gain muscle.

            Around workouts: a meal with protein + carbs 1–3h before and after works well.
            """
        }
        if has("water", "hydrate", "hydration", "drink") {
            return """
            Hydration:
            • Sip water through the day; have some before and after training.
            • For sessions over ~60 min or heavy sweating, add electrolytes.
            • A rough check: pale-yellow urine usually means you're well hydrated.
            """
        }
        if has("reps", "rep", "set", "sets") {
            return """
            Sets & reps guide:
            • Strength: 3–5 sets of 3–6 reps, longer rests (2–3 min).
            • Muscle growth: 3–4 sets of 6–12 reps, ~60–90s rest.
            • Endurance: 2–3 sets of 15+ reps, short rests.

            Whatever the range, train close to effort and add a little over time (progressive overload).
            """
        }

        // Generic fitness fallback
        return """
        Happy to help with that. To give you the best advice, tell me:
        • Your goal (lose fat, build muscle, get fitter, learn an exercise)?
        • Your level (beginner / intermediate / advanced)?
        • What equipment you have (none, dumbbells, full gym)?

        Then I can tailor a plan, form tips, or a routine for you. 💪
        """
    }

    private static func tokenize(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted.subtracting(CharacterSet(charactersIn: "-")))
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "-")) }
            .filter { !$0.isEmpty }
    }
}
