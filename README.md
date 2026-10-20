# PandaFit — Cross-Platform Health, Nutrition & Workout Tracking Platform

[![Deploy PandaFit Web](https://github.com/LiviuOloi/panda-fit/actions/workflows/deploy.yml/badge.svg)](https://github.com/LiviuOloi/panda-fit/actions/workflows/deploy.yml)
[![Build Android APK](https://github.com/LiviuOloi/panda-fit/actions/workflows/build-apk.yml/badge.svg)](https://github.com/LiviuOloi/panda-fit/actions/workflows/build-apk.yml)
[![Latest Android APK](https://img.shields.io/badge/Download-Android%20APK-10B981?logo=android&logoColor=white)](https://github.com/LiviuOloi/panda-fit/releases/download/mobile-latest/PandaFit.apk)
[![Live Web Demo](https://img.shields.io/badge/Live-Web%20App-06B6D4?logo=googlechrome&logoColor=white)](https://liviuoloi.github.io/panda-fit/)

A high-precision, cross-platform health, weight, body composition, nutrition, and workout logging platform engineered for sustainable outcomes:
1. **Glycemic & HbA1c Optimization** (low GI complex carbohydrates, weighed vegetables, healthy fats, lean protein).
2. **Gradual, Healthy Fat Loss (Cutting) or Controlled Muscle Gain (Bulking)**.
3. **Analytical Rigor Over Gimmicks** (7-day rolling moving averages to eliminate water weight noise, net calorie balancing, objective mission milestones, and pessimistic workout MET discounting).

Runs seamlessly on **Web**, **Android**, and **iOS** from a single Flutter & Dart codebase, powered by a 100% free cloud stack (Supabase PostgreSQL Free Tier).

---

## 📚 Core Documentation Index

- **[PandaFit.md](PandaFit.md)** — Product specifications, domain rules, and meal guidelines.
- **[AGENTS.md](AGENTS.md)** — Master engineering guardrails, strict mathematical invariants, agent operating protocols, and Definition of Done.
- **[ARCHITECTURE.md](ARCHITECTURE.md)** — System architecture diagrams, Riverpod state pipelines, offline-first caching, navigation tree, and design tokens.
- **[supabase/schema.sql](supabase/schema.sql)** — Production DDL schema with Row Level Security (RLS) policies, triggers, and meal seeds.

---

## 🛠️ Tech Stack (100% Free & Open Source)

- **Framework:** [Flutter 3.32+](https://flutter.dev) & Dart 3.8+
- **Backend & Cloud DB:** [Supabase](https://supabase.com) (PostgreSQL 15+, Auth, Realtime, RLS)
- **State Management:** [Flutter Riverpod](https://riverpod.dev) (`flutter_riverpod`)
- **Data Visualization:** [`fl_chart`](https://pub.dev/packages/fl_chart)
- **Local Storage & Offline Queue:** `shared_preferences`
- **Barcode & Computer Vision:** `mobile_scanner` (60 FPS camera engine) + OpenFoodFacts REST API
- **AI Engine:** Google Generative AI (`google_generative_ai` / Gemini 1.5 & 2.0 Flash) with multimodal vision label extraction, fallback cascade, and deterministic offline engine
- **Local Notifications & Alarms:** `flutter_local_notifications` + `timezone`
- **PDF & Document Export:** `pdf` + `printing`
- **Design System:** Material 3 Dark & Glassmorphism Theme (Emerald `#10B981`, Cyan `#06B6D4`, Slate `#0F172A`, Amber `#F59E0B`, Rose `#F43F5E`)

---

## 🤖 Features Highlight

### 1. 📊 Analytical Weight Tracking & 7-Day Moving Average
- **7-Day Rolling Moving Average ($\text{MA}_7$):** Filters out misleading water weight and digestive spikes to show genuine fat loss or muscle gain trends.
- **Interactive Time-Series Charts:** Built with vector `fl_chart`, showcasing daily morning weigh-ins, 7-day trendlines, and active mission target thresholds.
- **Strict Starting Weight Lock:** Initial profile starting weight is permanently locked once the first daily entry is saved, preventing revisionist history.

### 2. 🎯 Cutting & Bulking Missions Engine
- **Structured Targets:** Set goal weights with strict inequality completion requirements ($< \text{target}$ for cutting, $> \text{target}$ for bulking).
- **ETA & Weekly Pace Forecasting:** Dynamic prediction of arrival date based on actual rolling weight velocity.
- **Achievement Confetti & Archival:** Automatic milestone celebrations and historical record keeping.

### 3. 🏋️ Full Workout Tracker & Split Engine
- **30+ Exercise Library:** Covers all muscle groups (Chest, Back, Legs, Shoulders, Arms, Core, Cardio).
- **Pre-Built Templates:** Push, Pull, Legs, Full Body, Upper Body, Cardio & HIIT.
- **Active Workout Logger:** Real-time stopwatch, set weight (kg), reps, RPE, and set completion checkboxes.
- **Rest Timer with Vibration:** Configurable 90s/120s timer with `-15s` / `+30s` controls, progress bar, and automatic haptic vibration on completion.
- **Pessimistic MET Burn Sync:** Automatic calorie burn calculation factoring in user body weight and resistance rest intervals, seamlessly integrated with the Daily Logger.

### 4. 🐼 Panda Eats AI Coach, Multimodal Vision & Barcode Scanner
- **Live Gemini AI Integration:** Conversational coach with multi-model fallback (`gemini-1.5-flash-latest` $\rightarrow$ `gemini-1.5-flash` $\rightarrow$ `gemini-2.0-flash` $\rightarrow$ `gemini-pro` $\rightarrow$ Offline Rule-Based Engine).
- **Photo Nutrition Label Scanner:** Upload or snap photos of nutrition labels; Gemini automatically extracts macronutrients per 100g and crafts custom recipes.
- **60 FPS Barcode Scanner:** Real-time camera barcode scanner powered by OpenFoodFacts with instant tactile haptic feedback on recognition.
- **Custom Recipes & Menu Manager:** Save recipes directly from AI or barcode scans to your personal breakfast, snack, and dinner catalog with raw/dry weighing notes.

### 5. 📑 Clinical Health Reports & Multi-Format Exports
- **KPI Analysis:** Calculates Basal Metabolic Rate (BMR), Maintenance TDEE, Caloric Deficit, Diet Adherence Rate, and Logging Streaks.
- **Printable Clinical PDF:** Generates formatted A4 health reports for medical or coaching consultations.
- **Excel / CSV & Full JSON Backup:** Direct data ownership with UTF-8 BOM CSV exports and JSON backups.

### 6. 📱 Native Mobile Polish & Offline-First Resilience
- **Native Android & iOS Icons:** Slate & emerald adaptive launcher icons generated for all mobile screen densities.
- **Instant Dark Splash Screen:** Zero white flash on app startup (`#0F172A` theme).
- **System UI Immersive Styling:** Transparent dark status bar and compact navigation bar with Safe Area support.
- **Haptic Feedback:** Tactile pulses for tab navigation, set completion, workout saving, timer expiration, and barcode scanning.
- **Offline Sync Queue:** Works seamlessly in basement gyms or with airplane mode; logs save locally and sync automatically when online.
- **Local Scheduled Notifications:** Configurable daily reminders for morning weigh-ins (07:30 AM) and evening journals (21:00 PM).

---

## 🚀 Getting Started

### 1. Database Setup (Supabase Free Tier)
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

### 4. Direct Android Installation
Download the compiled release APK directly to your phone:
👉 **[Download PandaFit.apk](https://github.com/LiviuOloi/panda-fit/releases/download/mobile-latest/PandaFit.apk)**
