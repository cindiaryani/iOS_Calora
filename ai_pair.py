import os
import subprocess
import tempfile
import json
from crewai import Agent, Task, Crew, Process, LLM

# ── 1. LLM SETUP ────────────────────────────────────────────
os.environ["ANTHROPIC_API_KEY"] = os.getenv("ANTHROPIC_API_KEY", "")  # set via env var, do NOT hardcode
os.environ["GROQ_API_KEY"] = os.getenv("GROQ_API_KEY", "")  # set via env var, do NOT hardcode

claude_llm = LLM(
    model="anthropic/claude-sonnet-4-5",
    temperature=0.7,
)

groq_llm = LLM(
    model="groq/llama-3.3-70b-versatile",
    temperature=0.7,
)

# ── 2. HELPER: Gemini CLI Reviewer ───────────────────────────

def gemini_review(content: str, focus: str) -> str:
    """Call Gemini CLI to review content."""
    try:
        # Buat temp file supaya tidak bentrok
        with tempfile.NamedTemporaryFile(mode='w', suffix='.txt',
                                         prefix='gemini-review-',
                                         delete=False) as f:
            f.write(content)
            review_file = f.name

        prompt = (
            f"Review the content in {review_file} focusing on: {focus}. "
            "Be specific and constructive."
        )

        result = subprocess.run(
            ["gemini", "-p", prompt],
            capture_output=True,
            text=True,
            timeout=600
        )

        os.unlink(review_file)  # cleanup temp file

        if result.returncode == 0 and result.stdout:
            return result.stdout
        else:
            return f"[Gemini Error]: {result.stderr or 'No output returned'}"

    except subprocess.TimeoutExpired:
        return "[Gemini Error]: Timeout after 10 minutes"
    except FileNotFoundError:
        return "[Gemini Error]: gemini CLI not found"
    except Exception as e:
        return f"[Gemini Error]: {str(e)}"


# ── 3. AGENTS ────────────────────────────────────────────────

# Author — pakai Claude
author = Agent(
    role="Fitness Content Author",
    goal="Write comprehensive, engaging, and accurate fitness content based on the given topic",
    backstory=(
        "You are an expert fitness content writer with deep knowledge in exercise science, "
        "nutrition, and wellness coaching. You produce well-structured, motivating, and "
        "evidence-based fitness content tailored for beginners and intermediates alike."
    ),
    llm=claude_llm,
    verbose=True,
    allow_delegation=False,
)

# Codex Reviewer — Claude Fallback (karena tidak punya Codex premium)
codex_reviewer = Agent(
    role="Logic & Accuracy Reviewer [Claude Fallback]",
    goal="Review fitness content for logical coherence, factual accuracy, and structural quality",
    backstory=(
        "You are a meticulous content analyst and sports science fact-checker. "
        "You review fitness content for logical flow, scientific accuracy, proper structure, "
        "and completeness. You provide specific, actionable feedback with clear reasoning."
    ),
    llm=groq_llm,  # pakai Groq biar beda model
    verbose=True,
    allow_delegation=False,
)

# Gemini Reviewer — sebagai coordinator yang trigger Gemini CLI
gemini_reviewer = Agent(
    role="Readability & Engagement Reviewer",
    goal="Coordinate Gemini CLI review and assess fitness content for readability, engagement, and audience fit",
    backstory=(
        "You are a content engagement specialist who coordinates external AI reviews. "
        "You evaluate fitness content from the reader's perspective — is it clear, "
        "motivating, appropriately styled, and suitable for the target audience?"
    ),
    llm=claude_llm,
    verbose=True,
    allow_delegation=False,
)

# AppleHealthAgent Persona — deterministic mock A2A sender for the SwiftUI demo.
apple_health_agent = Agent(
    role="AppleHealthAgent",
    goal="Send Apple Health calorie summaries to the SwiftUI UI agent using an A2A JSON message",
    backstory=(
        "You represent the Health agent in a multi-agent fitness app. "
        "You do not render UI or answer coaching questions. Your only job is to package "
        "sample Apple Health calorie data into a strict A2A JSON contract that the UI agent can parse."
    ),
    llm=groq_llm,
    verbose=True,
    allow_delegation=False,
)

APPLE_HEALTH_A2A_RESPONSE = {
    "protocol": "A2A",
    "message_type": "health.calorie.summary",
    "sender": {
        "id": "apple_health_agent",
        "role": "AppleHealthAgent",
    },
    "receiver": {
        "id": "ui_agent",
        "role": "SwiftUIDashboardAgent",
    },
    "payload": {
        "date": "2026-05-15T07:30:00Z",
        "active_energy_burned_kcal": 420,
        "calorie_goal_kcal": 640,
        "steps": 8120,
        "mindful_minutes": 10,
        "confidence": 0.98,
    },
}


