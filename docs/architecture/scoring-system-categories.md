# Scoring System Categories

## Purpose

Categories provide a taxonomy for scoring systems (ranking policies) and the leagues created from them. League creation is now category-first: pick a **Category** → filter scoring systems via `RankingPolicyRepository.getByCategory` → create the league with `RankingPolicy.categoryIds` via `CreateLeagueService`. This document describes the domain model, persistence schema, indexes, migration, provider graph, UI flow, and invariants.

Currently three category→policy bindings exist:

* **`Simple` and `GoalDifference` restricted to the Custom category** (`cat_custom_league_001` = `kFallbackCategoryId`).
* **`Elo` (Pool) restricted to Sports + Pub Games** (`cat_sports` + `cat_pubgames` = `kEloCategoryIds`). The policy extends `RankingPolicy<SimpleMatch>` and must carry exactly those two ids (set-equality, order-insensitive). `kFargoCategoryIds` is a deprecated alias for `kEloCategoryIds`; `FargoRateRankingPolicy` is a `typedef` for `EloRankingPolicy`.
* Other built-in categories (`Board Games`, `Card Games`, `Video Games`) intentionally have no allowed scoring systems until future policy types are added.

Restrictions are enforced at three layers: seed map, provider whitelist, and write-path validation (see Scoring System Availability and Invariants).

Related: `docs/domain-language.md` → Category / RankingPolicy / Elo, `lib/presentation/mappers/category_icon_mapper.dart`, `lib/providers/leagues_provider.dart` → `categoriesProvider` / `rankingPolicyTypesForCategoryProvider`.

## Domain Model

| Concept | Location | Notes |
|---------|----------|-------|
| `Category` | `lib/domain/entities/category.dart` | `id`, `name`, `slug: Slug`, `icon: CategoryIcon`, `parentId?`, `sortOrder`, `isBuiltIn`, `createdAt`, `updatedAt`. `Slug` (`lib/domain/value_objects/slug.dart`) normalizes to `^[a-z0-9]+(-[a-z0-9]+)*$`, 3–32 chars. `CategoryIcon` (`lib/domain/value_objects/category_icon.dart`) is `enum {chess, playingCards, sportsSoccer, sportsEsports, categoryOther, other}` with `iconName` mapping + `fromName` fallback to `other`. |
| `RankingPolicy.categoryIds` | `lib/domain/entities/ranking_policy.dart` | `List<String>` required non-empty unique, `List.unmodifiable` with `ArgumentError` on violation. Many-to-many: a policy may live in multiple categories; a category contains many policies. Each policy must belong to ≥1 category. |
| `kFallbackCategoryId` | `lib/core/constants/hive_box_names.dart` | `const 'cat_custom_league_001'` — the Custom/Other seed. Single source for fallback references. Used by migration backfill, UI invalid-category fallback, and `CreateSimple/GoalDifferenceLeagueScreen` default param. |
| `kSportsCategoryId` / `kPubGamesCategoryId` / `kEloCategoryIds` | `lib/core/constants/hive_box_names.dart` | `cat_sports`, `cat_pubgames`, `const [cat_sports, cat_pubgames]`. Single source for Elo binding. Deprecated alias `kFargoCategoryIds = kEloCategoryIds` remains for backward compat — use `kEloCategoryIds` in new code. |
| `kCategoryMaxDepth` / `kMaxCategoryDepth` | `lib/domain/entities/category.dart` / `hive_box_names.dart` | `1` (roots + one sub-category level). |
| `kEloMinRating` / `kEloMaxRating` / `kEloDefaultInitialRating` / `kEloLegacyInitialRating` / `kEloDefaultKFactor` | `lib/domain/constants/elo_constants.dart` | `100` / `500` / `400` (new-league default) / `500` (legacy fallback) / `K=20`. Single source for valid range, defaults, and K-factor, independent of UI/Hive. `lib/domain/constants/fargo_constants.dart` is a deprecated shim re-exporting `elo_constants.dart`. `kFargoMinRating` etc. are `@Deprecated` aliases. `lib/core/constants/hive_box_names.dart:kFargoInitialRating=500` retained as `@Deprecated` literal for codegen `defaultValue:500`; do not use in domain logic. |
| `kFargoInitialRating` (deprecated) | `lib/core/constants/hive_box_names.dart` | `500` literal, deprecated in favor of `elo_constants.dart`. Kept only so `@HiveField(7, defaultValue:500)` remains a literal (codegen requirement). |

### Subtypes

| Policy | Extends | `RankingPolicyType` | `categoryIds` invariant | Location |
|--------|---------|---------------------|------------------------|----------|
| `SimpleRankingPolicy` | `RankingPolicy<SimpleMatch>` | `simple` | exactly `[kFallbackCategoryId]` | `lib/domain/entities/ranking_policies/simple_ranking_policy.dart` |
| `GoalDifferenceRankingPolicy` | `RankingPolicy<SimpleMatch>` | `goalDifference` | exactly `[kFallbackCategoryId]` | `lib/domain/entities/ranking_policies/goal_difference_ranking_policy.dart` |
| `EloRankingPolicy` | `RankingPolicy<SimpleMatch>` | `elo` (`displayName: 'Pool'`, `description: 'Elo Rankings'`; legacy `fargoRate` alias maps to same display) | exactly `{cat_sports, cat_pubgames}` (set-equality via `SetEquality` + length guard, order-insensitive) + `initialRating` 100..500 inclusive (`validateInitialRating`, `ArgumentError` otherwise) | `lib/domain/entities/ranking_policies/elo_ranking_policy.dart` + `lib/domain/constants/elo_constants.dart` (`FargoRateRankingPolicy` is deprecated `typedef` → `EloRankingPolicy`) |

`EloRankingPolicy.validateCategoryIds` and `validateInitialRating` are the canonical validators (`ArgumentError` with `FargoRate leagues must have categoryIds exactly $kEloCategoryIds. Got: ...` — message text retains legacy wording for error-code stability — and `initialRating must be within 100..500 inclusive. Got: ...`); `CreateLeagueService` (upfront validation before I/O) and `HiveRankingPolicyRepository.put` delegate to the same guards, and `EloRankingPolicyHiveModel.toDomain` validates on read. `RankingPolicyType` is a presentation enum; `rankingPolicyTypesForCategoryProvider` maps repo results to this enum for the UI (`elo` primary, `fargoRate` deprecated alias retained).

