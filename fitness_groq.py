import os
from crewai import Agent, Task, Crew, Process, LLM

# ── 1. LLM SETUP ────────────────────────────────────────────
GROQ_API_KEY = os.getenv("GROQ_API_KEY", "")  # set via env var, do NOT hardcode

llm = LLM(
    model="groq/llama-3.3-70b-versatile",
    api_key=GROQ_API_KEY,
    temperature=0.7,
)

# ── 2. AGENTS ────────────────────────────────────────────────

fitness_researcher = Agent(
    role="Senior Fitness Research Analyst",
    goal="Research the latest scientific trends in fitness, exercise, and physical health",
    backstory=(
        "You are an experienced fitness research expert with a background in "
        "sports science and physiology. You always rely on scientific data, "
        "recent studies, and valid facts about physical training and health."
    ),
    llm=llm,
    verbose=True,
    allow_delegation=False,
)

personal_trainer = Agent(
    role="Expert Personal Trainer & Content Writer",
    goal="Create practical, safe, and easy-to-follow workout programs and fitness content",
    backstory=(
        "You are a certified personal trainer with 10 years of experience "
        "training clients ranging from beginners to athletes. You specialize in "
        "designing effective, enjoyable, and condition-appropriate training programs."
    ),
    llm=llm,
    verbose=True,
    allow_delegation=False,
)

nutrition_reviewer = Agent(
    role="Nutrition & Safety Reviewer",
    goal="Ensure all fitness content is safe, accurate, and supported by proper nutritional guidance",
    backstory=(
        "You are a nutritionist and sports medicine expert responsible for reviewing "
        "every fitness program. You ensure no advice is harmful, add supporting "
        "nutritional guidelines, and provide safety notes for users with special conditions."
    ),
    llm=llm,
    verbose=True,
    allow_delegation=False,
)

# ── 3. TASKS ─────────────────────────────────────────────────

FITNESS_GOAL = "lose weight and build muscle for beginners"

research_task = Task(
    description=(
        f"Conduct in-depth research on a fitness program for the goal: '{FITNESS_GOAL}'. "
        "Cover: (1) the most scientifically effective types of exercise, "
        "(2) ideal weekly frequency and duration, "
        "(3) common mistakes beginners must avoid, "
        "(4) latest training method trends (HIIT, strength training, etc.)."
    ),
    expected_output=(
        "A structured research document containing: science-based exercise recommendations, "
        "optimal frequency & duration data, list of common mistakes, and a summary of current methods. "
        "Minimum 300 words, bullet-point format."
    ),
    agent=fitness_researcher,
)

workout_task = Task(
    description=(
        f"Based on the research results, create a complete 4-week workout program "
        f"for the goal: '{FITNESS_GOAL}'. "
        "Include: daily schedule (rest days vs training days), "
        "list of movements per session with sets & reps, proper form tips, "
        "and a short motivational note for each week."
    ),
    expected_output=(
        "A complete 4-week workout program in markdown format, containing: "
        "weekly schedule, exercise details per session (name, sets, reps, duration), "
        "form tips, and motivational notes each week. Minimum 500 words."
    ),
    agent=personal_trainer,
    context=[research_task],
)

review_task = Task(
    description=(
        "Review the workout program that has been created. Check: "
        "(1) movement safety for beginners, "
        "(2) whether intensity increases gradually (progressive overload), "
        "(3) add daily nutritional guidelines to support the fitness goal, "
        "(4) add disclaimers & notes for special conditions (injuries, pregnancy, etc.). "
        "Produce a final polished and safe version."
    ),
    expected_output=(
        "A complete final fitness program containing: revised workout program, "
        "daily nutritional guidelines (calories, protein, carbohydrates, fats), "
        "recovery & sleep tips, and a safety disclaimer. Markdown format."
    ),
    agent=nutrition_reviewer,
    context=[workout_task],
)

# ── 4. CREW ──────────────────────────────────────────────────

crew = Crew(
    agents=[fitness_researcher, personal_trainer, nutrition_reviewer],
    tasks=[research_task, workout_task, review_task],
    process=Process.sequential,
    verbose=True,
)

# ── 5. RUN ───────────────────────────────────────────────────

if __name__ == "__main__":
    print("🏋️ Starting Fitness AI Pipeline...\n")
    result = crew.kickoff()
    print("\n✅ FINAL FITNESS PROGRAM:\n")
    print(result)