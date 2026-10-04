# PandaFit — Cross-Platform Health & Fitness Platform

A high-precision, cross-platform health, weight, body composition, nutrition, and workout tracking application engineered for sustainable health outcomes (glycemic optimization, HbA1c control, gradual cutting or lean bulking).

Runs seamlessly on **Web**, **Android**, and **iOS** from a single Flutter & Dart codebase, powered by a 100% free cloud stack (Supabase PostgreSQL Free Tier).

---

## 📚 Core Documentation Index

- **[PandaFit.md](file:///c:/Users/George/Documents/panda-fit/PandaFit.md)** — Original product specification, domain rules, and meal guidelines.
- **[AGENTS.md](file:///c:/Users/George/Documents/panda-fit/AGENTS.md)** — Master engineering guardrails, strict mathematical invariants, agent operating protocols, and Definition of Done.
- **[ARCHITECTURE.md](file:///c:/Users/George/Documents/panda-fit/ARCHITECTURE.md)** — System architecture diagrams, state pipelines (Riverpod), offline-first caching, navigation tree, and design tokens.
- **[supabase/schema.sql](file:///c:/Users/George/Documents/panda-fit/supabase/schema.sql)** — Production DDL schema with Row Level Security (RLS) policies and PostgreSQL triggers.
- **[supabase/seed.sql](file:///c:/Users/George/Documents/panda-fit/supabase/seed.sql)** — Pre-populated nutrition templates (Breakfast, Snack, Dinner options A, B, C).

---

## 🛠️ Tech Stack (100% Free)

- **Framework:** [Flutter 3.32+](https://flutter.dev) & Dart 3.8+
- **Backend & Cloud DB:** [Supabase](https://supabase.com) (PostgreSQL 15+, Auth, Realtime, RLS)
- **State Management:** [Flutter Riverpod](https://riverpod.dev)
- **Charts:** [`fl_chart`](https://pub.dev/packages/fl_chart)
- **Offline Storage:** `hive` / `shared_preferences`
- **Design System:** Material 3 Dark & Glassmorphism Theme (Emerald, Cyan, Slate, Amber)

---

## 🚀 Getting Started

### 1. Database Setup
1. Create a free project at [supabase.com](https://supabase.com).
2. Go to the **SQL Editor** in the Supabase Dashboard.
3. Paste and run the contents of [supabase/schema.sql](file:///c:/Users/George/Documents/panda-fit/supabase/schema.sql).
4. Run [supabase/seed.sql](file:///c:/Users/George/Documents/panda-fit/supabase/seed.sql) to populate meal templates.

### 2. Environment Configuration
Copy `.env.example` to `.env` or inject via `--dart-define`:
```bash
flutter run -d chrome --dart-define=SUPABASE_URL=YOUR_URL --dart-define=SUPABASE_ANON_KEY=YOUR_KEY
```

### 3. Run the App
- **Web:** `flutter run -d chrome`
- **Android:** `flutter run -d android`
