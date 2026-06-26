# Calora — AI Fitness Coach

An iOS fitness coaching app built with SwiftUI. Tracks daily activity, recommends personalised workouts, analyses exercise form via the camera, and provides an offline AI coaching chat.

## Features

- **Dashboard** — daily calorie ring, Apple Health integration, workout recommendations
- **AI Coach** — offline fitness chatbot (Claude API optional, falls back to built-in knowledge)
- **Form Check** — live camera feedback using Vision body-pose detection + Core ML action classifier (squat form: correct / too shallow / torso lean)
- **Workout Player** — guided sessions with rep counter, rest timer, and "continue later" support
- **Statistics** — weekly activity charts (Swift Charts)
- **Goals** — calorie targets, BMI card, weekly active-day tracker
- **Calorie Lookup** — offline nutrition database (no external API required)
- **Exercise Library** — ExerciseDB catalog with animated GIFs (requires RapidAPI key in Settings)
- **Onboarding** — personalised setup (name, body metrics, goal, focus, schedule)
- **Authentication** — Firebase Auth (email/password + Google Sign-In)

## Requirements

| Tool | Version |
|------|---------|
| Xcode | 15.0 or later |
| iOS deployment target | 16.4+ |
| Swift | 5.9+ |

## Setup

### 1. Firebase

1. Create a project at [console.firebase.google.com](https://console.firebase.google.com).
2. Enable **Authentication** (Email/Password + Google Sign-In).
3. Enable **Firestore** (optional, for cloud profile sync).
4. Download `GoogleService-Info.plist` and place it at:
   ```
   Cindi_FitnessCoach_L25020008/GoogleService-Info.plist
   ```
   A template is provided at `GoogleService-Info.plist.template` — do **not** commit the real file.

### 2. AI Coach (optional)

The chatbot works fully offline without any key. To enable the Claude-powered online mode, paste your [Anthropic API key](https://console.anthropic.com) in **Settings → AI Coach** inside the app.

Alternatively, set it for local development only (never commit):
```swift
// FitnessCoachChatService.swift
private let fallbackKey = "sk-ant-..."  // local only
```

### 3. Exercise Library (optional)

The exercise library requires a [RapidAPI](https://rapidapi.com/justin-WFnsXH_t6/api/exercisedb) key for the ExerciseDB API. Paste it in **Settings → Exercise Library** inside the app, or set `fallbackKey` in `ExerciseDBService.swift` for local dev.

## Architecture

```
Cindi_FitnessCoach_L25020008/
├── Core/
│   ├── ML/               # Core ML action classifier (squat form)
│   ├── Models/           # Data models
│   ├── Services/         # Business logic, API clients, local stores
│   └── ViewModels/       # ObservableObject view models
├── Features/
│   ├── Auth/             # Firebase sign-in / sign-up
│   ├── Coach/            # AI chatbot
│   ├── Dashboard/        # Today tab — activity ring, health card
│   ├── ExerciseFeedback/ # Camera form check (Vision + Core ML)
│   ├── ExerciseLibrary/  # ExerciseDB catalog
│   ├── Goals/            # Calorie goal, BMI, weekly tracker
│   ├── Nutrition/        # Offline calorie lookup
│   ├── Onboarding/       # First-launch personalisation flow
│   ├── Recommendations/  # Workout plans + live session player
│   └── Statistics/       # Weekly charts
└── Shared/
    └── Components/       # Reusable UI (colours, metric tiles, GIF player)
```

## Dependencies (Swift Package Manager)

| Package | Version | Purpose |
|---------|---------|---------|
| firebase-ios-sdk | 10.18.0 | Auth + Firestore |
| GoogleSignIn-iOS | 7.1.0 | Google Sign-In |

## Privacy

The app requests the following permissions at runtime:

| Permission | Usage |
|-----------|-------|
| Camera | Live exercise form feedback |
| Apple Health (read) | Today's active energy burned |

## License

For educational purposes only.
