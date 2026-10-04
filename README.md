# PandaFit — Cross-Platform Health & Fitness Platform

A high-precision, cross-platform health, weight, body composition, nutrition, and workout tracking application engineered for sustainable health outcomes (glycemic optimization, HbA1c control, gradual cutting or lean bulking).

Runs seamlessly on **Web**, **Android**, and **iOS** from a single Flutter & Dart codebase, powered by a 100% free cloud stack (Supabase PostgreSQL Free Tier).

---

## 📚 Core Documentation Index

- **[PandaFit.md](PandaFit.md)** — Original product specification, domain rules, and meal guidelines.
- **[AGENTS.md](AGENTS.md)** — Master engineering guardrails, strict mathematical invariants, agent operating protocols, and Definition of Done.
- **[ARCHITECTURE.md](ARCHITECTURE.md)** — System architecture diagrams, state pipelines (Riverpod), offline-first caching, navigation tree, and design tokens.
- **[supabase/schema.sql](supabase/schema.sql)** — Production DDL schema with Row Level Security (RLS) policies, triggers, and meal seeds.

---

## 🛠️ Tech Stack (100% Free & Open Source)

- **Framework:** [Flutter 3.47+](https://flutter.dev) & Dart 3.13+
- **Backend & Cloud DB:** [Supabase](https://supabase.com) (PostgreSQL 15+, Auth, Realtime, RLS)
- **State Management:** [Flutter Riverpod](https://riverpod.dev)
- **Data Visualization:** [`fl_chart`](https://pub.dev/packages/fl_chart)
- **Offline Storage:** `shared_preferences`
- **AI Engine:** Google Generative AI (`google_generative_ai` / Gemini 1.5 Flash Free Tier) with offline rule-based fallback
- **Design System:** Material 3 Dark & Glassmorphism Theme (Emerald, Cyan, Slate, Amber)

---

## 🤖 Features Highlight

- **📊 7-Day Rolling Moving Average:** Filters water weight fluctuations and visualizes real biological progress.
- **🎯 Cutting & Bulking Missions:** Strict inequality completion milestones with instant celebration.
- **🤖 Panda Coach AI Nutritionist:** Interactive conversational AI powered by Gemini that dynamically crafts custom meals tailored to your biometric profile (height, weight, age, caloric targets, glycemic focus), with instant one-click save to your personal menu.
- **🥗 Custom Meal & Recipe Management:** Add, edit, and organize personal breakfast, snack, and dinner recipes with accurate raw/dry weighing tags.
- **⚡ Fast Daily Logger:** Morning weigh-in, dynamic dinner selection from your personalized menu, activity logging (swimming), and calorie balancing.

---

## 🚀 Getting Started

### 1. Database Setup
1. Create a free project at [supabase.com](https://supabase.com).
2. Go to the **SQL Editor** in the Supabase Dashboard.
3. Paste and run the contents of [supabase/schema.sql](supabase/schema.sql) (includes tables, RLS, triggers, and seed recipes).

### 2. Environment Configuration
Create a `.env` file in the root directory:
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
GEMINI_API_KEY=your-gemini-api-key # Optional: Panda Coach AI works with offline fallback if omitted
```

### 3. Run the App
- **Web:** `flutter run -d chrome`
- **Unit Tests:** `flutter test`
- **Static Analysis:** `flutter analyze`