`EloPlayerStats` (`lib/domain/value_objects/elo_player_stats.dart`) is the pure domain value object returned by `EloCalculator` (`FargoPlayerStats` is deprecated `typedef` → `EloPlayerStats`):

```dart
class EloPlayerStats {
  final int matchesPlayed, wins, losses, rating; // rating seeded from policy.initialRating (400 default, 500 legacy)
  double get winRate => matchesPlayed == 0 ? 0 : wins / matchesPlayed;
}
```

`LeagueDetailState.eloStats: Map<String, EloPlayerStats>` holds per-player stats when `rankingPolicy is EloRankingPolicy`; `isElo` getter mirrors `isGoalDifference`. `fargoStats` / `isFargo` are deprecated aliases (`Map<String, FargoPlayerStats>` / `isFargo => isElo`) for backward compat.

## Conceptual SQL vs Hive Schema

**Conceptual relational view (reference only — not implemented):**

```sql
CREATE TABLE categories (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL CHECK (trim(name) <> ''),
  slug TEXT NOT NULL UNIQUE,          -- 3..32, ^[a-z0-9]+(-[a-z0-9]+)*$
  icon_name TEXT NOT NULL,             -- CategoryIcon.name
  parent_id TEXT REFERENCES categories(id) ON DELETE RESTRICT,
  sort_order INT NOT NULL,
  is_built_in BOOLEAN NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  CHECK (parent_id IS NULL OR parent_id <> id),
  CHECK (depth(parent_id) <= 1)
);

CREATE TABLE ranking_policies (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  league_id TEXT NOT NULL,
  points_for_win INT, points_for_draw INT, points_for_loss INT,
  -- many-to-many via join table or array column
  category_ids TEXT[] NOT NULL CHECK (array_length(category_ids,1) >= 1)
);
CREATE TABLE ranking_policy_categories (
  policy_id TEXT REFERENCES ranking_policies(id),
  category_id TEXT REFERENCES categories(id) ON DELETE RESTRICT,
  PRIMARY KEY (policy_id, category_id)
);
-- Derived indexes: UNIQUE(slug), INDEX(parent_id), INDEX(ranking_policy_categories.category_id)
```

**Hive implementation (actual):**

| Box | Type | Purpose | Hive `typeId` |
|-----|------|---------|---------------|
| `HiveBoxNames.categories` | `CategoryHiveModel` | Truth store for categories | `11` (`@HiveType(typeId: 11)`) |
| `HiveBoxNames.categorySlugIndex` | `String` (`slug → id`) | Derived index for `getBySlug` fast path | — |
| `HiveBoxNames.categoryParentIndex` | `String` (`parentKey → comma-joined ids`) | Derived parent→children index (`'__roots__'` key for null) | — |
| `HiveBoxNames.rankingPolicies` | `RankingPolicyHiveModel` (`typeId 9` / `10` / `12`) | Truth store; base field `categoryIds` at `@HiveField(6, defaultValue: <String>[])` with `List.from` defensive copy | `9` = Simple, `10` = GoalDifference, `12` = Elo (was FargoRate — `typeId` 12 retained, renamed to `EloRankingPolicyHiveModel`; `FargoRateRankingPolicyHiveModel` deprecated alias) |
| `HiveBoxNames.categoryPolicyIndex` | `String` (`categoryId → comma-joined policyIds`) | Derived policy-by-category index | — |
| `HiveBoxNames.meta` | `int` (`db_version`) | Migration version | — |

Hive field layout `CategoryHiveModel`: `0:id`, `1:name`, `2:slug`, `3:iconName`, `4:sortOrder`, `5:isBuiltIn`, `6:parentId?`, `7:createdAt`, `8:updatedAt`.

Hive field layout `RankingPolicyHiveModel` base: `0:id`, `1:name`, `5:leagueId` (`defaultValue:''`), `6:categoryIds` (`defaultValue: <String>[]`, empty only to read pre-v2 boxes; runtime empty is treated as corruption — see Corruption Handling). `EloRankingPolicyHiveModel` (`typeId 12`) stores base fields (`0,1,5,6`) plus `@HiveField(7, defaultValue:500) int initialRating` (literal `500` required for codegen; on read missing field 7 → 500 legacy fallback; domain constants in `elo_constants.dart` provide `400` default for new leagues and `500` legacy; `toDomain` rejects empty `categoryIds` with `StateError` and validates `initialRating` 100..500 via `validateInitialRating`, with defensive `List.from` on write / `List.unmodifiable` on read). `hiveDbVersion` stays `3` — no migration bump; `typeId 12` + field 7 are additive and backward-compatible via `defaultValue:500` (see `hiveDbVersion stays 3` rationale below). `lib/data/models/hive/ranking_policies/elo_ranking_policy_hive_model.g.dart` is generated but `defaultValue:500` is hand-written as a literal (`read: fields[7] == null ? 500 : fields[7] as int`).

## Adjacency List Rationale

Hierarchy uses **adjacency list** (`parentId` nullable pointing to parent `id`). With `maxDepth = 1` there is no recursion beyond roots→children, so adjacent queries (`getChildren(parentId)`, `getRoots()`) are single-scan `where(parentId == x)` plus sort by `sortOrder`.

Alternatives considered and deferred:

- **Nested sets / materialized path / closure table** — add write complexity and require bookkeeping for re-parenting and ordering, unnecessary at depth 1. The plan patch explicitly notes future hierarchy extension would adopt a **closure table** (`ancestor_id`, `descendant_id`, `depth`) to support deeper trees efficiently without changing the `parentId` API.

`Category.validateNoCycleAndDepth` performs DFS up `parentId` with `visited` set for cycle detection and depth counting; `HiveCategoryRepository.put` re-validates the entire sibling set including the candidate inside the shared `Lock` before persisting.

## Icons

- Domain: `CategoryIcon` enum (value object) — no Flutter dependency.
- Data: `CategoryHiveModel.iconName: String` — Hive stores `CategoryIcon.iconName` string; `CategoryIconExtension.fromName` maps back with fallback `other` for unknown strings (forward compatibility when enum grows).
- Presentation: `lib/presentation/mappers/category_icon_mapper.dart:mapCategoryIconToIconData` maps to `IconData` (`chess→grid_on`, `playingCards→style`, `sportsSoccer→sports_soccer`, `sportsEsports→sports_esports`, `categoryOther→category_outlined`, `other→category`). `Pub Games` (`cat_pubgames`) reuses `category_other` icon.

