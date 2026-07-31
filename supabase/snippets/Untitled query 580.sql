-- =======================================================================
-- PHASE 1 CLEANUP: Fix matches.status default value mismatch
-- The DB defaulted to 'pending' but all app code inserts and filters
-- on 'scheduled'. This aligns the DB default with the app's convention.
-- =======================================================================

-- 1. Fix any existing rows that slipped through with 'pending' status
--    (seed data or any match created before this migration)
UPDATE public.matches
  SET status = 'scheduled'
  WHERE status = 'pending';

-- 2. Update the column default so new rows are consistent
ALTER TABLE public.matches
  ALTER COLUMN status SET DEFAULT 'scheduled';