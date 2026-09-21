# Sorting Architecture

## Overview

Sorting in Game On is an **in-memory presentation concern** applied after every
fetch. Hive repositories remain unsorted (storage order); providers and
services re-sort before exposing state to the UI. Two families of sorting
co-exist:

| Family | Scope | Primary key | Null / empty handling |
|--------|-------|-------------|----------------------|
| **Name sorting** | Users, `LeaguePlayer` pickers | `compareNames` (trim, empty-first, case-insensitive primary, case-sensitive secondary) then `id` | empty/whitespace first |
| **League sorting (My Leagues)** | `HomeScreen` — `sortedLeaguesProvider` | `lastPlayed` (derived) or `name` depending on `LeagueSortPreference` | `null` ("Never") last regardless of direction |

Ranked standings (`LeagueDetailState.players`: points → GD → GF → `id`) are
an independent ordering and are documented in `docs/domain-language.md` and
`docs/architecture/league-presentation.md`. They intentionally do **not** use
`compareNames` as a tie-breaker.

## Pure Comparators (`lib/core/sorting/`)

All comparators are **pure functions**: no I/O, no Hive, no domain imports
beyond what the boundary allows, deterministic, and fully unit-tested.

### `compareNullableDateNullLast` — `lib/core/sorting/date_sort.dart`

Generic nullable date comparator with **null-last** semantics.

```
int compareNullableDateNullLast(DateTime? a, DateTime? b, {required bool descending})
```

Contract (R1):

- `null` ("Never") always sorts **last** regardless of `descending`.
  `null` vs `null` → `0`; `null` vs non-null → `1` (a after b); non-null vs `null` → `-1`.
- When both non-null: `descending == true` → most recent first (`b.compareTo(a)`),
  otherwise oldest first (`a.compareTo(b)`).
- Core file — **must not** import domain types. Used by the
  application-layer league comparator so `core` stays domain-free.

Tests: `test/unit/core/sorting/date_sort_test.dart` (6 cases: both null,
null-last both directions, descending, ascending, list sort, equal dates).

### `compareNames` — `lib/core/sorting/name_sort.dart`

```
int compareNames(String a, String b)
```

- Trims surrounding whitespace before comparison.
- Empty / whitespace-only names sort **first** (`-1`).
- Primary: case-insensitive (`toLowerCase`); secondary: case-sensitive for
  determinism (e.g. `Alice` < `alice`).
- Not locale-aware (ASCII / simple Latin). See file header for limitation.

Used by: `usersProvider`, `LeagueDetailState.playersByName`, and the
alphabetical branch of `compareLeagues`.

### `compareLeagues` / `sortLeagues` — `lib/application/services/sorted_leagues_service.dart`

Canonical implementation for **My Leagues** ordering. Located in
`application/services` to avoid importing `League` / `SortedLeague` into
`core` (DDD boundary). `lib/core/sorting/league_sort.dart` is a skeleton
re-export (`export 'package:game_on/application/services/sorted_leagues_service.dart'`)
satisfying the alternative import path `core/sorting/league_sort.dart`.

```
int compareLeagues(SortedLeague a, SortedLeague b, LeagueSortPreference preference)
List<SortedLeague> sortLeagues(List<SortedLeague> leagues, LeagueSortPreference preference) // copy, never mutates input
```

State model — 4 states driven by `LeagueSortPreference` (`lib/application/preferences/sort_preference.dart`):

| `mode` | `descending` | Meaning |
|--------|--------------|---------|
| `lastPlayed` | `true` (default) | Most recent first, `null` last — **default** (R1) |
| `lastPlayed` | `false` | Oldest first, `null` last |
| `alphabetical` | `false` | A→Z via `compareNames` |
| `alphabetical` | `true` | Z→A (negated `compareNames` + negated `id`) |

Comparator logic:

- **`lastPlayed` mode**: `compareNullableDateNullLast(a.lastPlayed, b.lastPlayed, descending: preference.descending)` is primary. Deterministic tie-break is `compareNames(a.league.name, b.league.name)` → `a.league.id.compareTo(b.league.id)`. Null-last invariant is inherited; the name/id fallback guarantees stable order when dates are equal or both `null`.
- **`alphabetical` mode**: `compareNames` primary, negated when `descending`. `id` tie-break also negated for consistency. No date is consulted.

`sortLeagues` copies the list (`List.from`) before sorting to avoid mutating the
provider's source list.

Tests: `test/unit/application/services/sorted_leagues_service_test.dart` and
`test/unit/core/sorting/` cover all four states, null-last in both directions,
case sensitivity, and determinism.

## Domain Helper `maxCompletePlayedAt` — `lib/domain/services/match_stats.dart`

```
DateTime? maxCompletePlayedAt(Iterable<SimpleMatch> matches)
```

Pure domain helper:

- Returns `max(SimpleMatch.playedAt)` among matches where `isComplete == true`.
- Returns `null` when there are no completed matches (UI maps to "Never").
- No DTO, no Hive, no framework imports.
- Intended for grouped per-league derivation via `groupBy` in
  `SortedLeaguesNotifier` (single `O(M)` scan; see Bulk Strategy).

