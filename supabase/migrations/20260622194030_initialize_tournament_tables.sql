-- =======================================================================
-- 1. DROP PRE-EXISTING TABLES (CLEAN RESETS)
-- =======================================================================
DROP TABLE IF EXISTS public.matches CASCADE;
DROP TABLE IF EXISTS public.players CASCADE;
DROP TABLE IF EXISTS public.groups CASCADE;
DROP TABLE IF EXISTS public.tournaments CASCADE;

-- =======================================================================
-- 2. CREATE TOURNAMENTS TABLE
-- =======================================================================
CREATE TABLE public.tournaments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    status TEXT DEFAULT 'upcoming'::text NOT NULL,
    settings JSONB DEFAULT '{"best_of": {"final": 7, "semi-final": 5, "round-robin": 3, "quarter-final": 5}}'::jsonb NOT NULL,
    round_robin_sets INT DEFAULT 3 NOT NULL,
    knockout_sets INT DEFAULT 5 NOT NULL,
    knockout_format TEXT DEFAULT 'league_topper' NOT NULL,
    dr_form_url TEXT,
    dr_sheet_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,

    -- Enforces tournament formatting rules at the database engine layer
    CONSTRAINT valid_knockout_format CHECK (
        knockout_format IN ('league_topper', 'finals', 'sf', 'qf', 'r16', 'r32')
    )
);

ALTER TABLE public.tournaments ENABLE ROW LEVEL SECURITY;

-- =======================================================================
-- 3. CREATE GROUPS TABLE
-- =======================================================================
CREATE TABLE public.groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID,
    class_tier TEXT NOT NULL,
    group_name TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,

    CONSTRAINT groups_tournament_id_fkey 
        FOREIGN KEY (tournament_id) 
        REFERENCES public.tournaments(id) 
        ON DELETE CASCADE
);

ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;

-- =======================================================================
-- 4. CREATE PLAYERS TABLE
-- =======================================================================
CREATE TABLE public.players (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID,
    name TEXT NOT NULL,
    class_tier TEXT DEFAULT 'Beginner'::text NOT NULL,
    group_label TEXT DEFAULT 'Group A'::text NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,

    CONSTRAINT players_tournament_id_fkey 
        FOREIGN KEY (tournament_id) 
        REFERENCES public.tournaments(id) 
        ON DELETE CASCADE
);

ALTER TABLE public.players ENABLE ROW LEVEL SECURITY;

-- =======================================================================
-- 5. CREATE MATCHES TABLE
-- =======================================================================
CREATE TABLE public.matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID,
    group_id UUID,
    player1_id UUID,
    player2_id UUID,
    winner_id UUID,
    player1_name_fallback TEXT,
    player2_name_fallback TEXT,
    stage TEXT NOT NULL,
    status TEXT DEFAULT 'pending'::text NOT NULL,
    player1_score INTEGER DEFAULT 0 NOT NULL,
    player2_score INTEGER DEFAULT 0 NOT NULL,
    scores JSONB DEFAULT '[]'::jsonb NOT NULL,
    set_scores JSONB DEFAULT '[]'::jsonb NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,

    -- Foreign Key Constraint Relations
    CONSTRAINT matches_tournament_id_fkey 
        FOREIGN KEY (tournament_id) 
        REFERENCES public.tournaments(id) 
        ON DELETE CASCADE,
        
    CONSTRAINT matches_group_id_fkey 
        FOREIGN KEY (group_id) 
        REFERENCES public.groups(id) 
        ON DELETE CASCADE,
        
    CONSTRAINT matches_player1_id_fkey 
        FOREIGN KEY (player1_id) 
        REFERENCES public.players(id) 
        ON DELETE CASCADE,
        
    CONSTRAINT matches_player2_id_fkey 
        FOREIGN KEY (player2_id) 
        REFERENCES public.players(id) 
        ON DELETE CASCADE,
        
    CONSTRAINT matches_winner_id_fkey 
        FOREIGN KEY (winner_id) 
        REFERENCES public.players(id)
);

ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;

-- =======================================================================
-- 6. PERFORMANCE ACCELERATION INDEXES
-- =======================================================================
CREATE INDEX idx_players_tournament_lookup ON public.players(tournament_id);
CREATE INDEX idx_matches_tournament_lookup ON public.matches(tournament_id);
CREATE INDEX idx_groups_tournament_lookup ON public.groups(tournament_id);

-- =======================================================================
-- 7. ROW LEVEL SECURITY POLICIES (RLS)
-- =======================================================================

-- Tournaments Table Policies
CREATE POLICY "Allow public insert" ON public.tournaments FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Allow public select" ON public.tournaments FOR SELECT TO public USING (true);

-- Groups Table Policies
CREATE POLICY "Allow public insert" ON public.groups FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Allow public select" ON public.groups FOR SELECT TO public USING (true);

-- Players Table Policies
CREATE POLICY "Allow public insert" ON public.players FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Allow public select" ON public.players FOR SELECT TO public USING (true);

-- Matches Table Policies
CREATE POLICY "Allow public all" ON public.matches FOR ALL TO public USING (true);
CREATE POLICY "Allow public select" ON public.matches FOR SELECT TO public USING (true);

-- =======================================================================
-- 8. SYSTEM ROLE PERMISSION GRANTS
-- =======================================================================
GRANT ALL PRIVILEGES ON TABLE public.tournaments TO anon, authenticated, service_role;
GRANT ALL PRIVILEGES ON TABLE public.groups TO anon, authenticated, service_role;
GRANT ALL PRIVILEGES ON TABLE public.players TO anon, authenticated, service_role;
GRANT ALL PRIVILEGES ON TABLE public.matches TO anon, authenticated, service_role;