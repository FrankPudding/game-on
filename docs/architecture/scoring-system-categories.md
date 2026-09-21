# Scoring System Categories

## Purpose

Categories provide a taxonomy for scoring systems (ranking policies) and the leagues created from them. League creation is now category-first: pick a **Category** → filter scoring systems via `RankingPolicyRepository.getByCategory` → create the league with `RankingPolicy.categoryIds` via `CreateLeagueService`. This document describes the domain model, persistence schema, indexes, migration, provider graph, UI flow, and invariants.

Currently **`Simple` and `GoalDifference` scoring systems are restricted to the Custom category** (`cat_custom_league_001` = `kFallbackCategoryId`). Other built-in categories (`Board Games`, `Card Games`, `Sports`, `Video Games`) intentionally have no allowed scoring systems until future policy types are added. The restriction is enforced at three layers: seed map, provider, and write-path validation (see Scoring System Availability and Invariants).

Related: `docs/domain-language.md` → Category / RankingPolicy, `lib/presentation/mappers/category_icon_mapper.dart`, `lib/providers/leagues_provider.dart` → `categoriesProvider` / `rankingPolicyTypesForCategoryProvider`.

## Domain Model

| Concept | Location | Notes |
|---------|----------|-------|
| `Category` | `lib/domain/entities/category.dart` | `id`, `name`, `slug: Slug`, `icon: CategoryIcon`, `parentId?`, `sortOrder`, `isBuiltIn`, `createdAt`, `updatedAt`. `Slug` (`lib/domain/value_objects/slug.dart`) normalizes to `^[a-z0-9]+(-[a-z0-9]+)*$`, 3–32 chars. `CategoryIcon` (`lib/domain/value_objects/category_icon.dart`) is `enum {chess, playingCards, sportsSoccer, sportsEsports, categoryOther, other}` with `iconName` mapping + `fromName` fallback to `other`. |
| `RankingPolicy.categoryIds` | `lib/domain/entities/ranking_policy.dart` | `List<String>` required non-empty unique, `List.unmodifiable` with `ArgumentError` on violation. Many-to-many: a policy may live in multiple categories; a category contains many policies. Each policy must belong to ≥1 category. |
| `kFallbackCategoryId` | `lib/core/constants/hive_box_names.dart` | `const 'cat_custom_league_001'` — the Custom/Other seed. Single source for fallback references. Used by migration backfill, UI invalid-category fallback, and `CreateSimple/GoalDifferenceLeagueScreen` default param. |
| `kCategoryMaxDepth` / `kMaxCategoryDepth` | `lib/domain/entities/category.dart` / `hive_box_names.dart` | `1` (roots + one sub-category level). |

### Subtypes

`SimpleRankingPolicy` and `GoalDifferenceRankingPolicy` both extend `RankingPolicy<SimpleMatch>` and carry `categoryIds`. `RankingPolicyType` (`simple`, `goalDifference`) is a presentation enum; `rankingPolicyTypesForCategoryProvider` maps repo results to this enum for the UI. Both types are currently **custom-only** — `Simple`/`GoalDifferenceRankingPolicy.categoryIds` must be exactly `[kFallbackCategoryId]` (enforced by `CreateLeagueService` and `HiveRankingPolicyRepository.put`).

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
| `HiveBoxNames.categories` | `CategoryHiveModel` | Truth store for categories | `11` (`@HiveType(typeId: 11)`) — next free after 10. |
| `HiveBoxNames.categorySlugIndex` | `String` (`slug → id`) | Derived index for `getBySlug` fast path | — |
| `HiveBoxNames.categoryParentIndex` | `String` (`parentKey → comma-joined ids`) | Derived parent→children index (`'__roots__'` key for null) | — |
| `HiveBoxNames.rankingPolicies` | `RankingPolicyHiveModel` (`typeId 9` / `10`) | Truth store; base field `categoryIds` at `@HiveField(6, defaultValue: <String>[])` with `List.from` defensive copy | `9` = Simple, `10` = GoalDifference |
| `HiveBoxNames.categoryPolicyIndex` | `String` (`categoryId → comma-joined policyIds`) | Derived policy-by-category index | — |
| `HiveBoxNames.meta` | `int` (`db_version`) | Migration version | — |

