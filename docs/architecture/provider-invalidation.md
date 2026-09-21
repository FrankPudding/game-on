# Provider Invalidation Architecture

## Overview

This document describes the provider invalidation strategy for the Game On application. The goal is to ensure that when data mutations occur, all affected providers are properly invalidated so that UI components reflect the latest state.

## Design Principles

1. **Explicit Invalidation Over Reactive Watches**: Providers should not use `ref.watch()` on other providers to trigger rebuilds. Instead, mutations explicitly call `ref.invalidate()` on dependent providers.

2. **No Self-Invalidation**: A provider should not invalidate itself. State updates are handled by explicit data fetching within the mutation method.

3. **Invalidate Dependent Providers Only**: When a mutation occurs, invalidate only the providers that depend on the changed data.

4. **Invalidate After Successful Write**: All invalidation calls happen AFTER the write operation succeeds, before returning fresh data.

5. **Precise Invalidation**: Use `ref.invalidate(provider)` for entire provider families and `ref.invalidate(provider(arg))` for specific instances.

## Provider Dependency Graph

```
leaguesProvider (list of leagues)
  ├── invalidate: leagueDetailProvider(leagueId) when league deleted
  └── invalidate: sortedLeaguesProvider (addLeague, deleteLeague, archiveLeague, renameLeague, refresh) — bulk My Leagues view

leagueDetailProvider(leagueId) (league details, players, matches, stats)
  ├── invalidate: usersProvider (addPlayer creates new user, removePlayer)
  ├── invalidate: userDetailProvider(userId) for affected users
  │   - addPlayer (new user or existing user)
  │   - logSimpleMatch (winner, loser)
  │   - updateSimpleMatch (winner, loser)
  │   - deleteMatch (all involved players)
  │   - updatePlayer (player's user)
  │   - removePlayer (player's user)
  ├── invalidate: leagueLastPlayedProvider(leagueId) (logSimpleMatch, updateSimpleMatch, deleteMatch)
  ├── invalidate: sortedLeaguesProvider (logSimpleMatch, updateSimpleMatch, deleteMatch) — lastPlayed changes recency order
  └── invalidate: leagueDetailProvider(leagueId) - NOT self (explicit fetch)

usersProvider (list of users)
  ├── invalidate: leaguesProvider (when user deleted/updated, affects league player counts)
  ├── invalidate: userDetailProvider(userId) for affected user
  └── invalidate: leagueDetailProvider(leagueId) for leagues where user has players
  └── invalidate: usersProvider - NOT self (explicit fetch)

userDetailProvider(userId) (user's leagues, players, matches)
  ├── invalidate: usersProvider - removed (was causing unnecessary rebuilds)
  ├── invalidate: leaguesProvider - removed (was causing unnecessary rebuilds)
  └── Depends on explicit invalidation from usersProvider and leagueDetailProvider

leagueLastPlayedProvider(leagueId) (derived FutureProvider<DateTime?> for My Leagues per-league last-played — legacy path)
  ├── No mutation methods — reads SimpleMatchRepository.getByLeague, filters isComplete, returns max playedAt (null → "Never")
  └── Invalidated by: leagueDetailProvider(leagueId) on logSimpleMatch / updateSimpleMatch / deleteMatch
  └── Note: HomeScreen now consumes sortedLeaguesProvider (bulk groupBy) for the list; leagueLastPlayedProvider remains as a per-league derived view for other callers

sortedLeaguesProvider (AsyncNotifier keepAlive — bulk My Leagues sorted view)
  ├── Reads: leagueRepository.getAll() + simpleMatchRepository.getAll() + sortPreferenceProvider (via ref.read, no ref.watch) → groupBy O(M+L log L) → sortLeagues (compareNullableDateNullLast/compareNames then id)
  ├── Exposes: List<SortedLeague> (DTO: league + lastPlayed null→"Never") — lib/providers/sorted_leagues_provider.dart
  ├── No mutation methods — derived, explicitly invalidated after writes
  ├── keepAlive (not autoDispose): stays cached across preference toggles; no spurious refetch without explicit invalidate
  └── Invalidated by:
      ├── leaguesProvider (addLeague, deleteLeague, archiveLeague, renameLeague, refresh)
      ├── leagueDetailProvider (logSimpleMatch, updateSimpleMatch, deleteMatch)
      └── sortPreferenceProvider (setPreference — HomeScreen single PopupMenuButton<LeagueSortPreference> with 4 consts latest/oldest/aToZ/zToA; setMode/toggleDirection delegate to setPreference) — write-then-invalidate

sortPreferenceProvider (Notifier — persisted My Leagues sort preference)
  ├── State: LeagueSortPreference(mode: lastPlayed|alphabetical, descending: bool) + const helpers latest (=lastPlayed descending true, default) / oldest / aToZ / zToA — lib/application/preferences/sort_preference.dart; default lastPlayed descending (most recent first, null last)
  ├── Persistence: Hive Box<String> app_preferences (keys sort_mode / sort_descending) via HiveSortPreferenceRepository — lib/data/repositories/hive/hive_sort_preference_repository.dart
  ├── No flicker: build() returns defaultPreference synchronously, then async repo.get() updates state + microtask ref.invalidate(sortedLeaguesProvider) only if persisted differs
  ├── Mutations: setPreference(preference) — write-then-invalidate (await repo.set/setPreference → state = pref → ref.invalidate(sortedLeaguesProvider)); HomeScreen calls setPreference with latest/oldest/aToZ/zToA via PopupMenuButton<LeagueSortPreference> (tooltip Sort, child Row(swap_vert + Sort), check via ==); setMode/toggleDirection delegate to setPreference
  └── Resilience: idempotent Hive.isBoxOpen guard in injection_container; malformed strings fallback to defaultPreference; read errors keep default, write errors propagate; degraded handling leaves HomeScreen usable
```

