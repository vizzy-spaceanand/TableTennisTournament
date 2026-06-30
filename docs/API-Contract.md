# API & Supabase Contract
> **Living Document** — Update this file when query patterns change or new endpoints are added.
>
> **Last Updated:** June 2026 | **Version:** v0.1

---

## Table of Contents
1. [Conventions](#1-conventions)
2. [Phase 1 — Auth Queries](#2-phase-1--auth-queries)
3. [Phase 2 — Player Profile Queries](#3-phase-2--player-profile-queries)
4. [Phase 3 — Club Queries](#4-phase-3--club-queries)
5. [Phase 4 — RBAC Queries](#5-phase-4--rbac-queries)
6. [Phase 5 — H2H & Friend Group Queries](#6-phase-5--h2h--friend-group-queries)
7. [Realtime Subscriptions](#7-realtime-subscriptions)
8. [Error Handling Patterns](#8-error-handling-patterns)

---

## 1. Conventions

- All queries are written in Dart using `supabase_flutter`
- `supabase` refers to `Supabase.instance.client`
- Queries are documented with their expected response shape
- `!inner` on a join means the row is excluded if the join has no match (acts as an INNER JOIN filter)
- Error handling follows the pattern in [Section 8](#8-error-handling-patterns)

---

## 2. Phase 1 — Auth Queries

### Sign up
```dart
await supabase.auth.signUp(
  email: email,
  password: password,
  data: {'name': displayName},  // stored in raw_user_meta_data, used by trigger
);
```

### Sign in
```dart
await supabase.auth.signInWithPassword(
  email: email,
  password: password,
);
```

### Sign out
```dart
await supabase.auth.signOut();
```

### Get current user
```dart
final user = supabase.auth.currentUser;
// Returns null if not logged in
```

### Listen to auth state changes
```dart
supabase.auth.onAuthStateChange.listen((data) {
  final event = data.event;   // AuthChangeEvent
  final session = data.session;
});
```

### Load tournaments owned by current user
```dart
final data = await supabase
  .from('tournaments')
  .select()
  .eq('created_by', supabase.auth.currentUser!.id)
  .order('created_at', ascending: false);
```

---

## 3. Phase 2 — Player Profile Queries

### Get current user's profile
```dart
final data = await supabase
  .from('player_profiles')
  .select('*, clubs(name, tier)')
  .eq('id', supabase.auth.currentUser!.id)
  .single();
```

### Search player registry
```dart
final data = await supabase
  .from('player_profiles')
  .select('id, name, class_tier, clubs(name, tier)')
  .ilike('name', '%$query%')
  .limit(20);
```

### Add player to tournament group
```dart
await supabase
  .from('tournament_players')
  .insert({
    'tournament_id': tournamentId,
    'player_profile_id': playerProfileId,
    'group_label': groupLabel,
  });
```

### Load tournament roster with profiles
```dart
final data = await supabase
  .from('tournament_players')
  .select('*, player_profiles(id, name, class_tier, avatar_url)')
  .eq('tournament_id', tournamentId)
  .order('group_label');
```

### Get player's matches across all tournaments (My Matches)
```dart
final uid = supabase.auth.currentUser!.id;
final data = await supabase
  .from('matches')
  .select('*, tournaments(name)')
  .or('p1_profile_id.eq.$uid,p2_profile_id.eq.$uid')
  .order('created_at', ascending: false);
```

---

## 4. Phase 3 — Club Queries

### Register a verified club (GST)
```dart
await supabase.from('clubs').insert({
  'owner_id': supabase.auth.currentUser!.id,
  'name': clubName,
  'city': city,
  'tier': 'verified',
  'gst_number': gstNumber,
});
// Trigger auto-inserts owner row into club_admins
```

### Register a community club (email)
```dart
await supabase.from('clubs').insert({
  'owner_id': supabase.auth.currentUser!.id,
  'name': clubName,
  'city': city,
  'tier': 'community',
  'owner_email': ownerEmail,
});
```

### Search club directory
```dart
final data = await supabase
  .from('clubs')
  .select('id, name, city, tier')
  .ilike('name', '%$query%')
  .order('tier')   // verified clubs first
  .limit(30);
```

### Join a club
```dart
await supabase
  .from('player_profiles')
  .update({'club_id': clubId})
  .eq('id', supabase.auth.currentUser!.id);
```

### Leave current club
```dart
await supabase
  .from('player_profiles')
  .update({'club_id': null})
  .eq('id', supabase.auth.currentUser!.id);
```

---

## 5. Phase 4 — RBAC Queries

### Load club dashboard (admin view)
```dart
final data = await supabase
  .from('clubs')
  .select('''
    *,
    club_admins!inner(role),
    tournaments(id, name, status, created_at)
  ''')
  .eq('club_admins.user_id', supabase.auth.currentUser!.id)
  .single();
```

### Add a co-leader to club
```dart
await supabase.from('club_admins').insert({
  'club_id': clubId,
  'user_id': targetUserId,
  'role': 'co_leader',
});
```

### Assign scorekeeper to tournament
```dart
await supabase.from('tournament_members').insert({
  'tournament_id': tournamentId,
  'user_id': targetUserId,
  'role': 'scorekeeper',
});
```

### Check current user's role in a tournament
```dart
final data = await supabase
  .from('tournament_members')
  .select('role')
  .eq('tournament_id', tournamentId)
  .eq('user_id', supabase.auth.currentUser!.id)
  .maybeSingle();

final role = data?['role'] as String?;  // null if no access
```

---

## 6. Phase 5 — H2H & Friend Group Queries

### Create friend group
```dart
final inviteCode = _generateInviteCode();  // 6-char alphanumeric
await supabase.from('friend_groups').insert({
  'name': groupName,
  'created_by': supabase.auth.currentUser!.id,
  'invite_code': inviteCode,
});
```

### Join friend group by code
```dart
// 1. Find group by code
final group = await supabase
  .from('friend_groups')
  .select('id')
  .eq('invite_code', enteredCode)
  .single();

// 2. Add current user's player profile as member
await supabase.from('friend_group_members').insert({
  'group_id': group['id'],
  'player_profile_id': supabase.auth.currentUser!.id,
});
```

### Load H2H stats between two players
```dart
// From materialised table (fast)
final data = await supabase
  .from('player_h2h_stats')
  .select()
  .or(
    'and(player_a_id.eq.$p1Id,player_b_id.eq.$p2Id),'
    'and(player_a_id.eq.$p2Id,player_b_id.eq.$p1Id)'
  )
  .maybeSingle();
```

### Load all matches between two players (full history)
```dart
final data = await supabase
  .from('matches')
  .select('*, tournaments(name, sport)')
  .or('and(p1_profile_id.eq.$p1Id,p2_profile_id.eq.$p2Id),'
      'and(p1_profile_id.eq.$p2Id,p2_profile_id.eq.$p1Id)')
  .eq('status', 'completed')
  .order('created_at', ascending: false);
```

---

## 7. Realtime Subscriptions

### Subscribe to live match updates in a tournament
```dart
final channel = supabase
  .channel('tournament_matches_$tournamentId')
  .onPostgresChanges(
    event: PostgresChangeEvent.update,
    schema: 'public',
    table: 'matches',
    filter: PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'tournament_id',
      value: tournamentId,
    ),
    callback: (payload) {
      // Refresh standings and fixtures
      _refreshData();
    },
  )
  .subscribe();

// Unsubscribe when leaving the screen
@override
void dispose() {
  supabase.removeChannel(channel);
  super.dispose();
}
```

---

## 8. Error Handling Patterns

### Standard try/catch wrapper
```dart
Future<void> _performAction() async {
  setState(() => _isLoading = true);
  try {
    await supabase.from('...').insert({...});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Success'), backgroundColor: Colors.green),
      );
    }
  } on PostgrestException catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('DB Error: ${e.message}'), backgroundColor: Colors.red),
      );
    }
  } on AuthException catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Auth Error: ${e.message}'), backgroundColor: Colors.red),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

### Unique constraint violation (e.g. duplicate GST number)
```dart
on PostgrestException catch (e) {
  if (e.code == '23505') {
    // Unique violation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('A club with this GST number already exists.'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
```

---

## Changelog
| Version | Date | Author | Changes |
|---|---|---|---|
| v0.1 | June 2026 | @vizzy-spaceanand | Initial API contract |
