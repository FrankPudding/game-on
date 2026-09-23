# Scoring System Categories

## Purpose

Categories provide a taxonomy for scoring systems (ranking policies) and the leagues created from them. League creation is now category-first: pick a **Category** → filter scoring systems via `RankingPolicyRepository.getByCategory` → create the league with `RankingPolicy.categoryIds` via `CreateLeagueService`. This document describes the domain model, persistence schema, indexes, migration, provider graph, UI flow, and invariants.

Currently three category→policy bindings exist:

* **`Simple` and `GoalDifference` restricted to the Custom category** (`cat_custom_league_001` = `kFallbackCategoryId`).
* **`FargoRate` (Pool) restricted to Sports + Pub Games** (`cat_sports` + `cat_pubgames` = `kFargoCategoryIds`). The policy extends `RankingPolicy<SimpleMatch>` and must carry exactly those two ids (set-equality, order-insensitive).
* Other built-in categories (`Board Games`, `Card Games`, `Video Games`) intentionally have no allowed scoring systems until future policy types are added.

Restrictions are enforced at three layers: seed map, provider whitelist, and write-path validation (see Scoring System Availability and Invariants).

Related: `docs/domain-language.md` → Category / RankingPolicy / FargoRate, `lib/presentation/mappers/category_icon_mapper.dart`, `lib/providers/leagues_provider.dart` → `categoriesProvider` / `rankingPolicyTypesForCategoryProvider`.

## Domain Model

| Concept | Location | Notes |
|---------|----------|-------|
| `Category` | `lib/domain/entities/category.dart` | `id`, `name`, `slug: Slug`, `icon: CategoryIcon`, `parentId?`, `sortOrder`, `isBuiltIn`, `createdAt`, `updatedAt`. `Slug` (`lib/domain/value_objects/slug.dart`) normalizes to `^[a-z0-9]+(-[a-z0-9]+)*$`, 3–32 chars. `CategoryIcon` (`lib/domain/value_objects/category_icon.dart`) is `enum {chess, playingCards, sportsSoccer, sportsEsports, categoryOther, other}` with `iconName` mapping + `fromName` fallback to `other`. |
| `RankingPolicy.categoryIds` | `lib/domain/entities/ranking_policy.dart` | `List<String>` required non-empty unique, `List.unmodifiable` with `ArgumentError` on violation. Many-to-many: a policy may live in multiple categories; a category contains many policies. Each policy must belong to ≥1 category. |
| `kFallbackCategoryId` | `lib/core/constants/hive_box_names.dart` | `const 'cat_custom_league_001'` — the Custom/Other seed. Single source for fallback references. Used by migration backfill, UI invalid-category fallback, and `CreateSimple/GoalDifferenceLeagueScreen` default param. |
| `kSportsCategoryId` / `kPubGamesCategoryId` / `kFargoCategoryIds` / `kFargoInitialRating` | `lib/core/constants/hive_box_names.dart` | `cat_sports`, `cat_pubgames`, `const [cat_sports, cat_pubgames]`, `500`. Single source for Fargo binding. `kFargoInitialRating` is the Elo starting rating used by `FargoRateCalculator` and `LeagueDetailState` fallback. |
| `kCategoryMaxDepth` / `kMaxCategoryDepth` | `lib/domain/entities/category.dart` / `hive_box_names.dart` | `1` (roots + one sub-category level). |

### Subtypes

