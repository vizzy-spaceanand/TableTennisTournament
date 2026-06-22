-- Inject a jsonb array column to hold per-set granular point metrics
ALTER TABLE matches ADD COLUMN IF NOT EXISTS set_scores JSONB DEFAULT '[]'::jsonb;