Hive field layout `CategoryHiveModel`: `0:id`, `1:name`, `2:slug`, `3:iconName`, `4:sortOrder`, `5:isBuiltIn`, `6:parentId?`, `7:createdAt`, `8:updatedAt`.

Hive field layout `RankingPolicyHiveModel` base: `0:id`, `1:name`, `5:leagueId` (`defaultValue:''`), `6:categoryIds` (`defaultValue: <String>[]`, empty only to read pre-v2 boxes; runtime empty is treated as corruption — see Corruption Handling).

## Adjacency List Rationale

Hierarchy uses **adjacency list** (`parentId` nullable pointing to parent `id`). With `maxDepth = 1` there is no recursion beyond roots→children, so adjacent queries (`getChildren(parentId)`, `getRoots()`) are single-scan `where(parentId == x)` plus sort by `sortOrder`.

Alternatives considered and deferred:

- **Nested sets / materialized path / closure table** — add write complexity and require bookkeeping for re-parenting and ordering, unnecessary at depth 1. The plan patch explicitly notes future hierarchy extension would adopt a **closure table** (`ancestor_id`, `descendant_id`, `depth`) to support deeper trees efficiently without changing the `parentId` API.

`Category.validateNoCycleAndDepth` performs DFS up `parentId` with `visited` set for cycle detection and depth counting; `HiveCategoryRepository.put` re-validates the entire sibling set including the candidate inside the shared `Lock` before persisting.

## Icons

- Domain: `CategoryIcon` enum (value object) — no Flutter dependency.
- Data: `CategoryHiveModel.iconName: String` — Hive stores `CategoryIcon.iconName` string; `CategoryIconExtension.fromName` maps back with fallback `other` for unknown strings (forward compatibility when enum grows).
- Presentation: `lib/presentation/mappers/category_icon_mapper.dart:mapCategoryIconToIconData` maps to `IconData` (`chess→grid_on`, `playingCards→style`, `sportsSoccer→sports_soccer`, `sportsEsports→sports_esports`, `categoryOther→category_outlined`, `other→category`).

## Deterministic Seed

`HiveDatabaseMigrationService._migrateToV2` upserts five built-ins idempotently (preserves existing `sortOrder` if row already exists):

| id | name | slug | iconName | sortOrder |
|----|------|------|----------|-----------|
| `cat_boardgames` | Board Games | `board-games` | `chess` | 0 |
| `cat_cardgames` | Card Games | `card-games` | `playing_cards` | 1000 |
| `cat_sports` | Sports | `sports` | `sports_soccer` | 2000 |
| `cat_videogames` | Video Games | `video-games` | `sports_esports` | 3000 |
| `cat_custom_league_001` | Custom | `custom` | `category_other` | 4000 |

`isBuiltIn: true`, `parentId: null`, `createdAt/updatedAt: now` on fresh insert; on upgrade only `name`/`slug`/`iconName`/`isBuiltIn` drift is corrected, `sortOrder` is left intact to respect reordering.

### Scoring System Availability (Custom-Only)

Seed-time mapping `lib/core/constants/category_policy_map.dart:kSeedCategoryPolicyTypes` is the **only** place that declares which scoring systems a category may offer. It is seed-only (not runtime truth); runtime filtering is repo-driven via `RankingPolicyRepository.getByCategory`.

Current invariant (requirement: "simple scoring and goal difference leagues should only be in the custom category"):

```dart
// lib/core/constants/category_policy_map.dart
const kSeedCategoryPolicyTypes = {
  'cat_boardgames': <RankingPolicyType>[], // intentionally empty
  'cat_cardgames':  <RankingPolicyType>[],
  'cat_sports':     <RankingPolicyType>[],
  'cat_videogames': <RankingPolicyType>[],
  'cat_custom_league_001': [RankingPolicyType.simple, RankingPolicyType.goalDifference],
};
```

