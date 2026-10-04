# AGENTS.md — PandaFit Master Architecture & Engineering Guardrails

> **System Purpose:** This document defines the engineering standards, architecture blueprints, strict domain rules, database specifications, and AI agent operating protocols for the **PandaFit** cross-platform health and fitness tracking application.
> All AI agents, contributors, and automated tooling MUST adhere to every rule established herein.

---

## 1. Project Vision & Core Identity

**PandaFit** is a high-precision, cross-platform health, weight, body composition, nutrition, and workout logging platform engineered for sustainable outcomes:
1. **Glycemic & HbA1c Optimization** (low GI complex carbohydrates, weighed vegetables, healthy fats, lean protein).
2. **Gradual, Healthy Fat Loss (Cutting) or Controlled Muscle Gain (Bulking)**.
3. **Analytical Rigor Over Gimmicks** (7-day rolling moving averages to eliminate water weight noise, net calorie balancing, and objective mission milestones).

### 1.1 Target Platforms
- **Web App:** Modern responsive SPA with dark mode, interactive charts, and keyboard shortcuts (deployed as static web or PWA).
- **Mobile App:** Native **Android** (APK/AAB) and **iOS** applications built from a **single Flutter & Dart codebase**.
- **Desktop/Tablet:** Seamless responsive scaling across wider screens.

### 1.2 Zero-Cost Mandate (100% Free Stack)
- **Zero Paid Licensing:** No proprietary runtimes, no paid UI kits, no commercial license locks.
- **Zero Cloud Billing Requirement:** Built entirely around generous free-tier cloud services (Supabase Free Tier) and open-source infrastructure (Flutter, Dart, PostgreSQL, Flutter Riverpod, `fl_chart`).
- **Offline First Resilience:** Must store and cache data locally so the user can log metrics even when offline.

---

## 2. Agent Persona & Operational Guidelines

Every AI agent working on PandaFit assumes the role of:
* **Senior Staff Cross-Platform Software Engineer**
* **Lead QA Architect & Security Auditor**
* **Evidence-Based Nutrition & Fitness Domain Specialist**

### 2.1 Agent Engineering Principles
1. **Defensive Coding & Type Safety:** No dynamic types where static types can be used. Enforce null-safety across the entire Dart codebase.
2. **Clean / Feature-First Architecture:** Separate domain business logic from data sources and presentation layers.
3. **Strict Domain Invariants:** Never compromise on business rules (e.g. strict inequality for mission completion, read-only starting weight).
4. **Self-Verification Mandate:** Before marking any task as complete:
   - Run `flutter analyze` — zero errors and zero warnings allowed.
   - Run relevant unit tests (`flutter test`) for domain calculations.
5. **No Regressions or Placeholders:** Do not leave dummy `TODO` comments or mock data where production logic is expected.

---

## 3. Technology Stack & Ecosystem

| Component | Technology | Rationale / Specification |
| :--- | :--- | :--- |
| **Framework** | **Flutter 3.32+** | Google's open-source multi-platform framework (Dart 3.8+). Compiles natively to Web (CanvasKit/HTML) and Mobile (AOT native machine code). |
| **Language** | **Dart 3.8+** | Strongly typed, null-safe, modern pattern matching, records, sealed classes. |
| **Backend & Cloud DB** | **Supabase (PostgreSQL 15+)** | 100% Free Tier: 500 MB DB, Auth, Row Level Security (RLS), Realtime WebSocket engine, PostgREST API. |
| **Client Library** | `supabase_flutter` | Official SDK with automatic session management and offline token storage. |
| **State Management** | **Flutter Riverpod (`flutter_riverpod`)** | Compile-safe, testable, decoupled dependency injection and reactive state caching. |
| **Data Visualization** | **`fl_chart`** | High-performance interactive vector charts for 7-day moving average, daily weights, and mission target thresholds. |
| **Local Storage / Cache** | `shared_preferences` / `hive` | Fast local caching of credentials, active preferences, and offline pending entries. |
| **Design System** | **Material 3 Custom Dark Theme** | Emerald (`#10B981`), Cyan (`#06B6D4`), Slate (`#0F172A`, `#1E293B`), Amber (`#F59E0B`). Glassmorphism cards, micro-animations. |
| **AI Engine** | **Google Generative AI (`google_generative_ai` / Gemini 1.5/2.0)** | Live generative nutrition coach with multi-model fallback cascade, biometric prompt injection, on-device API key persistence, and deterministic offline fallback. |
| **Icons & Media** | `flutter_lucide` / Material Symbols | Consistent, minimalist iconography for health, weight, swimming, and meals. |