## Invalidation Rules by Mutation

### leaguesProvider

| Method | Invalidates |
|--------|-------------|
| `addLeague` | `sortedLeaguesProvider` (explicit fetch updates self + bulk view resort) |
| `deleteLeague` | `leagueDetailProvider(deletedLeagueId)`, `sortedLeaguesProvider` |
| `archiveLeague` | `sortedLeaguesProvider` |
| `renameLeague` | `sortedLeaguesProvider` (name change affects alphabetical fallback / tie-break) |
| `refresh` | `sortedLeaguesProvider` |

### leagueDetailProvider(leagueId)

| Method | Invalidates |
|--------|-------------|
| `addPlayer` | `usersProvider` (if new user created), `userDetailProvider(newUserId)` |
| `logSimpleMatch` | `userDetailProvider(winnerId)`, `userDetailProvider(loserId)`, `leagueLastPlayedProvider(leagueId)`, `sortedLeaguesProvider` |
| `updateSimpleMatch` | `userDetailProvider(winnerId)`, `userDetailProvider(loserId)`, `leagueLastPlayedProvider(leagueId)`, `sortedLeaguesProvider` |
| `deleteMatch` | `userDetailProvider(playerId)` for all players in match, `leagueLastPlayedProvider(leagueId)`, `sortedLeaguesProvider` |
| `updatePlayer` | `userDetailProvider(playerUserId)` |
| `removePlayer` | `usersProvider`, `userDetailProvider(playerUserId)` |

### leagueLastPlayedProvider(leagueId)

| Method | Invalidates |
|--------|-------------|
| (No mutation methods) | N/A — read-only `FutureProvider.family<DateTime?, String>` that queries `SimpleMatchRepository.getByLeague(leagueId)`, filters `isComplete`, returns `max(playedAt)` or `null`; invalidated by `leagueDetailProvider` match mutations above; UI maps `null`/loading/error → "Never", `DateTime` → `DateFormat('MMM d, yyyy')` |

> **Note:** `leagueLastPlayedProvider` is a per-league derived view (legacy path, still valid). `HomeScreen` no longer uses per-league `_LeagueCard` watching individual providers; since the sort feature it consumes the bulk `sortedLeaguesProvider` (`_SortedLeagueCard` `StatelessWidget`) which joins `lastPlayed` via a single `groupBy` scan. `leagueLastPlayedProvider` remains for other per-league callers and is still explicitly invalidated by `LeagueDetailNotifier` (see `lib/providers/league_detail_provider.dart: leagueLastPlayedProvider`).

