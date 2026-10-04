-- ============================================================================
-- PandaFit PostgreSQL Schema for Supabase (Production DDL)
-- ============================================================================

-- 1. PROFILES TABLE (Extends auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
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
CREATE TABLE IF NOT EXISTS public.daily_entries (
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
CREATE INDEX IF NOT EXISTS idx_daily_entries_user_date ON public.daily_entries (user_id, entry_date DESC);

-- 3. MISSIONS TABLE
CREATE TABLE IF NOT EXISTS public.missions (
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
    -- Invariant: Cutting target must be strictly lower than start, bulking strictly higher
    CONSTRAINT check_mission_logic CHECK (
        (mission_type = 'CUTTING' AND target_weight < mission_start_weight) OR
        (mission_type = 'BULKING' AND target_weight > mission_start_weight)
    )
);

CREATE INDEX IF NOT EXISTS idx_missions_user_status ON public.missions (user_id, status);

-- 4. MEAL RECIPES TABLE
CREATE TABLE IF NOT EXISTS public.meal_recipes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE, -- NULL for system templates, set for personal user recipes
    category TEXT NOT NULL CHECK (category IN ('BREAKFAST', 'SNACK', 'DINNER', 'CUSTOM')),
    code TEXT,
    title TEXT NOT NULL,
    ingredients JSONB NOT NULL,
    calories INTEGER NOT NULL,
    protein_g NUMERIC(5,1),
    carbs_g NUMERIC(5,1),
    fat_g NUMERIC(5,1),
    instructions TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_meal_recipes_user ON public.meal_recipes (user_id);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.missions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meal_recipes ENABLE ROW LEVEL SECURITY;

-- Profiles Policies
DO $$ BEGIN
    DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
    CREATE POLICY "Users can view own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
    
    DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
    CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);
    
    DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
    CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);
END $$;

-- Daily Entries Policies
DO $$ BEGIN
    DROP POLICY IF EXISTS "Users can CRUD own daily entries" ON public.daily_entries;
    CREATE POLICY "Users can CRUD own daily entries" ON public.daily_entries
        FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
END $$;

-- Missions Policies
DO $$ BEGIN
    DROP POLICY IF EXISTS "Users can CRUD own missions" ON public.missions;
    CREATE POLICY "Users can CRUD own missions" ON public.missions
        FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
END $$;

-- Meal Recipes Policies (System templates public, custom recipes user-specific)
DO $$ BEGIN
    DROP POLICY IF EXISTS "Anyone can view system or own meal recipes" ON public.meal_recipes;
    CREATE POLICY "Anyone can view system or own meal recipes" ON public.meal_recipes
        FOR SELECT USING (user_id IS NULL OR user_id = auth.uid());

    DROP POLICY IF EXISTS "Users can insert own meal recipes" ON public.meal_recipes;
    CREATE POLICY "Users can insert own meal recipes" ON public.meal_recipes
        FOR INSERT WITH CHECK (user_id = auth.uid());

    DROP POLICY IF EXISTS "Users can update own meal recipes" ON public.meal_recipes;
    CREATE POLICY "Users can update own meal recipes" ON public.meal_recipes
        FOR UPDATE USING (user_id = auth.uid());

    DROP POLICY IF EXISTS "Users can delete own meal recipes" ON public.meal_recipes;
    CREATE POLICY "Users can delete own meal recipes" ON public.meal_recipes
        FOR DELETE USING (user_id = auth.uid());
END $$;

-- ============================================================================
-- DATABASE TRIGGERS & GUARDRAILS
-- ============================================================================

-- Guardrail: Enforce immutable profile_start_weight once daily entries exist
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

DROP TRIGGER IF EXISTS trg_lock_profile_start_weight ON public.profiles;
CREATE TRIGGER trg_lock_profile_start_weight
BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION check_profile_start_weight_lock();