---

## 4. Strict Domain Rules & Mathematical Invariants

These domain rules are **non-negotiable**. Any pull request, refactor, or generation violating these rules must be rejected immediately.

### 4.1 User Profile & Starting Weight
1. **`profile_start_weight` Immutability Rule:**
   - The user records their starting weight during initial setup.
   - **LOCK RULE:** `profile_start_weight` is editable **ONLY** if the user has `0` daily entries.
   - As soon as the first `DailyEntry` is persisted in the database, `profile_start_weight` becomes **STRICTLY READ-ONLY**.
   - Subsequent daily weigh-ins MUST NEVER overwrite or mutate `profile_start_weight`.
2. **Age Calculation:**
   - Derived dynamically from `birth_date` and the current date:
     $$\text{Age} = \text{CurrentYear} - \text{BirthYear} - (1 \text{ if birthday not yet reached this year else } 0)$$

### 4.2 Precision & Calculation Engines
1. **Weight Precision:**
   - All body weight values must be stored, displayed, and computed with **exactly `0.1 kg` precision** (e.g., `102.4 kg`, `98.1 kg`).
   - Rounding must use standard arithmetic half-up to 1 decimal place: `(weight * 10).round() / 10`.
2. **7-Day Rolling Moving Average ($\text{MA}_7$):**
   - Eliminates misleading weight spikes caused by water retention, glycogen storage, sodium intake, or digestive transit.
   - For any date $t$, let $\{W_0, W_1, \dots, W_{k-1}\}$ be the available morning weights for the last 7 calendar days up to and including $t$ ($k \le 7$):
     $$\text{MA}_7(t) = \frac{\sum_{i=0}^{k-1} W_{t-i}}{k}, \quad k = \min(\text{valid entries in 7-day window}, 7)$$
   - If no weigh-in exists on a given day, calculate over the actual logged days in that window ($k \ge 1$).
3. **Total $\Delta$ from Start:**
   $$\Delta_{\text{total}} = \text{Current Weight} - \text{Profile Starting Weight}$$
   - A negative value indicates weight loss; a positive value indicates weight gain.
4. **Net Calories:**
   $$\text{Net Calories} = \text{Calories In} - \text{Calories Out}$$
   - Where `Calories Out` represents active calories burned (from exercise/swimming); defaults to `0` if unspecified.

### 4.3 Missions Engine (Cutting vs. Bulking)
The user works toward structured **Missions**:
1. **Mission Types:**
   - **`CUTTING`**: Target weight is strictly lower than mission start weight ($\text{Target} < \text{Start}$).
   - **`BULKING`**: Target weight is strictly higher than mission start weight ($\text{Target} > \text{Start}$).
   - **Validation:** $\text{Target Weight} == \text{Mission Start Weight}$ is **INVALID** (minimum difference: $0.1\text{ kg}$).
2. **Strict Inequality Rule for Mission Accomplishment:**
   - A mission is NOT accomplished merely by tying the target. It requires **strict surpassing**:
     - **Cutting Accomplished:** $\text{Current Weight} < \text{Target Weight}$  
       *(Example: If target is 95.0 kg, the user is still active at 95.0 kg; accomplishment triggers only at $\le 94.9\text{ kg}$).*
     - **Bulking Accomplished:** $\text{Current Weight} > \text{Target Weight}$  
       *(Example: If target is 100.0 kg, accomplishment triggers only at $\ge 100.1\text{ kg}$).*
3. **Mission Lifecycle & Archival:**
   - Only **one** mission can be `ACTIVE` at any given time per user.
   - When a mission meets the strict inequality rule, the user receives an achievement celebration, `status` transitions to `ACCOMPLISHED`, and `achieved_at` is set to the current timestamp.
   - The user can then immediately configure their next mission (e.g. Next Cut or Maintenance/Bulk).

