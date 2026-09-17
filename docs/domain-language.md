User - Either the app owner, or someone the app owner wants represented in the app. A User is the global identity (name, icon, avatarColor). It exists in `usersProvider` and is independent of any League.

LeaguePlayer - A representation of a User in a League. A User can be a participant in multiple Leagues and they should have a single LeaguePlayer per League they are involved in. LeaguePlayer holds the **league-scoped** nickname and icon — these are stored on the `LeaguePlayer` row (`userId` + `leagueId`) and may differ from the linked User's name/icon and from the same User's LeaguePlayer in another League.

League - A collection of information regarding LeaguePlayers and their Matches against each other. A League should be parametrised by a particular subclass of Match.

RankingPolicy - When a League is set up, it needs to be given a RankingPolicy. This RankingPolicy will take a list of all matches and calculate the ranking of each LeaguePlayer based on their Match results. It will also calculate relevant metrics for each LeaguePlayer based on their Match results. The RankingPolicy will be parametrised by a particular subclass of Match.

Match – A competition between Sides. A Match is made up of two or more Sides playing against each other.

Side – A set of LeaguePlayers from the same League competing together against other Sides. A Side can be made up of one or more LeaguePlayers.

## Visual Distinction — User vs LeaguePlayer

The domain distinction (global User vs league-scoped LeaguePlayer) is made explicit in the edit flow:

- **Title bracket** (`lib/presentation/screens/league/widgets/player_edit_dialog.dart`) — `PlayerEditDialog` shows the linked global `User` as a bracket suffix in the title: `Edit Player (<name>)`. It uses a **selective watch** of `usersProvider` (`select((a) => a.whenData((users)=> users.where((u)=>u.id==player.userId).firstOrNull))`) and renders:
  - `Edit Player (Alice)` with truncation at 22 chars + `…` when the `userId` resolves to a User with a non-empty name (normal style).
  - `Edit Player (Unknown user)` (italic, `textTertiary`, ellipsis on suffix only) when the display name is `Unknown user` — covers `user == null` (orphan), `_truncateName` empty/whitespace fallback, and error state. Styling uses `isUnknown = name == 'Unknown user'` (not `user == null` alone).
  - Plain `Edit Player` (no brackets, no spinner) while loading.
  The title is wrapped in `Semantics(header: true, label: _semanticLabel(...), child: ExcludeSemantics(child: _buildTitle(...)))` so the accessible label announces `Edit Player, linked to <name>` / `Unknown user — linked account missing` / `loading linked user` / `failed to load linked user`. Prefix `Edit Player` never truncates; only the suffix is `Flexible` + `ellipsis`.

- **"Changes only affect this league."** — the subtitle at the top of `PlayerEditDialog` content (`lib/presentation/screens/league/widgets/player_edit_dialog.dart`). Editing the nickname/icon mutates only the `LeaguePlayer` (via `LeagueDetailNotifier.updatePlayer`); it does not update the `User` row or any other league's `LeaguePlayer` for the same User.

- **Invariants:** Bracket suffix is `Flexible` + `ellipsis`; row is `mainAxisSize: min`; `_truncateName` trims and caps at 22 + `…`. Former `LinkedUserHeader` card (`lib/presentation/screens/league/widgets/linked_user_header.dart`) is deleted.

## Ordering — Alphabetical Pickers vs Ranked Standings

Users and league players are presented **alphabetically** wherever they appear as selectable or browsable lists; the **only** exception is the league standings table, which is ordered by competitive position.

- **Users** (`usersProvider`) — alphabetical by `User.name` using `lib/core/sorting/name_sort.dart:compareNames` then `id`. Trimmed, empty/whitespace first, case-insensitive primary with case-sensitive secondary for determinism (see `docs/architecture/sorting.md`). Insertion or storage order never affects display; all provider paths (`build`, `addUser`, `deleteUser`, `updateUser`, `refresh`) re-sort.
- **League players as pickers** — alphabetical as above via `LeagueDetailState.playersByName` (`compareNames(LeaguePlayer.name)` then `id`). Pickers, selectors, dropdowns and the two-player auto-select in `LogMatchScreen` must use `playersByName`.
- **League standings** — ranked by position: points → (goal difference → goals for for GD leagues) → `id`. `LeagueDetailState.players` carries this order and **never** uses name as a tie-breaker; the stable `id` fallback is the only tie-break beyond the ranking policy. Only the standings table may use `players`. `players` and `playersByName` always contain the same set, only differing in order.

Hive repositories remain unsorted — ordering is an in-memory presentation concern at the provider layer.