### sortedLeaguesProvider

| Method | Invalidates |
|--------|-------------|
| (No mutation methods) | N/A — derived `AsyncNotifier<List<SortedLeague>>` (keepAlive, no `ref.watch`, explicit `ref.read` of `leagueRepositoryProvider` + `simpleMatchRepositoryProvider` + `sortPreferenceProvider`). Bulk `getAll()` for leagues + matches, `groupBy` `O(M+L log L)` → `sortLeagues` (null-last date vs alphabetical, tie-break `compareNames`→`id`). Invalidated by `LeaguesNotifier` (add/delete/archive/rename/refresh), `LeagueDetailNotifier` (log/update/delete match), and `SortPreferenceNotifier` (setPreference/setMode/toggleDirection). Error state propagates to `HomeScreen` degraded `Error: ...` (not silent empty). |

### sortPreferenceProvider

| Method | Invalidates |
|--------|-------------|
| `setPreference(pref)` | `sortedLeaguesProvider` (write-then-invalidate: `await repo.set`/`setPreference` → `state = pref` → `ref.invalidate(sortedLeaguesProvider)`); **UI path** — `HomeScreen` single `PopupMenuButton<LeagueSortPreference>` (`tooltip: 'Sort'`, child `Row(swap_vert + Sort)`) has 4 items `Latest` (`latest` = lastPlayed descending true, default) / `Oldest` (`oldest`) / `A-Z` (`aToZ`) / `Z-A` (`zToA`) via const helpers in `sort_preference.dart`; check via `==`, `onSelected` → `setPreference` |
| `setMode(mode)` | `sortedLeaguesProvider` (delegates to `setPreference(copyWith(mode))` — not used by current HomeScreen) |
| `toggleDirection()` | `sortedLeaguesProvider` (delegates to `setPreference(copyWith(descending: !descending))` — not used by current HomeScreen; former `IconButton(swap_vert)` toggle removed) |
| `build()` async load | `sortedLeaguesProvider` (once, via `Future.microtask` only if persisted `pref != state`; no flicker — returns `defaultPreference` synchronously) |

> **Write-then-invalidate:** `LeagueSortPreferenceNotifier` never invalidates before the Hive write completes. Persistence is `Box<String>` `app_preferences` (`sort_mode`/`sort_descending`) with `Hive.isBoxOpen` idempotent guard in `injection_container`. Malformed values fallback to `defaultPreference`; read errors keep the synchronous default so first frame never flickers. UI uses `PopupMenuButton<LeagueSortPreference>` with `LeagueSortPreference.latest`/`oldest`/`aToZ`/`zToA` consts; legacy `PopupMenuButton<LeagueSortMode>` (`Sort by last played` / `Sort by name`) + `IconButton(swap_vert, tooltip Toggle sort direction)` removed. See `lib/providers/sort_preference_provider.dart` and `lib/data/repositories/hive/hive_sort_preference_repository.dart`.

### usersProvider

| Method | Invalidates |
|--------|-------------|
| `addUser` | None (explicit fetch updates self) |
| `deleteUser` | `leaguesProvider`, `userDetailProvider(deletedUserId)`, `leagueDetailProvider(leagueId)` for each affected league |
| `updateUser` | `leaguesProvider`, `userDetailProvider(updatedUserId)`, `leagueDetailProvider(leagueId)` for each league where user has players |

### userDetailProvider(userId)

| Method | Invalidates |
|--------|-------------|
| (No mutation methods) | N/A - Invalidated by other providers |

## UserDetailProvider Invalidation Details

The `userDetailProvider` has no mutation methods of its own. It is invalidated by mutations in `leagueDetailProvider` and `usersProvider`:

### Invalidation from leagueDetailProvider

