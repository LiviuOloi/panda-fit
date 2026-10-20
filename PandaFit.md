# Panda Fit — Health, Weight & Nutrition Tracking Platform

*Master Configuration, Architecture Specification, and Domain Guardrails (`PandaFit.md`)*

---

## 1. Project Context & Vision

**Panda Fit** este o aplicație modernă, completă și intuitivă de monitorizare a greutății, compoziției corporale, nutriției și activităților fizice, proiectată pentru a asigura rezultate sustenabile (optimizare glicemică / HbA1c, slăbire graduală sau bulking controlat).

Aplicația combină rigoarea analitică (medie mobilă pe 7 zile, calcul precis al caloriilor nete, urmărire a misiunilor de greutate, calcul pesimist al arderilor la sală) cu o experiență de utilizare de nivel premium (interfață modernă, grafice interactive, formulare rapide de logging zilnic, asistent AI multimodal și tracker complet de forță).

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
* **Local Storage & Offline Queue:** `shared_preferences` cu sincronizare automată la reconectare.
* **Camera & Barcode Scanner:** `mobile_scanner` (60 FPS camera engine) + OpenFoodFacts REST API.
* **AI Engine:** Google Generative AI (`google_generative_ai` / Gemini 1.5 & 2.0 Flash) cu cascadă de fallback automată, analiză multimodală de etichete și motor offline determinist.
* **Notificări Locale & Alarme:** `flutter_local_notifications` + `timezone`.
* **Rapoarte Medicale & Documente:** `pdf` + `printing`.
* **Styling & Design System:** Material 3 Dark Theme personalizat + Glassmorphism, paletă curatoriată (Emerald / Cyan / Slate / Amber / Rose).
* **Feedback Tactil:** Haptic feedback nativ pentru sală, scanare și navigație.

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
* **Arhivare și Misiuni noi:** Doar o misiune poate fi activă simultan. La îndeplinire, statusul trece în `ACCOMPLISHED`, iar utilizatorul este invitat să își configureze următoarea misiune.

### 4.4. Nutrition & Meal Protocol
* **Măsurare precisă:**
  * Carnea / Proteina: Cântărită **crudă**.
  * Orezul / Carbohidrații complecși: Cântăriți **uscați / nepreparați**.
  * Legumele: Cântărite **crude / congelate**.
  * Uleiul de gătit: Măsurat cu lingurița sau cântărit în grame (niciodată turnat „din ochi”).
* **Control Glicemic & HbA1c:** Prioritizarea carbohidraților cu indice glicemic scăzut (pâine graham/secară, orez basmati, ovăz integral) și a fibrelor vegetale mari (broccoli, fasole verde, ciuperci).

---

## 5. Functional Modules & UI Architecture

### 1. Dashboard & Metric Overview
* Carduri principale: Greutate Start, Greutate Curentă, Medie 7 zile, $\Delta$ Total, Status Misiune curentă.
* Target Progress Bar (progresul către atingerea misiunii de Cutting/Bulking).
* Grafic interactiv `fl_chart`: Evoluția greutății zilnice vs. Medie mobilă pe 7 zile vs. Linie de target.

### 2. Daily Logger (Offline-First)
* Input rapid pentru greutatea de dimineață.
* Selector dinamic pentru cină bazat pe meniul personal.
* Calculator pesimist de calorii pentru activități fizice (înot, sală cu MET ponderat, cardio).
* Salvare locală automată offline cu sincronizare în fundal când revine conexiunea.

### 3. Workout Tracker & Split Engine
* **Bibliotecă de 30+ exerciții** pe toate grupele musculare (Piept, Spate, Picioare, Umeri, Brațe, Core, Cardio).
* **Șabloane gata configurate:** Push Day, Pull Day, Leg Day, Full Body, Upper Body, Cardio & HIIT.
* **Logger activ de antrenament:** Cronometru live, setare greutăți (kg), repetări, RPE și bifare serii cu feedback haptic.
* **Rest Timer cu vibrație:** Cronometru de pauză între serii (90s/120s) cu butoane `-15s` / `+30s` și vibrație automată la 0.
* **Calcul automat de volum (kg)** și sincronizare a caloriilor arse cu jurnalul zilnic.

### 4. Panda Eats AI Coach & Personal Recipe Manager
* **Scanare Etichetă & Analiză Multimodală (Computer Vision):** Trimitere poze cu etichete nutriționale sau alimente direct din cameră sau galerie. Extragere automată macronutrienți per 100g și calcul porții cântărite.
* **Scaner Coduri de Bare la 60 FPS:** Scanare video instantanee a codurilor de bare din magazin prin OpenFoodFacts cu vibrație tactilă de confirmare.
* **Chat Interactiv AI:** Consultanță nutrițională personalizată cu cascadă automată multi-model Gemini.
* **Salvare Rețete în Meniu Personal:** Adăugare directă din chat sau scaner în catalogul propriu de rețete.

### 5. Clinical Health Reports & Multi-Format Exports
* **Raport Medical PDF A4:** Generare document printabil cu parametri clinici (BMR, TDEE, deficit, ritm săptămânal, aderență).
* **Export Excel CSV (UTF-8 BOM)** și **Backup complet JSON** pentru proprietate totală asupra datelor.

### 6. Missions Hub
* Misiunea Activă cu indicator de status strict ($< \text{Target}$ pentru Cutting, $> \text{Target}$ pentru Bulking).
* Estimare ETA dinamică bazată pe ritmul săptămânal real.
* Confeti la atingerea țintei și istoric complet al misiunilor îndeplinite.

### 7. Profile, Setări & Notificări Locale
* Date personale, calcul vârstă, vizualizare greutate inițială blocată.
* **Mementouri Locale Programate:** Reamintire zilnică pentru cântărire dimineața (ex: 07:30) și salvare jurnal seara (ex: 21:00).
* **Card Descărcare Nativă Android:** Buton direct pentru descărcarea fișierului `PandaFit.apk`.

---

## 6. Native Packaging & CI/CD Pipeline

* **GitHub Pages Web Deployment:** Automatizat prin `.github/workflows/deploy.yml`.
* **Automated Android APK Release:** Automatizat prin `.github/workflows/build-apk.yml`, cu publicare automată în GitHub Releases la adresa `https://github.com/LiviuOloi/panda-fit/releases/tag/mobile-latest`.
* **Splash Screen Dark & App Icons:** Iconițe adaptive pe toate densitățile Android/iOS și pornire fără flash alb (`#0F172A`).