-- ============================================================================
-- SEED INITIAL MEAL RECIPES
-- ============================================================================
INSERT INTO public.meal_recipes (category, code, title, ingredients, calories, protein_g, carbs_g, fat_g, instructions)
VALUES
(
    'BREAKFAST',
    'BREAKFAST_STD',
    'Standard High-Protein Omelet & Greens',
    '[
        {"name": "Whole Eggs", "amount": "3 pcs", "state": "raw"},
        {"name": "Cottage Cheese Light (3%)", "amount": "100g", "state": "ready"},
        {"name": "Broccoli", "amount": "80g", "state": "frozen/raw"},
        {"name": "Green Beans", "amount": "60g", "state": "frozen/raw"},
        {"name": "Mushrooms", "amount": "60g", "state": "raw"},
        {"name": "Graham Bread", "amount": "70-80g", "state": "ready"},
        {"name": "Olive Oil (Measured)", "amount": "5g", "state": "measured"}
    ]'::jsonb,
    620,
    42.0,
    48.0,
    26.0,
    'Whisk eggs. Sauté veggies in measured oil. Cook omelet, serve with light cottage cheese and weighed graham bread.'
),
(
    'SNACK',
    'SNACK_GREEK_BERRY',
    'Greek Yogurt & Berry Antioxidant Bowl',
    '[
        {"name": "Greek Yogurt (2%)", "amount": "150g", "state": "ready"},
        {"name": "Blueberries", "amount": "75g", "state": "raw"},
        {"name": "Chia Seeds", "amount": "10g", "state": "raw"},
        {"name": "Natural Peanut Butter", "amount": "10g", "state": "measured"}
    ]'::jsonb,
    240,
    18.0,
    18.0,
    9.5,
    'Mix Greek yogurt with chia seeds, top with fresh/frozen blueberries and natural peanut butter.'
),
(
    'DINNER',
    'DINNER_A',
    'Dinner Option A: Lean Chicken Breast, Rice & Pickles',
    '[
        {"name": "Chicken Breast", "amount": "200-250g", "state": "raw/weighed"},
        {"name": "Panzani / Basmati Rice", "amount": "125g", "state": "dry/uncooked"},
        {"name": "Mixed Stir-Fry Veggies", "amount": "250g", "state": "frozen/raw"},
        {"name": "Pickles in Brine", "amount": "50-100g", "state": "ready"},
        {"name": "Olive Oil", "amount": "0-5g", "state": "measured"}
    ]'::jsonb,
    780,
    62.0,
    105.0,
    8.0,
    'Boil 125g dry rice. Cook raw chicken and veggies with 0-5g measured oil. Serve with pickles.'
),
(
    'DINNER',
    'DINNER_B',
    'Dinner Option B: Pork Collar & High-Volume Veggies',
    '[
        {"name": "Pork Collar (Ceafa)", "amount": "180-200g", "state": "raw/weighed"},
        {"name": "Mixed Vegetables", "amount": "300g", "state": "frozen/raw"},
        {"name": "Pickles in Brine", "amount": "50-100g", "state": "ready"}
    ]'::jsonb,
    540,
    44.0,
    20.0,
    32.0,
    'Pan-sear raw pork collar in own fat (no oil added). Steam or stir-fry 300g veggies. Serve with pickles.'
),
(
    'DINNER',
    'DINNER_C',
    'Dinner Option C: Chicken Breast & Air-Fried Potato Wedges',
    '[
        {"name": "Chicken Breast", "amount": "200-250g", "state": "raw/weighed"},
        {"name": "Gustona Potato Wedges", "amount": "200g", "state": "raw/frozen"},
        {"name": "Pickles in Brine", "amount": "50-100g", "state": "ready"}
    ]'::jsonb,
    610,
    58.0,
    48.0,
    14.0,
    'Air-fry 200g potato wedges. Grill raw seasoned chicken breast. Accompany with pickles.'
)
ON CONFLICT (code) DO NOTHING;