| Mutation | Invalidated userDetailProvider Instances |
|----------|------------------------------------------|
| `addPlayer` (new user created) | `userDetailProvider(newUserId)` |
| `addPlayer` (existing userId provided) | `userDetailProvider(existingUserId)` |
| `logSimpleMatch` | `userDetailProvider(winnerUserId)`, `userDetailProvider(loserUserId)` |
| `updateSimpleMatch` | `userDetailProvider(newWinnerUserId)`, `userDetailProvider(newLoserUserId)` |
| `deleteMatch` | `userDetailProvider(playerUserId)` for all players in deleted match |
| `updatePlayer` | `userDetailProvider(playerUserId)` |
| `removePlayer` | `userDetailProvider(playerUserId)` |

### Invalidation from usersProvider

| Mutation | Invalidated userDetailProvider Instances |
|----------|------------------------------------------|
| `deleteUser` | `userDetailProvider(deletedUserId)` |
| `updateUser` | `userDetailProvider(updatedUserId)` |

## Ownership Rule — LeagueDetailNotifier Is Sole Invalidator of userDetailProvider

All `userDetailProvider(userId)` invalidation for league-scoped mutations is owned
exclusively by `LeagueDetailNotifier`. The presentation layer (dialogs, screens) must
**not** call `ref.invalidate(userDetailProvider(...))` itself.

**Why:** The earlier global widget at `lib/presentation/widgets/player_edit_dialog.dart`
duplicated `ref.invalidate(userDetailProvider(player.userId))` after `updatePlayer`.
That created two owners for the same side effect (notifier + dialog), risking double
invalidation, race conditions, and an unclear dependency graph. The fix:

- Deleted `lib/presentation/widgets/player_edit_dialog.dart` and the private
  `_EditPlayerDialog` in `league_detail_screen.dart`.
- Unified the dialog at `lib/presentation/screens/league/widgets/player_edit_dialog.dart`;
  its `_submit()` / `_removePlayer()` methods contain an explicit comment
  `// Invalidation is handled by LeagueDetailNotifier... — do not duplicate invalidate here`
  and do **not** import or invalidate `userDetailProvider`.
- `LeagueDetailNotifier.updatePlayer` and `LeagueDetailNotifier.removePlayer` remain the
  single place that calls `ref.invalidate(userDetailProvider(userId))` after the write
  succeeds (see tables above). `PlayerEditDialog` only awaits the notifier and pops.

If you add a new league-player mutation, add the `ref.invalidate(userDetailProvider(...))`
call inside `LeagueDetailNotifier`, not in any widget.

### Presentation Layer Is Not an Invalidation Owner

```dart
// BAD — inside PlayerEditDialog._submit() (removed)
await ref.read(leagueDetailProvider(leagueId).notifier)
    .updatePlayer(playerId: id, name: name, icon: icon);
ref.invalidate(userDetailProvider(player.userId)); // ❌ duplicated, now forbidden
```

```dart
// GOOD — inside LeagueDetailNotifier.updatePlayer() (sole owner)
await _playerRepo.put(updatedPlayer);
ref.invalidate(userDetailProvider(userId)); // ✅ sole location
return _fetchData();
```

Dialogs may watch state (e.g. `PlayerEditDialog` title selectively watches `usersProvider` via `usersProvider.select((a) => a.whenData(...))`),
but they never invalidate cross-provider state.

## Implementation Details

### DeleteUserService Returns Affected League IDs

The `DeleteUserService.execute()` method returns a `DeleteUserResult` containing the set of league IDs where the deleted user had players. This allows precise invalidation of only the affected `leagueDetailProvider` instances.

```dart
class DeleteUserResult {
  const DeleteUserResult({required this.affectedLeagueIds});
  final Set<String> affectedLeagueIds;
}
```

### Finding Affected Leagues for User Updates

When updating a user, we query the `LeaguePlayerRepository` to find all leagues where the user has players:

```dart
final userPlayers = await _playerRepo.getByUserId(user.id);
final leagueIds = userPlayers.map((p) => p.leagueId).toSet();
for (final leagueId in leagueIds) {
  ref.invalidate(leagueDetailProvider(leagueId));
}
```

### Removed Reactive Watches

The following `ref.watch()` calls were removed to eliminate unnecessary rebuilds:

- `leagueDetailProvider.build()`: Removed `ref.watch(usersProvider)`
- `userDetailProvider.build()`: Removed `ref.watch(usersProvider)` and `ref.watch(leaguesProvider)`

