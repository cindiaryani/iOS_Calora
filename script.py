import os
from crewai import Agent, Task, Crew, Process, LLM

# ── 1. LLM SETUP ────────────────────────────────────────────
os.environ["ANTHROPIC_API_KEY"] = os.getenv("ANTHROPIC_API_KEY", "")  # set via env var, do NOT hardcode

llm = LLM(
    model="anthropic/claude-sonnet-4-5",
    temperature=0.7,
)

# ── 2. AGENTS ────────────────────────────────────────────────

fitness_psychologist = Agent( 
    role="Sports Psychologist & Motivation Coach",
    goal="Analyze the user's mental barriers and build a strong mindset foundation for fitness success",
    backstory=(
        "You are a certified sports psychologist with 12 years of experience helping "
        "people overcome mental blocks around fitness. You specialize in habit formation, "
        "motivation psychology, and building long-term lifestyle consistency."
    ),
    llm=llm,
    verbose=True,
    allow_delegation=False,
)

body_assessment_coach = Agent(
    role="Body Assessment & Goal Setting Specialist",
    goal="Assess the user's current physical condition and set realistic, measurable fitness milestones",
    backstory=(
        "You are a kinesiologist and body composition expert who has assessed thousands "
        "of clients. You excel at reading physical baselines, identifying imbalances, "
        "and crafting SMART goals tailored to each individual's starting point."
    ),
    llm=llm,
    verbose=True,
    allow_delegation=False,
)

lifestyle_integration_coach = Agent(
    role="Lifestyle & Habit Integration Coach",
    goal="Blend the fitness plan seamlessly into the user's daily routine, sleep, and stress management",
    backstory=(
        "You are a holistic wellness coach who understands that fitness is not just about "
        "the gym. You specialize in integrating workout schedules, recovery routines, sleep "
        "optimization, and stress reduction into real-world busy lifestyles."
    ),
    llm=llm,
    verbose=True,
    allow_delegation=False,
)

# ── 3. TASKS ─────────────────────────────────────────────────

FITNESS_GOAL = "lose weight and build muscle for beginners"

mindset_task = Task(
    description=(
        f"Analyze the psychological profile of someone trying to: '{FITNESS_GOAL}'. "
        "Cover: (1) the most common mental barriers and how to overcome them, "
        "(2) proven motivation techniques for long-term consistency, "
        "(3) how to build an identity-based fitness habit, "
        "(4) strategies to handle setbacks, bad days, and plateaus mentally."
    ),
    expected_output=(
        "A mindset & motivation guide containing: list of common mental barriers with solutions, "
        "top motivation techniques, identity-based habit building steps, and a plateau recovery "
        "mental framework. Minimum 300 words, bullet-point format."
    ),
    agent=fitness_psychologist,
)

assessment_task = Task(
    description=(
        f"Based on the mindset foundation, create a full body assessment framework and "
        f"goal-setting roadmap for: '{FITNESS_GOAL}'. "
        "Include: (1) key metrics to track (weight, body fat %, measurements, strength benchmarks), "
        "(2) realistic milestone targets for weeks 2, 4, 8, and 12, "
        "(3) how to identify personal imbalances or weak points to address first, "
        "(4) a progress tracking template the user can fill in weekly."
    ),
    expected_output=(
        "A body assessment & goal roadmap in markdown format containing: "
        "metrics tracking guide, milestone targets per phase, imbalance identification checklist, "
        "and a weekly progress tracker template. Minimum 400 words."
    ),
    agent=body_assessment_coach,
    context=[mindset_task],
)

lifestyle_task = Task(
    description=(
        "Using the mindset guide and assessment roadmap, create a full lifestyle integration plan. "
        "Include: (1) how to fit workouts into a busy daily schedule (morning/evening options), "
        "(2) sleep optimization tips to maximize recovery and fat loss, "
        "(3) stress management techniques that complement the fitness journey, "
        "(4) a sample weekly lifestyle schedule combining work, rest, training, and social life, "
        "(5) warning signs of overtraining and how to adjust the plan sustainably."
    ),
    expected_output=(
        "A complete lifestyle integration plan in markdown format containing: "
        "flexible workout scheduling options, sleep & recovery protocol, stress management toolkit, "
        "sample weekly lifestyle schedule, and an overtraining warning guide. Minimum 500 words."
    ),
    agent=lifestyle_integration_coach,
    context=[assessment_task],
)

# ── 4. CREW ──────────────────────────────────────────────────

crew = Crew(
    agents=[fitness_psychologist, body_assessment_coach, lifestyle_integration_coach],
    tasks=[mindset_task, assessment_task, lifestyle_task],
    process=Process.sequential,
    verbose=True,
)

# ── 5. RUN ───────────────────────────────────────────────────

if __name__ == "__main__":
    print("🧠 Starting Claude Fitness Lifestyle Pipeline...\n")
    result = crew.kickoff()
    print("\n✅ FINAL LIFESTYLE FITNESS PLAN:\n")
    print(result)