- **Only `cat_custom_league_001` maps to `[simple, goalDifference]`.** Other built-in categories map to `[]` until future scoring systems are added.
- `rankingPolicyTypesForCategoryProvider(categoryId)` enforces this at the presentation boundary: if `categoryId != kFallbackCategoryId` it immediately returns `[]`, causing `SelectScoringSystemScreen` to render the empty state `No scoring systems available for this category`. For the custom category it queries `RankingPolicyRepository.getByCategory`, falling back to `RankingPolicyType.values` when the repo is empty or throws (so the custom category remains usable even with an empty box).
- Write-path defense in depth: both `lib/application/services/create_league_service.dart:CreateLeagueService.execute` and `lib/data/repositories/hive/hive_ranking_policy_repository.dart:HiveRankingPolicyRepository.put` reject any `SimpleRankingPolicy` / `GoalDifferenceRankingPolicy` whose `categoryIds` is not exactly `[kFallbackCategoryId]` (`ArgumentError`). `CategoryRepository.existsAll` is still checked first for referential integrity; the custom-only guard runs immediately after.

Tests: `test/unit/core/constants/category_policy_map_test.dart` (seed map empty vs custom), `test/unit/application/services/create_league_service_test.dart` + `test/integration/data/repositories/hive/hive_ranking_policy_custom_category_real_test.dart` + `test/unit/providers/ranking_policy_types_for_category_provider_test.dart` (61 new tests covering map, provider empty vs populated, service/repo rejects non-custom/bare/multiple categories, and the Custom empty-box fallback).

## Indexes — Rebuildable Caches, Not Truth

All three derived boxes (`categorySlugIndex`, `categoryParentIndex`, `categoryPolicyIndex`) are **strictly rebuildable caches**. Validation and queries must scan truth boxes; indexes are only queried for speed with fallback scan if missing.

- `categorySlugIndex`: `slug → id`. `HiveCategoryRepository.getBySlug` first probes the index, then scans `categories` on miss. `put` double-checks truth scan before `slugIndex.put` (double-checked locking inside `Lock`).
- `categoryParentIndex`: `parentId('__roots__' for null) → comma-joined child ids`. Kept by `_rebuildParentIndexForParent(parentId)` after each `put`/`delete`.
- `categoryPolicyIndex`: `categoryId → comma-joined policy ids`. Maintained by `HiveRankingPolicyRepository.put`/`delete` inside the same `Lock` and rebuilt by `HiveDatabaseMigrationService` and `CategoryIndexRebuilder`.

Shared `Lock` (single `synchronized.Lock` singleton injected via `GetIt`) is **best-effort single-isolate** only — it does not survive isolate kill or provide cross-isolate crash atomicity. The comment in repos reads `// Lock does not survive isolate kill — indexes are rebuildable caches`. On any exception after first box `put`, the catch block deletes the partial key, optionally flushes, and `CategoryIndexRebuilder.rebuildIfNeeded` (called after `openBox` in `_initHive`) repairs drift by comparing `slugIndex.length` vs `categoriesBox.length` and root counts, then clearing and re-populating indexes from truth.

## Migration — Version 2

`AppConfig.hiveDbVersion` defaults to `2` (fails fast if fresh installs would skip seeding). The test `expect(AppConfig().hiveDbVersion, 2)` enforces this.

**Ordered init in `lib/core/injection_container.dart:_initHive`:**

1. `await Hive.initFlutter()`
2. `HiveRegistrar.registerAdapters()` (generated `lib/hive_registrar.g.dart` — single source, includes `typeId 11`). Guarded with idempotence wrapper (`isAdapterRegistered` checks per typeId; swallow "already" errors).
3. `await HiveDatabaseMigrationService().migrate(sl<AppConfig>().hiveDbVersion)`
4. `await Hive.openBox(...)` for all boxes (or `Hive.box` if already opened by migration) — `categories`, `categorySlugIndex`, `categoryParentIndex`, `categoryPolicyIndex`, `rankingPolicies`, plus leagues/users/players/matches.
5. `await CategoryIndexRebuilder().rebuildIfNeeded()` — drift check + rebuild of slug/parent/policy indexes from truth; also rebuilds `categoryPolicyIndex` when both boxes are open.

**`migrate(targetVersion)` semantics:**

- If `currentVersion >= targetVersion` → **no-op early return** (idempotent guard). This preserves user `sortOrder` and avoids churn on every launch. Logged via `debugPrint`.
- Underlying `_migrateToV2` is individually idempotent and retry-safe: categories are upserted idempotently, ranking-policy backfill only rewrites rows where `categoryIds.isEmpty` to `[kFallbackCategoryId]`, and all indexes are cleared then rebuilt from truth. Crash-retry (throw before `meta.put(version)`) leaves version at old value; next launch re-executes idempotently.

