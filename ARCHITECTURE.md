# PandaFit — System Architecture & Technical Blueprint (`ARCHITECTURE.md`)

This document provides a comprehensive technical breakdown of the **PandaFit** cross-platform application architecture, state pipelines, offline-first data synchronization, navigation models, and design tokens.

---

## 1. High-Level System Architecture

PandaFit uses a **Feature-First Clean Architecture** built on Flutter (Client) and Supabase (Backend Cloud Engine), designed for zero operational cost and complete cross-platform fidelity (Web, Android, iOS).

```mermaid
graph TD
    subgraph Client ["Client Device (Web / Android / iOS)"]
        UI["Presentation Layer (Flutter Widgets + fl_chart)"]
        State["State Management (Riverpod AsyncNotifiers & Providers)"]
        Domain["Domain Layer (Entities, Pure Invariant Calculations)"]
        Data["Data Layer (Repositories & Remote/Local Sources)"]
        LocalCache["Local Storage & Offline Queue (SharedPreferences)"]
        CameraEngine["Camera & Barcode Engine (mobile_scanner)"]
        NotifEngine["Local Notification Engine (flutter_local_notifications)"]
    end

    subgraph Cloud ["Supabase Cloud (100% Free Tier)"]
        Auth["Supabase Auth (JWT, Email/Password)"]
        PostgREST["PostgREST API Engine"]
        Realtime["Realtime WebSocket Gateway"]
        Postgres[("PostgreSQL 15+ Database")]
        RLS["Row Level Security (RLS Engine)"]
    end

    subgraph ThirdParty ["External Free APIs"]
        Gemini["Google Generative AI (Gemini 1.5/2.0)"]
        OpenFoodFacts["OpenFoodFacts REST API"]
    end

    UI --> State
    State --> Domain
    State --> Data
    Data --> LocalCache
    UI --> CameraEngine
    UI --> NotifEngine
    Data -->|HTTPS / WSS| Auth
    Data -->|HTTPS / REST| PostgREST
    Data -->|WebSocket| Realtime
    PostgREST --> RLS
    Realtime --> RLS
    RLS --> Postgres
    Auth --> Postgres
    Data --> Gemini
    Data --> OpenFoodFacts
```

---

## 2. Layered Architecture (Clean / Feature-First)

Every functional module inside `lib/features/` follows strict separation of concerns:

```
feature_name/
├── domain/                  # PURE DART — Zero external Flutter dependencies
│   ├── models/              # Immutable Data Classes / Entities
│   ├── value_objects/       # Types with built-in validation (e.g., WeightValue)
│   └── calculations/        # Pure algorithmic engines (7-day MA, Mission inequality)
├── data/                    # Data sources, serialization, network mapping
│   ├── datasources/         # SupabaseClient remote calls & local storage adapters
│   ├── dtos/                # Data Transfer Objects (from/to JSON)
│   └── repositories/        # Repository implementations with offline-first fallback
└── presentation/            # User Interface & Reactive State
    ├── controllers/         # Riverpod Notifiers (AsyncNotifier, StateNotifier)
    ├── screens/             # Top-level screen views (Responsive web/mobile)
    └── widgets/             # Reusable, feature-specific UI components
```

### Layer Rules
1. **Domain Layer:** Pure Dart only. No imports of `flutter/material.dart` or `supabase_flutter`. This ensures 100% unit-testability without mocks.
2. **Data Layer:** Handles network calls, offline caching, and DTO-to-Domain mapping. Catches Supabase PostgREST exceptions and falls back to local storage.
3. **Presentation Layer:** Watches Riverpod providers. Reacts declaratively to `AsyncValue.loading()`, `AsyncValue.error()`, and `AsyncValue.data()`.

---

## 3. Data Flow & Offline-First Strategy

To ensure seamless operation even without network access (e.g. morning weigh-in or gym basement with zero signal), PandaFit employs a **Cache-First Write-Through with Pending Queue** pattern:

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant UI as DailyLogger UI / WorkoutScreen
    participant Riverpod as DailyEntriesNotifier / WorkoutController
    participant Repo as DailyEntryRepository / WorkoutRepository
    participant Local as SharedPreferences (Cache & Queue)
    participant Remote as Supabase Remote API

    User->>UI: Submit Weigh-in (102.4 kg) or Workout Session
    UI->>Riverpod: saveDailyEntry(entry) / finishWorkout()
    Riverpod->>Repo: saveDailyEntry(entry)
    Repo->>Local: Write entry to local cache immediately
    Local-->>Repo: Saved successfully
    Repo-->>Riverpod: Optimistic update local state
    Riverpod-->>UI: UI immediately updates charts & metrics

    par Attempt Sync to Cloud
        Repo->>Remote: POST /daily_entries (Upsert)
        alt Online (Success)
            Remote-->>Repo: 201 Created / Updated
            Repo->>Local: Clear pending queue entry
        else Offline / Network Failure
            Repo->>Local: Append to pandafit_pending_entries queue
            Note over Repo,Local: Background sync will retry upon network reconnect
        end
    end