These providers now rely on explicit invalidation from mutation methods.

### AsyncNotifier Field Initialization — `late` Not `late final`

All `AsyncNotifier` fields that are assigned inside `build()` **must** be declared `late`, not `late final`.

**Why:** The explicit-invalidation graph (`ref.invalidate(provider)`) re-executes `build()` on next read. A `late final` field can only be assigned once per notifier instance; the second `build()` assignment throws `LateInitializationError: Field '_xxx@...' has already been initialized.` Using `late` (without `final`) allows re-assignment on every rebuild.

This was fixed in `LeaguesNotifier` (`_leagueRepository`, `_createLeagueService`) and `UsersNotifier` (`_repo`, `_deleteService`, `_updateService`, `_playerRepo`) — previously `late final`, now `late`. `LeagueDetailNotifier` and `UserDetailNotifier` already used `late` and were not affected.

**Invariant:** Fields assigned in `AsyncNotifier.build()` must be `late` not `late final` because `build()` is re-entrant after `ref.invalidate()` – `late final` would throw on second build.

## Testing

### Unit Tests

Unit tests verify that:
- Each mutation method calls the expected invalidation methods
- State is correctly updated via explicit fetch
- Self-invalidation is not used

### Integration Tests

Integration tests (`test/integration/providers/invalidation_test.dart`) verify (25 tests total):
- Cross-provider invalidation works correctly
- Dependent providers receive updates after mutations
- No stale data remains after mutations
- **userDetailProvider invalidation scenarios (6 tests):**
  - `addPlayer` with new user invalidates `userDetailProvider` for new user
  - `addPlayer` with existing userId invalidates `userDetailProvider` for that user
  - `logSimpleMatch` invalidates both winner and loser `userDetailProvider`
  - `updateSimpleMatch` invalidates both winner and loser `userDetailProvider`
  - `deleteMatch` invalidates all involved players' `userDetailProvider`
  - `updatePlayer` and `removePlayer` invalidate affected user's `userDetailProvider`
- **LateInitializationError rebuild coverage (3 tests):**
  - `leaguesProvider` rebuild after `usersProvider.updateUser` invalidation — no `LateInitializationError`
  - `usersProvider` rebuild after `leagueDetailProvider.addPlayer(newUser)` invalidation — no `LateInitializationError`
  - Two sequential `updateUser` invalidations rebuild `leaguesProvider` twice — no `LateInitializationError` (verifies `late` fix)
- **leagueLastPlayedProvider invalidation (4 tests) — My Leagues last-played fix:**
  - `logSimpleMatch` invalidates `leagueLastPlayedProvider(leagueId)` — next read returns newest `DateTime`
  - `updateSimpleMatch` invalidates `leagueLastPlayedProvider` — re-fetches max `playedAt`
  - `deleteMatch` invalidates `leagueLastPlayedProvider` — returns `null` when no completes remain (UI → "Never")
  - Incomplete-only filter — `isComplete: false` matches are ignored; `null` returned despite later `playedAt` on incomplete (covers the `isComplete` filter invariant)

## Common Pitfalls

### ❌ Don't: Self-Invalidation
```dart
// BAD - causes race condition between explicit fetch and rebuild
Future<void> addItem() async {
  state = const AsyncValue.loading();
  state = await AsyncValue.guard(() async {
    await _repo.add(item);
    ref.invalidate(myProvider); // DON'T do this
    final items = await _repo.getAll();
    return items;
  });
}
```

### ✅ Do: Explicit Fetch Without Self-Invalidation
```dart
// GOOD - explicit fetch updates state, no race condition
Future<void> addItem() async {
  state = const AsyncValue.loading();
  state = await AsyncValue.guard(() async {
    await _repo.add(item);
    final items = await _repo.getAll();
    return items;
  });
}
```

### ❌ Don't: Invalidate from the Presentation Layer
```dart
// BAD - dialog duplicates invalidation owned by LeagueDetailNotifier
Future<void> _submit() async {
  await ref.read(leagueDetailProvider(leagueId).notifier)
      .updatePlayer(playerId: id, name: name, icon: icon);
  ref.invalidate(userDetailProvider(userId)); // ❌ remove — notifier already does this
}
```