**`_migrateToV2` steps (summary):**

1. Ensure adapters (fallback registration for `test` harness where `Hive.init` runs without DI).
2. Upsert the five seeds (preserve `sortOrder` if row exists, otherwise initial spaced values).
3. Clear `slugIndex` + `parentIndex`, rebuild from `categoriesBox` truth.
4. Backfill: for each `rankingPolicies` row where `categoryIds.isEmpty`, replace with `const [kFallbackCategoryId]` by reconstructing the concrete `Simple`/`GoalDifference` Hive model (preserving points).
5. Clear and rebuild `categoryPolicyIndex` from `rankingBox.categoryIds`.
6. `meta.db_version` is bumped to `2` by the loop in `migrate()` after `_migrateToV2` returns; tests cover `0→2` (fresh), `1→2` (upgrade), `2→2` (no-op), crash-retry (kill mid-migration then re-migrate succeeds, no duplicates, `sortOrder` preserved).

## Invariants

| Invariant | Enforcement |
|-----------|-------------|
| `RankingPolicy.categoryIds` non-empty + unique | Domain constructor `ArgumentError`; `RankingPolicyHiveModel.categoryIds` defensive `List.from`; `CreateLeagueService.execute` + `HiveRankingPolicyRepository.put` + `CategoryRepository.existsAll([]) → ArgumentError` defense in depth |
| `Simple` / `GoalDifference` leagues only in Custom category | `kSeedCategoryPolicyTypes` maps only `cat_custom_league_001 → [simple, goalDifference]`, others → `[]`; `rankingPolicyTypesForCategoryProvider` returns `[]` for any non-custom `categoryId`; `CreateLeagueService.execute` + `HiveRankingPolicyRepository.put` throw `ArgumentError` unless `categoryIds == [kFallbackCategoryId]` (exact single-element check). Tests: `category_policy_map_test`, `create_league_service_test`, `hive_ranking_policy_custom_category_real_test`, `ranking_policy_types_for_category_provider_test` (61 tests) |
| `Category.name` non-empty trimmed | `Category` constructor / `copyWith` `ArgumentError`; repository preserves under `Lock` |
| `Slug` 3–32 normalized lowercase alphanum + `-` | `Slug` value object throws `ArgumentError`; uniqueness scanned inside `Lock` before `put` |
| `parentId` null or existing id, never self-ref, depth ≤ 1, no cycles | `put` validates parent exists via truth scan, then `validateNoCycleAndDepth` (DFS + `ArgumentError`) inside `Lock` |
| `sortOrder` per-parent via midpoint + normalize on collision | Siblings share `parentId`; `prev < new < next` midpoint `(prev+next)~/2`; gap `<2` → `_normalizeSortOrders(parentId)` reassigns `0,1000,2000,...` under same `Lock` |
| `isBuiltIn` immutable, only `sortOrder` + `icon` mutable on built-ins; built-in delete forbidden | `put` compares incoming to existing built-in fields and throws `BuiltInCategoryException`; same for `delete` path |
| Delete is `RESTRICT` | `HiveCategoryRepository.delete` checks inside `Lock`: (1) `isBuiltIn` → `BuiltInCategoryException`, (2) any child `parentId == id` → `ArgumentError`, (3) any `rankingPolicy.categoryIds.contains(id)` via truth scan → `ArgumentError` (cascade reassign to `kFallbackCategoryId` only if future product decision opts to cascade — default is restrict) |
| `existsAll([])` is programmer error | Throws `ArgumentError` (not vacuous `true`). Documented dartdoc on `CategoryRepository.existsAll` |
| Box `categoryIds == []` on read is corruption | `Simple/GoalDifferenceRankingPolicyHiveModel.toDomain` throws `StateError` mentioning `kFallbackCategoryId` — only migration’s backfill may write fallback, runtime never silently fixes |
| `Lock` is best-effort single-isolate | Explicit comment; indexes are rebuildable caches repaired by `rebuildIfNeeded` after `openBox` |
| Seed idempotency preserves user ordering | `_migrateToV2` re-put keeps existing `sortOrder`; indexes rebuilt from truth after |
| `migrate` 2→2 is no-op | Guard `if (current >= target) return`; explicit repair via direct `_migrateToV2` or `rebuildIndexes` when needed, not via `migrate()` |

## Provider Graph