```

---

## 4. Navigation & Responsive Layout Architecture

PandaFit uses a responsive layout shell that dynamically adapts between mobile viewports and desktop/tablet screens:

```mermaid
graph LR
    subgraph Viewport Detection
        VP["LayoutBuilder / Breakpoint"]
    end

    subgraph Mobile ["Mobile (< 768px)"]
        BottomNav["NavigationBar (6 Tabs, Safe Area, Compact Labels)"]
        MobileDrawer["Contextual Bottom Sheet Modals"]
    end

    subgraph Desktop ["Tablet & Desktop (>= 768px)"]
        Sidebar["Collapsible Navigation Rail / Sidebar"]
        Grid["Multi-column Dashboard Grid (Cards + Wide Chart)"]
        ModalDialog["Centered Glassmorphism Modal Dialogs"]
    end

    VP -->|< 768px| Mobile
    VP -->|>= 768px| Desktop
```

### Core Module Tree (6 Tabs)
| Tab Index | Tab Label | Screen View | Description |
| :---: | :--- | :--- | :--- |
| **0** | **Dashboard** | `DashboardScreen` | 7-day MA interactive chart, quick stats, delta from start, streak counters. |
| **1** | **Log** | `DailyLoggerScreen` | Morning weigh-in, habits, pessimistic activity calorie burn, dinner selector, offline-aware save. |
| **2** | **Workout** | `WorkoutHomeScreen` | 30+ exercise library, split templates, live workout logger, rest timer with vibration, volume tracking. |
| **3** | **Missions** | `MissionsScreen` | Active cutting/bulking progress, milestone forecasting ETA, historical accomplished missions. |
| **4** | **Eats AI** | `NutritionGuideScreen` / `AiNutritionistScreen` | Multi-turn AI nutrition coach, photo label analysis, 60 FPS barcode scanner, custom recipe management. |
| **5** | **Profile** | `ProfileScreen` | Biometrics, locked starting weight, notification reminders, clinical PDF report generator, direct Android APK download. |

---

## 5. Security & Authentication Architecture

```mermaid
graph TD
    ClientApp["PandaFit Flutter Client"]
    AnonKey["Supabase Public Anon Key (Embedded in Client)"]
    AuthHeader["Bearer JWT Token (Stored in Secure Storage)"]
    SupabaseAuth["Supabase GoTrue Auth Service"]
    RLSEngine["PostgreSQL Row Level Security (RLS)"]
    UserData["Private User Rows in Database"]

    ClientApp -->|Public Requests| AnonKey
    AnonKey --> SupabaseAuth
    SupabaseAuth -->|Issues Session JWT| AuthHeader
    AuthHeader -->|Authenticated Queries| RLSEngine
    RLSEngine -->|auth.uid() = user_id| UserData
```

1. **Authentication:** Supabase Auth manages sessions. The client securely persists the session token.
2. **Row Level Security (RLS):** Every query is executed under the context of `auth.uid()`. Even if an attacker inspects network traffic, they cannot read or write another user's rows.
3. **Database Guardrails:** A PostgreSQL trigger (`check_profile_start_weight_lock`) strictly rejects any database `UPDATE` modifying `profile_start_weight` if the user already has logged daily entries.

---

## 6. Design System Tokens & Aesthetics

PandaFit implements a modern, deep dark-mode theme utilizing glassmorphism and tailored semantic accents:

### 6.1 Color Palette
| Token Name | Hex Code | Purpose |
| :--- | :--- | :--- |
| `backgroundDark` | `#0A0F1D` | Deep slate/charcoal background canvas |
| `surfaceDark` | `#111827` | Primary card and container background |
| `surfaceGlass` | `rgba(30, 41, 59, 0.7)` | Translucent glassmorphism panels with 12px blur |
| `primaryEmerald` | `#10B981` | Accent color for healthy status, weight loss, and primary buttons |
| `secondaryCyan` | `#06B6D4` | Accent color for 7-day moving average, water, and swimming |
| `accentAmber` | `#F59E0B` | Calorie targets, warnings, and mission milestone flags |
| `accentRose` | `#F43F5E` | Caloric overage or weight spikes above baseline |
| `textPrimary` | `#F8FAFC` | High-contrast body and header text |
| `textSecondary` | `#94A3B8` | Subtle metadata, timestamps, and unit labels (`kg`, `kcal`) |