### ❌ Don't: Reactive Watches for Invalidation
```dart
// BAD - causes unnecessary rebuilds when ANY user/league changes
@Override
Future<State> build() async {
  ref.watch(usersProvider); // DON'T do this
  ref.watch(leaguesProvider); // DON'T do this
  return _fetchData();
}
```

### ✅ Do: Explicit Invalidation from Mutation Sources
```dart
// GOOD - precise invalidation from mutation methods
Future<void> addPlayer() async {
  // ... mutation logic ...
  ref.invalidate(usersProvider); // Invalidate dependent provider
  ref.invalidate(userDetailProvider(newUserId)); // Invalidate specific instance
}
```

### ❌ Don't: `late final` Fields Assigned in `build()`
```dart
// BAD - second build() after ref.invalidate() throws LateInitializationError
class LeaguesNotifier extends AsyncNotifier<List<League>> {
  late final LeagueRepository _repo; // ❌ final prevents re-assignment
  @override
  Future<List<League>> build() async {
    _repo = ref.read(repoProvider); // throws on second build
    return _repo.getAll();
  }
}
```

### ✅ Do: `late` Fields Assigned in `build()`
```dart
// GOOD - build() is re-entrant; late allows re-assignment
class LeaguesNotifier extends AsyncNotifier<List<League>> {
  late LeagueRepository _repo; // ✅ re-assignable on every build()
  @override
  Future<List<League>> build() async {
    _repo = ref.read(repoProvider); // succeeds on every rebuild
    return _repo.getAll();
  }
}
```

## Migration Guide

If adding a new mutation method:

1. Identify all providers that depend on the mutated data
2. Add `ref.invalidate()` calls for each dependent provider AFTER the write succeeds
3. Do NOT invalidate the provider containing the mutation method
4. Ensure explicit fetch returns fresh data for the current provider
5. Add unit tests verifying invalidation calls
6. Add integration tests if cross-provider behavior is complex

## Ordering Note (non-invalidation) & Sorting ↔ Invalidation Boundary

Sorting does not change the write path — it only determines **when the
derived sorted cache is invalidated**. Two ordering concerns are independent:

- **Name ordering** (`lib/core/sorting/name_sort.dart:compareNames`) is applied **in-memory after every fetch** — `usersProvider` re-sorts on `build`/`addUser`/`deleteUser`/`updateUser`/`refresh`; `leagueDetailProvider._fetchData()` derives both `players` (ranked) and `playersByName` (alphabetical) from the same raw snapshot. Hive repositories remain unsorted (storage order). See `docs/architecture/sorting.md` and `docs/domain-language.md` → *Ordering — Alphabetical Pickers vs Ranked Standings* for the ranked-vs-alphabetical invariant and the picker ban (`playersByName` for pickers, `players` for standings only).

- **My Leagues ordering** (`lib/application/services/sorted_leagues_service.dart:compareLeagues` / `sortLeagues`, `lib/core/sorting/date_sort.dart:compareNullableDateNullLast`) is a **derived sorted view** (`sortedLeaguesProvider`) over the `SortedLeague` DTO (`league` + nullable `lastPlayed` via `maxCompletePlayedAt` in `lib/domain/services/match_stats.dart`). Default: `lastPlayed` descending (most recent first, `null`/"Never" last); 4 states (`lastPlayed` desc/asc, alphabetical A→Z/Z→A) via `LeagueSortPreference` (`lib/application/preferences/sort_preference.dart`). Tie-break is deterministic `compareNames` → `id`. Bulk strategy is `O(M + L log L)` (`groupBy` single scan over all matches + `L log L` sort). See `docs/architecture/sorting.md` and `docs/domain-language.md` → *Ordering — My Leagues* and the dependency graph / invalidation tables above for `sortedLeaguesProvider` + `sortPreferenceProvider`.