```dart
// lib/providers/leagues_provider.dart + lib/presentation/screens/league/select_scoring_system_screen.dart
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) => sl<CategoryRepository>());
final rankingPolicyRepositoryProvider = Provider<RankingPolicyRepository>((ref) => sl<RankingPolicyRepository>());
final categoriesProvider = FutureProvider<List<Category>>((ref) async => ref.read(categoryRepositoryProvider).getAllOrdered());
final categoriesRootsProvider = FutureProvider<List<Category>>((ref) async => ref.read(categoryRepositoryProvider).getRoots());
final rankingPolicyTypesForCategoryProvider = FutureProvider.family<List<RankingPolicyType>, String>((ref, categoryId) async {
  if (categoryId != kFallbackCategoryId) return <RankingPolicyType>[]; // custom-only: non-custom → empty
  final repo = ref.read(rankingPolicyRepositoryProvider);
  try {
    final policies = await repo.getByCategory(categoryId);
    if (policies.isEmpty) return RankingPolicyType.values; // custom empty-box fallback → show all for usability
    // map Simple/GoalDifference → RankingPolicyType, then toList()
  } catch (_) { return RankingPolicyType.values; } // custom-only fallback on error
});

// Consumption:
// - SelectCategoryScreen  → ref.watch(categoriesRootsProvider) → roots sorted by sortOrder, Icon via mapCategoryIconToIconData
// - SelectScoringSystemScreen(categoryId) → ref.watch(categoriesProvider) for existence check,
//     then ref.watch(rankingPolicyTypesForCategoryProvider(effectiveCategoryId)) → custom: repo-driven via
//     getByCategory (truth scan + index cache, fallback to all types when empty/error); non-custom: [] → empty state
// - CreateSimpleLeagueScreen(categoryId) / CreateGoalDifferenceLeagueScreen(categoryId) → Simple/GoalDifferenceRankingPolicy(categoryIds: [categoryId])
//     via CreateLeagueService(categoryIds) → validates existsAll + custom-only guard before put
```

Providers are read-only `FutureProvider`s over repository truth; mutations flow through `CreateLeagueService` and `HiveCategoryRepository`/`HiveRankingPolicyRepository` under the shared `Lock`. See `docs/architecture/provider-invalidation.md` for the broader invalidation rules (categories currently seed-only, no provider-level invalidation required).

## UI Flow

```
HomeScreen (FAB + empty-state "Create First League")
  └→ SelectCategoryScreen (roots sorted, icon per CategoryIcon → card)
       └→ SelectScoringSystemScreen(categoryId)
            ├─ if categoryId != kFallbackCategoryId → rankingPolicyTypesForCategoryProvider returns [] → empty state
            │  "No scoring systems available for this category" (current behaviour for Board/Card/Sports/Video)
            └─ if categoryId == kFallbackCategoryId (Custom) → repo-driven via rankingPolicyTypesForCategoryProvider
                 ├→ CreateSimpleLeagueScreen(categoryId)       // categoryIds == [kFallbackCategoryId]
                 └→ CreateGoalDifferenceLeagueScreen(categoryId) // ditto
                      └→ CreateLeagueService(categoryIds:[categoryId]) → validates existsAll + custom-only guard
                         → HiveRankingPolicyRepository.put → same custom-only guard + index update under Lock

Deprecated fallback: SelectRankingPolicyScreen (@Deprecated('Use CategoryFiltered flow; kept as fallback until v3'))
  — kept one release to preserve deep links / old FAB paths; shows unfiltered RankingPolicyType.values with SnackBar "Categories unavailable — showing all" if categories box fails.
Invalid categoryId deep link: SelectScoringSystemScreen validates existence against categoriesProvider, shows SnackBar('Invalid category') and falls back to kFallbackCategoryId list rather than crashing. CreateLeagueService with unknown categoryIds throws ArgumentError (surfaced as SnackBar in create screens). Non-custom valid categories do NOT fallback — they correctly show the empty state above.
```

`HomeScreen` FAB now routes to `SelectCategoryScreen` instead of directly to `SelectRankingPolicyScreen`.

## Exceptions and Corruption Handling

