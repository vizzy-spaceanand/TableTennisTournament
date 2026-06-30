# RBAC & Security
> **Living Document** — Update this file in every PR that changes roles or permissions.
>
> **Last Updated:** June 2026 | **Version:** v0.1

---

## Table of Contents
1. [Role Definitions](#1-role-definitions)
2. [Access Matrix](#2-access-matrix)
3. [RLS Policy Patterns](#3-rls-policy-patterns)
4. [Auth Triggers](#4-auth-triggers)
5. [Security Rules](#5-security-rules)

---

## 1. Role Definitions

### Platform Level
| Role | Description |
|---|---|
| `anon` | Unauthenticated public viewer |
| `authenticated` | Any logged-in user (Supabase built-in) |

### Club Level (stored in `club_admins.role`)
| Role | Description |
|---|---|
| `owner` | Created the club. Full control. Cannot be removed. |
| `leader` | Can create/manage tournaments, add co-leaders and scorekeepers |
| `co_leader` | Can create/manage tournaments. Cannot manage other admins. |

### Tournament Level (stored in `tournament_members.role`)
| Role | Description |
|---|---|
| `organizer` | Created the tournament or assigned by a club leader. Full tournament control. |
| `scorekeeper` | Can enter/update match scores only for their assigned tournament. |

### Friend Group Level
| Role | Description |
|---|---|
| `creator` | Created the friend group. Can remove members. |
| `member` | Can log casual matches and view group stats. |

---

## 2. Access Matrix

### Tournament & Match Data
| Action | anon | player | scorekeeper | co_leader | leader | owner |
|---|---|---|---|---|---|---|
| View any tournament | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| View live standings | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| View fixtures | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Enter match scores | ✗ | ✗ | ✓ (assigned) | ✓ | ✓ | ✓ |
| Create tournament | ✗ | ✗ | ✗ | ✓ | ✓ | ✓ |
| Manage tournament players | ✗ | ✗ | ✗ | ✓ | ✓ | ✓ |
| Generate knockout bracket | ✗ | ✗ | ✗ | ✓ | ✓ | ✓ |
| Delete tournament | ✗ | ✗ | ✗ | ✗ | ✓ | ✓ |

### Club Management
| Action | anon | player | scorekeeper | co_leader | leader | owner |
|---|---|---|---|---|---|---|
| View club profile | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Browse club directory | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Join a club | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Assign scorekeeper | ✗ | ✗ | ✗ | ✗ | ✓ | ✓ |
| Add co-leader | ✗ | ✗ | ✗ | ✗ | ✓ | ✓ |
| Add leader | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ |
| Edit club details | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ |
| Delete club | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ |

---

## 3. RLS Policy Patterns

All policies use `auth.uid()` as the single source of truth. UI-level restrictions are UX only — security is enforced entirely at the Postgres layer.

### Pattern 1 — Public read, owner write (Phase 1)
```sql
-- Tournaments: anyone can read, only creator can write
CREATE POLICY "public read" ON public.tournaments
  FOR SELECT TO public USING (true);

CREATE POLICY "owner insert" ON public.tournaments
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = created_by);

CREATE POLICY "owner update" ON public.tournaments
  FOR UPDATE TO authenticated
  USING (auth.uid() = created_by);

CREATE POLICY "owner delete" ON public.tournaments
  FOR DELETE TO authenticated
  USING (auth.uid() = created_by);
```

### Pattern 2 — Club role check (Phase 4)
```sql
-- Helper: check if calling user has a role in a club
CREATE OR REPLACE FUNCTION auth.user_club_role(p_club_id UUID)
RETURNS TEXT AS $$
  SELECT role FROM public.club_admins
  WHERE club_id = p_club_id AND user_id = auth.uid()
  LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Leaders and above can create tournaments for their club
CREATE POLICY "club leaders can create tournaments"
ON public.tournaments FOR INSERT TO authenticated
WITH CHECK (
  auth.user_club_role(club_id) IN ('owner', 'leader', 'co_leader')
);
```

### Pattern 3 — Tournament member check (Phase 4)
```sql
-- Helper: check if calling user has a role in a tournament
CREATE OR REPLACE FUNCTION auth.user_tournament_role(p_tournament_id UUID)
RETURNS TEXT AS $$
  SELECT role FROM public.tournament_members
  WHERE tournament_id = p_tournament_id AND user_id = auth.uid()
  LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Scorekeepers and above can update match scores
CREATE POLICY "scorekeepers can update scores"
ON public.matches FOR UPDATE TO authenticated
USING (
  auth.user_tournament_role(tournament_id) IN ('organizer', 'scorekeeper')
);
```

### Pattern 4 — Player profile ownership (Phase 2)
```sql
-- Players can only edit their own profile
CREATE POLICY "player owns profile"
ON public.player_profiles FOR UPDATE TO authenticated
USING (auth.uid() = id);
```

### Pattern 5 — Friend group membership (Phase 5)
```sql
-- Only group members can see casual match data
CREATE POLICY "group members read matches"
ON public.matches FOR SELECT TO authenticated
USING (
  friend_group_id IS NULL  -- public tournament matches, always visible
  OR EXISTS (
    SELECT 1 FROM public.friend_group_members fgm
    JOIN public.player_profiles pp ON pp.id = fgm.player_profile_id
    WHERE fgm.group_id = matches.friend_group_id
    AND pp.id = auth.uid()
  )
);
```

---

## 4. Auth Triggers

These Postgres triggers fire automatically on auth events to keep data consistent.

### On user signup → create player profile
```sql
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.player_profiles (id, name)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1))
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

### On club creation → assign owner role
```sql
CREATE OR REPLACE FUNCTION public.handle_new_club()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.club_admins (club_id, user_id, role)
  VALUES (NEW.id, NEW.owner_id, 'owner');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_club_created
  AFTER INSERT ON public.clubs
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_club();
```

### On tournament creation → assign organizer role
```sql
CREATE OR REPLACE FUNCTION public.handle_new_tournament()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.tournament_members (tournament_id, user_id, role)
  VALUES (NEW.id, NEW.created_by, 'organizer');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_tournament_created
  AFTER INSERT ON public.tournaments
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_tournament();
```

---

## 5. Security Rules

### Non-negotiable rules
- **RLS is always on.** Every table has `ALTER TABLE ... ENABLE ROW LEVEL SECURITY`. No exceptions.
- **No secrets in source code.** All Supabase keys via `--dart-define` at build time.
- **Flutter UI gates are UX only.** Never rely on hiding a button as a security control.
- **Helper functions use `SECURITY DEFINER`.** Role-check functions run as the function owner, not the calling user, to prevent privilege escalation.

### GST number
- Stored as plain text — it is public information by design.
- Used purely as a uniqueness constraint, not for authentication.
- No encryption needed.

### PII minimisation
- Collect only name and email. No phone numbers, addresses, or payment data.
- Avatar URLs point to Supabase Storage — files scoped to the user's own bucket path.

---

## Changelog
| Version | Date | Author | Changes |
|---|---|---|---|
| v0.1 | June 2026 | @vizzy-spaceanand | Initial RBAC doc |