In both cases sorting is in-memory; repositories never sort. `sortedLeaguesProvider` explicitly uses `ref.read` (no `ref.watch`) — re-sorting after a preference toggle or a write that changes `lastPlayed` / league set is triggered solely by explicit `ref.invalidate(sortedLeaguesProvider)` from the three owners (`LeaguesNotifier`, `LeagueDetailNotifier`, `LeagueSortPreferenceNotifier`). KeepAlive (`AsyncNotifier`, not `autoDispose`) means the sorted cache persists across rebuilds until an owner invalidates it. Degraded error handling: systematic repo failures in `sortedLeaguesProvider.build()` propagate as `AsyncError` and `HomeScreen` renders `Error: ...` (red `AppTheme.errorRed`) rather than a silent empty list; `sortPreferenceProvider` keeps its synchronous `defaultPreference` on read errors so `HomeScreen` never flickers on first frame.

## Related Files

- `lib/providers/leagues_provider.dart` — `LeaguesNotifier` (`late` fields, `_invalidateSorted()` helper → `ref.invalidate(sortedLeaguesProvider)` on add/delete/archive/rename/refresh)
- `lib/providers/league_detail_provider.dart` — defines `leagueLastPlayedProvider(leagueId)` (`FutureProvider.family<DateTime?, String>` → `SimpleMatchRepository.getByLeague` + `isComplete` filter + `max playedAt`) and `LeagueDetailNotifier` (sole owner of `userDetailProvider` invalidation for `updatePlayer` / `removePlayer` / match mutations, sole invalidator of `leagueLastPlayedProvider` and co-owner of `sortedLeaguesProvider` on `logSimpleMatch` / `updateSimpleMatch` / `deleteMatch`); also computes `players` (ranked) and `playersByName` (alphabetical) in `_fetchData()`
- `lib/providers/sorted_leagues_provider.dart` — `SortedLeague` DTO (`league` + `lastPlayed`) + `SortedLeaguesNotifier` (`AsyncNotifier` keepAlive, no mutation methods, `ref.read` bulk `getAll` + `groupBy` `O(M+L log L)` → `sortLeagues`, no `ref.watch`, explicit invalidation only)
- `lib/providers/sort_preference_provider.dart` — `leagueSortPreferenceRepositoryProvider` (`Provider<SortPreferenceRepository>` via `GetIt`) + `sortPreferenceProvider` (`NotifierProvider<LeagueSortPreferenceNotifier, LeagueSortPreference>`: sync `defaultPreference` no-flicker, async `repo.get()` + microtask invalidate, `setPreference`/`setMode`/`toggleDirection` write-then-invalidate; UI uses `setPreference` with consts `latest`/`oldest`/`aToZ`/`zToA`)
- `lib/application/preferences/sort_preference.dart` — `LeagueSortMode` / `LeagueSortPreference` (`defaultPreference` = `lastPlayed` descending, helpers `latest`/`oldest`/`aToZ`/`zToA` for the 4-item Sort menu)
- `lib/core/preferences/sort_preference.dart` — re-export alias
- `lib/application/services/sorted_leagues_service.dart` — `compareLeagues` / `sortLeagues` (null-last date, alphabetical, tie-break `compareNames`→`id`)
- `lib/core/sorting/league_sort.dart` — re-export alias
- `lib/core/sorting/date_sort.dart` — `compareNullableDateNullLast` (null always last, `descending` flag)
- `lib/core/sorting/name_sort.dart` — pure comparator (`trim` / empty-first / case-insensitive primary / case-sensitive secondary); not locale-aware (see `docs/architecture/sorting.md`)
- `lib/domain/services/match_stats.dart` — `maxCompletePlayedAt` (max `playedAt` of `isComplete` matches, `null` if none)
- `lib/data/repositories/hive/hive_sort_preference_repository.dart` — `Box<String>` `app_preferences` (`sort_mode`/`sort_descending`, `boxName` constant, `Hive.isBoxOpen` guard in `injection_container`, malformed fallback)
- `lib/core/injection_container.dart` — idempotent `app_preferences` open (`Hive.isBoxOpen` guard), `SortPreferenceRepository` lazy singleton; no `hiveDbVersion` bump for `Box<String>` addition, `TypeId 11` reserved not used
- `lib/domain/repositories/preferences/sort_preference_repository.dart` — abstract `get`/`set` + `getPreference`/`setPreference` aliases (skeleton, resilience R7)
- `lib/presentation/screens/home/home_screen.dart` — `HomeScreen` (`ConsumerWidget` watching `sortedLeaguesProvider` + `sortPreferenceProvider`; `AppBar.actions` → single `PopupMenuButton<LeagueSortPreference>` `tooltip: 'Sort'` with child `Row(swap_vert + Sort)`; 4 items `Latest`/`Oldest`/`A-Z`/`Z-A` via consts `latest`/`oldest`/`aToZ`/`zToA`, check via `==`, `onSelected` → `setPreference` write-then-invalidate) + `Stateless _SortedLeagueCard` (`DateFormat('MMM d, yyyy')`, `null` → "Last played: Never"); replaces former `_LeagueCard` (`ConsumerWidget` watching `leagueLastPlayedProvider`) and former two-control `PopupMenuButton<LeagueSortMode>` + `IconButton(swap_vert)` toggle
- `lib/providers/users_provider.dart` — sorts via `compareNames` + `id` on every path (`build`/`addUser`/`deleteUser`/`updateUser`/`refresh`)
- `lib/providers/user_detail_provider.dart`
- `lib/application/services/delete_user_service.dart`
- `lib/presentation/screens/league/widgets/player_edit_dialog.dart` — unified `PlayerEditDialog` (requires `showRemoveAction`, title bracket via selective `usersProvider` watch); **does not** invalidate providers
- `docs/architecture/sorting.md` — sorting contracts, bulk strategy, DTO, 4 states
- `docs/domain-language.md` — *Ordering — My Leagues* (recency vs alphabetical) + *Ordering — Alphabetical Pickers vs Ranked Standings*
- `docs/versioning.md` — Hive boxes (`app_preferences` `Box<String>` no-version-bump note)
- `test/unit/providers/league_last_played_provider_test.dart` — 6 unit tests for `leagueLastPlayedProvider` (empty, incomplete-only → null, single complete, max unsorted, error, invalidate re-fetch)
- `test/unit/core/sorting/date_sort_test.dart`, `test/unit/core/sorting/name_sort_test.dart` — comparator unit tests
- `test/unit/domain/services/match_stats_test.dart`, `test/unit/application/services/sorted_leagues_service_test.dart` — league sort / stats tests
- `test/unit/data/repositories/hive_sort_preference_repository_test.dart` — persistence tests (default fallback, round-trip, malformed graceful, alias consistency, `boxName` constant)
- `test/unit/providers/` - Unit tests for each provider (including `sorted_leagues` + `sort_preference`)
- `test/integration/providers/invalidation_test.dart` - Cross-provider integration tests (`leagueLastPlayedProvider` invalidation: log/update/delete + incomplete-only null; also `sortedLeaguesProvider` bulk + `sort_preference` write-then-invalidate)
- `test/integration/presentation/screens/home/home_screen_test.dart` — 9 HomeScreen widget tests (loading, error, empty/CTA, league list display via bulk `SortedLeague` `lastPlayed: null` → "Last played: Never", navigation, FAB, multi-league, pull-to-refresh without `RefreshIndicator`; uses `sortedLeaguesProvider` + `sortPreferenceProvider` bulk overrides — per-league `leagueLastPlayedProvider` / `simpleMatchRepositoryProvider` / `MockSimpleMatchRepository` deprecated bulk R5 group removed)
- `test/integration/presentation/screens/home/home_screen_sorting_test.dart` — 9 HomeScreen sorting integration tests (R1 default lastPlayed desc via bulk `groupBy` `O(M+L log L)`, R2 `PopupMenuButton<LeagueSortPreference>` 4 items `Latest`/`Oldest`/`A-Z`/`Z-A` checkmark via `==`, R3 preference switching via `setPreference` (`swap_vert` + `Sort`, `tooltip: 'Sort'`), R5 keepAlive — `sortedLeaguesProvider` not refetched without explicit invalidate (bulk path replaces deprecated per-league `leagueLastPlayedProvider` + `simpleMatchRepositoryProvider`), R7 error degraded + empty, alphabetical empty-first with null-last, AppBar single sort control, `Stateless _SortedLeagueCard` Never/date `DateFormat('MMM d, yyyy')` with `isComplete` filter)