| Policy | Extends | `RankingPolicyType` | `categoryIds` invariant | Location |
|--------|---------|---------------------|------------------------|----------|
| `SimpleRankingPolicy` | `RankingPolicy<SimpleMatch>` | `simple` | exactly `[kFallbackCategoryId]` | `lib/domain/entities/ranking_policies/simple_ranking_policy.dart` |
| `GoalDifferenceRankingPolicy` | `RankingPolicy<SimpleMatch>` | `goalDifference` | exactly `[kFallbackCategoryId]` | `lib/domain/entities/ranking_policies/goal_difference_ranking_policy.dart` |
| `FargoRateRankingPolicy` | `RankingPolicy<SimpleMatch>` | `fargoRate` (`displayName: 'FargoRate'`, `description: 'Pool'`) | exactly `{cat_sports, cat_pubgames}` (set-equality via `SetEquality` + length guard, order-insensitive) | `lib/domain/entities/ranking_policies/fargo_rate_ranking_policy.dart` |

`FargoRateRankingPolicy.validateCategoryIds` is the canonical validator (throws `ArgumentError` with message `FargoRate leagues must have categoryIds exactly $kFargoCategoryIds. Got: ...`); `CreateLeagueService` and `HiveRankingPolicyRepository.put` delegate to the same length + `containsAll` guard. `RankingPolicyType` is a presentation enum; `rankingPolicyTypesForCategoryProvider` maps repo results to this enum for the UI.

`FargoPlayerStats` (`lib/domain/value_objects/fargo_player_stats.dart`) is the pure domain value object returned by `FargoRateCalculator`:

```dart
class FargoPlayerStats {
  final int matchesPlayed, wins, losses, rating; // rating initial 500
  double get winRate => matchesPlayed == 0 ? 0 : wins / matchesPlayed;
}
```

`LeagueDetailState.fargoStats: Map<String, FargoPlayerStats>` holds per-player stats when `rankingPolicy is FargoRateRankingPolicy`; `isFargo` getter mirrors `isGoalDifference`.

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
| `HiveBoxNames.rankingPolicies` | `RankingPolicyHiveModel` (`typeId 9` / `10` / `12`) | Truth store; base field `categoryIds` at `@HiveField(6, defaultValue: <String>[])` with `List.from` defensive copy | `9` = Simple, `10` = GoalDifference, `12` = FargoRate |
| `HiveBoxNames.categoryPolicyIndex` | `String` (`categoryId → comma-joined policyIds`) | Derived policy-by-category index | — |
| `HiveBoxNames.meta` | `int` (`db_version`) | Migration version | — |

Hive field layout `CategoryHiveModel`: `0:id`, `1:name`, `2:slug`, `3:iconName`, `4:sortOrder`, `5:isBuiltIn`, `6:parentId?`, `7:createdAt`, `8:updatedAt`.