## Deterministic Seed

`HiveDatabaseMigrationService._migrateToV2` upserts five built-ins idempotently (preserves existing `sortOrder` if row already exists); `_migrateToV3` adds the sixth:

| id | name | slug | iconName | sortOrder |
|----|------|------|----------|-----------|
| `cat_boardgames` | Board Games | `board-games` | `chess` | 0 |
| `cat_cardgames` | Card Games | `card-games` | `playing_cards` | 1000 |
| `cat_sports` | Sports | `sports` | `sports_soccer` | 2000 |
| `cat_videogames` | Video Games | `video-games` | `sports_esports` | 3000 |
| `cat_pubgames` | Pub Games | `pub-games` | `category_other` | 3500 (midpoint) |
| `cat_custom_league_001` | Custom | `custom` | `category_other` | 4000 |

`isBuiltIn: true`, `parentId: null`, `createdAt/updatedAt: now` on fresh insert; on upgrade only `name`/`slug`/`iconName`/`isBuiltIn` drift is corrected, `sortOrder` is left intact to respect reordering. V3 insertion computes midpoint `(prev+next)~/2` between `cat_videogames` (3000) and `cat_custom_league_001` (4000) → 3500; if midpoint collides with a neighbor it falls back to 3500; if gap `<2` between any siblings after insertion, V3 normalizes all roots to `0,1000,2000,...` sorted by current `sortOrder` then `id` (same algorithm as `HiveCategoryRepository`).

### Scoring System Availability (Whitelist)

Seed-time mapping `lib/core/constants/category_policy_map.dart:kSeedCategoryPolicyTypes` is the **only** place that declares which scoring systems a category may offer. It is seed-only (not runtime truth); runtime filtering is repo-driven via `RankingPolicyRepository.getByCategory`.

Current invariant:

```dart
// lib/core/constants/category_policy_map.dart
const kSeedCategoryPolicyTypes = {
  'cat_boardgames': <RankingPolicyType>[], // intentionally empty
  'cat_cardgames':  <RankingPolicyType>[],
  'cat_sports':     [RankingPolicyType.elo],
  'cat_videogames': <RankingPolicyType>[],
  'cat_pubgames':   [RankingPolicyType.elo],
  'cat_custom_league_001': [RankingPolicyType.simple, RankingPolicyType.goalDifference],
};
```

* **Custom (`cat_custom_league_001`) → `[simple, goalDifference]`** — `Simple`/`GoalDifference` are custom-only.
* **Sports (`cat_sports`) and Pub Games (`cat_pubgames`) → `[elo]`** — `Elo` (Pool, formerly FargoRate) is only in those two categories, and an Elo league must be in **both** (`categoryIds` exactly `{cat_sports, cat_pubgames}`).
* **Board/Card/Video → `[]`** until future scoring systems are added.

**Provider whitelist (`rankingPolicyTypesForCategoryProvider`):**

For `cat_sports` / `cat_pubgames` the provider is an **unconditional whitelist** — it returns `[elo]` directly without querying the repository. This mirrors `kSeedCategoryPolicyTypes` (`cat_sports` + `cat_pubgames` → `[elo]`) and guarantees Pool (Elo) is always available under Sports + Pub Games regardless of repo state (fresh install, populated repo, or after Custom leagues exist). `RankingPolicyType.fargoRate` remains as `@Deprecated('Use elo')` alias mapping to same `displayName`/`description` (`Pool` / `Elo Rankings`). No `getByCategory`/`getAll` bootstrap vs corruption check is performed for Elo; that distinction applies only to the Custom fallback.

For `kFallbackCategoryId` (Custom) it is repo-driven: queries `getByCategory`; empty/error → `RankingPolicyType.values` fallback so custom remains usable even with an empty box (bootstrap vs corruption distinction lives here — empty box → show all types for usability, populated box → map actual `Simple`/`GoalDifference`/`Elo` policies). For any other id (`board/card/video`) it immediately returns `[]` → `SelectScoringSystemScreen` shows `No scoring systems available for this category`.

**Write-path defense in depth:**

* `lib/application/services/create_league_service.dart:CreateLeagueService.execute` — rejects `Simple`/`GoalDifference` unless `categoryIds == [kFallbackCategoryId]`; rejects `EloRankingPolicy` unless `categoryIds` length == 2 and `containsAll(kEloCategoryIds)`. `CategoryRepository.existsAll` is checked first for referential integrity; the category-specific guard runs immediately after; if `categoryIds` param differs from `policy.categoryIds` it also throws `RankingPolicy categoryIds must match provided categoryIds`.
* `lib/data/repositories/hive/hive_ranking_policy_repository.dart:HiveRankingPolicyRepository.put` — same two guards plus `existsAll` via `CategoryRepository` (throws `UnknownCategoryException` on miss, mapped to `ArgumentError` by service). Defensive `List.from` copy.

Tests: `test/unit/core/constants/category_policy_map_test.dart` (seed map — expects `elo` for sports/pubgames), `test/unit/application/services/create_league_service_test.dart` + `test/unit/application/services/create_league_service_fargo_test.dart` (now Elo) + `test/integration/data/repositories/hive/hive_ranking_policy_custom_category_real_test.dart` + `test/unit/providers/ranking_policy_types_for_category_provider_test.dart` (provider whitelist — Elo unconditional via `kSeedCategoryPolicyTypes`, Custom repo-driven empty vs populated), + `test/unit/providers/ranking_policy_types_for_category_provider_fargo_test.dart` (Elo unconditional under Sports/PubGames regardless of repo state) + service/repo rejects + custom empty-box fallback with bootstrap vs corruption (Custom only).

## Elo Domain — Calculator

`EloCalculator` (`lib/domain/services/elo_calculator.dart`, `FargoRateCalculator` is deprecated `typedef` → `EloCalculator` re-exported at `lib/domain/calculators/fargo_rate_calculator.dart` shim) is a **pure domain service** — no Flutter/Hive imports, deterministic, testable in isolation.

