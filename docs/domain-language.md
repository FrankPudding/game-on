User - Either the app owner, or someone the app owner wants represented in the app. A User is the global identity (name, icon, avatarColor). It exists in `usersProvider` and is independent of any League.

LeaguePlayer - A representation of a User in a League. A User can be a participant in multiple Leagues and they should have a single LeaguePlayer per League they are involved in. LeaguePlayer holds the **league-scoped** nickname and icon — these are stored on the `LeaguePlayer` row (`userId` + `leagueId`) and may differ from the linked User's name/icon and from the same User's LeaguePlayer in another League.

League - A collection of information regarding LeaguePlayers and their Matches against each other. A League should be parametrised by a particular subclass of Match.

RankingPolicy - When a League is set up, it needs to be given a RankingPolicy. This RankingPolicy will take a list of all matches and calculate the ranking of each LeaguePlayer based on their Match results. It will also calculate relevant metrics for each LeaguePlayer based on their Match results. The RankingPolicy will be parametrised by a particular subclass of Match. Every `RankingPolicy` belongs to **one or more categories** via `categoryIds: List<String>` — required, non-empty, unique (see Category). `categoryIds` is part of the domain constructor invariant (`ArgumentError` if empty or duplicate) and is persisted at `HiveField(6)` with defensive `List.from` copy on write / `List.unmodifiable` on read.

Category - A taxonomy label for grouping scoring systems and leagues. Used to filter which scoring systems are offered during league creation. Each `League` is indirectly categorized through its `RankingPolicy.categoryIds` (many-to-many: one policy in multiple categories, one category contains many policies). At least one category is required per policy; UI entry is `SelectCategoryScreen` (see `docs/architecture/scoring-system-categories.md`). **Current product rule:** `Simple` and `GoalDifference` scoring systems are only allowed in the **Custom** category (`cat_custom_league_001`); other built-ins (`Board Games`, `Card Games`, `Sports`, `Video Games`) intentionally have no allowed types until future scoring systems are added — enforced by `kSeedCategoryPolicyTypes`, `rankingPolicyTypesForCategoryProvider` (non-custom → `[]`), and `CreateLeagueService`/`HiveRankingPolicyRepository` (reject non-`[kFallbackCategoryId]`).

- **Identity:** `id: String` (e.g. `cat_boardgames`, fallback `cat_custom_league_001` = `kFallbackCategoryId`), `name: String` (non-empty after trim).
- **Slug:** `slug: Slug` value object — normalized lowercase `^[a-z0-9]+(-[a-z0-9]+)*$`, 3–32 chars after replacing non-alphanumerics with `-`; used for URL-safe lookup and the `category_slug_index` derived index. Uniqueness is enforced by scanning the truth box inside the shared `Lock` (index is cache, not truth).
- **Icon:** `icon: CategoryIcon` domain enum (`chess`, `playingCards`, `sportsSoccer`, `sportsEsports`, `categoryOther`, `other`). Hive stores `iconName: String` with `CategoryIconExtension.fromName` fallback to `other` for forward compatibility; presentation maps via `lib/presentation/mappers/category_icon_mapper.dart` to `IconData`.
- **Hierarchy:** `parentId: String?` nullable adjacency list. `null` = root. Depth limit `kCategoryMaxDepth = 1` (roots + one child level); deeper nesting, self-parent, missing parent, and cycles (DFS walk up `parentId`) all throw `ArgumentError`. Validated inside `HiveCategoryRepository.put` and statically via `Category.validateNoCycleAndDepth`.
- **Ordering:** `sortOrder: int` scoped **per `parentId`** sibling set. Midpoint insertion ` (prev+next)~/2`; gap `<2` triggers normalize under `Lock` to `0, 1000, 2000, ...` (sorted by current order then `id` for determinism) before retry. Built-in upsert preserves existing `sortOrder`.
- **Built-in:** `isBuiltIn: bool` — five deterministic seeds (`Board Games`, `Card Games`, `Sports`, `Video Games`, `Custom` with id `cat_custom_league_001`) are `isBuiltIn: true`. Only `sortOrder` and `icon` are mutable on built-ins; any other mutation via `put` throws `BuiltInCategoryException`. `delete` of a built-in also throws `BuiltInCategoryException` (delete is `RESTRICT` — see architecture doc). `isBuiltIn` is immutable after creation.
- **Timestamps:** `createdAt`, `updatedAt`.

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