Hive field layout `RankingPolicyHiveModel` base: `0:id`, `1:name`, `5:leagueId` (`defaultValue:''`), `6:categoryIds` (`defaultValue: <String>[]`, empty only to read pre-v2 boxes; runtime empty is treated as corruption — see Corruption Handling). `FargoRateRankingPolicyHiveModel` (`typeId 12`) stores only base fields (no points fields) and `toDomain` rejects empty `categoryIds` with `StateError` mentioning `kFargoCategoryIds`.

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
  'cat_sports':     [RankingPolicyType.fargoRate],
  'cat_videogames': <RankingPolicyType>[],
  'cat_pubgames':   [RankingPolicyType.fargoRate],
  'cat_custom_league_001': [RankingPolicyType.simple, RankingPolicyType.goalDifference],
};
```

* **Custom (`cat_custom_league_001`) → `[simple, goalDifference]`** — `Simple`/`GoalDifference` are custom-only.
* **Sports (`cat_sports`) and Pub Games (`cat_pubgames`) → `[fargoRate]`** — `FargoRate` (Pool) is only in those two categories, and a Fargo league must be in **both** (`categoryIds` exactly `{cat_sports, cat_pubgames}`).
* **Board/Card/Video → `[]`** until future scoring systems are added.

**Provider whitelist (`rankingPolicyTypesForCategoryProvider`):**

For `cat_sports` / `cat_pubgames` the provider is an **unconditional whitelist** — it returns `[fargoRate]` directly without querying the repository. This mirrors `kSeedCategoryPolicyTypes` (`cat_sports` + `cat_pubgames` → `[fargoRate]`) and guarantees Pool (FargoRate) is always available under Sports + Pub Games regardless of repo state (fresh install, populated repo, or after Custom leagues exist). No `getByCategory`/`getAll` bootstrap vs corruption check is performed for Fargo; that distinction applies only to the Custom fallback.

For `kFallbackCategoryId` (Custom) it is repo-driven: queries `getByCategory`; empty/error → `RankingPolicyType.values` fallback so custom remains usable even with an empty box (bootstrap vs corruption distinction lives here — empty box → show all types for usability, populated box → map actual `Simple`/`GoalDifference`/`FargoRate` policies). For any other id (`board/card/video`) it immediately returns `[]` → `SelectScoringSystemScreen` shows `No scoring systems available for this category`.

**Write-path defense in depth:**

* `lib/application/services/create_league_service.dart:CreateLeagueService.execute` — rejects `Simple`/`GoalDifference` unless `categoryIds == [kFallbackCategoryId]`; rejects `FargoRateRankingPolicy` unless `categoryIds` length == 2 and `containsAll(kFargoCategoryIds)`. `CategoryRepository.existsAll` is checked first for referential integrity; the category-specific guard runs immediately after; if `categoryIds` param differs from `policy.categoryIds` it also throws `RankingPolicy categoryIds must match provided categoryIds`.
* `lib/data/repositories/hive/hive_ranking_policy_repository.dart:HiveRankingPolicyRepository.put` — same two guards plus `existsAll` via `CategoryRepository` (throws `UnknownCategoryException` on miss, mapped to `ArgumentError` by service). Defensive `List.from` copy.

Tests: `test/unit/core/constants/category_policy_map_test.dart` (seed map), `test/unit/application/services/create_league_service_test.dart` + `test/unit/application/services/create_league_service_fargo_test.dart` + `test/integration/data/repositories/hive/hive_ranking_policy_custom_category_real_test.dart` + `test/unit/providers/ranking_policy_types_for_category_provider_test.dart` (provider whitelist — Fargo unconditional via `kSeedCategoryPolicyTypes`, Custom repo-driven empty vs populated), + `test/unit/providers/ranking_policy_types_for_category_provider_fargo_test.dart` (Fargo unconditional under Sports/PubGames regardless of repo state) + service/repo rejects + custom empty-box fallback with bootstrap vs corruption (Custom only).

## FargoRate Domain — Calculator

`FargoRateCalculator` (`lib/domain/services/fargo_rate_calculator.dart`, re-exported at `lib/domain/calculators/fargo_rate_calculator.dart`) is a **pure domain service** — no Flutter/Hive imports, deterministic, testable in isolation.

* **Inputs:** `List<SimpleMatch> matches`, `List<LeaguePlayer> players`.
* **Filtering:** `where(isComplete)` **before** sort — incomplete matches are ignored entirely.
* **Ordering:** `playedAt ASC` then `id ASC` — guarantees stable replay order regardless of insertion order.
* **Validation (throws `ArgumentError`):** `isDraw == true`, `sides.length != 2`, any `side.playerIds.length != 1`, `winnerSideId == null` or not found. Fargo does not support draws or team play.
* **Rating:** Elo-like with `kFargoInitialRating = 500` and `K = 32`. Expected score `1 / (1 + 10^((loserRating - winnerRating)/400))`; winner `rating + K*(1 - expected)`, loser `rating + K*(0 - expected)`, rounded. Ratings are kept per player and evolve sequentially in sorted order.
* **Stats:** Returns `Map<String, FargoPlayerStats>` for every player in `players` (even those with no matches → `0/0/0/500`). `wins`/`losses`/`matchesPlayed` are incremented per completed match; `winRate` is derived.

Non-obvious: `LogMatchScreen` hides the Draw option when `state.isFargo` (see `lib/presentation/screens/match/log_match_screen.dart:_buildWinnerSection`); `LeagueDetailState` sorting for Fargo uses `rating DESC → wins DESC → id ASC` (never name), vs `points → GD → GF → id` for other leagues.

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

- If `currentVersion >= targetVersion` → **no-op early return** (idempotent guard). This preserves user `sortOrder` and avoids churn on every launch. Logged via `debugPrint`.
- Underlying `_migrateToV*` are individually idempotent and retry-safe: categories are upserted idempotently, ranking-policy backfill only rewrites rows where `categoryIds.isEmpty` to `[kFallbackCategoryId]`, and all indexes are cleared then rebuilt from truth. Crash-retry (throw before `meta.put(version)`) leaves version at old value; next launch re-executes idempotently.

**`_migrateToV2` steps (summary):**

1. Ensure adapters (fallback registration for `test` harness where `Hive.init` runs without DI).
2. Upsert the five seeds (Board/Card/Sports/Video/Custom; preserve `sortOrder` if row exists, otherwise initial spaced values).
3. Clear `slugIndex` + `parentIndex`, rebuild from `categoriesBox` truth.
4. Backfill: for each `rankingPolicies` row where `categoryIds.isEmpty`, replace with `const [kFallbackCategoryId]` by reconstructing the concrete `Simple`/`GoalDifference` Hive model (preserving points).
5. Clear and rebuild `categoryPolicyIndex` from `rankingBox.categoryIds`.
6. `meta.db_version` is bumped to `2` by the loop in `migrate()` after `_migrateToV2` returns; tests cover `0→2` (fresh), `1→2` (upgrade), `2→2` (no-op), crash-retry (kill mid-migration then re-migrate succeeds, no duplicates, `sortOrder` preserved).

**`_migrateToV3` steps (summary):**

1. Ensure adapters including `typeId 12` (`FargoRateRankingPolicyHiveModelAdapter`).
2. Upsert `cat_pubgames` (`Pub Games`, `pub-games`, `category_other`): if row exists and drifted, correct `name`/`slug`/`iconName`/`isBuiltIn`/`parentId` while preserving `sortOrder`; if missing, compute insertion `sortOrder` as midpoint `(video.sortOrder + custom.sortOrder)~/2` (defaults to 3500 if neighbors missing or midpoint collides), then `put`.
3. Gap `<2` normalize: scan all categories sorted by `sortOrder` then `id`; if any `gap = curr - prev < 2`, reassign `0,1000,2000,...` in that sorted order under same boxes (updates `updatedAt`).
4. Clear `slugIndex` + `parentIndex`, rebuild from `categoriesBox` truth (including new `cat_pubgames`).
5. Clear and rebuild `categoryPolicyIndex` from `rankingBox.categoryIds` (now may contain `12` rows with both `cat_sports` and `cat_pubgames` entries).
6. `meta.db_version` bumped to `3` by the outer loop after `_migrateToV3` returns; idempotent and retry-safe (version not bumped on throw). Fresh `0→3` runs V2 then V3 sequentially; `2→3` runs only V3; `3→3` is no-op.

## Invariants

| Invariant | Enforcement |
|-----------|-------------|
| `RankingPolicy.categoryIds` non-empty + unique | Domain constructor `ArgumentError`; `RankingPolicyHiveModel.categoryIds` defensive `List.from`; `CreateLeagueService.execute` + `HiveRankingPolicyRepository.put` + `CategoryRepository.existsAll([]) → ArgumentError` defense in depth |
| `Simple` / `GoalDifference` leagues only in Custom category | `kSeedCategoryPolicyTypes` maps only `cat_custom_league_001 → [simple, goalDifference]`; `rankingPolicyTypesForCategoryProvider` returns `[]` for non-custom non-Fargo ids; `CreateLeagueService.execute` + `HiveRankingPolicyRepository.put` throw `ArgumentError` unless `categoryIds == [kFallbackCategoryId]` (exact single-element check). Tests: `category_policy_map_test`, `create_league_service_test`, `hive_ranking_policy_custom_category_real_test`, `ranking_policy_types_for_category_provider_test` |
| `FargoRate` leagues only in Sports + Pub Games | `kSeedCategoryPolicyTypes` maps `cat_sports` + `cat_pubgames` → `[fargoRate]`; `FargoRateRankingPolicy.validateCategoryIds` (SetEquality + length) + `CreateLeagueService` + `HiveRankingPolicyRepository.put` throw `ArgumentError` unless `categoryIds` set-equals `kFargoCategoryIds` (`[cat_sports, cat_pubgames]`, order-insensitive, exactly 2). Provider whitelist for `cat_sports`/`cat_pubgames` is **unconditional** (`return [fargoRate]` without repo query, via `kSeedCategoryPolicyTypes`) — always available regardless of repo state; bootstrap vs corruption distinction applies only to Custom fallback (see above). Tests: `create_league_service_fargo_test`, `fargo_rate_calculator_test`, `category_policy_map_test` |
| `Category.name` non-empty trimmed | `Category` constructor / `copyWith` `ArgumentError`; repository preserves under `Lock` |
| `Slug` 3–32 normalized lowercase alphanum + `-` | `Slug` value object throws `ArgumentError`; uniqueness scanned inside `Lock` before `put` |
| `parentId` null or existing id, never self-ref, depth ≤ 1, no cycles | `put` validates parent exists via truth scan, then `validateNoCycleAndDepth` (DFS + `ArgumentError`) inside `Lock` |
| `sortOrder` per-parent via midpoint + normalize on collision | Siblings share `parentId`; `prev < new < next` midpoint `(prev+next)~/2`; gap `<2` → `_normalizeSortOrders(parentId)` reassigns `0,1000,2000,...` under same `Lock`; V3 additionally normalizes all roots if any gap `<2` after inserting `cat_pubgames` at 3500 |
| `isBuiltIn` immutable, only `sortOrder` + `icon` mutable on built-ins; built-in delete forbidden | `put` compares incoming to existing built-in fields and throws `BuiltInCategoryException`; same for `delete` path; V3 upserts preserve `sortOrder` for `cat_pubgames` if already present |
| Delete is `RESTRICT` | `HiveCategoryRepository.delete` checks inside `Lock`: (1) `isBuiltIn` → `BuiltInCategoryException`, (2) any child `parentId == id` → `ArgumentError`, (3) any `rankingPolicy.categoryIds.contains(id)` via truth scan → `ArgumentError` (cascade reassign to `kFallbackCategoryId` only if future product decision opts to cascade — default is restrict) |
| `existsAll([])` is programmer error | Throws `ArgumentError` (not vacuous `true`). Documented dartdoc on `CategoryRepository.existsAll` |
| Box `categoryIds == []` on read is corruption | `Simple/GoalDifference/FargoRateRankingPolicyHiveModel.toDomain` throws `StateError` mentioning expected ids (`kFallbackCategoryId` or `kFargoCategoryIds`) — only migration backfill may write fallback, runtime never silently fixes |
| `FargoRateCalculator` pure domain | No Flutter/Hive imports; filters `isComplete` before sort; sorts `playedAt ASC + id ASC`; throws on `isDraw` / `sides.length !=2` / `playerIds.length !=1` / missing `winnerSideId`; Elo `K=32`, initial `500`; returns `FargoPlayerStats` for all `players` |
| `Lock` is best-effort single-isolate | Explicit comment; indexes are rebuildable caches repaired by `rebuildIfNeeded` after `openBox` |
| Seed idempotency preserves user ordering | `_migrateToV2`/`_migrateToV3` re-put keeps existing `sortOrder`; indexes rebuilt from truth after |
| `migrate` 3→3 is no-op | Guard `if (current >= target) return`; explicit repair via direct `_migrateToV2`/`_migrateToV3` or `rebuildIndexes` when needed, not via `migrate()` |

## Provider Graph

```dart
// lib/providers/leagues_provider.dart + lib/presentation/screens/league/select_scoring_system_screen.dart
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) => sl<CategoryRepository>());
final rankingPolicyRepositoryProvider = Provider<RankingPolicyRepository>((ref) => sl<RankingPolicyRepository>());
final categoriesProvider = FutureProvider<List<Category>>((ref) async => ref.read(categoryRepositoryProvider).getAllOrdered());
final categoriesRootsProvider = FutureProvider<List<Category>>((ref) async => ref.read(categoryRepositoryProvider).getRoots());
final rankingPolicyTypesForCategoryProvider = FutureProvider.family<List<RankingPolicyType>, String>((ref, categoryId) async {
  // Fargo whitelist: sports/pubgames → unconditional [fargoRate] via kSeedCategoryPolicyTypes.
  // Always available regardless of repo state (no getByCategory/getAll bootstrap vs corruption check).
  if (categoryId == kSportsCategoryId || categoryId == kPubGamesCategoryId) {
    return [RankingPolicyType.fargoRate];
  }
  if (categoryId != kFallbackCategoryId) return <RankingPolicyType>[]; // board/card/video → empty
  // Custom is the only repo-driven category; bootstrap vs corruption distinction lives here.
  final repo = ref.read(rankingPolicyRepositoryProvider);
  try {
    final policies = await repo.getByCategory(categoryId);
    if (policies.isEmpty) return RankingPolicyType.values; // custom empty-box fallback → show all for usability (bootstrap)
    // map Simple/GoalDifference/FargoRate → RankingPolicyType, then toList()
  } catch (_) { return RankingPolicyType.values; } // custom fallback on error
});