* **Inputs:** `List<SimpleMatch> matches`, `List<LeaguePlayer> players`, `int initialRating` (required, 100..500). Caller is `LeagueDetailState._fetchData()` which captures `eloInitial = (policy as EloRankingPolicy).initialRating` and passes it through; no global constant is read inside `calculate`.
* **Filtering:** `where(isComplete)` **before** sort — incomplete matches are ignored entirely.
* **Ordering:** `playedAt ASC` then `id ASC` — guarantees stable replay order regardless of insertion order.
* **Validation (throws `ArgumentError`):** `isDraw == true`, `sides.length != 2`, any `side.playerIds.length != 1`, `winnerSideId == null` or not found. Elo does not support draws or team play. 4 seed sites: every `players` id is seeded at `initialRating`, plus `putIfAbsent` for any winner/loser id not in `players` (unknown ghost) also at `initialRating`.
* **Rating:** Elo-like with `K = 20` (constant `kEloDefaultKFactor = 20`, `_kFactor = 20` inside `EloCalculator`) seeded from `initialRating` (not a global). Expected score `1 / (1 + 10^((loserRating - winnerRating)/400))`; winner `rating + K*(1 - expected)`, loser `rating + K*(0 - expected)`, rounded. Ratings are `double` internally, `round()` on output, and evolve sequentially in sorted order.

  > **Breaking change — K 32 → 20 (global recalc):** `K` was `32`; now `20`. This is a **breaking recalc** — all existing Elo leagues recompute ratings on next load via `EloCalculator.calculate`. Ratings shift toward the mean slower; a 400-vs-400 win now yields `410/390` (was `416/384`). No Hive migration is required (see `hiveDbVersion stays 3` below); the new `K` applies immediately on recalculation. Tests now expect `K=20` (e.g. `410/390`, `510/490`).

