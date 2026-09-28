# Changelog

All notable changes to this project will be documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and [Semantic Versioning](https://semver.org/).

## [0.3.0] - 2026-09-26 — Legacy Rating Purge — BREAKING (hard delete, no shim)

**Version bump:** `0.2.0` → `0.3.0` (BREAKING). No `hiveDbVersion` bump — `AppConfig.hiveDbVersion` stays `3`.

### Breaking — Hard Delete (no deprecated shims retained)

- **Entire repo purged of legacy rating name (case-insensitive) (case-insensitive) in content and paths.** Zero matches in `lib/` and `git ls-files` (verified via `tool/verify_no_fargo.sh` + `dart analyze` clean + `660 tests pass`). The verifier `tool/verify_no_fargo.sh` excludes itself and `test/elo_purge_verification_test.dart` (intentionally contains the legacy string to assert absence elsewhere).

  **Deleted (hard, no `typedef`/shim retained):**

  | Removed | Was | Notes |
  |---------|-----|-------|
  | `RankingPolicyType` legacy enum value | enum value | `RankingPolicyType` now has only `simple`, `goalDifference`, `elo` (`displayName: 'Pool'`, `description: 'Elo Rankings'`) |
  | `lib/domain/entities/ranking_policies/legacy_rate_ranking_policy.dart` | domain entity | Canonical is now `elo_ranking_policy.dart` (`EloRankingPolicy`) |
  | `lib/domain/value_objects/legacy_player_stats.dart` | value object | Canonical is now `elo_player_stats.dart` (`EloPlayerStats`) |
  | `lib/domain/services/legacy_rate_calculator.dart` + `lib/domain/calculators/legacy_rate_calculator.dart` | domain service + shim | Canonical is now `lib/domain/services/elo_calculator.dart` (`EloCalculator`, `K=20`) |
  | `lib/domain/constants/legacy_constants.dart` | constants shim | Canonical is now `lib/domain/constants/elo_constants.dart` (`kEloMinRating=100`, `kEloMaxRating=500`, `kEloDefaultInitialRating=400`, `kEloLegacyInitialRating=500`, `kEloDefaultKFactor=20`) |
  | `lib/data/models/hive/ranking_policies/legacy_rate_ranking_policy_hive_model.dart` + `.g.dart` | Hive model (`typeId 12`) | Canonical is now `elo_ranking_policy_hive_model.dart` `@HiveType(typeId: 12)` `@HiveField(7, defaultValue:500)` literal |
  | Provider aliases `isLegacy` / `legacyStats` | `LeagueDetailState` getters | Canonical is now `isElo` (`rankingPolicy is EloRankingPolicy`) + `eloStats: Map<String, EloPlayerStats>` only |
  | Constants `kLegacyCategoryIds` / `kLegacyInitialRating` / `kLegacy*` | `hive_box_names.dart` / `elo_constants.dart` | Canonical is now `kEloCategoryIds = [cat_sports, cat_pubgames]` + `kElo*` |
  | Tests `*_legacy_*` (legacy rate, legacy UI contract, league detail provider legacy, ranking policy types for category provider legacy, etc.) | test files | Deleted; Elo equivalents remain (`elo_calculator_test` `K=20` `410/390`, `create_league_service_elo_test`, etc.) |

  **File rename (BREAKING path change):**

  - `lib/presentation/screens/league/create_legacy_rate_league_screen.dart` → `lib/presentation/screens/league/create_elo_league_screen.dart` (`CreateLegacyRateLeagueScreen` → `CreateEloLeagueScreen`, `AppBar` title `New Pool League` (was legacy title), `TextFormField` `labelText: 'Starting Elo Rating'` (was legacy rating) pre-filled `kEloDefaultInitialRating=400`, validator delegates to `EloRankingPolicy.validateInitialRating` 100..500, `hintText: '100 - 500'`)

- **Hive `typeId 12` retained for Elo, no schema bump.** `EloRankingPolicyHiveModel` `@HiveType(typeId: 12)` `@HiveField(7, defaultValue:500) int initialRating` (literal `500` required for codegen; hand-patched `elo_ranking_policy_hive_model.g.dart` `read: fields[7] == null ? 500 : fields[7] as int`; re-running `build_runner` overwrites — hand-patch back). `hiveDbVersion` stays `3` — additive field via literal default is backward-compatible (existing rows missing field 7 → `500` legacy, new leagues `400`), and `K` change (`20`) is in-memory recalc only (`EloCalculator._kFactor = 20`, `EloCalculator.calculate` filters `isComplete` before sort, sorts `playedAt ASC + id ASC`, throws on `isDraw`/`sides.length !=2`/`playerIds.length !=1`/`winnerSideId` missing). No `_migrateToV4`; `3→3` no-op retained.

- **Provider inversion to `isElo`/`eloStats` only.** `LeagueDetailState.isElo` + `eloStats` are canonical; legacy aliases **deleted** (no `@Deprecated` shim). Standings header is `Elo` (`_StandingsTab` `P | W | L | Win% | Elo`), sorting `rating DESC → wins DESC → id ASC` with fallback `eloStats[id]?.rating ?? policy.initialRating` (never hard-coded `500` for Elo; `500` only for non-Elo fallback). `LogMatchScreen._buildWinnerSection` hides Draw when `isElo` (`if (!isElo) Draw`); `EloCalculator` would throw on `isDraw` anyway.

- **Error message change (BREAKING string).** `EloRankingPolicy.validateCategoryIds` still throws `ArgumentError` with `Elo leagues must have categoryIds exactly $kEloCategoryIds. Got: ...` (`kEloCategoryIds = [cat_sports, cat_pubgames]`). Previously the same message referred to legacy leagues; consumers matching on the string must update to `Elo`. `validateInitialRating` message `initialRating must be within 100..500 inclusive. Got: ...` unchanged (via `kEloMinRating`/`kEloMaxRating`).

- **Category whitelist unchanged in behavior, now `elo` only.** `kSeedCategoryPolicyTypes` `cat_sports`/`cat_pubgames` → `[elo]` (was legacy), `cat_custom_league_001` → `[simple, goalDifference]`, others `[]`. `rankingPolicyTypesForCategoryProvider` unconditional `[elo]` for sports/pubgames (no repo query, always available), custom repo-driven with `RankingPolicyType.values` fallback, board/card/video `[]`.

### Changed

- `lib/presentation/screens/league/league_detail_screen.dart` — standings header text/column now `Elo` via `isElo`/`eloStats` only (no alias check).
- `lib/presentation/screens/league/select_scoring_system_screen.dart` + `select_ranking_policy_screen.dart` — now reference `elo` (`Pool`/`Elo Rankings`) only.
- `lib/providers/league_detail_provider.dart` — `isElo`/`eloStats` canonical, `K=20`, `initialRating` 100..500, `eloInitial = policy.initialRating` passed to `EloCalculator.calculate(required initialRating)`.
- `lib/core/constants/category_policy_map.dart` — seed map `elo` whitelist.
- `pubspec.yaml` — `version: 0.2.0` → `0.3.0`.

### Operational

- Run `tool/verify_no_fargo.sh` locally and in CI — must `PASS: No legacy mentions in content` + `PASS: No legacy in git tracked paths` (legacy string `fargo` case-insensitive). The verifier `tool/verify_no_fargo.sh` excludes itself and `test/elo_purge_verification_test.dart` (intentionally contains the legacy string to assert absence elsewhere).).
- After pulling, `dart run build_runner build --delete-conflicting-outputs` then **hand-patch** `elo_ranking_policy_hive_model.g.dart` to restore `fields[7] == null ? 500 : fields[7] as int` literal if overwritten. Verify `AppConfig().hiveDbVersion == 3` (`3→3` no-op) and `660 tests pass` / `dart analyze` clean.

## [0.2.0] - 2026-09-26 — Elo Rename + K 32→20

### Breaking

- **Elo K-factor 32 → 20 (global recalc).** `EloCalculator._kFactor` is now `20` (`lib/domain/constants/elo_constants.dart:kEloDefaultKFactor = 20`, was `32`). All existing Elo leagues **recalculate on next load** — ratings shift slower toward the mean. Example: `400` vs `400` win now `410/390` (was `416/384`). No Hive migration; ratings are recomputed in-memory from `SimpleMatch` history via `LeagueDetailState._fetchData()` → `EloCalculator.calculate(initialRating: policy.initialRating)`. To verify, run `test/unit/domain/services/elo_calculator_test.dart` (expects `410/390`, `510/490`). No `hiveDbVersion` bump — `AppConfig.hiveDbVersion` stays `3`.

### Changed

- Domain/constants/persistence renames legacy → Elo (Pool) with deprecated shims (now removed in 0.3.0 — see above).

## [0.1.1] - 2026-09-18

- See git history prior to changelog introduction.
