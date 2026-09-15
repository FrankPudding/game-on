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
| `logSimpleMatch` | `userDetailProvider(winnerId)`, `userDetailProvider(loserId)` |
| `updateSimpleMatch` | `userDetailProvider(winnerId)`, `userDetailProvider(loserId)` |
| `deleteMatch` | `userDetailProvider(playerId)` for all players in match |
| `updatePlayer` | `userDetailProvider(playerUserId)` |
| `removePlayer` | `usersProvider`, `userDetailProvider(playerUserId)` |

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

## Testing

### Unit Tests

Unit tests verify that:
- Each mutation method calls the expected invalidation methods
- State is correctly updated via explicit fetch
- Self-invalidation is not used

### Integration Tests

Integration tests (`test/integration/providers/invalidation_test.dart`) verify:
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

### ❌ Don't: Reactive Watches for Invalidation
```dart
// BAD - causes unnecessary rebuilds when ANY user/league changes
@override
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

## Migration Guide

If adding a new mutation method:

1. Identify all providers that depend on the mutated data
2. Add `ref.invalidate()` calls for each dependent provider AFTER the write succeeds
3. Do NOT invalidate the provider containing the mutation method
4. Ensure explicit fetch returns fresh data for the current provider
5. Add unit tests verifying invalidation calls
6. Add integration tests if cross-provider behavior is complex

## Related Files

- `lib/providers/leagues_provider.dart`
- `lib/providers/league_detail_provider.dart`
- `lib/providers/users_provider.dart`
- `lib/providers/user_detail_provider.dart`
- `lib/application/services/delete_user_service.dart`
- `test/unit/providers/` - Unit tests for each provider
- `test/integration/providers/invalidation_test.dart` - Cross-provider integration tests