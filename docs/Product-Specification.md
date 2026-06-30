# Product Specification
> **Living Document** — Commit changes with `docs:` prefix so spec changes are traceable in git history.
>
> **Last Updated:** June 2026 | **Version:** v0.1 | **Status:** Draft

---

## Table of Contents
1. [Vision & Goals](#1-vision--goals)
2. [User Personas & Journeys](#2-user-personas--journeys)
3. [Feature Roadmap by Phase](#3-feature-roadmap-by-phase)
4. [Non-Functional Requirements](#4-non-functional-requirements)

> Schema lives in [Schema.md](./Schema.md)
> RBAC and security lives in [RBAC.md](./RBAC.md)
> API contract lives in [API-Contract.md](./API-Contract.md)

---

## 1. Vision & Goals

### Product Vision
A multi-sport tournament management platform that serves both organised clubs and casual friend groups — from ITTF-standard table tennis tournaments to informal badminton rivalries tracked over WhatsApp.

### Core Principles
- **Curated over chaotic** — Club names, player profiles, and standings are canonical, not free-text soup.
- **Public by default** — Live tournament progress is visible to anyone without login. Authentication gates writes, not reads.
- **Sport-agnostic engine** — The bracket and standings engine is pluggable. Tie-breaker rules are swappable per sport's international body (ITTF, BWF, etc.).
- **Two tracks, one platform** — B2B (club-hosted tournaments) and B2C (friend groups, casual H2H) coexist without friction.

### Goals by Phase

| Phase | Goal | Status |
|---|---|---|
| 1 | Auth foundation — secure writes without breaking current read experience | 🔲 Not started |
| 2 | Player identity — profiles owned by users, not typed by organizers | 🔲 Not started |
| 3 | Club registry — curated, verified directory with no duplicate entries | 🔲 Not started |
| 4 | Club RBAC — multi-admin club management with scoped permissions | 🔲 Not started |
| 5 | Friend groups + H2H — casual B2C track with ongoing rivalry tracking | 🔲 Not started |
| 6 | Multi-sport — pluggable tie-breaker engine per sport | 🔲 Not started |

---

## 2. User Personas & Journeys

### Persona 1 — The Club Owner (Verified)
**Profile:** Runs a registered table tennis club. Has a GST number. Manages 20–100 players. Hosts 4–6 tournaments a year.

**Journey:**
```
Registers club with GST number
→ Becomes club owner
→ Adds leaders and co-leaders
→ Leaders create tournaments
→ Picks players from global registry into groups
→ Assigns scorekeepers
→ Runs tournament (fixtures auto-generated, scores entered live)
→ Standings computed automatically
→ Knockout bracket seeded from group standings
→ Tournament archived with full results
```

### Persona 2 — The Community Organizer (Unverified Club)
**Profile:** Organises informal club or college group. No GST. Hosts casual tournaments.

**Journey:**
```
Registers community club with owner email
→ Same flow as verified club owner
→ Visible in directory with "Community" badge (no ✓ Verified)
→ Can host tournaments but may have feature limits in future tiers
```

### Persona 3 — The Competitive Player
**Profile:** Registered player. Belongs to a club. Participates in multiple tournaments.

**Journey:**
```
Signs up → creates player profile (name, class tier, bio)
→ Searches club directory → joins their club
→ Organizer picks them into a tournament group
→ Views their own fixtures and standings (My Matches filter)
→ Sees live standings without login
→ H2H record accumulates across all tournaments
```

### Persona 4 — The Casual Player (Friend Group)
**Profile:** Plays with friends informally. Not in any club. Wants to track who's winning their group.

**Journey:**
```
Signs up → creates player profile
→ Creates or joins a friend group via invite link/code
→ Logs casual match results against friends
→ Views H2H stats and group leaderboard
→ Optionally spins up a proper bracket tournament within the group
```

### Persona 5 — The Scorekeeper
**Profile:** Assigned by a club organizer to enter scores during a tournament. Not an admin.

**Journey:**
```
Receives invite to tournament as scorekeeper
→ Logs in → sees only the matches assigned to their tournament
→ Enters set-by-set scores live
→ Cannot create tournaments, manage players, or access other tournaments
```

### Persona 6 — The Public Viewer
**Profile:** Spectator, parent, or curious player. No account needed.

**Journey:**
```
Receives shared tournament link
→ Views live standings, fixtures, results
→ No login required
→ Can browse club directory and their public tournaments
```

---

## 3. Feature Roadmap by Phase

### Phase 1 — Auth Foundation
**Goal:** Secure writes without breaking the current read experience.
**Schema changes:** `user_id` added to `tournaments`. See [Schema.md](./Schema.md#phase-1-changes).

- [ ] Email + password signup and login screens (Flutter)
- [ ] Supabase Auth integration in `main.dart`
- [ ] Session persistence across app restarts
- [ ] `user_id` column added to `tournaments` table
- [ ] RLS enabled: public SELECT, authenticated writes scoped to owned records
- [ ] Logout flow
- [ ] Auth guard on CreateTournamentScreen and score entry

**Definition of Done:** App works exactly as today for public viewers. Writes require login. An organizer can only edit their own tournaments.

---

### Phase 2 — Player Profiles
**Goal:** Players own their identity across tournaments.
**Schema changes:** New `player_profiles` and `tournament_players` tables. See [Schema.md](./Schema.md#phase-2-changes).

- [ ] `player_profiles` table (name, class_tier, bio, avatar_url)
- [ ] Profile creation screen on first login
- [ ] `tournament_players` junction table replaces current `players` table
- [ ] Organizer searches player registry when building tournament groups
- [ ] "My Matches" filter for logged-in players on FixturesTab
- [ ] Player profile page (public) showing tournament history

**Definition of Done:** No more free-text player names. Every match entry references a real player profile.

---

### Phase 3 — Club Registry
**Goal:** Curated, searchable club directory with no duplicate or misspelled entries.
**Schema changes:** New `clubs` table. See [Schema.md](./Schema.md#phase-3-changes).

- [ ] `clubs` table with `gst_number UNIQUE` (verified) and `owner_email UNIQUE` (community)
- [ ] Club registration flow with tier selection
- [ ] `verified` badge for GST clubs, `community` badge for email clubs
- [ ] Club profile page: name, city, tier, hosted tournaments
- [ ] Player can search and join exactly one club at a time
- [ ] Club directory publicly browsable (search by name, city, sport)
- [ ] Tournaments linked to hosting club

**Definition of Done:** Player signup shows a searchable dropdown of clubs. No free-text club entry allowed anywhere.

---

### Phase 4 — Club RBAC
**Goal:** Multi-admin club management with scoped permissions enforced at DB level.
**Schema changes:** New `club_admins` and `tournament_members` tables. See [Schema.md](./Schema.md#phase-4-changes) and [RBAC.md](./RBAC.md).

- [ ] `club_admins` table: `(club_id, user_id, role)`
- [ ] `tournament_members` table: `(tournament_id, user_id, role)`
- [ ] Owner can add/remove leaders and co-leaders
- [ ] Leaders and co-leaders can create tournaments on behalf of their club
- [ ] Scorekeepers assigned per tournament, can only enter scores
- [ ] RLS policies enforce all role checks at Postgres layer
- [ ] Club dashboard: tournaments, member roster, admin panel

**Definition of Done:** A co-leader cannot access another club's data. A scorekeeper cannot create tournaments. All enforced by RLS, not just Flutter UI.

---

### Phase 5 — Friend Groups + H2H
**Goal:** B2C casual track — friends can track ongoing rivalries and run informal tournaments.
**Schema changes:** New `friend_groups` and `friend_group_members` tables. See [Schema.md](./Schema.md#phase-5-changes).

- [ ] `friend_groups` table with invite code/link generation
- [ ] Group membership: any `player_profile` can join via code
- [ ] Casual match logging between any two members
- [ ] H2H stats (global and group-scoped): win/loss, set ratio, point ratio, streak
- [ ] Group leaderboard using existing standings engine
- [ ] Friend group can spin up a full bracket tournament
- [ ] H2H comparison page: Player A vs Player B across all time

**Definition of Done:** A group of friends can sign up, form a group, log matches over weeks, and see who's the overall champion with full stats.

---

### Phase 6 — Multi-Sport Extension
**Goal:** Platform works for any racket or rally-scored sport.
**Schema changes:** `sport` and `tie_breaker_ruleset` fields on `tournaments`. See [Schema.md](./Schema.md#phase-6-changes).

- [ ] `sport` enum: `table_tennis`, `badminton`, `squash`, `tennis`, `pickleball`
- [ ] `tie_breaker_ruleset`: `ittf`, `bwf`, `wsf`, `itf`, `usa_pickleball`
- [ ] `StandingsEngine` refactored to abstract base with sport-specific implementations
- [ ] Match format varies by sport
- [ ] Sport filter on club directory and tournament discovery

**Definition of Done:** A badminton club can run a BWF-standard tournament with correct tie-breaker logic.

---

## 4. Non-Functional Requirements

### Performance
| Metric | Target | Notes |
|---|---|---|
| Dashboard load | < 1s | Cached after first load |
| Live standings refresh | < 500ms | Supabase Realtime subscription |
| Player search | < 300ms | Index on `player_profiles.name` |
| Club directory search | < 300ms | Index on `clubs.name`, `clubs.city` |
| Score entry round-trip | < 800ms | Optimistic UI update, confirm on response |

### Scalability
- RLS policy filter columns must all have indexes — no full table scans
- `matches` will be the largest table — index on `tournament_id`, `player1_id`, `player2_id`
- H2H stats materialised into `player_h2h_stats` table via Postgres triggers at scale
- Supabase free tier handles ~500 concurrent users; upgrade before going live with real tournaments

### Availability
- GitHub Pages + Supabase: no SLA on free tier
- DR fallback: `dr_form_url` on tournament row for score entry if app is down
- Supabase daily backups enabled on paid tier before production use

### Security
- All secrets via `--dart-define` at build time, never in source code
- RLS enforced at Postgres layer on every table — Flutter UI restrictions are UX only, not security
- GST number is public information — no encryption needed
- No PII beyond name and email — no phone numbers, no addresses
- Supabase Auth handles password hashing

### Offline / Resilience
- Score entry queues locally if connectivity drops, syncs on reconnect (Phase 4+)
- Standings are derived read-only data — cache aggressively
- Tournament structure cached on load, refreshed on focus

### Browser / Device Support
- Primary: Web (Chrome, Safari) via GitHub Pages
- Secondary: Android and iOS (Flutter mobile builds)
- Minimum screen width: 360px (mobile-first)

---

## Changelog
| Version | Date | Author | Changes |
|---|---|---|---|
| v0.1 | June 2026 | @vizzy-spaceanand | Initial draft |