// Consumption:
// - SelectCategoryScreen  → ref.watch(categoriesRootsProvider) → roots sorted by sortOrder, Icon via mapCategoryIconToIconData
// - SelectScoringSystemScreen(categoryId) → ref.watch(categoriesProvider) for existence check,
//     then ref.watch(rankingPolicyTypesForCategoryProvider(effectiveCategoryId))
//     → sports/pubgames: unconditional [fargoRate] (no repo query, always available); custom: repo-driven via
//       getByCategory (truth scan + index cache, bootstrap fallback to all types when empty/error); board/card/video: [] → empty state
// - Create*LeagueScreen(categoryId) → Simple/GoalDifferenceRankingPolicy(categoryIds: [categoryId]) or FargoRateRankingPolicy(categoryIds: kFargoCategoryIds)
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
             │  → rankingPolicyTypesForCategoryProvider → unconditional [fargoRate] (no repo query)
             │     → always card "FargoRate — Pool" regardless of repo state (fresh install, has Custom leagues, etc.)
             │     └→ CreateFargoRateLeagueScreen(categoryId) // default cat_sports, but policy always kFargoCategoryIds
            │          └→ CreateLeagueService(categoryIds:kFargoCategoryIds) → validates existsAll + Fargo guard
            │             → HiveRankingPolicyRepository.put → same Fargo guard + index update under Lock
            └─ if categoryId == kFallbackCategoryId (Custom) → repo-driven via rankingPolicyTypesForCategoryProvider
                 ├→ CreateSimpleLeagueScreen(categoryId)       // categoryIds == [kFallbackCategoryId]
                 └→ CreateGoalDifferenceLeagueScreen(categoryId) // ditto
                      └→ CreateLeagueService(categoryIds:[categoryId]) → validates existsAll + custom-only guard
                         → HiveRankingPolicyRepository.put → same custom-only guard + index update under Lock

