# Panda Fit — Health, Weight & Nutrition Tracking Platform

*Master Configuration, Architecture Specification, and Domain Guardrails (`PandaFit.md`)*

---

## 1. Project Context & Vision

**Panda Fit** este o aplicație modernă, completă și intuitivă de monitorizare a greutății, compoziției corporale, nutriției și activităților fizice, proiectată pentru a asigura rezultate sustenabile (optimizare glicemică / HbA1c, slăbire graduală sau bulking controlat).

Aplicația combină rigoarea analitică (medie mobilă pe 7 zile, calcul precis al caloriilor nete, urmărire a misiunilor de greutate) cu o experiență de utilizare de nivel premium (interfață modernă, grafice interactive, formulare rapide de logging zilnic și ghid de mese integrat).

---

## 2. AI Agent Role & Persona

* **Role:** Senior Full-Stack Software Engineer, QA Architect & Fitness Domain Expert.
* **Tone:** Structurat, pragmatic, orientat pe calitate software, validări robuste și arhitectură curată (SOLID).
* **Approach:** Construcție modulară, validări complete la nivel de client și server, experiență vizuală de top și cod gata de producție.

---

## 3. Tech Stack & Architecture (100% Free & Open Source)

* **Framework:** Flutter 3.32+ (Dart 3.8+) multi-platform (Web, Android, iOS).
* **Backend & Cloud DB:** Supabase (PostgreSQL 15+, Auth, Realtime WebSocket, PostgREST API cu Row Level Security RLS).
* **State Management:** Flutter Riverpod (`flutter_riverpod`).
* **Data Visualization:** `fl_chart` (Grafic interactiv greutate zilnică vs. Medie mobilă 7 zile vs. Target Mission).
* **AI Engine:** Google Generative AI (`google_generative_ai` / Gemini 1.5 & 2.0 Flash) cu cascadă de fallback automată și motor offline determinist.
* **Styling & Design System:** Material 3 Dark Theme personalizat + Glassmorphism, paletă curatoriată (Emerald / Cyan / Slate / Amber / Rose).
* **Icons & UI Extras:** Material Symbols / Lucide Icons, carduri glassmorphic cu micro-animații fluide.

---

## 4. Core Domain Rules & Business Logic

### 4.1. User Profile & Baseline Identity
1. **User Identification:** `user_id` unic în baza de date. Câmpuri profil: Prenume, Nume, Username unic, Sex, Data Nașterii (calcul automat al vârstei), Înălțime (cm).
2. **Profile Starting Weight:**
   * Reprezintă greutatea inițială la înscrierea în aplicație.
   * *Regulă de aur:* Poate fi editată doar până la crearea primei înregistrări zilnice (Daily Entry). După prima înregistrare, devine **read-only** pentru a nu denatura istoricul.
   * Nu se suprascrie automat la introducerea de noi Daily Entries.

### 4.2. Precision & Calculations
* **Precizia greutății:** `0.1 kg` (ex: `102.4 kg`, `102.2 kg`).
* **Media mobilă pe 7 zile (7-Day Moving Average):**
  $$\text{MA}_7 = \frac{\sum_{i=0}^{k-1} \text{Greutate}_{t-i}}{k}, \quad k = \min(\text{număr zile disponibile}, 7)$$
  *Important:* Fluctuațiile zilnice de apă/glicogen sunt estompate prin urmărirea mediei pe 7 zile.
* **$\Delta$ față de start:** $\text{Greutate curentă} - \text{Profile Starting Weight}$.
* **Calorii Nete:** $\text{Total Calorii} = \text{Calorii Ingerate} - \text{Calorii Consumate (Arse)}$.

### 4.3. Missions Engine (Cutting vs. Bulking)
Obiectivele de greutate sunt tratate ca **Misiuni active**:
* **Mission Starting Weight:** Greutatea utilizatorului în momentul demarării misiunii curente (diferită de Starting Weight-ul inițial din profil).
* **Tipuri de misiune:**
  * **Cutting:** $\text{Target Weight} < \text{Mission Starting Weight}$
  * **Bulking:** $\text{Target Weight} > \text{Mission Starting Weight}$
  * *Validare:* $\text{Target Weight} == \text{Mission Starting Weight}$ este invalid (diferență minimă de $0.1\text{ kg}$).
* **Regulă strictă de îndeplinire (Strict Inequality):**
  * **Cutting Accomplished:** $\text{Current Weight} < \text{Target Weight}$ (atingerea exactă a targetului NU este suficientă; ex: la target 95.0 kg, devine îndeplinit la 94.9 kg).
  * **Bulking Accomplished:** $\text{Current Weight} > \text{Target Weight}$ (ex: la target 100.0 kg, devine îndeplinit la 100.1 kg).
* **Missions Accomplished (Istoric):** La finalizarea unei misiuni, aceasta se arhivează cu data reușitei, greutatea de start, greutatea țintă și durata, permițând inițierea unei noi misiuni.

### 4.4. Nutrition & Activity Rules (Sincronizat cu Google Sheet)
* **Țintă calorică:** $\sim 2300\text{ kcal/zi}$ (ajustabilă în funcție de trendul greutății).
* **Priorități:**
  1. Optimizare glicemică / HbA1c (carbohidrați complecși, indice glicemic redus, fibre, legume cântărite).
  2. Slăbire graduală sănătoasă.