| Exception | When |
|-----------|------|
| `BuiltInCategoryException(categoryId)` | Attempt to `put` a built-in with mutated `name`/`slug`/`parentId`/`isBuiltIn`/`createdAt`, or to `delete` a built-in. |
| `UnknownCategoryException(ids)` | `HiveRankingPolicyRepository.put` after `existsAll` returns `false` (one or more ids missing). `CreateLeagueService` maps this to `ArgumentError` message `One or more categoryIds do not exist` for UI surface. |
| `ArgumentError` | `RankingPolicy` ctor empty/duplicate; `Category` empty name / self-parent; `Slug` length/pattern; `validateNoCycleAndDepth` depth>1 or cycle; `HiveCategoryRepository.put` duplicate slug / missing parent / depth; `delete` hasChildren or inUse; `existsAll([])`; **Custom-only violation**: `CreateLeagueService` / `HiveRankingPolicyRepository.put` when `Simple`/`GoalDifference` `categoryIds != [kFallbackCategoryId]` (empty, multiple, or non-custom id) — message `Simple and Goal Difference leagues are only allowed in the Custom category (cat_custom_league_001). Got: ...` |
| `StateError` | `SimpleRankingPolicyHiveModel.toDomain` / `GoalDifferenceRankingPolicyHiveModel.toDomain` when `categoryIds.isEmpty` — signals corruption of a pre-v2 row that migration should have backfilled; message names `kFallbackCategoryId` and directs to re-run `HiveDatabaseMigrationService._migrateToV2`. |

Direct `Box.put(RankingPolicyHiveModel(categoryIds: []))` bypassing the domain constructor is an anti-pattern — all writes must go via repositories; tests assert `StateError` on `get`/`getAll` and `ArgumentError` on repository `put` for such bypass.

## Operational Notes

- `dart run build_runner build --delete-conflicting-outputs` must regenerate `lib/hive_registrar.g.dart` and `*.g.dart` after changing Hive fields/typeIds (CI `test.yml` runs it after `pub get`).
- `lib/data/models/hive/hive_box_names.dart` is the single source for box names and `kFallbackCategoryId` / `kMaxCategoryDepth` constants.
- Indexes can be deleted and will be rebuilt on next launch (`rebuildIfNeeded`).

## Future Extension

If hierarchy deeper than one child level is needed, extend without changing the `parentId` API:

- Add a **closure table** box `category_closure (ancestor_id, descendant_id, depth)` maintained alongside `put`/`delete` inside the shared `Lock`.
- Query descendants/ancestors via closure instead of recursive `parentId` scans; keep `validateNoCycleAndDepth` with configurable `maxDepth`.
- Preserve the current adjacency list as truth (`parentId` on `categories`); closure is a derived cache like the existing `categoryParentIndex`.

## Related Files

- `lib/domain/entities/category.dart`
- `lib/domain/value_objects/slug.dart`, `category_icon.dart`
- `lib/domain/entities/ranking_policy.dart` (+ `simple_ranking_policy.dart`, `goal_difference_ranking_policy.dart`)
- `lib/data/models/hive/category_hive_model.dart` (`typeId 11`), `ranking_policy_hive_model.dart` (`HiveField 6`)
- `lib/data/repositories/hive/hive_category_repository.dart`, `hive_ranking_policy_repository.dart`
- `lib/data/services/hive/hive_database_migration_service.dart`, `category_index_rebuilder.dart`
- `lib/core/constants/hive_box_names.dart` (`kFallbackCategoryId`, `kMaxCategoryDepth`)
- `lib/core/constants/category_policy_map.dart` (`kSeedCategoryPolicyTypes` — custom-only seed map)
- `lib/application/services/create_league_service.dart` (custom-only guard)
- `lib/core/injection_container.dart` (`_initHive` ordered init + shared `Lock`)
- `lib/presentation/screens/league/select_category_screen.dart`, `select_scoring_system_screen.dart` (provider custom-only branch + empty state)
- `test/data/services/hive/hive_database_migration_service_test.dart` (0→2, 1→2, 2→2, crash-retry), `test/integration/data/repositories/hive/hive_repositories_real_test.dart` (slug, depth, concurrency)
- `test/unit/core/constants/category_policy_map_test.dart`, `test/unit/application/services/create_league_service_test.dart`, `test/integration/data/repositories/hive/hive_ranking_policy_custom_category_real_test.dart`, `test/unit/providers/ranking_policy_types_for_category_provider_test.dart` (custom-only restriction, 61 tests)