### 4.4 Nutrition, Meal Plans & Activity Guardrails
* **Caloric Target:** Default baseline $\sim 2300\text{ kcal/day}$ (dynamically modifiable in profile).
* **Glycemic & Metabolic Focus:** Prioritizes complex carbohydrates, elevated dietary fiber, controlled glycemic load, and precise weighing.
* **Weighing Protocol:**
  - Meat / Protein: Measured in **raw / uncooked** state.
  - Rice / Carbs: Measured in **dry / uncooked** state.
  - Vegetables: Weighed **frozen / raw**.
  - Cooking Oils: Weighed or measured by gram/ml (never unmeasured).
* **Predefined Quick Meal Templates:**
  - **Breakfast:** 3 eggs omelet, 100g Cottage Cheese Light (3%), 200g mixed vegetables (80g broccoli + 60g green beans + 60g mushrooms), 70–80g Graham bread, measured olive oil.
  - **Snack:** 150g Greek Yogurt (2%), 75g blueberries, 10g chia seeds, 10g peanut butter.
  - **Dinner Option A:** 200–250g raw chicken breast, 125g dry Panzani rice, 250g vegetables, 50–100g pickles, 0–5g oil.
  - **Dinner Option B:** 180–200g raw pork collar (no rice), 300g vegetables, 50–100g pickles, 0g oil.
  - **Dinner Option C:** 200–250g raw chicken breast, 200g Gustona potato wedges, 50–100g pickles.
* **Activity & Adherence Tracking:**
  - Swimming flag (`swimming: bool`)
  - Nutrition adherence flag (`plan_followed: bool`)
  - Notes for exercise sets, gym logs, or deviations.

### 4.5 Panda Eats AI Coach, Multimodal Label Scanning & Dynamic Meal Generation
* **Live Gemini API Integration & Computer Vision:**
  - Dynamic user consultation using Google Gemini (`google_generative_ai`).
  - Automatic model fallback cascade: `gemini-1.5-flash-latest` $\rightarrow$ `gemini-1.5-flash` $\rightarrow$ `gemini-2.0-flash` $\rightarrow$ `gemini-pro` $\rightarrow$ Offline Rule-Based Engine.
  - Multi-turn conversation protocol: History turns must strictly begin with `role: 'user'`, never `role: 'model'`.
  - Multimodal Vision Support: Users can attach photos of food nutrition labels or food items (`image_picker` Camera / Gallery). Photos are passed via `DataPart('image/jpeg', imageBytes)` to Gemini for macronutrient extraction (Calories, Protein, Carbs, Sugars, Fat, Fiber per 100g) and custom recipe synthesis with weighed portions.
  - Proposed meal proposals are attached inline per AI message turn, preserving all historical recipe sets across turns.
  - User API key is configured seamlessly via `GeminiApiKeyDialog` with 3-step guide and persisted locally via `gemini_api_key_provider.dart`.

### 4.6 Physical Activity & Pessimistic Calorie Burn Engine
* **Pessimistic MET Formulas:**
  - Standard fitness trackers heavily overestimate active calories burned. PandaFit uses evidence-based conservative MET values with strict discounting for resistance training (resting set intervals) to prevent accidental caloric surplus.
  - Swimming: Calorie burn computed dynamically based on body weight and duration.
  - Exercise toggles: Supports both duration-based MET calculation and direct custom calorie override.

---

## 5. Supabase PostgreSQL Schema (Production DDL)

AI agents must use this exact relational schema in Supabase. It incorporates Row Level Security (RLS), automated triggers, and constraint integrity:

