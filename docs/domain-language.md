User - Either the app owner, or someone the app owner wants represented in the app. A User is the global identity (name, icon, avatarColor). It exists in `usersProvider` and is independent of any League.

LeaguePlayer - A representation of a User in a League. A User can be a participant in multiple Leagues and they should have a single LeaguePlayer per League they are involved in. LeaguePlayer holds the **league-scoped** nickname and icon — these are stored on the `LeaguePlayer` row (`userId` + `leagueId`) and may differ from the linked User's name/icon and from the same User's LeaguePlayer in another League.

League - A collection of information regarding LeaguePlayers and their Matches against each other. A League should be parametrised by a particular subclass of Match.

RankingPolicy - When a League is set up, it needs to be given a RankingPolicy. This RankingPolicy will take a list of all matches and calculate the ranking of each LeaguePlayer based on their Match results. It will also calculate relevant metrics for each LeaguePlayer based on their Match results. The RankingPolicy will be parametrised by a particular subclass of Match. Every `RankingPolicy` belongs to **one or more categories** via `categoryIds: List<String>` — required, non-empty, unique (see Category). `categoryIds` is part of the domain constructor invariant (`ArgumentError` if empty or duplicate) and is persisted at `HiveField(6)` with defensive `List.from` copy on write / `List.unmodifiable` on read. Subtypes: `SimpleRankingPolicy` and `GoalDifferenceRankingPolicy` (both `RankingPolicy<SimpleMatch>`, custom-only `categoryIds == [kFallbackCategoryId]`), and `EloRankingPolicy` (`RankingPolicy<SimpleMatch>`, `categoryIds` exactly `{cat_sports, cat_pubgames}` = `kEloCategoryIds`, order-insensitive via `SetEquality` + length guard; deprecated alias `FargoRateRankingPolicy` → `EloRankingPolicy`, `kFargoCategoryIds` → `kEloCategoryIds`). `RankingPolicyType` (`simple`, `goalDifference`, `elo` with `displayName`/`description` — `elo` = `Pool` / `Elo Rankings`; deprecated `fargoRate` alias maps to same) is the presentation enum mapped from repo results (see `docs/architecture/scoring-system-categories.md`).

Category - A taxonomy label for grouping scoring systems and leagues. Used to filter which scoring systems are offered during league creation. Each `League` is indirectly categorized through its `RankingPolicy.categoryIds` (many-to-many: one policy in multiple categories, one category contains many policies). At least one category is required per policy; UI entry is `SelectCategoryScreen` (see `docs/architecture/scoring-system-categories.md`). **Current product rules:** `Simple` and `GoalDifference` scoring systems are only allowed in the **Custom** category (`cat_custom_league_001`); `Elo` (Pool, formerly FargoRate) is only allowed in **Sports** (`cat_sports`) + **Pub Games** (`cat_pubgames`) together (`categoryIds` must be exactly those two) — enforced by `kSeedCategoryPolicyTypes`, `rankingPolicyTypesForCategoryProvider` (sports/pubgames → unconditional `[elo]` whitelist via `kSeedCategoryPolicyTypes`, always available regardless of repo state; board/card/video → `[]`; custom → repo-driven with bootstrap vs corruption fallback to `RankingPolicyType.values`), and `CreateLeagueService`/`HiveRankingPolicyRepository`/`EloRankingPolicy` (reject wrong ids). Sports/PubGames Elo availability is unconditional and Custom is the only repo-driven category. See architecture doc for whitelist semantics.

- **Identity:** `id: String` (e.g. `cat_boardgames`, `cat_sports`, `cat_pubgames`, fallback `cat_custom_league_001` = `kFallbackCategoryId`), `name: String` (non-empty after trim).
- **Slug:** `slug: Slug` value object — normalized lowercase `^[a-z0-9]+(-[a-z0-9]+)*$`, 3–32 chars after replacing non-alphanumerics with `-`; used for URL-safe lookup and the `category_slug_index` derived index. Uniqueness is enforced by scanning the truth box inside the shared `Lock` (index is cache, not truth).
- **Icon:** `icon: CategoryIcon` domain enum (`chess`, `playingCards`, `sportsSoccer`, `sportsEsports`, `categoryOther`, `other`). Hive stores `iconName: String` with `CategoryIconExtension.fromName` fallback to `other` for forward compatibility; presentation maps via `lib/presentation/mappers/category_icon_mapper.dart` to `IconData`.
- **Hierarchy:** `parentId: String?` nullable adjacency list. `null` = root. Depth limit `kCategoryMaxDepth = 1` (roots + one child level); deeper nesting, self-parent, missing parent, and cycles (DFS walk up `parentId`) all throw `ArgumentError`. Validated inside `HiveCategoryRepository.put` and statically via `Category.validateNoCycleAndDepth`.
- **Ordering:** `sortOrder: int` scoped **per `parentId`** sibling set. Midpoint insertion ` (prev+next)~/2`; gap `<2` triggers normalize under `Lock` to `0, 1000, 2000, ...` (sorted by current order then `id` for determinism) before retry. Built-in upsert preserves existing `sortOrder`; V3 inserts `cat_pubgames` at 3500 via midpoint between `cat_videogames` (3000) and `cat_custom_league_001` (4000), with gap `<2` full normalize.
- **Built-in:** `isBuiltIn: bool` — six deterministic seeds (`Board Games`, `Card Games`, `Sports`, `Video Games`, `Pub Games` 3500, `Custom` with id `cat_custom_league_001`) are `isBuiltIn: true`. Only `sortOrder` and `icon` are mutable on built-ins; any other mutation via `put` throws `BuiltInCategoryException`. `delete` of a built-in also throws `BuiltInCategoryException` (delete is `RESTRICT` — see architecture doc). `isBuiltIn` is immutable after creation.
- **Timestamps:** `createdAt`, `updatedAt`.