def apple_health_a2a_json() -> str:
    """Return the exact mock A2A JSON parsed by the SwiftUI app."""
    return json.dumps(APPLE_HEALTH_A2A_RESPONSE, indent=2)

# ── 4. FITNESS TOPIC ─────────────────────────────────────────

FITNESS_TOPIC = "7-day beginner fitness kickstart plan: mindset, movement, and meal basics"

# ── 5. TASKS ─────────────────────────────────────────────────

author_task = Task(
    description=(
        f"Write a comprehensive fitness content piece about: '{FITNESS_TOPIC}'. "
        "Include: (1) an engaging introduction that hooks the reader, "
        "(2) day-by-day breakdown with clear activities and goals, "
        "(3) mindset tips for each day to keep motivation high, "
        "(4) basic meal guidance without being overly restrictive, "
        "(5) a motivating closing that encourages continuation beyond 7 days. "
        "Write in a warm, encouraging, and practical tone."
    ),
    expected_output=(
        "A complete 7-day fitness kickstart guide in markdown format. "
        "Must include: hook introduction, daily breakdown (day 1-7) with activities + mindset tips, "
        "basic meal guidance section, and motivating conclusion. Minimum 600 words."
    ),
    agent=author,
)

codex_review_task = Task(
    description=(
        "Review the fitness content written by the author. "
        "This is a Claude Fallback review (Codex CLI unavailable). "
        "Check: (1) logical flow — does each day build on the previous? "
        "(2) factual accuracy — are exercise and nutrition claims scientifically sound? "
        "(3) structural completeness — are all promised sections present and well-developed? "
        "(4) consistency — are tone, terminology, and difficulty level consistent throughout? "
        "Provide specific feedback with section references."
    ),
    expected_output=(
        "## Codex Content Review\n"
        "**Source: Claude Fallback — Codex CLI unavailable**\n\n"
        "### Logic & Flow\n"
        "- {findings}\n\n"
        "### Factual Accuracy\n"
        "- {findings}\n\n"
        "### Structure & Completeness\n"
        "- {findings}\n\n"
        "### Consistency\n"
        "- {findings}\n\n"
        "### Summary\n"
        "{one-line overall assessment}"
    ),
    agent=codex_reviewer,
    context=[author_task],
)

gemini_review_task = Task(
    description=(
        "You are the Gemini CLI reviewer. Do the following steps:\n"
        "1. Take the fitness content from the author task\n"
        "2. Call the Gemini CLI to review it by passing the content\n"
        "3. The Gemini CLI focus should be: readability, engagement, style consistency, and audience fit for beginners\n"
        "4. If Gemini CLI is unavailable, do a Claude fallback review with the same focus areas\n"
        "5. Structure your final report clearly with the sections below\n\n"
        "IMPORTANT: Always attempt Gemini CLI first before doing fallback."
    ),
    expected_output=(
        "## Gemini Content Review\n"
        "**Source: Gemini CLI** (or Claude Fallback if CLI failed)\n\n"
        "### Readability & Flow\n"
        "- {findings}\n\n"
        "### Engagement & Hook\n"
        "- {findings}\n\n"
        "### Style Consistency\n"
        "- {findings}\n\n"
        "### Audience Fit (Beginners)\n"
        "- {findings}\n\n"
        "### Summary\n"
        "{one-line overall assessment}"
    ),
    agent=gemini_reviewer,
    context=[author_task],
)

# ── 6. CREW ──────────────────────────────────────────────────

crew = Crew(
    agents=[author, codex_reviewer, gemini_reviewer],
    tasks=[author_task, codex_review_task, gemini_review_task],
    process=Process.sequential,
    verbose=True,
)

# ── 7. RUN ───────────────────────────────────────────────────

if __name__ == "__main__":
    print("🤝 Starting AI Pair Collaboration — Fitness Content Team...\n")
    print("Mock AppleHealthAgent A2A JSON for SwiftUI:")
    print(apple_health_a2a_json())
    print()
    print("Team:")
    print("  ✍️  Author        → Claude (content writer)")
    print("  🔍 Codex Reviewer → Claude/Groq Fallback (logic & accuracy)")
    print("  🌟 Gemini Reviewer → Gemini CLI (readability & engagement)")
    print()

    result = crew.kickoff()

    print("\n" + "="*60)
    print("✅ AI PAIR COLLABORATION COMPLETE")
    print("="*60)
    print(result)