```sql
-- ============================================================================
-- PandaFit PostgreSQL Schema for Supabase
-- ============================================================================

-- 1. PROFILES TABLE (Extends auth.users)
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    sex TEXT NOT NULL CHECK (sex IN ('MALE', 'FEMALE', 'OTHER')),
    birth_date DATE NOT NULL,
    height_cm NUMERIC(5,1) NOT NULL CHECK (height_cm > 50 AND height_cm < 300),
    profile_start_weight NUMERIC(4,1) NOT NULL CHECK (profile_start_weight > 20 AND profile_start_weight < 500),
    daily_target_calories INTEGER NOT NULL DEFAULT 2300 CHECK (daily_target_calories > 500),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 2. DAILY ENTRIES TABLE
CREATE TABLE public.daily_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    entry_date DATE NOT NULL,
    weight NUMERIC(4,1) CHECK (weight > 20 AND weight < 500),
    rolling_avg_7days NUMERIC(4,1),
    swimming BOOLEAN NOT NULL DEFAULT FALSE,
    plan_followed BOOLEAN NOT NULL DEFAULT TRUE,
    calories_in INTEGER CHECK (calories_in >= 0),
    calories_out INTEGER CHECK (calories_out >= 0),
    net_calories INTEGER GENERATED ALWAYS AS (COALESCE(calories_in, 0) - COALESCE(calories_out, 0)) STORED,
    selected_dinner TEXT CHECK (selected_dinner IN ('A', 'B', 'C', 'CUSTOM', 'NONE')),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_user_entry_date UNIQUE (user_id, entry_date)
);

-- Index for fast time-series queries
CREATE INDEX idx_daily_entries_user_date ON public.daily_entries (user_id, entry_date DESC);

-- 3. MISSIONS TABLE
CREATE TABLE public.missions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    mission_type TEXT NOT NULL CHECK (mission_type IN ('CUTTING', 'BULKING')),
    mission_start_weight NUMERIC(4,1) NOT NULL CHECK (mission_start_weight > 20 AND mission_start_weight < 500),
    target_weight NUMERIC(4,1) NOT NULL CHECK (target_weight > 20 AND target_weight < 500),
    status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'ACCOMPLISHED', 'ABANDONED')),
    started_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    achieved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    -- Cutting target must be lower than start, bulking must be higher
    CONSTRAINT check_mission_logic CHECK (
        (mission_type = 'CUTTING' AND target_weight < mission_start_weight) OR
        (mission_type = 'BULKING' AND target_weight > mission_start_weight)
    )
);

CREATE INDEX idx_missions_user_status ON public.missions (user_id, status);

-- 4. MEAL RECIPES TABLE
CREATE TABLE public.meal_recipes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category TEXT NOT NULL CHECK (category IN ('BREAKFAST', 'SNACK', 'DINNER', 'CUSTOM')),
    code TEXT UNIQUE,
    title TEXT NOT NULL,
    ingredients JSONB NOT NULL,
    calories INTEGER NOT NULL,
    protein_g NUMERIC(5,1),
    carbs_g NUMERIC(5,1),
    fat_g NUMERIC(5,1),
    instructions TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.missions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meal_recipes ENABLE ROW LEVEL SECURITY;

-- Profiles: Users can only view/update their own profile
CREATE POLICY "Users can view own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Daily Entries: Users can only CRUD their own entries
CREATE POLICY "Users can CRUD own daily entries" ON public.daily_entries
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Missions: Users can only CRUD their own missions
CREATE POLICY "Users can CRUD own missions" ON public.missions
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Meal Recipes: Public read, admin write
CREATE POLICY "Anyone can view meal recipes" ON public.meal_recipes FOR SELECT USING (true);

-- ============================================================================
-- DATABASE TRIGGERS
-- ============================================================================

-- Guardrail Trigger: Enforce read-only profile_start_weight once entries exist
CREATE OR REPLACE FUNCTION check_profile_start_weight_lock()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.profile_start_weight IS DISTINCT FROM NEW.profile_start_weight THEN
        IF EXISTS (SELECT 1 FROM public.daily_entries WHERE user_id = NEW.id LIMIT 1) THEN
            RAISE EXCEPTION 'Cannot modify profile_start_weight after daily entries have been recorded.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_lock_profile_start_weight
BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION check_profile_start_weight_lock();
```

---

## 6. Architecture & Code Structure (Flutter / Dart)

The codebase must follow a **Feature-First Clean Architecture**:

```
panda_fit/
├── android/                   # Native Android host configuration
├── ios/                       # Native iOS host configuration
├── web/                       # Web entry, PWA manifest, index.html
├── assets/                    # SVG icons, images, recipes seed JSON
├── lib/
│   ├── main.dart              # Entrypoint, Supabase & Riverpod initialization
│   ├── core/                  # Core infrastructure shared across features
│   │   ├── constants/         # App constants, API keys (from env), colors
│   │   ├── theme/             # Material 3 Dark & Glassmorphism themes
│   │   ├── utils/             # Calculation engines (7-day MA, delta, unit math)
│   │   ├── network/           # Supabase client singleton & error handling
│   │   └── widgets/           # Global reusable UI (PandaCard, PandaButton, GlassContainer)
│   └── features/              # Feature modules
│       ├── auth/              # Sign in, Sign up, Session listener
│       │   ├── data/
│       │   ├── domain/
│       │   └── presentation/
│       ├── profile/           # User details, starting weight lock, settings
│       │   ├── data/
│       │   ├── domain/
│       │   └── presentation/
│       ├── dashboard/         # Metric overview cards, 7-day MA chart, quick stats
│       │   ├── presentation/
│       │   └── widgets/       # WeightProgressChart, MetricSummaryCard
│       ├── daily_logger/      # Fast morning weigh-in, calories, dinner selector
│       │   ├── data/
│       │   ├── domain/
│       │   └── presentation/
│       ├── missions/          # Active mission progress bar, mission history
│       │   ├── data/
│       │   ├── domain/
│       │   └── presentation/
│       └── nutrition_guide/   # Predefined meal cards, ingredients, weighing guidelines
│           ├── data/
│           ├── domain/
│           └── presentation/
└── test/                      # Unit, domain, and widget test suites
    ├── core/
    ├── features/
    └── mocks/
```

### 6.1 State Management Rules (Riverpod)
- Always use `AsyncNotifierProvider` or `StateNotifierProvider` / code-gen `riverpod_generator` for asynchronous operations.
- UI widgets must extend `ConsumerWidget` or `ConsumerStatefulWidget`.
- Never perform database calls inside UI build methods; delegate to repositories.

### 6.2 Responsive Design Guidelines
The UI must deliver a first-class experience on both mobile viewports ($< 600\text{px}$) and desktop/web ($> 1024\text{px}$):
- **Mobile:** Bottom navigation bar, vertical scrolling, compact quick-log modal, touch-friendly tap targets ($\ge 48\times 48\text{dp}$).
- **Web / Desktop:** Left sidebar navigation or top header, multi-column dashboard grid, expansive charts with hover tooltips and data point inspection.

---

## 7. QA, Testing & Validation Protocols

1. **Unit Testing Domain Math:**
   - Test cases MUST cover:
     - 7-day moving average with $< 7$ days of data (e.g. 1 day, 3 days).
     - 7-day moving average with missing middle dates.
     - Strict inequality check: cutting mission of 95.0 kg with weights: `95.1` (Active), `95.0` (Active), `94.9` (Accomplished).
     - Bulking mission of 100.0 kg with weights: `99.9` (Active), `100.0` (Active), `100.1` (Accomplished).
     - Profile starting weight mutation lock rejection when daily entries exist.
2. **Lint & Code Formatting:**
   - Every file must adhere to `dart format` (80-character or 100-character line wrap).
   - Zero linter warnings (`flutter analyze`).
3. **Environment & Secrets:**
   - Supabase Project URL and Anon Key must be injected via compile-time environment variables (`--dart-define=SUPABASE_URL=...`, `--dart-define=SUPABASE_ANON_KEY=...`) or a `.env` file that is excluded in `.gitignore`.

---

## 8. Definition of Done (DoD) Checklist

For any feature or pull request to be considered complete:
- [ ] Requirements from [PandaFit.md](file:///c:/Users/George/Documents/panda-fit/PandaFit.md) and [AGENTS.md](file:///c:/Users/George/Documents/panda-fit/AGENTS.md) are strictly respected.
- [ ] Works cleanly on **Web** (`flutter run -d chrome`) and **Mobile** (`flutter run -d android`).
- [ ] Passes all unit tests (`flutter test`).
- [ ] Passes static analysis (`flutter analyze` with 0 issues).
- [ ] Responsive UI verified on both compact and expanded viewports.
- [ ] Dark mode / Glassmorphism aesthetic conforms to the curated color palette.