Elo - Pool Elo ranking policy (formerly FargoRate). `EloRankingPolicy` extends `RankingPolicy<SimpleMatch>` with invariants `categoryIds` exactly `{cat_sports, cat_pubgames}` (`kEloCategoryIds`, deprecated alias `kFargoCategoryIds`) and `initialRating` 100..500 inclusive (`kEloMinRating`/`kEloMaxRating`/`kEloDefaultInitialRating`=400/`kEloLegacyInitialRating`=500/`kEloDefaultKFactor`=20 in `lib/domain/constants/elo_constants.dart`; `lib/domain/constants/fargo_constants.dart` is deprecated shim re-exporting `elo_constants.dart` with `kFargo*` aliases; `lib/core/constants/hive_box_names.dart:kFargoInitialRating=500` retained as deprecated literal for codegen). New leagues default to 400 via `CreateFargoRateLeagueScreen` (legacy name, now Elo; pre-filled `kEloDefaultInitialRating`, validator delegates to `EloRankingPolicy.validateInitialRating`); legacy Hive rows missing field 7 fall back to 500 via `@HiveField(7, defaultValue:500)` literal (hand-patched `elo_ranking_policy_hive_model.g.dart`). Persistence `EloRankingPolicyHiveModel` `@HiveType(typeId: 12)` (was FargoRate, `typeId` 12 retained) `@HiveField(7, defaultValue:500)` literal (defensive `List.from` on write / `List.unmodifiable` on read, validates `initialRating` and `categoryIds`). `hiveDbVersion` stays `3` — no migration bump (additive field via literal default, `K` change is in-memory recalc). Calculation via `EloCalculator` (pure domain, `lib/domain/services/elo_calculator.dart`; `FargoRateCalculator` is deprecated `typedef` → `EloCalculator`): `calculate({required matches, required players, required initialRating})`, filters `isComplete` before sort, sorts `playedAt ASC + id ASC`, throws `ArgumentError` on `isDraw`/`sides.length !=2`/`playerIds.length !=1`/`winnerSideId` missing, Elo-like with `K = 20` (was 32 — breaking global recalc; see architecture doc) seeded from `initialRating`, returns `Map<String, EloPlayerStats>` (`matchesPlayed`, `wins`, `losses`, `winRate`, `rating`; `FargoPlayerStats` is deprecated `typedef` → `EloPlayerStats`). League standings for Elo leagues are sorted by `rating DESC → wins DESC → id ASC` (never name, `eloStats[id]?.rating ?? policy.initialRating`, `fargoStats` alias delegates to `eloStats`), shown as columns `P W L Win% Elo` (header `Elo`, was `Fargo`); `LogMatchScreen` hides the Draw option when `isElo` (`isFargo` deprecated alias). `RankingPolicyType.elo` (display `Pool`, description `Elo Rankings`; `fargoRate` deprecated alias maps to same) is the presentation enum.

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
- **League standings** — ranked by position. For Simple/GoalDifference: points → (goal difference → goals for for GD leagues) → `id`. For Elo: `rating DESC → wins DESC → id ASC` (computed by `EloCalculator`, `K=20` (was 32, breaking recalc), seeded from `EloRankingPolicy.initialRating` — 100..500, default 400 for new leagues, legacy 500 fallback via `HiveField(7, defaultValue:500)` literal, `typeId 12`), surfaced as `P W L Win% Elo` in `_StandingsTab` (header `Elo`, was `Fargo`). `LeagueDetailState.players` carries this order and **never** uses name as a tie-breaker; the stable `id` fallback is the only tie-break beyond the ranking policy. Only the standings table may use `players`. `players` and `playersByName` always contain the same set, only differing in order.
  - `LeagueDetailState.eloStats: Map<String, EloPlayerStats>` (deprecated `fargoStats` alias) + `isElo` (`isFargo` deprecated alias) drive the Elo branch; missing entry falls back to `policy.initialRating` (never hard-coded `500`).