---

## 7. State Management Pipelines (Riverpod)

```mermaid
graph LR
    subgraph Data Pipeline
        DB[(Supabase DB)] -->|Stream / Watch| Repo[DailyEntryRepository]
        Repo -->|AsyncValue| Provider[dailyEntriesProvider]
        WorkoutRepo[WorkoutRepository] -->|AsyncValue| Sessions[workoutSessionsProvider]
        DeviceStorage[SharedPreferences] --> KeyProvider[geminiApiKeyProvider]
    end

    subgraph Derived State Pipeline
        Provider --> MAEngine[rolling7DayMovingAverageProvider]
        Provider --> DeltaEngine[totalWeightDeltaProvider]
        Provider --> MissionEngine[activeMissionProgressProvider]
        Provider --> CalorieEngine[ActivityCaloriesCalculator]
    end

    subgraph UI Pipeline
        MAEngine --> ChartWidget[WeightProgressChart]
        DeltaEngine --> MetricCard[MetricSummaryCard]
        MissionEngine --> MissionBar[MissionProgressBar]
        Sessions --> WorkoutUI[WorkoutHomeScreen & ActiveWorkoutScreen]
        KeyProvider --> AICoach[AiNutritionistScreen]
    end
```

By computing moving averages and deltas through pure **derived Riverpod providers**, UI components never re-calculate complex math in their render trees, guaranteeing smooth 60fps animations.

---

## 8. Workout Tracker & Split Engine Architecture

```mermaid
graph TD
    Template[Choose Template / Custom Workout] --> ActiveSession[ActiveWorkoutNotifier: Stopwatch Running]
    ActiveSession --> AddExercise[Select Exercise from 30+ Library]
    AddExercise --> LogSets[Enter Weight kg, Reps, RPE]
    LogSets --> CheckSet[Tap Set Checkbox: Haptic Medium Impact]
    CheckSet --> AutoRestTimer[Trigger RestTimerNotifier: 90s/120s Countdown]
    AutoRestTimer --> TimerFinished[Timer Hits 0: Haptic Vibrate Pulse]
    LogSets --> FinishWorkout[Finish Workout: Haptic Heavy Impact]
    FinishWorkout --> CalcVolume[Aggregate Volume kg & Duration]
    FinishWorkout --> PessimisticMET[Compute Burned Calories via Discounted MET]
    PessimisticMET --> SyncDaily[Auto-sync with Daily Logger & Save to SharedPreferences]
```

---

## 9. Barcode Scanner & Computer Vision Pipeline

```mermaid
graph TD
    OpenScanner[Open BarcodeScannerDialog] --> CameraStream[mobile_scanner 60 FPS Camera Stream]
    CameraStream --> Detection[Barcode Captured: Instant Haptic Pulse]
    Detection --> FetchAPI[Query OpenFoodFacts API]
    FetchAPI --> ParseProduct[Parse Macros, NutriScore, EcoScore, Nova]
    ParseProduct --> UserAction{User Selection}
    UserAction -->|Convert to Recipe| SaveRecipe[Save to Personal Recipes Catalog]
    UserAction -->|Consult AI Coach| InjectAI[Direct Context Injection into Panda Eats AI]
```

---

## 10. Clinical Health Reports & Multi-Format Export Engine

The `ExportService` computes clinical-grade metrics from raw daily entries:
- **Biometric Formulas:** Mifflin-St Jeor BMR, Physical Activity Level (PAL) Maintenance TDEE, Caloric Deficit, Diet Adherence Rate, Weight Velocity (kg/week).
- **Export Outputs:**
  1. **Printable PDF Report:** Multi-page A4 document with patient biometrics, KPI overview, trend curves, and meal logs.
  2. **CSV Spreadsheet:** UTF-8 BOM formatted Excel file with complete column headers.
  3. **JSON Backup:** Full database serialization for offline archiving and restoration.

---

## 11. Local Scheduled Notifications Architecture

The `NotificationService` manages on-device timezone-aware notifications without cloud messaging servers:
- **Morning Weigh-in Reminder:** Daily recurring at user-configured time (default 07:30 AM).
- **Evening Journal Reminder:** Daily recurring at user-configured time (default 21:00 PM).
- **Platform Implementations:**
  - **Android:** AndroidNotificationChannel with high priority, custom launcher icons, and exact alarm support.
  - **iOS:** DarwinNotificationDetails with alert, badge, and sound support.
