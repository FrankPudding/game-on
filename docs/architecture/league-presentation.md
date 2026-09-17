# League Presentation — Player Editing

## Purpose

Documents the league-scoped player-editing UI: where it lives, how it is reused,
and why it visually distinguishes the global `User` from the league-scoped
`LeaguePlayer`.

## Canonical Locations

| Component | Path | Notes |
|-----------|------|-------|
| `PlayerEditDialog` | `lib/presentation/screens/league/widgets/player_edit_dialog.dart` | Unified dialog — **sole** player-edit dialog. Requires `showRemoveAction: bool`. |
| `LeagueDetailScreen` | `lib/presentation/screens/league/league_detail_screen.dart` | Calls `PlayerEditDialog.show(..., showRemoveAction: true)`. |

### Former locations (deleted — do not reintroduce)

- Private `_EditPlayerDialog` inside `league_detail_screen.dart` — removed; replaced by the unified widget above.
- Global widget `lib/presentation/widgets/player_edit_dialog.dart` — deleted. Its copy duplicated `ref.invalidate(userDetailProvider(...))`, violating the single-owner rule (see `provider-invalidation.md`).
- `LinkedUserHeader` (`lib/presentation/screens/league/widgets/linked_user_header.dart`) — deleted; replaced by the bracket title inside `PlayerEditDialog` (see Title Bracket Spec below).

> **Rule:** Import from `lib/presentation/screens/league/widgets/player_edit_dialog.dart`. The old `lib/presentation/widgets/...` path no longer exists.

## PlayerEditDialog — API

```dart
const PlayerEditDialog({
  required String leagueId,
  required LeaguePlayer player,
  required bool showRemoveAction, // required — no default
});

static Future<void> show(BuildContext context, {
  required String leagueId,
  required LeaguePlayer player,
  required bool showRemoveAction,
});
```

### `showRemoveAction` is required

The dialog is reused in two contexts with different affordances:

- **`LeagueDetailScreen` → `showRemoveAction: true`** — Standings tab owns league membership; removing a `LeaguePlayer` (if they have no match history) is allowed. Shows the `Remove from League` `TextButton.icon` and wires `LeagueDetailNotifier.removePlayer`.

- **`UserDetailScreen` (`lib/presentation/screens/settings/user_detail_screen.dart`) → `showRemoveAction: false`** — The user-detail view is cross-league and read-oriented; removing a player from there would be surprising. The remove affordance is hidden.

Making the flag required forces every call site to make an explicit, reviewable decision. Do not add a default value.

## Title Bracket Spec

The linked global `User` is surfaced directly in the dialog **title** as a bracket suffix, not as a separate header card. The parent (`PlayerEditDialog`) derives the linked user via a **selective watch**:

```dart
final userAsync = ref.watch(usersProvider.select((a) => a.whenData((users)=> users.where((u)=>u.id==player.userId).firstOrNull)));
```

This avoids rebuilding the whole dialog when unrelated users change — only the resolved user for `player.userId` matters.

### Helpers

```dart
String _truncateName(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return 'Unknown user';
  if (t.length > 22) return '${t.substring(0, 22)}…';
  return t;
}

String _semanticLabel(AsyncValue<User?> async) => async.when(
  data: (u) => u == null
    ? 'Edit Player, Unknown user — linked account missing'
    : 'Edit Player, linked to ${_truncateName(u.name)}',
  loading: () => 'Edit Player, loading linked user',
  error: (_, __) => 'Edit Player, Unknown user — failed to load linked user',
);

Widget _buildTitle(AsyncValue<User?> async) => async.when(
  data: (user) {
    final name = user == null ? 'Unknown user' : _truncateName(user.name);
    final isUnknown = name == 'Unknown user';
    final suffix = ' ($name)';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Edit Player'),
        Flexible(child: Text(suffix, overflow: TextOverflow.ellipsis, style: isUnknown ? TextStyle(fontStyle: FontStyle.italic, color: AppTheme.textTertiary) : null)),
      ],
    );
  },
  loading: () => const Text('Edit Player'),
  error: (_, __) => Row(children: [const Text('Edit Player'), const Flexible(child: Text(' (Unknown user)', overflow: TextOverflow.ellipsis, style: TextStyle(fontStyle: FontStyle.italic, color: AppTheme.textTertiary)))]),
);
```

### Title wrapping (a11y)

```dart
Semantics(
  header: true,
  label: _semanticLabel(userAsync),
  child: ExcludeSemantics(child: _buildTitle(userAsync)),
)
```

The `Semantics` header provides the full spoken label (including truncation-aware linked name or unknown/loading/error variants), while `ExcludeSemantics` prevents the visual `Row` children from being read twice.

### States