Hive repositories remain unsorted — ordering is an in-memory presentation concern at the provider layer.

## Ordering — My Leagues (Recency vs Alphabetical)

`HomeScreen` ("My Leagues") presents leagues in one of **four** user-selectable
states driven by `LeagueSortPreference` (`lib/application/preferences/sort_preference.dart`):

| Mode | Direction | Behaviour |
|------|-----------|-----------|
| `lastPlayed` | descending `true` — **default** | Most recent first, `null` ("Never") last |
| `lastPlayed` | ascending `false` | Oldest first, `null` last |
| `alphabetical` | ascending `false` | A→Z via `compareNames` then `id` |
| `alphabetical` | ascending `true` (labelled Z→A) | Z→A (negated `compareNames` + negated `id`) |

The default on first launch (and before the persisted preference has been
loaded from Hive) is **lastPlayed descending** — no flicker, no empty flash;
`LeagueSortPreferenceNotifier` returns `LeagueSortPreference.defaultPreference`
synchronously from `build()` and only updates state if the async `repo.get()`
returns a different value.

### Definition of `lastPlayed`

`lastPlayed` is the **most recent `playedAt` among completed matches** for that
league, or `null` when no completed match exists (UI renders "Last played:
Never"). Derivation:

- Pure helper `maxCompletePlayedAt(Iterable<SimpleMatch>)` in
  `lib/domain/services/match_stats.dart` — filters `isComplete == true`,
  returns `max(playedAt)` or `null`.
- Production `SortedLeaguesNotifier` inlines an equivalent `O(M)` groupBy scan
  (single loop over all matches, `maxMap[leagueId] = max(playedAt)`) for
  bulk `O(M + L log L)` performance; the helper defines the contract.
- Incomplete matches (`isComplete == false`) are **ignored** even when their
  `playedAt` is later than any complete match.

### Comparator & determinism

- **Recency mode**: uses `lib/core/sorting/date_sort.dart:compareNullableDateNullLast`
  (null always last regardless of direction) then deterministic tie-break
  `compareNames(league.name)` → `league.id`. Implemented as
  `lib/application/services/sorted_leagues_service.dart:compareLeagues` /
  `sortLeagues` (copy, never mutates input).
- **Alphabetical mode**: `compareNames` primary (trim, empty-first,
  case-insensitive primary + case-sensitive secondary), `id` secondary; both
  negated when `descending` (Z→A).
- `lib/core/sorting/league_sort.dart` and
  `lib/core/preferences/sort_preference.dart` are re-export aliases for the
  canonical `application/` locations to keep `core` domain-free (DDD boundary).

### UI & persistence

- `HomeScreen` (`lib/presentation/screens/home/home_screen.dart`) watches
  `sortedLeaguesProvider` (bulk `SortedLeague` list) and
  `sortPreferenceProvider`; `AppBar.actions` exposes a **single**
  `PopupMenuButton<LeagueSortPreference>` (`tooltip: 'Sort'`) whose child is
  `Row(Icon(Icons.swap_vert) + Text('Sort'))`. The menu has four items —
  `Latest` (`LeagueSortPreference.latest` = `lastPlayed` descending `true`,
  **default**), `Oldest` (`oldest` = `lastPlayed` descending `false`),
  `A-Z` (`aToZ` = `alphabetical` descending `false`), `Z-A` (`zToA` =
  `alphabetical` descending `true`) — defined as const helpers in
  `lib/application/preferences/sort_preference.dart`; the active item shows
  `Icons.check` (size 18) via `==` equality. `onSelected` calls
  `sortPreferenceProvider.notifier.setPreference` (write-then-invalidate
  `sortedLeaguesProvider`). List is rendered by
  `Stateless _SortedLeagueCard` (`Last played: Never` vs
  `DateFormat('MMM d, yyyy')`).
- Preference is persisted in Hive `Box<String>` `app_preferences` under keys
  `sort_mode` (`lastPlayed` | `alphabetical`) and `sort_descending`
  (`true` | `false`) via `HiveSortPreferenceRepository`
  (`lib/data/repositories/hive/hive_sort_preference_repository.dart`);
  write-then-invalidate (`await repo.set` → `state = pref` →
  `ref.invalidate(sortedLeaguesProvider)`). See `docs/architecture/sorting.md`
  and `docs/architecture/provider-invalidation.md`.
- Error handling: `sortedLeaguesProvider` propagates repo failures as
  `AsyncError` → HomeScreen shows `Error: ...` (degraded, not silent empty);
  `sortPreferenceProvider` keeps the default on read errors and never blocks
  first frame.