Unit tests: `test/unit/domain/services/match_stats_test.dart`.

> `SortedLeaguesNotifier` inlines the same loop for the bulk path rather than
> calling the helper per-league to preserve `O(M)` complexity (one scan).
> `_read()`-level equivalence is asserted by tests.

## Sorted Leagues Provider — `lib/providers/sorted_leagues_provider.dart`

### DTO

```dart
class SortedLeague {
  final League league;
  final DateTime? lastPlayed; // null → "Never"
}
```

 lives **in the provider file** (view-model). DTOs must not appear here
(R6); `League` is the domain entity, `lastPlayed` is derived. `HomeScreen`
renders via `Stateless _SortedLeagueCard` (no `Consumer` needed; data is
already joined).

### `sortedLeaguesProvider`

`AsyncNotifierProvider<SortedLeaguesNotifier, List<SortedLeague>>`
(`SortedLeaguesNotifier` extends `AsyncNotifier`, keepAlive — not `autoDispose`).

`build()`:

1. Explicit `ref.read(...)` — **no `ref.watch`** (R7). Reads
   `leagueRepositoryProvider`, `simpleMatchRepositoryProvider`, and
   `sortPreferenceProvider` synchronously.
2. Bulk `getAll()` for leagues + matches (two repo calls).
3. `groupBy` scan `O(M)`: single loop over matches, skip `!isComplete`,
   `maxMap[leagueId] = max(playedAt)`.
4. Map leagues → `SortedLeague(league, lastPlayed: maxMap[league.id])`.
5. `sortLeagues(sortedLeagues, preference)` — deterministic, copy-based.

Complexity: `O(M + L log L)` (`M` matches scanned once, `L` leagues sorted).
Avoids the `N+1` pattern of per-league `getByLeague` queries (the older
`leagueLastPlayedProvider(leagueId)` remains as a per-league derived view but
is no longer on the `HomeScreen` critical path).

- **KeepAlive**: provider is not `autoDispose` so toggling
  `sortPreferenceProvider` does not trigger an unnecessary refetch; the
  `SortedLeaguesNotifier` stays cached and only rebuilds on explicit
  `ref.invalidate(sortedLeaguesProvider)`.
- **No mutation methods**: derived view; all writes go through
  `LeaguesNotifier`, `LeagueDetailNotifier`, or `LeagueSortPreferenceNotifier`.
- **Error propagation**: exceptions from `getAll()` propagate as
  `AsyncError` — `HomeScreen` shows degraded `Error: ...` (red `AppTheme.errorRed`)
  rather than a silent empty list. Empty `leagues` correctly renders
  "No leagues yet" + CTA.
- **Uses `ref.read` not `ref.watch`**: re-sorting on preference change is
  driven by explicit invalidation from `SortPreferenceNotifier`, not by a
  reactive watch.

## Preference — `lib/application/preferences/sort_preference.dart`

```dart
enum LeagueSortMode { lastPlayed, alphabetical }
class LeagueSortPreference { final LeagueSortMode mode; final bool descending; }
static const defaultPreference = LeagueSortPreference(mode: lastPlayed, descending: true);
static const latest = LeagueSortPreference(mode: lastPlayed, descending: true);   // Latest — default
static const oldest = LeagueSortPreference(mode: lastPlayed, descending: false);  // Oldest
static const aToZ   = LeagueSortPreference(mode: alphabetical, descending: false); // A-Z
static const zToA   = LeagueSortPreference(mode: alphabetical, descending: true);  // Z-A
```

- Default: `lastPlayed` descending (most recent first, null last) — fulfils
  R1 and the no-flicker requirement (see `SortPreferenceNotifier`).
- `descending` reverses direction in either mode (R3).
- Helper consts `latest` / `oldest` / `aToZ` / `zToA` drive the single
  `PopupMenuButton<LeagueSortPreference>` in `HomeScreen` — four items
  `Latest` / `Oldest` / `A-Z` / `Z-A` with `check` via `==` equality;
  `onSelected` calls `setPreference` (write-then-invalidate).
- Domain-pure value object: no Hive / DTO imports.
- Canonical path `application/preferences/sort_preference.dart`;
  `lib/core/preferences/sort_preference.dart` is a re-export alias.

Persistence and invalidation are owned by `LeagueSortPreferenceNotifier`
(`lib/providers/sort_preference_provider.dart`); storage details are in
`lib/data/repositories/hive/hive_sort_preference_repository.dart`.

## Invalidation Owners (summary)

Sorting does **not** affect the write path except for cache invalidation.
`sortedLeaguesProvider` is explicitly invalidated after every write that can
change either the set of leagues or any league's `lastPlayed`:

- `LeaguesNotifier`: `addLeague`, `deleteLeague`, `archiveLeague`,
  `renameLeague`, `refresh` → `ref.invalidate(sortedLeaguesProvider)`
- `LeagueDetailNotifier`: `logSimpleMatch`, `updateSimpleMatch`,
  `deleteMatch` → `ref.invalidate(sortedLeaguesProvider)` (also invalidates
  `leagueLastPlayedProvider(leagueId)` for the per-league view)