* **Stats:** Returns `Map<String, EloPlayerStats>` for every player in `players` plus any ghost ids seen in matches (union of keys). Even those with no matches → `matchesPlayed:0, wins:0, losses:0, rating:initialRating`. `wins`/`losses`/`matchesPlayed` are incremented per completed match; `winRate` is derived (`0` if none). `LeagueDetailState` sorts with fallback `eloStats[id]?.rating ?? initialRating` (so a missing entry uses the policy's own initial, not a hard-coded 500).

Non-obvious: `LogMatchScreen` hides the Draw option when `state.isElo` (see `lib/presentation/screens/match/log_match_screen.dart:_buildWinnerSection` — `if (!isFargo) Draw`, where `isFargo` now aliases `isElo`); `LeagueDetailState` sorting for Elo uses `rating DESC → wins DESC → id ASC` with fallback `rating ?? policy.initialRating` (never name, never hard-coded 500), vs `points → GD → GF → id` for other leagues. `EloRankingPolicyHiveModel` uses `@HiveField(7, defaultValue:500)` literal for backward compat, but new leagues are created with `400` via `elo_constants.dart`. `hiveDbVersion` stays `3` — additive field with literal default is backward-compatible (see below).

## Indexes — Rebuildable Caches, Not Truth

All three derived boxes (`categorySlugIndex`, `categoryParentIndex`, `categoryPolicyIndex`) are **strictly rebuildable caches**. Validation and queries must scan truth boxes; indexes are only queried for speed with fallback scan if missing.

- `categorySlugIndex`: `slug → id`. `HiveCategoryRepository.getBySlug` first probes the index, then scans `categories` on miss. `put` double-checks truth scan before `slugIndex.put` (double-checked locking inside `Lock`).
- `categoryParentIndex`: `parentId('__roots__' for null) → comma-joined child ids`. Kept by `_rebuildParentIndexForParent(parentId)` after each `put`/`delete`.
- `categoryPolicyIndex`: `categoryId → comma-joined policy ids`. Maintained by `HiveRankingPolicyRepository.put`/`delete` inside the same `Lock` and rebuilt by `HiveDatabaseMigrationService` and `CategoryIndexRebuilder`.

Shared `Lock` (single `synchronized.Lock` singleton injected via `GetIt`) is **best-effort single-isolate** only — it does not survive isolate kill or provide cross-isolate crash atomicity. The comment in repos reads `// Lock does not survive isolate kill — indexes are rebuildable caches`. On any exception after first box `put`, the catch block deletes the partial key, optionally flushes, and `CategoryIndexRebuilder.rebuildIfNeeded` (called after `openBox` in `_initHive`) repairs drift by comparing `slugIndex.length` vs `categoriesBox.length` and root counts, then clearing and re-populating indexes from truth.

## Migration — Versions 2 and 3

`AppConfig.hiveDbVersion` defaults to `3` (fails fast if fresh installs would skip seeding). Tests `expect(AppConfig().hiveDbVersion, 3)` enforce this.

**Ordered init in `lib/core/injection_container.dart:_initHive`:**

1. `await Hive.initFlutter()`
2. `HiveRegistrar.registerAdapters()` (generated `lib/hive_registrar.g.dart` — single source, includes `typeId 11` + `12`). Guarded with idempotence wrapper (`isAdapterRegistered` checks per typeId; swallow "already" errors).
3. `await HiveDatabaseMigrationService().migrate(sl<AppConfig>().hiveDbVersion)`
4. `await Hive.openBox(...)` for all boxes (or `Hive.box` if already opened by migration) — `categories`, `categorySlugIndex`, `categoryParentIndex`, `categoryPolicyIndex`, `rankingPolicies`, plus leagues/users/players/matches.
5. `await CategoryIndexRebuilder().rebuildIfNeeded()` — drift check + rebuild of slug/parent/policy indexes from truth; also rebuilds `categoryPolicyIndex` when both boxes are open.

**`migrate(targetVersion)` semantics:**

- If `currentVersion >= targetVersion` → **no-op early return** (idempotent guard). This preserves user `sortOrder` and avoids churn on every launch. Logged via `debugPrint`. `3→3` no-op is retained after the Elo rename — no data change, no re-seed.
- Underlying `_migrateToV*` are individually idempotent and retry-safe: categories are upserted idempotently, ranking-policy backfill only rewrites rows where `categoryIds.isEmpty` to `[kFallbackCategoryId]`, and all indexes are cleared then rebuilt from truth. Crash-retry (throw before `meta.put(version)`) leaves version at old value; next launch re-executes idempotently.

**`_migrateToV2` steps (summary):**

1. Ensure adapters (fallback registration for `test` harness where `Hive.init` runs without DI).
2. Upsert the five seeds (Board/Card/Sports/Video/Custom; preserve `sortOrder` if row exists, otherwise initial spaced values).
3. Clear `slugIndex` + `parentIndex`, rebuild from `categoriesBox` truth.
4. Backfill: for each `rankingPolicies` row where `categoryIds.isEmpty`, replace with `const [kFallbackCategoryId]` by reconstructing the concrete `Simple`/`GoalDifference` Hive model (preserving points).
5. Clear and rebuild `categoryPolicyIndex` from `rankingBox.categoryIds`.
6. `meta.db_version` is bumped to `2` by the loop in `migrate()` after `_migrateToV2` returns; tests cover `0→2` (fresh), `1→2` (upgrade), `2→2` (no-op), crash-retry (kill mid-migration then re-migrate succeeds, no duplicates, `sortOrder` preserved).

**`_migrateToV3` steps (summary):**

1. Ensure adapters including `typeId 12` (`EloRankingPolicyHiveModelAdapter`, formerly `FargoRateRankingPolicyHiveModelAdapter` — `typeId` 12 unchanged).
2. Upsert `cat_pubgames` (`Pub Games`, `pub-games`, `category_other`): if row exists and drifted, correct `name`/`slug`/`iconName`/`isBuiltIn`/`parentId` while preserving `sortOrder`; if missing, compute insertion `sortOrder` as midpoint `(video.sortOrder + custom.sortOrder)~/2` (defaults to 3500 if neighbors missing or midpoint collides), then `put`.
3. Gap `<2` normalize: scan all categories sorted by `sortOrder` then `id`; if any `gap = curr - prev < 2`, reassign `0,1000,2000,...` in that sorted order under same boxes (updates `updatedAt`).
4. Clear `slugIndex` + `parentIndex`, rebuild from `categoriesBox` truth (including new `cat_pubgames`).
5. Clear and rebuild `categoryPolicyIndex` from `rankingBox.categoryIds` (now may contain `12` rows with both `cat_sports` and `cat_pubgames` entries).
6. `meta.db_version` bumped to `3` by the outer loop after `_migrateToV3` returns; idempotent and retry-safe (version not bumped on throw). Fresh `0→3` runs V2 then V3 sequentially; `2→3` runs only V3; `3→3` is no-op.

**Elo `initialRating` (400 default) + K-factor change — no V4 migration / `hiveDbVersion` stays 3:**

The 100..500 `initialRating` field stays at `hiveDbVersion = 3`. `EloRankingPolicyHiveModel` (formerly `FargoRateRankingPolicyHiveModel`) adds `@HiveField(7, defaultValue:500)` with a **literal** `500` (codegen requires a literal, not a const reference) — existing rows without field 7 read as `500` (legacy rating). `lib/domain/constants/elo_constants.dart` is the domain single source (`400` default for new leagues, `500` legacy, `K=20`); `lib/core/constants/hive_box_names.dart:kFargoInitialRating=500` is retained `@Deprecated` only for the literal. The generated `lib/data/models/hive/ranking_policies/elo_ranking_policy_hive_model.g.dart` `defaultValue:500` is hand-patched to a literal (`fields[7] == null ? 500 : fields[7] as int`); re-running `build_runner` will overwrite the `.g.dart` — hand-patch back to the literal `500` if needed. No `AppConfig.hiveDbVersion` bump and no `_migrateToV4` is required because the Hive addition is backward-compatible via `defaultValue` and the `K` change (`32→20`) is purely in-memory recalculation (`EloCalculator._kFactor = 20`), not stored state.

**Rationale for `hiveDbVersion` staying `3`:** Bumping to `4` would force a migration path that rewrites every `typeId 12` row for no schema change; the additive `field 7` with `defaultValue:500` already handles legacy rows (missing field → `500`), and `K=20` requires no persisted delta — ratings are recomputed from matches on every `_fetchData()`. Keeping `3` avoids churn, preserves idempotent `migrate` no-op (`3→3`), and is covered by `hiveDbVersion == 3` tests.

## Invariants

| Invariant | Enforcement |
|-----------|-------------|
| `RankingPolicy.categoryIds` non-empty + unique | Domain constructor `ArgumentError`; `RankingPolicyHiveModel.categoryIds` defensive `List.from`; `CreateLeagueService.execute` + `HiveRankingPolicyRepository.put` + `CategoryRepository.existsAll([]) → ArgumentError` defense in depth |
| `Simple` / `GoalDifference` leagues only in Custom category | `kSeedCategoryPolicyTypes` maps only `cat_custom_league_001 → [simple, goalDifference]`; `rankingPolicyTypesForCategoryProvider` returns `[]` for non-custom non-Elo ids; `CreateLeagueService.execute` + `HiveRankingPolicyRepository.put` throw `ArgumentError` unless `categoryIds == [kFallbackCategoryId]` (exact single-element check). Tests: `category_policy_map_test`, `create_league_service_test`, `hive_ranking_policy_custom_category_real_test`, `ranking_policy_types_for_category_provider_test` |
| `Elo` leagues only in Sports + Pub Games | `kSeedCategoryPolicyTypes` maps `cat_sports` + `cat_pubgames` → `[elo]`; `EloRankingPolicy.validateCategoryIds` (SetEquality + length) + `CreateLeagueService` + `HiveRankingPolicyRepository.put` throw `ArgumentError` unless `categoryIds` set-equals `kEloCategoryIds` (`[cat_sports, cat_pubgames]`, order-insensitive, exactly 2). Provider whitelist for `cat_sports`/`cat_pubgames` is **unconditional** (`return [elo]` without repo query, via `kSeedCategoryPolicyTypes`) — always available regardless of repo state; bootstrap vs corruption distinction applies only to Custom fallback (see above). `kFargoCategoryIds`/`RankingPolicyType.fargoRate`/`FargoRateRankingPolicy` are deprecated aliases. Tests: `create_league_service_fargo_test` (now Elo), `elo_calculator_test` (K=20), `category_policy_map_test` |
| `EloRankingPolicy.initialRating` 100..500, `K=20` | `lib/domain/constants/elo_constants.dart` defines `kEloMinRating=100`, `kEloMaxRating=500`, `kEloDefaultInitialRating=400`, `kEloLegacyInitialRating=500`, `kEloDefaultKFactor=20`. `EloRankingPolicy.validateInitialRating` + `EloRankingPolicyHiveModel.toDomain` + `HiveRankingPolicyRepository.put` + `CreateLeagueService.execute` throw `ArgumentError` if outside range. `EloCalculator._kFactor = 20` (was 32 — breaking recalc, see Elo Domain). New leagues via `CreateFargoRateLeagueScreen` (now Elo) pre-fill 400 and validator delegates to `validateInitialRating`; legacy Hive rows (field 7 missing) read as 500 via `@HiveField(7, defaultValue:500)` literal. `hiveDbVersion` stays 3 (no migration) — additive field with literal default is backward-compatible + K change is in-memory only. |
| `Category.name` non-empty trimmed | `Category` constructor / `copyWith` `ArgumentError`; repository preserves under `Lock` |
| `Slug` 3–32 normalized lowercase alphanum + `-` | `Slug` value object throws `ArgumentError`; uniqueness scanned inside `Lock` before `put` |
| `parentId` null or existing id, never self-ref, depth ≤ 1, no cycles | `put` validates parent exists via truth scan, then `validateNoCycleAndDepth` (DFS + `ArgumentError`) inside `Lock` |
| `sortOrder` per-parent via midpoint + normalize on collision | Siblings share `parentId`; `prev < new < next` midpoint `(prev+next)~/2`; gap `<2` → `_normalizeSortOrders(parentId)` reassigns `0,1000,2000,...` under same `Lock`; V3 additionally normalizes all roots if any gap `<2` after inserting `cat_pubgames` at 3500 |
| `isBuiltIn` immutable, only `sortOrder` + `icon` mutable on built-ins; built-in delete forbidden | `put` compares incoming to existing built-in fields and throws `BuiltInCategoryException`; same for `delete` path; V3 upserts preserve `sortOrder` for `cat_pubgames` if already present |
| Delete is `RESTRICT` | `HiveCategoryRepository.delete` checks inside `Lock`: (1) `isBuiltIn` → `BuiltInCategoryException`, (2) any child `parentId == id` → `ArgumentError`, (3) any `rankingPolicy.categoryIds.contains(id)` via truth scan → `ArgumentError` (cascade reassign to `kFallbackCategoryId` only if future product decision opts to cascade — default is restrict) |
| `existsAll([])` is programmer error | Throws `ArgumentError` (not vacuous `true`). Documented dartdoc on `CategoryRepository.existsAll` |
| Box `categoryIds == []` on read is corruption | `Simple/GoalDifference/EloRankingPolicyHiveModel.toDomain` throws `StateError` mentioning expected ids (`kFallbackCategoryId` or `kEloCategoryIds`) — only migration backfill may write fallback, runtime never silently fixes |
| `EloCalculator` pure domain | No Flutter/Hive imports; filters `isComplete` before sort; sorts `playedAt ASC + id ASC`; throws on `isDraw` / `sides.length !=2` / `playerIds.length !=1` / missing `winnerSideId`; Elo `K=20` seeded from `initialRating` (required, 100..500); `LeagueDetailState` captures `policy.initialRating` and sorts `rating ?? initialRating`; returns `EloPlayerStats` for all `players` + ghost ids; `FargoRateCalculator`/`FargoPlayerStats` are deprecated aliases |
| `Lock` is best-effort single-isolate | Explicit comment; indexes are rebuildable caches repaired by `rebuildIfNeeded` after `openBox` |
| Seed idempotency preserves user ordering | `_migrateToV2`/`_migrateToV3` re-put keeps existing `sortOrder`; indexes rebuilt from truth after |
| `migrate` 3→3 is no-op | Guard `if (current >= target) return`; explicit repair via direct `_migrateToV2`/`_migrateToV3` or `rebuildIndexes` when needed, not via `migrate()` — retained after Elo rename (no-op, no re-seed) |

## Provider Graph

```dart
// lib/providers/leagues_provider.dart + lib/presentation/screens/league/select_scoring_system_screen.dart
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) => sl<CategoryRepository>());
final rankingPolicyRepositoryProvider = Provider<RankingPolicyRepository>((ref) => sl<RankingPolicyRepository>());
final categoriesProvider = FutureProvider<List<Category>>((ref) async => ref.read(categoryRepositoryProvider).getAllOrdered());
final categoriesRootsProvider = FutureProvider<List<Category>>((ref) async => ref.read(categoryRepositoryProvider).getRoots());
final rankingPolicyTypesForCategoryProvider = FutureProvider.family<List<RankingPolicyType>, String>((ref, categoryId) async {
  // Elo whitelist: sports/pubgames → unconditional [elo] via kSeedCategoryPolicyTypes.
  // Always available regardless of repo state (no getByCategory/getAll bootstrap vs corruption check).
  if (categoryId == kSportsCategoryId || categoryId == kPubGamesCategoryId) {
    return [RankingPolicyType.elo];
  }
  if (categoryId != kFallbackCategoryId) return <RankingPolicyType>[]; // board/card/video → empty
  // Custom is the only repo-driven category; bootstrap vs corruption distinction lives here.
  final repo = ref.read(rankingPolicyRepositoryProvider);
  try {
    final policies = await repo.getByCategory(categoryId);
    if (policies.isEmpty) return RankingPolicyType.values; // custom empty-box fallback → show all for usability (bootstrap)
    // map Simple/GoalDifference/Elo → RankingPolicyType, then toList()
  } catch (_) { return RankingPolicyType.values; } // custom fallback on error
});

// Consumption:
// - SelectCategoryScreen  → ref.watch(categoriesRootsProvider) → roots sorted by sortOrder, Icon via mapCategoryIconToIconData
// - SelectScoringSystemScreen(categoryId) → ref.watch(categoriesProvider) for existence check,
//     then ref.watch(rankingPolicyTypesForCategoryProvider(effectiveCategoryId))
//     → sports/pubgames: unconditional [elo] (no repo query, always available); custom: repo-driven via
//       getByCategory (truth scan + index cache, bootstrap fallback to all types when empty/error); board/card/video: [] → empty state
// - Create*LeagueScreen(categoryId) → Simple/GoalDifferenceRankingPolicy(categoryIds: [categoryId]) or EloRankingPolicy(categoryIds: kEloCategoryIds, initialRating: 100..500 default 400 legacy 500)
//     via CreateLeagueService(categoryIds) → validates existsAll + category-specific guard before put
```

Providers are read-only `FutureProvider`s over repository truth; mutations flow through `CreateLeagueService` and `HiveCategoryRepository`/`HiveRankingPolicyRepository` under the shared `Lock`. See `docs/architecture/provider-invalidation.md` for the broader invalidation rules (categories currently seed-only, no provider-level invalidation required).

## UI Flow

```
HomeScreen (FAB + empty-state "Create First League")
  └→ SelectCategoryScreen (roots sorted, icon per CategoryIcon → card)
       └→ SelectScoringSystemScreen(categoryId)
            ├─ if categoryId in {cat_boardgames, cat_cardgames, cat_videogames}
            │  → rankingPolicyTypesForCategoryProvider returns [] → empty state
            │     "No scoring systems available for this category" (current for Board/Card/Video)
             ├─ if categoryId in {cat_sports, cat_pubgames}
             │  → rankingPolicyTypesForCategoryProvider → unconditional [elo] (no repo query)
             │     → always card "Pool — Elo Rankings" regardless of repo state (fresh install, has Custom leagues, etc.)
             │     └→ CreateFargoRateLeagueScreen(categoryId) // legacy name, now Elo; default cat_sports, but policy always kEloCategoryIds; collects `initialRating` (100..500, pre-filled 400, validator → validateInitialRating)
            │          └→ CreateLeagueService(categoryIds:kEloCategoryIds) → validates existsAll + Elo guard
            │             → HiveRankingPolicyRepository.put → same Elo guard + index update under Lock
            └─ if categoryId == kFallbackCategoryId (Custom) → repo-driven via rankingPolicyTypesForCategoryProvider
                 ├→ CreateSimpleLeagueScreen(categoryId)       // categoryIds == [kFallbackCategoryId]
                 └→ CreateGoalDifferenceLeagueScreen(categoryId) // ditto
                      └→ CreateLeagueService(categoryIds:[categoryId]) → validates existsAll + custom-only guard
                         → HiveRankingPolicyRepository.put → same custom-only guard + index update under Lock

Deprecated fallback: SelectRankingPolicyScreen (@Deprecated('Use CategoryFiltered flow; kept as fallback until v3'))
  — kept one release to preserve deep links / old FAB paths; shows unfiltered RankingPolicyType.values with SnackBar "Categories unavailable — showing all" if categories box fails.
Invalid categoryId deep link: SelectScoringSystemScreen validates existence against categoriesProvider, shows SnackBar('Invalid category') and falls back to kFallbackCategoryId list rather than crashing. CreateLeagueService with unknown categoryIds throws ArgumentError (surfaced as SnackBar in create screens). Non-Elo valid categories do NOT fallback — they correctly show the empty state above.
```

`HomeScreen` FAB now routes to `SelectCategoryScreen` instead of directly to `SelectRankingPolicyScreen`.

### League Detail — Elo Presentation

`LeagueDetailState.isElo` (`rankingPolicy is EloRankingPolicy`) switches standings; `isFargo` is deprecated alias (`isFargo => isElo`):

* Header: `P | W | L | Win% | Elo` (was `Fargo`) — `Elo` header for Elo leagues (vs `P | GF | GA | GD | Pts` for GD or `P | Pts` for Simple).
* Sorting: `rating DESC → wins DESC → id ASC` (never name; fallback `eloStats[id]?.rating ?? policy.initialRating` — 400 for new leagues, 500 legacy via Hive `defaultValue:500`; `fargoStats` alias delegates to `eloStats`).
* `eloStats` from `EloCalculator.calculate(initialRating: policy.initialRating)` is passed to `_StandingsTab` (`eloStats: Map<String, EloPlayerStats>`, `fargoStats` deprecated alias), computed with required `initialRating` (not a global) and `K=20`.
* `LogMatchScreen` (`_buildWinnerSection`) hides the Draw `DropdownMenuItem` when `isElo` (`isFargo` alias) — checks `isElo`/`isFargo`; domain calculator would throw on `isDraw` anyway, but UI prevents it.

## Exceptions and Corruption Handling

| Exception | When |
|-----------|------|
| `BuiltInCategoryException(categoryId)` | Attempt to `put` a built-in with mutated `name`/`slug`/`parentId`/`isBuiltIn`/`createdAt`, or to `delete` a built-in. |
| `UnknownCategoryException(ids)` | `HiveRankingPolicyRepository.put` after `existsAll` returns `false` (one or more ids missing). `CreateLeagueService` maps this to `ArgumentError` message `One or more categoryIds do not exist` for UI surface. |
| `ArgumentError` | `RankingPolicy` ctor empty/duplicate; `Category` empty name / self-parent; `Slug` length/pattern; `validateNoCycleAndDepth` depth>1 or cycle; `HiveCategoryRepository.put` duplicate slug / missing parent / depth; `delete` hasChildren or inUse; `existsAll([])`; **Custom-only violation**: `CreateLeagueService` / `HiveRankingPolicyRepository.put` when `Simple`/`GoalDifference` `categoryIds != [kFallbackCategoryId]` — message `Simple and Goal Difference leagues are only allowed in the Custom category (cat_custom_league_001). Got: ...`; **Elo violations**: (1) `EloRankingPolicy.validateCategoryIds` / `CreateLeagueService` / `HiveRankingPolicyRepository.put` when `categoryIds` not exactly `{cat_sports, cat_pubgames}` — message `FargoRate leagues must have categoryIds exactly [cat_sports, cat_pubgames]. Got: ...` (retains legacy text); (2) `EloRankingPolicy.validateInitialRating` / `CreateLeagueService` / `HiveRankingPolicyRepository.put` / `EloRankingPolicyHiveModel.toDomain` when `initialRating` outside 100..500 — message `initialRating must be within 100..500 inclusive. Got: ...` (UI `CreateFargoRateLeagueScreen` / Elo TextFormField pre-filled 400, validator delegates to `validateInitialRating`); `EloCalculator` when `isDraw` / `sides.length !=2` / `playerIds.length !=1` / missing winnerSideId |
| `StateError` | `Simple/GoalDifference/EloRankingPolicyHiveModel.toDomain` when `categoryIds.isEmpty` — signals corruption of a pre-v2 row that migration should have backfilled (Elo message names `kEloCategoryIds`); only migration may write fallback, runtime never silently fixes. `EloRankingPolicyHiveModel.toDomain` also throws `ArgumentError` (propagated) when `initialRating` outside 100..500. |

Direct `Box.put(RankingPolicyHiveModel(categoryIds: []))` bypassing the domain constructor is an anti-pattern — all writes must go via repositories; tests assert `StateError` on `get`/`getAll` and `ArgumentError` on repository `put` for such bypass.

## Operational Notes

- `dart run build_runner build --delete-conflicting-outputs` must regenerate `lib/hive_registrar.g.dart` and `*.g.dart` after changing Hive fields/typeIds (CI `test.yml` runs it after `pub get`). V3 added `typeId 12` for Elo (formerly Fargo). `EloRankingPolicyHiveModel` field 7 uses `@HiveField(7, defaultValue:500)` with a **literal** `500` (not a const ref) — the generated `elo_ranking_policy_hive_model.g.dart` must retain that literal; re-running build_runner will overwrite the `.g.dart` default, so hand-patch `defaultValue:500` back if needed (`fields[7] == null ? 500 : fields[7] as int`). `FargoRateRankingPolicyHiveModel` is now a deprecated shim re-exporting `elo_ranking_policy_hive_model.dart`.
- `lib/data/models/hive/hive_box_names.dart` is the single source for box names and `kFallbackCategoryId` / `kMaxCategoryDepth` / `kSportsCategoryId` / `kPubGamesCategoryId` / `kEloCategoryIds` (plus deprecated `kFargoCategoryIds` alias and `kFargoInitialRating=500` literal retained only for `@HiveField(7, defaultValue:500)` codegen); domain range/defaults/K live in `lib/domain/constants/elo_constants.dart` (`kEloMinRating`/`kEloMaxRating`/`kEloDefaultInitialRating=400`/`kEloLegacyInitialRating=500`/`kEloDefaultKFactor=20`, with `fargo_constants.dart` shim and `kFargo*` deprecated aliases).
- Indexes can be deleted and will be rebuilt on next launch (`rebuildIfNeeded` + migration rebuilds).
- **K-factor change is not a Hive migration:** `K 32→20` applies on next recalc; no DB bump. To verify, run `test/unit/domain/services/elo_calculator_test.dart` — expects `410/390`.

## Future Extension

If hierarchy deeper than one child level is needed, extend without changing the `parentId` API:

- Add a **closure table** box `category_closure (ancestor_id, descendant_id, depth)` maintained alongside `put`/`delete` inside the shared `Lock`.
- Query descendants/ancestors via closure instead of recursive `parentId` scans; keep `validateNoCycleAndDepth` with configurable `maxDepth`.
- Preserve the current adjacency list as truth (`parentId` on `categories`); closure is a derived cache like the existing `categoryParentIndex`.

## Related Files

- `lib/domain/entities/category.dart`
- `lib/domain/value_objects/slug.dart`, `category_icon.dart`
- `lib/domain/entities/ranking_policy.dart` (+ `simple_ranking_policy.dart`, `goal_difference_ranking_policy.dart`, `elo_ranking_policy.dart` / deprecated `fargo_rate_ranking_policy.dart` shim, `ranking_policy_type.dart` with `elo` + deprecated `fargoRate`)
- `lib/domain/value_objects/elo_player_stats.dart` (deprecated `fargo_player_stats.dart` shim)
- `lib/domain/services/elo_calculator.dart` (pure domain; `fargo_rate_calculator.dart` deprecated shim re-exports it; `K=20`)
- `lib/data/models/hive/category_hive_model.dart` (`typeId 11`), `ranking_policy_hive_model.dart` (`HiveField 6`)
- `lib/data/models/hive/ranking_policies/elo_ranking_policy_hive_model.dart` (`typeId 12`, `@HiveField(7, defaultValue:500)` literal) / deprecated `fargo_rate_ranking_policy_hive_model.dart` shim
- `lib/data/repositories/hive/hive_category_repository.dart`, `hive_ranking_policy_repository.dart`
- `lib/data/services/hive/hive_database_migration_service.dart`, `category_index_rebuilder.dart`
- `lib/core/constants/hive_box_names.dart` (`kFallbackCategoryId`, `kMaxCategoryDepth`, `kSportsCategoryId`, `kPubGamesCategoryId`, `kEloCategoryIds` / deprecated `kFargoCategoryIds` + deprecated `kFargoInitialRating=500` literal) + `lib/domain/constants/elo_constants.dart` (`kEloMinRating`/`kEloMaxRating`/`kEloDefaultInitialRating`/`kEloLegacyInitialRating`/`kEloDefaultKFactor`)
- `lib/core/constants/category_policy_map.dart` (`kSeedCategoryPolicyTypes` — includes Elo whitelist `[elo]` for sports/pubgames)
- `lib/core/config.dart` (`AppConfig.hiveDbVersion = 3` — stays 3 after Elo rename + K change, no bump)
- `lib/application/services/create_league_service.dart` (custom-only + Elo guards)
- `lib/core/injection_container.dart` (`_initHive` ordered init + shared `Lock`)
- `lib/providers/league_detail_provider.dart` (`isElo` / deprecated `isFargo`, `eloStats` / deprecated `fargoStats`, rating→wins→id sorting with `rating ?? policy.initialRating`, `K=20`)
- `lib/presentation/screens/league/select_category_screen.dart`, `select_scoring_system_screen.dart` (provider whitelist `elo` + empty state + Elo branch)
- `lib/presentation/screens/league/create_fargo_rate_league_screen.dart` (legacy name, now Elo; `TextFormField` for `initialRating` 100..500 default 400), `league_detail_screen.dart` (`_StandingsTab` Elo columns `P W L Win% Elo`, `eloStats`/`fargoStats`), `match/log_match_screen.dart` (hide draw when `isElo`)
- `test/data/services/hive/hive_database_migration_service_test.dart` (0→2, 1→2, 2→2, 0→3, 2→3, 3→3, crash-retry — `3→3` no-op retained), `test/integration/data/repositories/hive/hive_repositories_real_test.dart` (slug, depth, concurrency)
- `test/unit/core/constants/category_policy_map_test.dart`, `test/unit/application/services/create_league_service_test.dart`, `test/unit/application/services/create_league_service_fargo_test.dart` (now Elo, K=20), `test/unit/domain/services/elo_calculator_test.dart` (K=20, `410/390`), `test/integration/data/repositories/hive/hive_ranking_policy_custom_category_real_test.dart`, `test/unit/providers/ranking_policy_types_for_category_provider_test.dart` (Elo + custom restrictions)

