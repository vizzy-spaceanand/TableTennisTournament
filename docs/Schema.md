# Schema
> **Living Document** — Update this file in every PR that changes the database.
>
> **Last Updated:** June 2026 | **Version:** v0.1

---

## Table of Contents
1. [Current Schema (Pre-Auth)](#1-current-schema-pre-auth)
2. [Entity Relationship Overview](#2-entity-relationship-overview)
3. [Phase 1 Changes](#3-phase-1-changes)
4. [Phase 2 Changes](#4-phase-2-changes)
5. [Phase 3 Changes](#5-phase-3-changes)
6. [Phase 4 Changes](#6-phase-4-changes)
7. [Phase 5 Changes](#7-phase-5-changes)
8. [Phase 6 Changes](#8-phase-6-changes)
9. [Index Strategy](#9-index-strategy)

---

## 1. Current Schema (Pre-Auth)

Four tables. No auth. Full public access. RLS enabled but all policies allow everything.

### `tournaments`
| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | `gen_random_uuid()` |
| `name` | TEXT NOT NULL | |
| `status` | TEXT | `upcoming`, `active`, `completed` |
| `settings` | JSONB | Legacy best_of config |
| `round_robin_sets` | INT | Default 3 |
| `knockout_sets` | INT | Default 5 |
| `knockout_format` | TEXT | `league_topper`, `finals`, `sf`, `qf`, `r16`, `r32` |
| `dr_form_url` | TEXT | DR fallback Google Form |
| `dr_sheet_url` | TEXT | DR fallback Google Sheet |
| `created_at` | TIMESTAMPTZ | |

### `players`
| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | |
| `tournament_id` | UUID FK → tournaments | CASCADE delete |
| `name` | TEXT NOT NULL | ⚠️ Free text — replaced in Phase 2 |
| `class_tier` | TEXT | Beginner / Intermediate / Advanced |
| `group_label` | TEXT | Group A, Group B etc. |
| `created_at` | TIMESTAMPTZ | |

### `groups`
| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | |
| `tournament_id` | UUID FK → tournaments | |
| `class_tier` | TEXT | |
| `group_name` | TEXT | |
| `created_at` | TIMESTAMPTZ | |

> ⚠️ `groups` table is currently unused — `group_label` is stored directly on `players`. Will be properly wired in Phase 2.

### `matches`
| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | |
| `tournament_id` | UUID FK → tournaments | CASCADE delete |
| `group_id` | UUID FK → groups | Nullable, currently unused |
| `player1_id` | UUID FK → players | CASCADE delete |
| `player2_id` | UUID FK → players | CASCADE delete |
| `winner_id` | UUID FK → players | Nullable |
| `player1_name_fallback` | TEXT | Used since player names aren't in a registry yet |
| `player2_name_fallback` | TEXT | |
| `stage` | TEXT | `group`, `semifinal`, `final` etc. |
| `status` | TEXT | `scheduled`, `completed` |
| `player1_score` | INT | Sets won |
| `player2_score` | INT | Sets won |
| `scores` | JSONB | Legacy field |
| `set_scores` | JSONB | `[{"p1": 11, "p2": 8}, ...]` |
| `created_at` | TIMESTAMPTZ | |

---

## 2. Entity Relationship Overview

### Target state (all phases complete)
```
auth.users
    ├── player_profiles          (1:1 with auth.users)
    │       └── club_id          (FK → clubs, nullable)
    │
    └── clubs                    (created by auth.users as owner)
            └── club_admins      (owner, leader, co_leader)

clubs
    └── tournaments
            ├── tournament_players   (FK → player_profiles)
            ├── tournament_members   (organizer, scorekeeper)
            └── matches
                    ├── player1_id   (FK → player_profiles)
                    └── player2_id   (FK → player_profiles)

friend_groups
    ├── friend_group_members     (FK → player_profiles)
    └── matches                  (casual, FK → player_profiles)
```

---

## 3. Phase 1 Changes
**Goal:** Add ownership to tournaments so RLS can scope writes.

### Migration: add `created_by` to tournaments
```sql
ALTER TABLE public.tournaments
  ADD COLUMN created_by UUID REFERENCES auth.users(id);

-- Backfill: leave existing rows as NULL (pre-auth data)
-- New rows will always have created_by set by the app
```

### RLS policy changes
```sql
-- Drop the old permissive policies
DROP POLICY IF EXISTS "Allow public insert" ON public.tournaments;

-- Public can read everything
CREATE POLICY "public can read tournaments"
ON public.tournaments FOR SELECT
TO public USING (true);

-- Only the creator can insert/update/delete their own tournaments
CREATE POLICY "owner can insert tournament"
ON public.tournaments FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = created_by);

CREATE POLICY "owner can update tournament"
ON public.tournaments FOR UPDATE
TO authenticated
USING (auth.uid() = created_by);

CREATE POLICY "owner can delete tournament"
ON public.tournaments FOR DELETE
TO authenticated
USING (auth.uid() = created_by);
```

---

## 4. Phase 2 Changes
**Goal:** Replace free-text player names with real user-owned profiles.

### New table: `player_profiles`
```sql
CREATE TABLE public.player_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  name TEXT NOT NULL,
  class_tier TEXT DEFAULT 'Beginner' NOT NULL,
  bio TEXT,
  avatar_url TEXT,
  club_id UUID REFERENCES public.clubs(id),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
```

### New table: `tournament_players` (replaces `players`)
```sql
CREATE TABLE public.tournament_players (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tournament_id UUID NOT NULL REFERENCES public.tournaments(id) ON DELETE CASCADE,
  player_profile_id UUID NOT NULL REFERENCES public.player_profiles(id),
  group_label TEXT DEFAULT 'Group A' NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,

  UNIQUE(tournament_id, player_profile_id)
);
```

### Changes to `matches`
```sql
-- player FKs now point to player_profiles instead of players
-- player_name_fallback columns kept for backwards compat, deprecated in Phase 2
ALTER TABLE public.matches
  ADD COLUMN p1_profile_id UUID REFERENCES public.player_profiles(id),
  ADD COLUMN p2_profile_id UUID REFERENCES public.player_profiles(id),
  ADD COLUMN winner_profile_id UUID REFERENCES public.player_profiles(id);
```

> ⚠️ The old `players` table and its FK columns on `matches` are kept during Phase 2 and dropped in Phase 3 once all data is migrated.

---

## 5. Phase 3 Changes
**Goal:** Curated club registry.

### New table: `clubs`
```sql
CREATE TABLE public.clubs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES auth.users(id),
  name TEXT NOT NULL,
  city TEXT,
  tier TEXT NOT NULL DEFAULT 'community',
  gst_number TEXT UNIQUE,   -- required for verified tier
  owner_email TEXT UNIQUE,  -- required for community tier
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,

  CONSTRAINT valid_tier CHECK (tier IN ('verified', 'community')),
  CONSTRAINT verified_needs_gst CHECK (
    tier != 'verified' OR gst_number IS NOT NULL
  ),
  CONSTRAINT community_needs_email CHECK (
    tier != 'community' OR owner_email IS NOT NULL
  )
);
```

### Changes to `tournaments`
```sql
ALTER TABLE public.tournaments
  ADD COLUMN club_id UUID REFERENCES public.clubs(id);
```

### Changes to `player_profiles`
```sql
-- club_id already added in Phase 2 definition above
-- No additional migration needed
```

### Drop legacy tables
```sql
-- Drop old players table (data fully migrated to player_profiles + tournament_players)
DROP TABLE IF EXISTS public.players CASCADE;
```

---

## 6. Phase 4 Changes
**Goal:** Multi-admin club management.

### New table: `club_admins`
```sql
CREATE TABLE public.club_admins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id UUID NOT NULL REFERENCES public.clubs(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  role TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,

  UNIQUE(club_id, user_id),
  CONSTRAINT valid_club_role CHECK (role IN ('owner', 'leader', 'co_leader'))
);
```

### New table: `tournament_members`
```sql
CREATE TABLE public.tournament_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tournament_id UUID NOT NULL REFERENCES public.tournaments(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  role TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,

  UNIQUE(tournament_id, user_id),
  CONSTRAINT valid_tournament_role CHECK (role IN ('organizer', 'scorekeeper'))
);
```

---

## 7. Phase 5 Changes
**Goal:** Friend groups and H2H tracking.

### New table: `friend_groups`
```sql
CREATE TABLE public.friend_groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  created_by UUID NOT NULL REFERENCES auth.users(id),
  invite_code TEXT UNIQUE NOT NULL,  -- 6-char alphanumeric, generated on insert
  is_public BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
```

### New table: `friend_group_members`
```sql
CREATE TABLE public.friend_group_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.friend_groups(id) ON DELETE CASCADE,
  player_profile_id UUID NOT NULL REFERENCES public.player_profiles(id),
  joined_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,

  UNIQUE(group_id, player_profile_id)
);
```

### New table: `player_h2h_stats` (materialised)
```sql
CREATE TABLE public.player_h2h_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  player_a_id UUID NOT NULL REFERENCES public.player_profiles(id),
  player_b_id UUID NOT NULL REFERENCES public.player_profiles(id),
  player_a_wins INT DEFAULT 0,
  player_b_wins INT DEFAULT 0,
  total_matches INT DEFAULT 0,
  last_played_at TIMESTAMPTZ,

  -- Canonical ordering: always store lower UUID as player_a
  UNIQUE(player_a_id, player_b_id),
  CONSTRAINT ordered_ids CHECK (player_a_id < player_b_id)
);
```

---

## 8. Phase 6 Changes
**Goal:** Multi-sport support.

### Changes to `tournaments`
```sql
ALTER TABLE public.tournaments
  ADD COLUMN sport TEXT DEFAULT 'table_tennis' NOT NULL,
  ADD COLUMN tie_breaker_ruleset TEXT DEFAULT 'ittf' NOT NULL;

ALTER TABLE public.tournaments
  ADD CONSTRAINT valid_sport CHECK (
    sport IN ('table_tennis', 'badminton', 'squash', 'tennis', 'pickleball')
  ),
  ADD CONSTRAINT valid_ruleset CHECK (
    tie_breaker_ruleset IN ('ittf', 'bwf', 'wsf', 'itf', 'usa_pickleball')
  );
```

---

## 9. Index Strategy

```sql
-- Phase 1
CREATE INDEX idx_tournaments_created_by ON public.tournaments(created_by);

-- Phase 2
CREATE INDEX idx_tournament_players_tournament ON public.tournament_players(tournament_id);
CREATE INDEX idx_tournament_players_profile ON public.tournament_players(player_profile_id);
CREATE INDEX idx_player_profiles_name ON public.player_profiles(name);
CREATE INDEX idx_player_profiles_club ON public.player_profiles(club_id);
CREATE INDEX idx_matches_p1_profile ON public.matches(p1_profile_id);
CREATE INDEX idx_matches_p2_profile ON public.matches(p2_profile_id);

-- Phase 3
CREATE INDEX idx_clubs_name ON public.clubs(name);
CREATE INDEX idx_clubs_city ON public.clubs(city);
CREATE INDEX idx_clubs_tier ON public.clubs(tier);
CREATE INDEX idx_tournaments_club ON public.tournaments(club_id);

-- Phase 4
CREATE INDEX idx_club_admins_club ON public.club_admins(club_id);
CREATE INDEX idx_club_admins_user ON public.club_admins(user_id);
CREATE INDEX idx_tournament_members_tournament ON public.tournament_members(tournament_id);
CREATE INDEX idx_tournament_members_user ON public.tournament_members(user_id);

-- Phase 5
CREATE INDEX idx_friend_group_members_group ON public.friend_group_members(group_id);
CREATE INDEX idx_h2h_player_a ON public.player_h2h_stats(player_a_id);
CREATE INDEX idx_h2h_player_b ON public.player_h2h_stats(player_b_id);
```

---

## Changelog
| Version | Date | Author | Changes |
|---|---|---|---|
| v0.1 | June 2026 | @vizzy-spaceanand | Initial schema doc — current state + all phase migrations |