- `LeagueSortPreferenceNotifier`: `setPreference(preference)` →
  write-then-`ref.invalidate(sortedLeaguesProvider)` — `HomeScreen` exposes a
  single `PopupMenuButton<LeagueSortPreference>` (`tooltip: 'Sort'`,
  child `Row(swap_vert + Sort)`) with four const values `latest`/`oldest`/
  `aToZ`/`zToA`; `onSelected` calls `setPreference` (check via `==`);
  `setMode`/`toggleDirection` delegate to `setPreference` and remain available
  but are not used by the current UI.

Preference changes are **write-then-invalidate**: Hive write completes before
`state = preference` and `ref.invalidate(sortedLeaguesProvider)`. No
`ref.watch(sortPreferenceProvider)` inside `SortedLeaguesNotifier.build()` —
explicit invalidation is the sole trigger (see
`docs/architecture/provider-invalidation.md`).

## Boundaries & Aliases

```
core/sorting/date_sort.dart        ── pure, domain-free (compareNullableDateNullLast)
core/sorting/name_sort.dart        ── pure, domain-free (compareNames)
core/sorting/league_sort.dart      ── re-export → application/services/sorted_leagues_service.dart
core/preferences/sort_preference.dart ── re-export → application/preferences/sort_preference.dart

application/preferences/sort_preference.dart  ── LeagueSortMode / LeagueSortPreference (no I/O)
application/services/sorted_leagues_service.dart ── compareLeagues / sortLeagues (pure, imports SortedLeague + preference)
domain/services/match_stats.dart   ── maxCompletePlayedAt (pure, imports SimpleMatch)

providers/sorted_leagues_provider.dart ── SortedLeague DTO + SortedLeaguesNotifier (bulk groupBy, keepAlive, explicit reads)
providers/sort_preference_provider.dart ── LeagueSortPreferenceNotifier (sync default, async load, write-then-invalidate)
data/repositories/hive/hive_sort_preference_repository.dart ── Box<String> app_preferences (keys documented)
```

## Related Files

- `lib/core/sorting/date_sort.dart` — `compareNullableDateNullLast`
- `lib/core/sorting/name_sort.dart` — `compareNames`
- `lib/core/sorting/league_sort.dart` — re-export alias
- `lib/core/preferences/sort_preference.dart` — re-export alias
- `lib/application/preferences/sort_preference.dart` — `LeagueSortMode` / `LeagueSortPreference`
- `lib/application/services/sorted_leagues_service.dart` — `compareLeagues` / `sortLeagues`
- `lib/domain/services/match_stats.dart` — `maxCompletePlayedAt`
- `lib/providers/sorted_leagues_provider.dart` — `SortedLeague` + `SortedLeaguesNotifier`
- `lib/providers/sort_preference_provider.dart` — `LeagueSortPreferenceNotifier`
- `lib/data/repositories/hive/hive_sort_preference_repository.dart` — persistence
- `lib/providers/leagues_provider.dart` / `lib/providers/league_detail_provider.dart` — invalidation owners
- `lib/presentation/screens/home/home_screen.dart` — `HomeScreen` (single `PopupMenuButton<LeagueSortPreference>` `tooltip: 'Sort'` with child `Row(swap_vert + Sort)`; 4 items `Latest`/`Oldest`/`A-Z`/`Z-A` via consts `latest`/`oldest`/`aToZ`/`zToA` + check via `==`, `onSelected` → `setPreference` write-then-invalidate) + `Stateless _SortedLeagueCard`
- `test/unit/core/sorting/date_sort_test.dart`, `test/unit/core/sorting/name_sort_test.dart` — comparator tests
- `test/unit/application/services/sorted_leagues_service_test.dart`, `test/unit/domain/services/match_stats_test.dart` — league sort / stats tests
- `test/unit/data/repositories/hive_sort_preference_repository_test.dart` — persistence tests
- `test/integration/presentation/screens/home/home_screen_sorting_test.dart` — UI sorting integration via bulk `sortedLeaguesProvider` (R1 default lastPlayed desc `groupBy` `O(M+L log L)` with null-last + `DateFormat('MMM d, yyyy')` / `isComplete` filter, R2 `PopupMenuButton<LeagueSortPreference>` 4 items checkmark via `==`, R3 `setPreference` switching, R5 keepAlive bulk — replaces deprecated per-league `leagueLastPlayedProvider` / `simpleMatchRepositoryProvider` / `MockSimpleMatchRepository` group removed from `home_screen_test.dart`, R7 error degraded + empty) + alphabetical empty-first, AppBar single sort control, `Stateless _SortedLeagueCard` Never/date
- `test/integration/presentation/screens/home/home_screen_test.dart` — 9 HomeScreen widget tests via bulk `SortedLeague` (loading, error, empty/CTA, list display, navigation, FAB, multi-league, pull-to-refresh) — Last Played verified via bulk DTO, per-league provider not on HomeScreen critical path (see `provider-invalidation.md` legacy note)
