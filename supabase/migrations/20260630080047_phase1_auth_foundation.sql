-- =======================================================================
-- PHASE 1: AUTH FOUNDATION
-- Adds ownership tracking to tournaments and locks down RLS so that
-- writes require login while reads stay fully public.
-- =======================================================================

-- =======================================================================
-- 1. ADD OWNERSHIP COLUMN
-- =======================================================================
ALTER TABLE public.tournaments
  ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id);

-- Existing rows (pre-auth data) are left with created_by = NULL.
-- They remain publicly readable but are not editable by anyone until
-- manually claimed (not in scope for Phase 1).

CREATE INDEX IF NOT EXISTS idx_tournaments_created_by
  ON public.tournaments(created_by);

-- =======================================================================
-- 2. DROP OLD PERMISSIVE POLICIES
-- =======================================================================
DROP POLICY IF EXISTS "Allow public insert" ON public.tournaments;
DROP POLICY IF EXISTS "Allow public select" ON public.tournaments;

DROP POLICY IF EXISTS "Allow public insert" ON public.groups;
DROP POLICY IF EXISTS "Allow public select" ON public.groups;

DROP POLICY IF EXISTS "Allow public insert" ON public.players;
DROP POLICY IF EXISTS "Allow public select" ON public.players;

DROP POLICY IF EXISTS "Allow public all" ON public.matches;
DROP POLICY IF EXISTS "Allow public select" ON public.matches;

-- =======================================================================
-- 3. TOURNAMENTS — public read, owner-only write
-- =======================================================================
CREATE POLICY "public can read tournaments"
ON public.tournaments FOR SELECT
TO public
USING (true);

CREATE POLICY "authenticated users can create tournaments"
ON public.tournaments FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = created_by);

CREATE POLICY "owner can update own tournaments"
ON public.tournaments FOR UPDATE
TO authenticated
USING (auth.uid() = created_by)
WITH CHECK (auth.uid() = created_by);

CREATE POLICY "owner can delete own tournaments"
ON public.tournaments FOR DELETE
TO authenticated
USING (auth.uid() = created_by);

-- =======================================================================
-- 4. GROUPS — public read, write only if you own the parent tournament
-- =======================================================================
CREATE POLICY "public can read groups"
ON public.groups FOR SELECT
TO public
USING (true);

CREATE POLICY "tournament owner can write groups"
ON public.groups FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.tournaments t
    WHERE t.id = groups.tournament_id
    AND t.created_by = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.tournaments t
    WHERE t.id = groups.tournament_id
    AND t.created_by = auth.uid()
  )
);

-- =======================================================================
-- 5. PLAYERS — public read, write only if you own the parent tournament
-- =======================================================================
CREATE POLICY "public can read players"
ON public.players FOR SELECT
TO public
USING (true);

CREATE POLICY "tournament owner can write players"
ON public.players FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.tournaments t
    WHERE t.id = players.tournament_id
    AND t.created_by = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.tournaments t
    WHERE t.id = players.tournament_id
    AND t.created_by = auth.uid()
  )
);

-- =======================================================================
-- 6. MATCHES — public read, write only if you own the parent tournament
-- =======================================================================
CREATE POLICY "public can read matches"
ON public.matches FOR SELECT
TO public
USING (true);

CREATE POLICY "tournament owner can write matches"
ON public.matches FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.tournaments t
    WHERE t.id = matches.tournament_id
    AND t.created_by = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.tournaments t
    WHERE t.id = matches.tournament_id
    AND t.created_by = auth.uid()
  )
);

-- =======================================================================
-- 7. TIGHTEN GRANTS
-- Previously: GRANT ALL to anon, authenticated, service_role (RLS was the
-- only thing stopping writes, and RLS allowed everything). Now that RLS
-- is locked down, anon no longer needs INSERT/UPDATE/DELETE grants at all.
-- =======================================================================
REVOKE INSERT, UPDATE, DELETE ON public.tournaments FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.groups FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.players FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.matches FROM anon;

GRANT SELECT ON public.tournaments TO anon;
GRANT SELECT ON public.groups TO anon;
GRANT SELECT ON public.players TO anon;
GRANT SELECT ON public.matches TO anon;

GRANT ALL PRIVILEGES ON TABLE public.tournaments TO authenticated, service_role;
GRANT ALL PRIVILEGES ON TABLE public.groups TO authenticated, service_role;
GRANT ALL PRIVILEGES ON TABLE public.players TO authenticated, service_role;
GRANT ALL PRIVILEGES ON TABLE public.matches TO authenticated, service_role;