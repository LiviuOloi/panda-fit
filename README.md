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
- **Design System:** Material 3 Dark & Glassmorphism Theme (Emerald, Cyan, Slate, Amber)

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
```

### 3. Run the App
- **Web:** `flutter run -d chrome`
- **Unit Tests:** `flutter test`
- **Static Analysis:** `flutter analyze`