* **Plan Mese Predefinite (Quick Templates):**
  * **Mic Dejun:** Omletă (3 ouă, 100g Cottage Cheese Light 3%, 200g legume: 80g broccoli + 60g fasole verde + 60g ciuperci, 70-80g pâine Graham, ulei de măsline măsurat).
  * **Gustare:** Iaurt & afine (150g iaurt grecesc 2%, 75g afine, 10g chia, 10g unt de arahide).
  * **Cină A:** Pui + orez (200-250g piept pui crud, 125g orez Panzani uscat, 250g legume, 50-100g murături, 0-5g ulei).
  * **Cină B:** Ceafă + legume (180-200g ceafă crudă fără orez, 300g legume, 50-100g murături, fără ulei).
  * **Cină C:** Pui + wedges (200-250g piept pui crud, 200g wedges Gustona, 50-100g murături).
* **Reguli cântărire alimente:** Măsurare în stare crudă / uscată înainte de preparare; legume cântărite congelate.
* **Activități:** Urmărire Înot (Da/Nu), Antrenamente sală, Plan respectat (Da/Nu).

---

## 5. Database Schema (Prisma Blueprint)

```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "sqlite" // Sau "postgresql" cu env("DATABASE_URL")
  url      = env("DATABASE_URL")
}

model User {
  id                  String       @id @default(cuid())
  email               String?      @unique
  username            String       @unique
  firstName           String
  lastName            String
  sex                 String       // "MALE" | "FEMALE" | "OTHER"
  birthDate           DateTime
  heightCm            Float
  profileStartWeight  Float
  dailyTargetCalories Int          @default(2300)
  createdAt           DateTime     @default(now())
  updatedAt           DateTime     @updatedAt

  dailyEntries        DailyEntry[]
  missions            Mission[]
}

model Mission {
  id                 String       @id @default(cuid())
  userId             String
  missionType        String       // "CUTTING" | "BULKING"
  missionStartWeight Float
  targetWeight       Float
  status             String       @default("ACTIVE") // "ACTIVE" | "ACCOMPLISHED" | "ABANDONED"
  startedAt          DateTime     @default(now())
  achievedAt         DateTime?

  user               User         @relation(fields: [userId], references: [id], onDelete: Cascade)
}

model DailyEntry {
  id              String       @id @default(cuid())
  userId          String
  date            DateTime     // Normalizat la YYYY-MM-DD
  weight          Float?       // Greutate cântărită dimineața (0.1 kg precizie)
  rollingAvg7Days Float?       // Calculat automat pe ultimele 7 zile
  swimming        Boolean      @default(false)
  planFollowed    Boolean      @default(true)
  caloriesIn      Int?         // Calorii ingerate
  caloriesOut     Int?         // Calorii consumate / arse prin efort
  netCalories     Int?         // caloriesIn - (caloriesOut || 0)
  selectedDinner  String?      // "A" | "B" | "C" | "CUSTOM"
  notes           String?
  createdAt       DateTime     @default(now())
  updatedAt       DateTime     @updatedAt

  user            User         @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@unique([userId, date])
}

model MealRecipe {
  id          String   @id @default(cuid())
  category    String   // "BREAKFAST" | "SNACK" | "DINNER"
  code        String?  // ex: "DINNER_A", "DINNER_B", "DINNER_C"
  title       String
  ingredients String   // JSON sau text detaliat
  calories    Int
  proteinG    Float?
  carbsG      Float?
  fatG        Float?
  instructions String?
}
```

---

## 6. Functional Modules & UI Architecture

1. **Dashboard & Metric Overview:**
   * Carduri principale: Greutate Start, Greutate Curentă, Medie 7 zile, $\Delta$ Total, Status Misiune curentă.
   * Target Progress Bar (progresul către atingerea misiunii de Cutting/Bulking).
   * Grafic interactiv: Evoluția greutății zilnice vs. Medie mobilă pe 7 zile vs. Linie de target.

2. **Daily Logger (Quick Modal / Inline Card):**
   * Input rapid pentru greutatea de dimineață.
   * Selector dinamic pentru cină bazat pe meniul personal (Rețete predefinite A/B/C + Rețete personalizate).
   * Calculator pesimist de calorii pentru activități fizice (înot, sală cu MET ponderat, cardio).
   * Input Calorii (Ingerate, Consumate) cu calcul automat al caloriilor nete.

3. **Panda Eats AI Coach & Personal Recipe Manager:**
   * **Scanare Etichetă & Analiză Multimodală (Computer Vision):** Trimitere poze cu etichete nutriționale / produse direct din cameră sau galerie. Extragere automată macronutrienți per 100g și calcul porții cântărite pentru obiectivele curente.
   * **Chat Interactiv AI:** Consultanță nutrițională personalizată în funcție de BMR, TDEE și target caloric.
   * **Generare Meniuri Tailored:** Sugestii de mese cu ingrediente cântărite crud/uscat și respectarea încărcăturii glicemice.
   * **Carduri Inline Persistente:** Meniurile generate sunt atașate fiecărui răspuns și salvate persistent în istoricul conversației.
   * **Salvare Rețete în Meniu Personal:** Buton instant de adăugare în meniul propriu pentru selecție rapidă în Daily Logger.
   * **Dialog Configurare Gemini API Key:** Ghid în 3 pași cu salvare securizată pe dispozitiv.

4. **Missions Hub:**
   * Misiunea Activă cu indicator de status strict ($< \text{Target}$ pentru Cutting, $> \text{Target}$ pentru Bulking).
   * Sărbătorire cu confeti la atingerea țintei.
   * Secțiunea **"Missions Accomplished"** cu istoricul tuturor obiectivelor atinse cu succes.

5. **Profile & Settings:**
   * Date personale, calcul automat vârstă, blocare automată a greutății de start după prima intrare.
   * Informații analitice: BMR (Basal Metabolic Rate), TDEE (Mentenanță) și Target Caloric recomandat.
