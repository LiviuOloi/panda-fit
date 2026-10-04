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

- **📊 7-Day Rolling Moving Average:** Filters water weight fluctuations and visualizes real biological progress with interactive `fl_chart` curves.
- **🎯 Cutting & Bulking Missions:** Strict mathematical inequality completion milestones (`< target` for cutting, `> target` for bulking) with instant celebration confetti and archival.
- **🐼 Panda Eats AI Coach:** Interactive conversational AI powered by Google Gemini (with smart multi-model fallback and secure on-device API key setup) that crafts personalized, raw/dry weighed meals matching your glycemic profile and caloric targets, with inline meal card persistence and one-click saving to your personal menu.
- **🥗 Custom Recipe & Personal Menu Manager:** Create, edit, and organize custom breakfast, snack, and dinner recipes with accurate raw/dry weighing tags and automatic macro calculations.
- **⚡ Fast Daily Logger & Pessimistic Calorie Engine:** Morning weigh-in, dynamic dinner selection from your personalized menu, swimming & workout logging with science-backed pessimistic MET calorie burn discounting.

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
GEMINI_API_KEY=your-gemini-api-key # Optional: Can also be configured directly in the app UI via the key button
```

### 3. Run the App
- **Web:** `flutter run -d chrome`
- **Android:** `flutter run -d android`
- **Unit Tests:** `flutter test`
- **Static Analysis:** `flutter analyze`


