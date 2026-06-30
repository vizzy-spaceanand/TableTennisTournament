# Codebase Walkthrough
> Plain-English explanation of every file in the app for a solo developer who is new to Flutter.
> Read this top to bottom once. After that, use it as a reference when you need to find where something lives.
>
> **Last Updated:** June 2026 | **Version:** v0.1

---

## Table of Contents
1. [How Flutter Apps Are Structured](#1-how-flutter-apps-are-structured)
2. [Project Folder Map](#2-project-folder-map)
3. [The Entry Point — `lib/main.dart`](#3-the-entry-point--libmaindart)
4. [Screens — What the User Sees](#4-screens--what-the-user-sees)
   - [Dashboard Screen](#41-dashboardscreendart)
   - [Create Tournament Screen](#42-createtournamentscreendart)
   - [Player Registration Screen](#43-playerregistrationscreendart)
   - [Tournament Details Screen](#44-tournamentdetailsscreendart)
5. [Tabs — Sections Inside Tournament Details](#5-tabs--sections-inside-tournament-details)
   - [Fixtures Tab](#51-fixturestabdart)
   - [Roster Tab](#52-rostertabdart)
   - [Standings Tab](#53-standingstabdart)
6. [Services — The Business Logic Engine](#6-services--the-business-logic-engine)
   - [Standings Engine](#61-standingsenginedart)
   - [Bracket Engine](#62-bracketenginedart)
7. [The Database Layer — Supabase](#7-the-database-layer--supabase)
8. [The CI/CD Pipeline](#8-the-cicd-pipeline)
9. [Key Flutter Concepts Decoded](#9-key-flutter-concepts-decoded)

---

## 1. How Flutter Apps Are Structured

Think of a Flutter app like a tree of boxes. Every visual element — a button, a text label, a list — is called a **Widget**. Widgets nest inside other widgets, like Russian dolls.

```
App
└── Screen (full page)
    └── Scaffold (page frame with app bar + body)
        ├── AppBar (top bar with title and buttons)
        └── Body
            ├── Column (stacks things vertically)
            │   ├── Text ("Hello")
            │   ├── Button
            │   └── List
            └── ...
```

There are two kinds of widgets you'll see everywhere:

**StatelessWidget** — A widget that just displays something. It has no internal memory. Like a printed poster — it shows what you give it and never changes on its own.

**StatefulWidget** — A widget that can remember things and redraw itself when those things change. Like a scoreboard — it updates when a score changes. Every screen in your app is a StatefulWidget because screens need to load data, respond to button presses, and refresh.

When you see `setState(() { ... })` in the code, that's the instruction that says "something changed — redraw this widget now."

---

## 2. Project Folder Map

Only the folders that matter for the app logic:

```
lib/                        ← ALL your app code lives here
├── main.dart               ← App entry point. Runs first.
├── screens/                ← Full pages the user navigates between
│   ├── dashboard_screen.dart
│   ├── create_tournament_screen.dart
│   ├── player_registration_screen.dart
│   ├── tournament_details_screen.dart
│   └── tabs/               ← Sub-sections inside tournament details
│       ├── fixtures_tab.dart
│       ├── roster_tab.dart
│       └── standings_tab.dart
└── services/               ← Pure logic, no UI
    ├── standings_engine.dart
    └── bracket_engine.dart

supabase/
├── migrations/             ← SQL that creates/modifies your database tables
│   └── 20260622194030_initialize_tournament_tables.sql
└── snippets/               ← SQL test data scripts (not deployed automatically)

.github/
└── workflows/
    └── supabase-ci.yml     ← The CI/CD pipeline (auto-deploy on git push)
```

Everything outside `lib/` and `supabase/` is boilerplate Flutter scaffolding for Android, iOS, Windows, Linux, macOS builds. You don't need to touch those unless you're building native mobile apps.

---

## 3. The Entry Point — `lib/main.dart`

**What it does:** This is the first file Flutter runs when the app starts. Think of it as `index.html` for a website — it bootstraps everything.

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ...
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
  runApp(const TableTennisApp());
}
```

**Line by line:**

`WidgetsFlutterBinding.ensureInitialized()`
— Flutter needs to set up its internal machinery before you can call async functions. This line says "make sure Flutter is ready before we do anything else." It's always the first line in a `main()` that does async work.

`String.fromEnvironment('SUPABASE_URL', defaultValue: '...')`
— This reads an environment variable baked in at build time via `--dart-define`. In production, it gets the real Supabase URL. When running locally without the variable set, it falls back to your local Supabase instance (`http://127.0.0.1:54321`). This is how the same codebase connects to different databases for staging vs prod.

`await Supabase.initialize(...)`
— Opens the connection to your Supabase project. After this line, anywhere in the app you can call `Supabase.instance.client` to talk to the database. It's like calling `mongoose.connect()` in Node.js.

`runApp(const TableTennisApp())`
— Hands control to Flutter and says "start rendering this widget tree." Everything the user sees flows from here.

---

```dart
class TableTennisApp extends StatelessWidget {
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ping Pong MVP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}
```

`MaterialApp` — The root wrapper that every Flutter app needs. It gives you navigation history (back button), theming, and the widget tree container. Think of it as the `<html>` tag.

`theme: ThemeData(...)` — Sets the global colour scheme. `seedColor: Colors.deepOrange` means Flutter auto-generates a full Material 3 colour palette derived from deep orange. You change one colour here and the whole app updates.

`home: const DashboardScreen()` — The first page shown when the app opens.

---

## 4. Screens — What the User Sees

### 4.1 `dashboard_screen.dart`

**What the user sees:** A list of all tournaments with a "Configure New Tournament" button at the top.

**Navigation role:** This is the home screen. All other screens are reached from here.

---

**The class split — why there are always two classes per screen:**

```dart
class DashboardScreen extends StatefulWidget { ... }        // The shell
class _DashboardScreenState extends State<DashboardScreen> { ... }  // The brain
```

Flutter always splits a stateful screen into two parts:
- The **widget class** (`DashboardScreen`) — just declares that this screen exists and creates its state. You rarely touch this.
- The **state class** (`_DashboardScreenState`) — where all your logic, variables, and UI building lives. The underscore prefix means it's private to this file.

---

```dart
late Future<List<Map<String, dynamic>>> _tournamentsFuture;
```

This declares a variable that will hold a **Future** — Flutter's version of a Promise. It will eventually contain a list of tournament rows from Supabase, where each row is a `Map<String, dynamic>` (equivalent to a JavaScript object / Python dict).

`late` means "I promise this will be assigned before it's used — don't panic yet."

---

```dart
void initState() {
  super.initState();
  _refreshTournaments();
}
```

`initState()` is Flutter's equivalent of `componentDidMount` in React or `ngOnInit` in Angular. It runs exactly once when the screen first appears. Here it kicks off the tournament data fetch.

---

```dart
void _refreshTournaments() {
  setState(() {
    _tournamentsFuture = Supabase.instance.client
        .from('tournaments')
        .select()
        .order('created_at', ascending: false)
        .then((value) => List<Map<String, dynamic>>.from(value));
  });
}
```

This function fetches all tournaments from Supabase ordered newest first, and stores the Promise (Future) in `_tournamentsFuture`. Wrapping it in `setState()` tells Flutter to redraw the screen so the loading spinner appears while waiting.

---

```dart
FutureBuilder<List<Map<String, dynamic>>>(
  future: _tournamentsFuture,
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return Center(child: Text('Query Failure: ${snapshot.error}'));
    }
    final dataRows = snapshot.data ?? [];
    ...
  }
)
```

`FutureBuilder` is Flutter's pattern for "show something while waiting for async data, then show the real thing." It's used on every screen that fetches from Supabase.

- `ConnectionState.waiting` → show a spinner
- `snapshot.hasError` → show the error message
- `snapshot.data` → the actual list of tournaments, use it to build the list

---

```dart
return ListView.builder(
  itemCount: dataRows.length,
  itemBuilder: (context, index) {
    final item = dataRows[index];
    return Card( ... ListTile( ... onTap: () { Navigator.push(...) } ) );
  },
);
```

`ListView.builder` is a lazy-loading list — it only builds the cards currently visible on screen. `itemBuilder` is called once per row, like `.map()` on an array.

`Navigator.push(...)` is how you navigate to a new screen. It pushes the new screen onto a stack. The back button pops it off. `Navigator.pop(context)` is "go back."

---

### 4.2 `create_tournament_screen.dart`

**What the user sees:** A form to create a new tournament — name, group stage format, knockout format, and an optional DR (Disaster Recovery) form URL.

---

```dart
final _formKey = GlobalKey<FormState>();
final _nameController = TextEditingController();
final _drFormController = TextEditingController();
int _roundRobinBestOf = 3;
int _knockoutBestOf = 5;
bool _isLoading = false;
```

These are the screen's memory:
- `_formKey` — a unique ID for the form, used to trigger validation
- `TextEditingController` — binds to a text field and lets you read what the user typed (`.text` property)
- `_roundRobinBestOf` / `_knockoutBestOf` — hold the currently selected dropdown values
- `_isLoading` — when true, hides the form and shows a spinner

---

```dart
Future<void> _saveTournamentToDatabase() async {
  if (!_formKey.currentState!.validate()) return;   // Run all validators first
  setState(() => _isLoading = true);                // Show spinner

  try {
    await Supabase.instance.client.from('tournaments').insert({
      'name': name,
      'status': 'upcoming',
      'settings': settingsConfig,
      'dr_form_url': drUrl.isEmpty ? null : drUrl,
    });
    Navigator.pop(context);                         // Go back to dashboard
  } catch (error) {
    // Show red snackbar with error
  } finally {
    setState(() => _isLoading = false);             // Always hide spinner
  }
}
```

The `try/catch/finally` pattern is used on every database write in your app:
- `try` — attempt the operation
- `catch` — if Supabase returns an error, show it to the user
- `finally` — always runs regardless of success or failure; used to hide the loading spinner

**Known gap:** This screen saves `round_robin_sets` and `knockout_sets` inside the `settings` JSONB blob, but the DB also has dedicated columns `round_robin_sets` and `knockout_sets` that are not being written to. They stay at their default values. This will need fixing in Phase 1.

---

### 4.3 `player_registration_screen.dart`

**What the user sees:** A form to add a player to a tournament — name, skill tier, and which group they belong to.

**How it receives data:** Unlike `DashboardScreen` which takes no inputs, this screen receives `tournamentId` and `tournamentName` as parameters passed in when navigating to it. In Flutter these are called **constructor parameters** — like function arguments for a screen.

```dart
class PlayerRegistrationScreen extends StatefulWidget {
  final String tournamentId;    // Passed in from TournamentDetailsScreen
  final String tournamentName;  // Passed in for display only

  const PlayerRegistrationScreen({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
  });
```

`required` means the caller must provide this value — it's a compile-time error if they forget.

**Known gap:** This screen writes player names as free text to the `players` table. In Phase 2, this will be replaced with a search-and-select from `player_profiles` instead of a free-text name field.

---

### 4.4 `tournament_details_screen.dart`

**What the user sees:** A tabbed screen with three tabs — Fixtures, Roster, Standings — for one specific tournament.

**This is the most complex screen in the app.** It owns all the tournament data and passes it down to the tabs.

---

```dart
class TournamentDetailsScreen extends StatefulWidget {
  final String tournamentId;
  final String tournamentName;
  final int roundRobinSets;
  final int knockoutSets;
```

Four parameters passed in from the Dashboard when tapping a tournament card.

---

```dart
List<Map<String, dynamic>> _players = [];
List<Map<String, dynamic>> _matches = [];
String _knockoutFormat = 'league_topper';
bool _isLoadingData = true;
```

This screen holds the master copy of all players and matches for the tournament. The tabs don't fetch their own data — they receive it from this screen as parameters. This is the **single source of truth** pattern — one place fetches, everything else just displays.

---

```dart
Future<void> _refreshScreenData() async {
  final tournamentData = await Supabase.instance.client
      .from('tournaments')
      .select('knockout_format')
      .eq('id', widget.tournamentId)
      .maybeSingle();

  final playersData = await Supabase.instance.client
      .from('players')
      .select()
      .eq('tournament_id', widget.tournamentId)
      .order('group_label', ascending: true);

  final matchesData = await Supabase.instance.client
      .from('matches')
      .select()
      .eq('tournament_id', widget.tournamentId)
      ...
```

Three separate Supabase queries run when the screen loads:
1. Tournament config (just the `knockout_format` field)
2. All players in this tournament
3. All matches in this tournament

`widget.tournamentId` — inside the state class, you access the parent widget's parameters via `widget.`. It's like `this.props` in React.

`.maybeSingle()` — returns one row or null. Use this instead of `.single()` when the row might not exist (`.single()` throws an error if no row is found).

---

```dart
DefaultTabController(
  length: 3,
  child: Scaffold(
    appBar: AppBar(
      bottom: TabBar(tabs: [
        Tab(icon: Icon(Icons.list_alt), text: 'Fixtures'),
        Tab(icon: Icon(Icons.people), text: 'Roster'),
        Tab(icon: Icon(Icons.leaderboard), text: 'Standings'),
      ]),
    ),
    body: TabBarView(children: [
      FixturesTab(...),
      RosterTab(...),
      StandingsTab(...),
    ]),
  ),
)
```

`DefaultTabController` wraps the screen and manages which tab is active. `TabBar` renders the tab headers. `TabBarView` renders the content — the order of children must match the order of tabs exactly.

---

## 5. Tabs — Sections Inside Tournament Details

The three tabs are not full screens — they're widgets that live inside `TournamentDetailsScreen`. They receive their data as parameters and call back to the parent when something needs refreshing.

### 5.1 `fixtures_tab.dart`

**What the user sees:** A list of all matches. Each card shows two player names, the score (or "SCHEDULED"), and a "Log Score" / "Edit Score" button. There's also a bracket view toggle and buttons to generate fixtures or advance the knockout bracket.

**This is the most feature-rich tab.** It handles:
- Round-robin fixture generation
- Score logging (set by set)
- Knockout bracket generation (calls `BracketEngine`)
- Bracket advancement (next round after all matches complete)
- Two view modes: list view and bracket/tree view

---

```dart
String _activeViewMode = 'list';  // 'list' or 'bracket'
```

This toggle switches between the list view (all matches as cards) and the bracket view (columns per round, like a tournament draw).

---

**The score logging modal:**

```dart
void _showScoreLoggingModal(BuildContext context, Map<String, dynamic> match) {
  showDialog(context: context, builder: (_) => AlertDialog(...));
}
```

`showDialog` pops a modal overlay on top of the current screen. Inside the dialog, the user enters set-by-set scores. On confirm, it writes to Supabase and calls `widget.onRefreshRequired()` to tell the parent screen to re-fetch all data.

`widget.onRefreshRequired()` — This is a **callback function** passed from parent to child. The tab can't directly call `_refreshScreenData()` on `TournamentDetailsScreen` — instead, the parent passes a reference to that function as a parameter, and the tab calls it when needed. It's Flutter's standard pattern for child-to-parent communication.

---

**Round-robin fixture generation:**

```dart
void _generateRoundRobinFixtures(BuildContext context) {
  // Groups players by group_label
  // Runs every player against every other player in the same group
  // Inserts all match rows into Supabase with status 'scheduled'
}
```

This generates every possible pairing within each group (round-robin). If Group A has 3 players: A vs B, A vs C, B vs C — 3 matches. The algorithm is a standard combinatorics loop.

---

**Generate Bracket button:**
Visible only when all group matches are completed. Calls `BracketEngine.generateInitialKnockoutMatches()` to seed the knockout draw from group standings, then inserts the knockout match rows into Supabase.

**Advance Bracket button:**
Visible when all matches in the current knockout round are completed and the next round doesn't exist yet. Calls `BracketEngine.generateNextStageMatches()` to progress winners forward.

---

### 5.2 `roster_tab.dart`

**What the user sees:** A list of all players in the tournament, grouped by their group label (Group A, Group B etc.). Has a button to add a new player (navigates to `PlayerRegistrationScreen`).

This tab is relatively simple — it just displays the players list passed down from `TournamentDetailsScreen` and provides navigation to the registration form.

---

### 5.3 `standings_tab.dart`

**What the user sees:** A leaderboard table per group, showing rank, player name, matches played, and win/loss record. If there's a tie, a "Tie-Breaker Logic" button appears showing the audit trail explaining exactly how the tie was resolved.

```dart
final standingsResult = StandingsEngine.generateGroupStandings(
  players: widget.players,
  matches: widget.matches,
);
final leaderboards = standingsResult['leaderboards'];
final auditTrails = standingsResult['audit_trails'];
```

This tab calls `StandingsEngine` directly — no Supabase query needed. All the data is already in memory (passed from the parent). The engine crunches the numbers and returns the sorted leaderboards.

The **Tie-Breaker Inspector** is a dialog (`showDialog`) showing the step-by-step audit trail from the engine — which players were tied, what metric broke the tie, and the final ratios compared.

---

## 6. Services — The Business Logic Engine

These are pure Dart classes with no UI. They take data in, compute something, and return a result. They never talk to Supabase directly.

### 6.1 `standings_engine.dart`

**What it does:** Takes a list of players and completed matches, and returns a ranked leaderboard per group following the official ITTF 5-step tie-breaking algorithm.

---

**`PlayerGroupStats` class:**

```dart
class PlayerGroupStats {
  final String id;
  final String name;
  final String group;
  
  int matchPoints = 0;    // Win = 2pts, Loss = 1pt (for playing), Default = 0
  int matchesWon = 0;
  int matchesLost = 0;

  // Used only during tie-breaking — reset and recalculated within tied sub-group
  int subGamesWon = 0;
  int subGamesLost = 0;
  int subPointsWon = 0;
  int subPointsLost = 0;
}
```

This is a data container — one instance per player, holding their running stats. The `sub*` fields are cleared and recalculated each time a tie needs breaking (ITTF rules: tiebreaking only counts head-to-head results within the tied group, ignoring matches played against others).

---

**`TieBreakerAuditLog` class:**

A simple data container for the audit trail — records which players were tied, what steps were taken, and the final ratios that broke the tie. This powers the "Tie-Breaker Logic" button in the Standings tab.

---

**`StandingsEngine.generateGroupStandings()`** — the main algorithm:

```
Step 1: Loop through all completed matches → add match points (Win=2, Loss=1)
Step 2: Group players by their group_label
Step 3: For each group, cluster players by match points (ties have same points)
Step 4: If a bucket has only one player → no tie, insert them at their rank
Step 5: If a bucket has 2+ players → TIE DETECTED:
    a. Reset all sub* stats for tied players
    b. Re-scan all matches, but ONLY count matches between tied players (sub-group isolation)
    c. Sort tied players by sub-game ratio (sets won / sets lost)
    d. If still tied → sort by sub-point ratio (rally points won / lost)
    e. If still tied → Step 5 fallback (currently returns 0, meaning equal rank)
Step 6: Merge sorted sub-groups back into the main ranked list
Step 7: Return leaderboards + audit trail
```

This is the most algorithmically complex piece of your codebase and it's well-implemented. The sub-group isolation (ignoring matches outside the tied group) is what makes it genuinely ITTF-compliant, not just a simple win/loss sort.

---

### 6.2 `bracket_engine.dart`

**What it does:** Generates knockout match fixtures from group standings, and advances winners from one round to the next.

---

**`getExpectedPlayerCount(format)`:**

```dart
case 'finals': return 2;   // 1 match, direct final
case 'sf':     return 4;   // 2 semis → 1 final
case 'qf':     return 8;   // 4 quarters → 2 semis → 1 final
case 'r16':    return 16;
case 'r32':    return 32;
```

Maps the `knockout_format` string to how many players need to qualify from the group stage.

---

**`generateInitialKnockoutMatches()`:**

```
1. Walk through group leaderboards depth-first:
   - Take rank 1 from Group A, rank 1 from Group B, rank 1 from Group C...
   - Then rank 2 from each group...
   - Until we have enough players for the format
2. Pair them using two-pointer seeding:
   - leftPointer starts at 0 (highest seed), rightPointer at end (lowest seed)
   - Match 1 = seed 1 vs seed N (top vs bottom)
   - Match 2 = seed 2 vs seed N-1
   - This is standard tournament seeding — protects top seeds from meeting early
```

---

**`generateNextStageMatches()`:**

```
1. Find what the current latest stage is (semifinal, quarterfinal etc.)
2. Check all matches in that stage are completed — throw error if not
3. Collect winners in order
4. Pair consecutive winners: Winner of Match 1 vs Winner of Match 2, etc.
5. Return the new fixture rows to be inserted into Supabase
```

---

## 7. The Database Layer — Supabase

Your Supabase schema lives in `supabase/migrations/20260622194030_initialize_tournament_tables.sql`. A migration is SQL that runs once to set up or modify your database structure. When you run `supabase db push`, Supabase compares what's already been applied and runs only the new ones.

**Four tables, currently:**

`tournaments` — one row per tournament. Stores name, status, format settings, and the DR fallback URL.

`players` — one row per player per tournament. Stores their name as free text, skill tier, and which group they're in. **This table is replaced in Phase 2.**

`groups` — exists in the schema but is currently unused. `group_label` is stored directly on the `players` row instead. Will be properly wired in Phase 2.

`matches` — one row per match. Stores both player IDs, the score (sets won each), and `set_scores` as a JSONB array of individual set scores like `[{"p1": 11, "p2": 8}, {"p1": 11, "p2": 6}]`.

**RLS (Row Level Security):** Currently enabled on all tables but set to allow everything publicly. This is the "security is on but the door is open" state. Phase 1 closes the door.

---

## 8. The CI/CD Pipeline

`.github/workflows/supabase-ci.yml` — runs automatically when you push to `main` or `develop`.

**Two jobs run in sequence:**

**Job 1: `deploy-backend`**
- Installs the Supabase CLI
- Links to your remote Supabase project using `SUPABASE_PROJECT_ID` and `SUPABASE_DB_PASSWORD` secrets
- Runs `supabase db push` — applies any new migration SQL files to the live database
- The environment (`production` or `staging`) is selected based on which branch triggered the run

**Job 2: `deploy` (depends on Job 1)**
- Sets up Flutter
- Runs `flutter build web --release` with the Supabase URL and key baked in via `--dart-define`
- The `--base-href` flag tells Flutter what URL path the app lives at (`/prod/` or `/staging/`)
- Deploys the compiled output to the `gh-pages` branch using the JamesIves action
- Production goes to `/prod/`, staging goes to `/staging/` — completely isolated subfolders

**GitHub Environments:** The pipeline uses GitHub's Environments feature (`production` and `staging`) to resolve secrets. Both jobs use `WEB_SUPABASE_URL` and `WEB_SUPABASE_ANON_KEY` as secret names, but GitHub injects the correct values based on which environment is active for that run.

---

## 9. Key Flutter Concepts Decoded

A quick reference for terms you'll keep seeing:

| Flutter Term | What It Means |
|---|---|
| `Widget` | Any UI element — button, text, screen, layout |
| `StatefulWidget` | A widget with memory that can redraw itself |
| `StatelessWidget` | A widget that just displays, never changes |
| `setState()` | "Something changed — redraw now" |
| `BuildContext` | Where in the widget tree we currently are. Required for navigation and dialogs. |
| `Future<T>` | A Promise that will eventually return a value of type T |
| `async/await` | Same as JavaScript async/await |
| `FutureBuilder` | Displays different widgets depending on whether a Future is loading, errored, or done |
| `Navigator.push()` | Go to a new screen |
| `Navigator.pop()` | Go back |
| `initState()` | Runs once when a screen first appears (like componentDidMount) |
| `dispose()` | Runs when a screen is destroyed — used to clean up listeners |
| `mounted` | Is this widget still on screen? Always check before calling setState after an async operation |
| `widget.x` | Access a parameter passed into a StatefulWidget from inside its State class |
| `context.mounted` | Same as `mounted` but accessible outside the State class |
| `required` | A constructor parameter that must be provided — compile error if missing |
| `final` | A variable that can be assigned once and never changed |
| `const` | A compile-time constant — value known before the app runs |
| `late` | "I'll assign this before using it, trust me" — skips Dart's null initialisation check |
| `??` | Null coalescing — `a ?? b` means "a if a is not null, otherwise b" |
| `?.` | Null-safe access — `a?.b` means "b if a is not null, otherwise null" |
| `!` | Force-unwrap — `a!` means "I promise a is not null" (crashes if wrong) |

---

## Changelog
| Version | Date | Author | Changes |
|---|---|---|---|
| v0.1 | June 2026 | @vizzy-spaceanand | Initial walkthrough — full codebase coverage |