- **Data + User found (known name):** `Row(mainAxisSize: min)` → `Text('Edit Player')` (never truncates) + `Flexible Text(' (TruncatedName)' ellipsis)`. Name is trimmed and truncated at 22 chars + `…`; normal (non-italic) style.
- **Data + Unknown user (orphan, empty/whitespace name, or error fallback):** Same `Row(min)` → `Text('Edit Player')` + `Flexible Text(' (Unknown user)' ellipsis, italic textTertiary)`. Styling is driven by `isUnknown = name == 'Unknown user'` (covers `user == null`, `_truncateName` returning `Unknown user` for empty/whitespace, and the error branch). Semantic label announces `Edit Player, Unknown user — linked account missing` for null, `Edit Player, linked to Unknown user` for empty/whitespace name, and `Edit Player, Unknown user — failed to load linked user` for error.
- **Loading:** Plain `Text('Edit Player')` — no brackets, no spinner. The semantic label still announces `Edit Player, loading linked user`.
- **Error:** `Row` → `Text('Edit Player')` + `Flexible Text(' (Unknown user)' ellipsis, italic textTertiary)` (same `isUnknown` styling).

### Overflow invariant

Ellipsis applies **only** to the suffix `Flexible` — the prefix `Edit Player` never truncates. `Row(mainAxisSize: min)` keeps the title compact; long names are truncated before display (22 + `…`) and additionally ellipsized by layout.

### Content

The `LinkedUserHeader` card and its `SizedBox(12)` spacer are removed. Dialog content starts with:

```dart
const Text('Changes only affect this league.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
const SizedBox(height: 16),
TextField(labelText: 'Nickname', ...),
```

Followed by icon picker and conditional `Remove from League` action. No `LinkedUserHeader` import.

### Non-interactive

The title is informational only. It does not navigate, does not open `UserDetailScreen`, and has no tap handler. This preserves the dialog's single purpose: editing the **league-scoped** `LeaguePlayer`.

## Rationale — Why the Bracket Title

`User` (global) and `LeaguePlayer` (per-league nickname + icon) are distinct domain concepts (see `docs/domain-language.md`). Without a visual cue, users reasonably assume editing the name/icon changes their global profile. The bracket suffix + subtitle make the scope explicit:

1. **Title answers "who is this?"** — Shows the linked global User as `Edit Player (<name>)` in the header.
2. **Subtitle answers "what will change?"** — `"Changes only affect this league."` (top of content, `13sp textSecondary`) scopes the edit to the `LeaguePlayer` row.
3. **Together they reinforce the invariant:** `LeagueDetailNotifier.updatePlayer` mutates `LeaguePlayer` only; `User` is untouched. Verified by the provider tests.

## Player Ordering — Ranked vs Alphabetical

`LeagueDetailState` exposes two views of the same player set (see `docs/architecture/sorting.md`):

- `players` — **ranked** (`points → GD → GF → id`). Never uses `name` as a tie-breaker; only `id` is the stable fallback. Only `_StandingsTab` may use this list.
- `playersByName` — **alphabetical** (`compareNames(name) → id`, via `lib/core/sorting/name_sort.dart`). Trim/empty-first/case-insensitive primary + case-sensitive secondary, then `id`. Pickers, selectors and dropdowns must use this list.

`LeagueDetailScreen` passes ranked `state.players` to both `_StandingsTab` and `_MatchesTab` for display; all pickers in `LogMatchScreen` (two-player auto-select, `_PlayerSelector` sheets, winner dropdown and score labels) use `state.playersByName` and carry a `// Use alphabetical list for pickers — never ranked list.` comment. `_AddPlayerDialog` inherits alphabetical order from `usersProvider` (already `compareNames`-sorted) filtered by `existingUserIds` — it does not re-sort locally.

**Ban:** Never use `players` for a picker/selector and never add name as a tie-breaker to the ranked sort. Tests assert the two lists are same-elements-different-order and that a player with top points (`Bob`) still sorts after `Alice` alphabetically — standings must stay ranked.

## Invalidation Ownership

`PlayerEditDialog` **does not** invalidate providers. `LeagueDetailNotifier` is the sole owner
of `userDetailProvider` invalidation for `updatePlayer` / `removePlayer` (see
`docs/architecture/provider-invalidation.md` → *Ownership Rule — LeagueDetailNotifier Is Sole Invalidator*).
Dialog code contains an explicit comment to that effect — do not re-add `ref.invalidate(userDetailProvider(...))` in the widget.

## Dependencies

```
PlayerEditDialog
  ├── ref.watch(usersProvider.select(...)) → title bracket (selective watch, header semantics)
  ├── LeagueDetailNotifier.updatePlayer() / removePlayer() (via leagueDetailProvider)
  └── AppTheme (surfaceOffWhite, accentRed, textTertiary, errorRed)
```

## Related Files

- `lib/presentation/screens/league/widgets/player_edit_dialog.dart`
- `lib/presentation/screens/league/league_detail_screen.dart`
- `lib/presentation/screens/settings/user_detail_screen.dart` (reuses dialog with `showRemoveAction: false`)
- `lib/providers/league_detail_provider.dart` — invalidation owner
- `docs/domain-language.md` — User vs LeaguePlayer
- `docs/architecture/provider-invalidation.md` — invalidation ownership rule
