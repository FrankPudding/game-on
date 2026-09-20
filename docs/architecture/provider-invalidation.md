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
  └── invalidate: leagueDetailProvider(leagueId) when league deleted

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

leagueLastPlayedProvider(leagueId) (derived FutureProvider<DateTime?> for My Leagues last-played)
  ├── No mutation methods — reads SimpleMatchRepository.getByLeague, filters isComplete, returns max playedAt (null → "Never")
  └── Invalidated by: leagueDetailProvider(leagueId) on logSimpleMatch / updateSimpleMatch / deleteMatch
```

## Invalidation Rules by Mutation

### leaguesProvider

| Method | Invalidates |
|--------|-------------|
| `addLeague` | None (explicit fetch updates self) |
| `deleteLeague` | `leagueDetailProvider(deletedLeagueId)` |

### leagueDetailProvider(leagueId)

| Method | Invalidates |
|--------|-------------|
| `addPlayer` | `usersProvider` (if new user created), `userDetailProvider(newUserId)` |
| `logSimpleMatch` | `userDetailProvider(winnerId)`, `userDetailProvider(loserId)`, `leagueLastPlayedProvider(leagueId)` |
| `updateSimpleMatch` | `userDetailProvider(winnerId)`, `userDetailProvider(loserId)`, `leagueLastPlayedProvider(leagueId)` |
| `deleteMatch` | `userDetailProvider(playerId)` for all players in match, `leagueLastPlayedProvider(leagueId)` |
| `updatePlayer` | `userDetailProvider(playerUserId)` |
| `removePlayer` | `usersProvider`, `userDetailProvider(playerUserId)` |

### leagueLastPlayedProvider(leagueId)

| Method | Invalidates |
|--------|-------------|
| (No mutation methods) | N/A — read-only `FutureProvider.family<DateTime?, String>` that queries `SimpleMatchRepository.getByLeague(leagueId)`, filters `isComplete`, returns `max(playedAt)` or `null`; invalidated by `leagueDetailProvider` match mutations above; UI maps `null`/loading/error → "Never", `DateTime` → `DateFormat('MMM d, yyyy')` |

> **Note:** `leagueLastPlayedProvider` is a derived view for `HomeScreen._LeagueCard` ("My Leagues" list). It does not watch other providers; it is explicitly invalidated after successful writes in `LeagueDetailNotifier` (see `lib/providers/league_detail_provider.dart: leagueLastPlayedProvider` and `HomeScreen` `ConsumerWidget`).

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

## Ordering Note (non-invalidation)

Sorting does not affect invalidation. Alphabetical ordering (`lib/core/sorting/name_sort.dart:compareNames`) is applied **in-memory after every fetch** — `usersProvider` re-sorts on `build`/`addUser`/`deleteUser`/`updateUser`/`refresh`; `leagueDetailProvider._fetchData()` derives both `players` (ranked) and `playersByName` (alphabetical) from the same raw snapshot. Hive repositories remain unsorted (storage order). See `docs/architecture/sorting.md` and `docs/domain-language.md` → *Ordering* for the ranked-vs-alphabetical invariant and the picker ban (`playersByName` for pickers, `players` for standings only).

## Related Files

- `lib/providers/leagues_provider.dart`
- `lib/providers/league_detail_provider.dart` — defines `leagueLastPlayedProvider(leagueId)` (`FutureProvider.family<DateTime?, String>` → `SimpleMatchRepository.getByLeague` + `isComplete` filter + `max playedAt`) and `LeagueDetailNotifier` (sole owner of `userDetailProvider` invalidation for `updatePlayer` / `removePlayer` / match mutations and sole invalidator of `leagueLastPlayedProvider` on `logSimpleMatch` / `updateSimpleMatch` / `deleteMatch`); also computes `players` (ranked) and `playersByName` (alphabetical) in `_fetchData()`
- `lib/presentation/screens/home/home_screen.dart` — `HomeScreen` + `_LeagueCard` (`ConsumerWidget` watching `leagueLastPlayedProvider(leagueId)`, `DateFormat('MMM d, yyyy')`, `null`/loading/error → "Last played: Never")
- `lib/providers/users_provider.dart` — sorts via `compareNames` + `id` on every path (`build`/`addUser`/`deleteUser`/`updateUser`/`refresh`)
- `lib/providers/user_detail_provider.dart`
- `lib/core/sorting/name_sort.dart` — pure comparator (`trim` / empty-first / case-insensitive primary / case-sensitive secondary); not locale-aware (see `docs/architecture/sorting.md`)
- `lib/application/services/delete_user_service.dart`
- `lib/presentation/screens/league/widgets/player_edit_dialog.dart` — unified `PlayerEditDialog` (requires `showRemoveAction`, title bracket via selective `usersProvider` watch); **does not** invalidate providers
- `test/unit/providers/league_last_played_provider_test.dart` — 6 unit tests for `leagueLastPlayedProvider` (empty, incomplete-only → null, single complete, max unsorted, error, invalidate re-fetch)
- `test/unit/providers/` - Unit tests for each provider
- `test/integration/providers/invalidation_test.dart` - Cross-provider integration tests (`leagueLastPlayedProvider` invalidation: log/update/delete + incomplete-only null)
- `test/integration/presentation/screens/home/home_screen_test.dart` — 7 "Last Played" widget/integration tests (never, complete date formatting, incomplete filtered, invalidation after log)