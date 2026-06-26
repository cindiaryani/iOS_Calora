import os
import json
from crewai import Agent, Task, Crew, Process, LLM

# ── 1. LLM SETUP ────────────────────────────────────────────
os.environ["ANTHROPIC_API_KEY"] = os.getenv("ANTHROPIC_API_KEY", "")  # set via env var, do NOT hardcode

llm = LLM(
    model="anthropic/claude-sonnet-4-5",
    temperature=0.7,
)

# ── MOCK A2A JSON (exact contract parsed by AppleHealthA2AResponse.swift) ──

MOCK_A2A_JSON = {
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

def mock_a2a_json() -> str:
    return json.dumps(MOCK_A2A_JSON, indent=2)

# ── AGENT CARDS ──────────────────────────────────────────────
AGENT_CARDS = {
    "apple_health_agent": {
        "name": "AppleHealthAgent",
        "role": "Health Data Provider",
        "capabilities": [
            "generate_mock_health_data",
            "send_a2a_calorie_summary"
        ],
        "input": "health data request",
        "output": "A2A JSON calorie summary"
    },
    "ui_agent": {
        "name": "SwiftUIDashboardAgent",
        "role": "Dashboard Consumer",
        "capabilities": [
            "parse_a2a_json",
            "map_payload_to_dashboard"
        ],
        "input": "A2A JSON",
        "output": "DailyFitnessSnapshot for SwiftUI"
    },
    "qa_agent": {
        "name": "QAAgent",
        "role": "Validation Agent",
        "capabilities": [
            "validate_a2a_schema",
            "check_codable_compatibility"
        ],
        "input": "A2A JSON and Swift model contract",
        "output": "QA validation report"
    }
}

# ── DELEGATION FLOW ──────────────────────────────────────────
DELEGATION_FLOW = [
    "UIAgent requests calorie summary from AppleHealthAgent",
    "AppleHealthAgent delegates validation to QAAgent",
    "QAAgent returns PASS/FAIL validation report",
    "UIAgent parses approved A2A JSON into SwiftUI dashboard"
]

# ── 2. AGENTS ────────────────────────────────────────────────

apple_health_agent = Agent(
    role="AppleHealthAgent",
    goal=(
        "Generate a mock A2A JSON response containing sample calorie and fitness data "
        "that matches the exact contract expected by the SwiftUI fitness dashboard. "
        "The data includes active energy burned, daily calorie goal, steps, and mindful minutes."
    ),
    backstory=(
        "You are an Apple Health data specialist that communicates using the "
        "Agent-to-Agent (A2A) protocol. You simulate Apple Health data by generating "
        "structured JSON messages with sender, receiver, message_type, and payload fields. "
        "Your output feeds directly into the SwiftUI fitness dashboard as a data bridge "
        "between the Health layer and the UI layer — not replacing the app, but acting "
        "as a mock communication layer for calorie and activity data."
    ),
    llm=llm,
    verbose=True,
    allow_delegation=False,
)

ui_agent = Agent(
    role="SwiftUIDashboardAgent",
    goal=(
        "Receive AppleHealthAgent A2A JSON and map it into the existing SwiftUI "
        "fitness dashboard: daily calorie goal, active energy progress, steps, "
        "mindful minutes, and workout recommendations."
    ),
    backstory=(
        "You are a SwiftUI dashboard specialist who understands Codable, JSON parsing, "
        "and iOS UI design. The existing SwiftUI app already displays daily calorie goals, "
        "Apple Health active energy progress, workout recommendations, and dashboard metrics. "
        "Your role is to explain how the incoming A2A JSON updates and enriches these "
        "existing features — acting as the data bridge between AppleHealthAgent and the UI."
    ),
    llm=llm,
    verbose=True,
    allow_delegation=False,
)

qa_agent = Agent(
    role="QAAgent",
    goal=(
        "Validate the A2A JSON schema, verify all required keys exist, confirm SwiftUI "
        "Codable compatibility, and ensure the data is ready to update the existing "
        "fitness dashboard without breaking any UI components."
    ),
    backstory=(
        "You are a QA engineer specialized in JSON schema validation and iOS data integrity. "
        "You check every A2A JSON response for correctness, completeness, and SwiftUI "
        "Codable compatibility before it reaches the UI. You understand that this JSON "
        "feeds into an existing dashboard with calorie goals, active energy progress, "
        "steps tracking, and workout recommendations — so data integrity is critical."
    ),
    llm=llm,
    verbose=True,
    allow_delegation=False,
)

# ── 3. TASKS ─────────────────────────────────────────────────

health_task = Task(
    description=(
        "Generate a mock A2A JSON response containing sample calorie data. "
        "The JSON MUST match this exact A2A protocol contract because SwiftUI "
        "parses these exact keys with AppleHealthA2AResponse.swift:\n\n"
        f"{mock_a2a_json()}\n\n"
        "Return the JSON first, then briefly explain each field and its role "
        "in the SwiftUI fitness dashboard."
    ),
    expected_output=(
        "A complete A2A JSON response with all required fields: "
        "protocol, message_type, sender, receiver, and payload containing "
        "date, active_energy_burned_kcal, calorie_goal_kcal, steps, "
        "mindful_minutes, and confidence. Include brief field explanations."
    ),
    agent=apple_health_agent,
)

ui_task = Task(
    description=(
        "Explain how the A2A calorie JSON from AppleHealthAgent updates the existing "
        "SwiftUI fitness dashboard. Map each field to its dashboard component:\n"
        "1. active_energy_burned_kcal → Apple Health Active Energy progress ring\n"
        "2. calorie_goal_kcal → Daily Calorie Goal display\n"
        "3. steps → Steps tracking metric\n"
        "4. mindful_minutes → Recovery/mindfulness section\n"
        "5. confidence → data reliability indicator\n\n"
        "Also explain:\n"
        "- The exact Swift Codable struct shape used by AppleHealthA2AResponse.swift\n"
        "- How DailyFitnessSnapshot is built from the payload\n"
        "- How loadAppleHealthA2AMock() feeds data into the ViewModel\n"
        "- How the ViewModel refreshes workout recommendations after parsing"
    ),
    expected_output=(
        "A complete SwiftUI integration guide containing:\n"
        "- Field mapping (JSON key → SwiftUI dashboard component)\n"
        "- Swift Codable structs matching AppleHealthA2AResponse\n"
        "- DailyFitnessSnapshot construction from payload\n"
        "- ViewModel refresh flow for workout recommendations\n"
        "- loadAppleHealthA2AMock() implementation explanation"
    ),
    agent=ui_agent,
    context=[health_task],
)

qa_task = Task(
    description=(
        "Validate the A2A JSON generated by AppleHealthAgent. Check:\n"
        "1. All required A2A protocol fields exist (protocol, message_type, sender, receiver, payload)\n"
        "2. All payload fields are present and have correct data types\n"
        "3. The JSON is valid and properly formatted\n"
        "4. Swift Codable compatibility — every key matches AppleHealthA2AResponse.swift\n"
        "5. Data value ranges are realistic (calories, steps, mindful minutes)\n"
        "6. payload.date format is ISO 8601 compatible\n"
        "7. Data is safe to feed into existing dashboard without breaking UI components\n\n"
        "Produce a validation report with PASS/FAIL status for each check."
    ),
    expected_output=(
        "## QA Validation Report\n\n"
        "### A2A Protocol Fields\n"
        "- protocol: PASS/FAIL\n"
        "- message_type: PASS/FAIL\n"
        "- sender.id: PASS/FAIL\n"
        "- sender.role: PASS/FAIL\n"
        "- receiver.id: PASS/FAIL\n"
        "- receiver.role: PASS/FAIL\n"
        "- payload: PASS/FAIL\n\n"
        "### Payload Data Validation\n"
        "- date (ISO 8601): PASS/FAIL\n"
        "- active_energy_burned_kcal: PASS/FAIL\n"
        "- calorie_goal_kcal: PASS/FAIL\n"
        "- steps: PASS/FAIL\n"
        "- mindful_minutes: PASS/FAIL\n"
        "- confidence: PASS/FAIL\n\n"
        "### Swift Codable Compatibility: PASS/FAIL\n"
        "### Dashboard Safety Check: PASS/FAIL\n\n"
        "### Overall Status: PASS/FAIL\n"
        "### Notes: {any issues found}"
    ),
    agent=qa_agent,
    context=[health_task, ui_task],
)

# ── 4. CREW ──────────────────────────────────────────────────

crew = Crew(
    agents=[apple_health_agent, ui_agent, qa_agent],
    tasks=[health_task, ui_task, qa_task],
    process=Process.sequential,
    verbose=True,
)

# ── 5. RUN ───────────────────────────────────────────────────

if __name__ == "__main__":
    print("🤖 Starting A2A Agent Pipeline...\n")
    print("Context: SwiftUI Fitness Dashboard App")
    print("Features: Daily Calorie Goal | Active Energy | Steps | Workout Recommendations")
    print()

    # Print Agent Cards
    print("📋 AGENT CARDS:")
    for agent_id, card in AGENT_CARDS.items():
        print(f"  [{card['name']}]")
        print(f"    Role        : {card['role']}")
        print(f"    Capabilities: {', '.join(card['capabilities'])}")
        print(f"    Input       : {card['input']}")
        print(f"    Output      : {card['output']}")
    print()

    # Print Delegation Flow
    print("🔄 DELEGATION FLOW:")
    for i, step in enumerate(DELEGATION_FLOW, 1):
        print(f"  {i}. {step}")
    print()

    # Print Mock JSON
    print("📦 Exact mock A2A JSON parsed by SwiftUI:")
    print(mock_a2a_json())
    print()

    print("Agents:")
    print("  🍎 AppleHealthAgent      → generate mock A2A JSON calorie data")
    print("  📱 SwiftUIDashboardAgent → map A2A JSON into existing SwiftUI dashboard")
    print("  ✅ QAAgent               → validate JSON before UI parses it")
    print()

    result = crew.kickoff()

    print("\n" + "="*60)
    print("✅ A2A PIPELINE COMPLETE")
    print("="*60)
    print(result)