Deprecated fallback: SelectRankingPolicyScreen (@Deprecated('Use CategoryFiltered flow; kept as fallback until v3'))
  — kept one release to preserve deep links / old FAB paths; shows unfiltered RankingPolicyType.values with SnackBar "Categories unavailable — showing all" if categories box fails.
Invalid categoryId deep link: SelectScoringSystemScreen validates existence against categoriesProvider, shows SnackBar('Invalid category') and falls back to kFallbackCategoryId list rather than crashing. CreateLeagueService with unknown categoryIds throws ArgumentError (surfaced as SnackBar in create screens). Non-Fargo valid categories do NOT fallback — they correctly show the empty state above.
```

`HomeScreen` FAB now routes to `SelectCategoryScreen` instead of directly to `SelectRankingPolicyScreen`.

### League Detail — Fargo Presentation

`LeagueDetailState.isFargo` (`rankingPolicy is FargoRateRankingPolicy`) switches standings:

* Header: `P | W | L | Win% | Fargo` (vs `P | GF | GA | GD | Pts` for GD or `P | Pts` for Simple).
* Sorting: `rating DESC → wins DESC → id ASC` (never name; fallback rating `500` if missing).
* `fargoStats` from `FargoRateCalculator` is passed to `_StandingsTab` (`fargoStats: Map<String, FargoPlayerStats>`).
* `LogMatchScreen` (`_buildWinnerSection`) hides the Draw `DropdownMenuItem` when `isFargo`; domain calculator would throw on `isDraw` anyway, but UI prevents it.

## Exceptions and Corruption Handling

| Exception | When |
|-----------|------|
| `BuiltInCategoryException(categoryId)` | Attempt to `put` a built-in with mutated `name`/`slug`/`parentId`/`isBuiltIn`/`createdAt`, or to `delete` a built-in. |
| `UnknownCategoryException(ids)` | `HiveRankingPolicyRepository.put` after `existsAll` returns `false` (one or more ids missing). `CreateLeagueService` maps this to `ArgumentError` message `One or more categoryIds do not exist` for UI surface. |
| `ArgumentError` | `RankingPolicy` ctor empty/duplicate; `Category` empty name / self-parent; `Slug` length/pattern; `validateNoCycleAndDepth` depth>1 or cycle; `HiveCategoryRepository.put` duplicate slug / missing parent / depth; `delete` hasChildren or inUse; `existsAll([])`; **Custom-only violation**: `CreateLeagueService` / `HiveRankingPolicyRepository.put` when `Simple`/`GoalDifference` `categoryIds != [kFallbackCategoryId]` — message `Simple and Goal Difference leagues are only allowed in the Custom category (cat_custom_league_001). Got: ...`; **Fargo violation**: `CreateLeagueService` / `HiveRankingPolicyRepository.put` / `FargoRateRankingPolicy` ctor when `categoryIds` not exactly `{cat_sports, cat_pubgames}` (missing one, extra, duplicate, empty, or single) — message `FargoRate leagues must have categoryIds exactly [cat_sports, cat_pubgames]. Got: ...`; `FargoRateCalculator` when `isDraw` / `sides.length !=2` / `playerIds.length !=1` / missing winnerSideId |
| `StateError` | `Simple/GoalDifference/FargoRateRankingPolicyHiveModel.toDomain` when `categoryIds.isEmpty` — signals corruption of a pre-v2 row that migration should have backfilled (Fargo message names `kFargoCategoryIds`); only migration may write fallback, runtime never silently fixes. |

Direct `Box.put(RankingPolicyHiveModel(categoryIds: []))` bypassing the domain constructor is an anti-pattern — all writes must go via repositories; tests assert `StateError` on `get`/`getAll` and `ArgumentError` on repository `put` for such bypass.

## Operational Notes

- `dart run build_runner build --delete-conflicting-outputs` must regenerate `lib/hive_registrar.g.dart` and `*.g.dart` after changing Hive fields/typeIds (CI `test.yml` runs it after `pub get`). V3 added `typeId 12` for Fargo.
- `lib/data/models/hive/hive_box_names.dart` is the single source for box names and `kFallbackCategoryId` / `kMaxCategoryDepth` / `kSportsCategoryId` / `kPubGamesCategoryId` / `kFargoCategoryIds` / `kFargoInitialRating` constants.
- Indexes can be deleted and will be rebuilt on next launch (`rebuildIfNeeded` + migration rebuilds).

## Future Extension

If hierarchy deeper than one child level is needed, extend without changing the `parentId` API:

- Add a **closure table** box `category_closure (ancestor_id, descendant_id, depth)` maintained alongside `put`/`delete` inside the shared `Lock`.
- Query descendants/ancestors via closure instead of recursive `parentId` scans; keep `validateNoCycleAndDepth` with configurable `maxDepth`.
- Preserve the current adjacency list as truth (`parentId` on `categories`); closure is a derived cache like the existing `categoryParentIndex`.

## Related Files

- `lib/domain/entities/category.dart`
- `lib/domain/value_objects/slug.dart`, `category_icon.dart`
- `lib/domain/entities/ranking_policy.dart` (+ `simple_ranking_policy.dart`, `goal_difference_ranking_policy.dart`, `fargo_rate_ranking_policy.dart`, `ranking_policy_type.dart`)
- `lib/domain/value_objects/fargo_player_stats.dart`
- `lib/domain/services/fargo_rate_calculator.dart` (pure domain; re-exported at `lib/domain/calculators/fargo_rate_calculator.dart`)
- `lib/data/models/hive/category_hive_model.dart` (`typeId 11`), `ranking_policy_hive_model.dart` (`HiveField 6`)
- `lib/data/models/hive/ranking_policies/fargo_rate_ranking_policy_hive_model.dart` (`typeId 12`)
- `lib/data/repositories/hive/hive_category_repository.dart`, `hive_ranking_policy_repository.dart`
- `lib/data/services/hive/hive_database_migration_service.dart`, `category_index_rebuilder.dart`
- `lib/core/constants/hive_box_names.dart` (`kFallbackCategoryId`, `kMaxCategoryDepth`, `kSportsCategoryId`, `kPubGamesCategoryId`, `kFargoCategoryIds`, `kFargoInitialRating`)
- `lib/core/constants/category_policy_map.dart` (`kSeedCategoryPolicyTypes` — includes Fargo whitelist)
- `lib/core/config.dart` (`AppConfig.hiveDbVersion = 3`)
- `lib/application/services/create_league_service.dart` (custom-only + Fargo guards)
- `lib/core/injection_container.dart` (`_initHive` ordered init + shared `Lock`)
- `lib/providers/league_detail_provider.dart` (`isFargo`, `fargoStats`, rating→wins→id sorting)
- `lib/presentation/screens/league/select_category_screen.dart`, `select_scoring_system_screen.dart` (provider whitelist + empty state + Fargo branch)
- `lib/presentation/screens/league/create_fargo_rate_league_screen.dart`, `league_detail_screen.dart` (`_StandingsTab` Fargo columns), `match/log_match_screen.dart` (hide draw)
- `test/data/services/hive/hive_database_migration_service_test.dart` (0→2, 1→2, 2→2, 0→3, 2→3, 3→3, crash-retry), `test/integration/data/repositories/hive/hive_repositories_real_test.dart` (slug, depth, concurrency)
- `test/unit/core/constants/category_policy_map_test.dart`, `test/unit/application/services/create_league_service_test.dart`, `test/unit/application/services/create_league_service_fargo_test.dart`, `test/unit/domain/services/fargo_rate_calculator_test.dart`, `test/integration/data/repositories/hive/hive_ranking_policy_custom_category_real_test.dart`, `test/unit/providers/ranking_policy_types_for_category_provider_test.dart` (Fargo + custom restrictions)
