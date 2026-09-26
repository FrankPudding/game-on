# Changelog

All notable changes to this project will be documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and [Semantic Versioning](https://semver.org/).

## [Unreleased] — Elo Rename + K 32→20 — BREAKING RECALC

### Breaking

- **Elo K-factor 32 → 20 (global recalc).** `EloCalculator._kFactor` is now `20` (`lib/domain/constants/elo_constants.dart:kEloDefaultKFactor = 20`, was `32`). All existing Elo (formerly FargoRate) leagues **recalculate on next load** — ratings shift slower toward the mean. Example: `400` vs `400` win now `410/390` (was `416/384`). No Hive migration; ratings are recomputed in-memory from `SimpleMatch` history via `LeagueDetailState._fetchData()` → `EloCalculator.calculate(initialRating: policy.initialRating)`. To verify, run `test/unit/domain/services/elo_calculator_test.dart` (expects `410/390`, `510/490`). No `hiveDbVersion` bump — `AppConfig.hiveDbVersion` stays `3` (see below).
- **Hive `typeId` 12 retained but renamed to Elo.** No schema bump: `typeId 12` was `FargoRateRankingPolicyHiveModel`, now `EloRankingPolicyHiveModel` (`lib/data/models/hive/ranking_policies/elo_ranking_policy_hive_model.dart` `@HiveType(typeId: 12)`, `@HiveField(7, defaultValue:500) int initialRating`). `FargoRateRankingPolicyHiveModel` is now a deprecated `typedef` → `EloRankingPolicyHiveModel`. `hiveDbVersion` stays `3`; `defaultValue:500` literal handles legacy rows (missing `field 7` → `500` legacy, new leagues default `400`). Generated `elo_ranking_policy_hive_model.g.dart` must keep hand-patched literal `fields[7] == null ? 500 : fields[7] as int`; re-running `build_runner` overwrites — hand-patch back.
- **Provider / UI header breaking for Elo.** Standings header is now `Elo` (was `Fargo`): `_StandingsTab` renders `P | W | L | Win% | Elo` when `isElo` (was `P | W | L | Win% | Fargo`). `LeagueDetailState.isElo` is canonical; `isFargo` remains as `@deprecated` alias `=> isElo`. Same for `eloStats` (was `fargoStats`), `RankingPolicyType.elo` (was `fargoRate`), `kEloCategoryIds` (was `kFargoCategoryIds`), `elo_constants.dart` (was `fargo_constants.dart`). Code using deprecated names still compiles but should migrate.

### Changed — Rename FargoRate → Elo (Pool Elo)

- **Domain:** `FargoRateRankingPolicy` → `EloRankingPolicy` (`lib/domain/entities/ranking_policies/elo_ranking_policy.dart` canonical, `fargo_rate_ranking_policy.dart` is shim `export 'elo_ranking_policy.dart'`). `FargoPlayerStats` → `EloPlayerStats` (`lib/domain/value_objects/elo_player_stats.dart` canonical, `fargo_player_stats.dart` shim). `FargoRateCalculator` → `EloCalculator` (`lib/domain/services/elo_calculator.dart` canonical, `fargo_rate_calculator.dart` shim `typedef FargoRateCalculator = EloCalculator`). `RankingPolicyType.fargoRate` (`displayName: 'FargoRate'`) → `RankingPolicyType.elo` (`displayName: 'Pool'`, `description: 'Elo Rankings'`; Pool display was already `Pool` — now canonical `elo`).
- **Constants:** `lib/domain/constants/elo_constants.dart` canonical (`kEloMinRating=100`, `kEloMaxRating=500`, `kEloDefaultInitialRating=400`, `kEloLegacyInitialRating=500`, `kEloDefaultKFactor=20`). `lib/domain/constants/fargo_constants.dart` now `export 'elo_constants.dart'` shim with `@Deprecated` `kFargo*` aliases. `lib/core/constants/hive_box_names.dart` canonical `kEloCategoryIds`; `kFargoCategoryIds` deprecated alias `= kEloCategoryIds`; `kFargoInitialRating=500` deprecated literal retained for `@HiveField(7, defaultValue:500)`.
- **Persistence:** `EloRankingPolicyHiveModel` `@HiveType(typeId: 12)` canonical; `FargoRateRankingPolicyHiveModel` deprecated `typedef`. Field `7` literal `defaultValue:500` unchanged — operational note: hand-patch `.g.dart` after `build_runner`.
- **Category map:** `kSeedCategoryPolicyTypes` now `{cat_sports: [elo], cat_pubgames: [elo]}` (was `[fargoRate]`); `lib/core/constants/category_policy_map.dart` canonical.
- **Providers:** `rankingPolicyTypesForCategoryProvider` whitelist now `→ [elo]` (was `[fargoRate]`). `LeagueDetailState` now `isElo` + `eloStats` canonical; `isFargo`/`fargoStats` deprecated aliases (`Map<String, FargoPlayerStats> get fargoStats => eloStats`, `bool get isFargo => isElo`). Sorting remains `rating DESC → wins DESC → id ASC` with fallback `eloStats[id]?.rating ?? policy.initialRating` (never hard-coded `500` for Elo leagues).
- **Presentation:** `league_detail_screen.dart` `_StandingsTab` header `Elo` (was `Fargo`), `isElo`/`eloStats` primary (`isFargo`/`fargoStats` alias). `log_match_screen.dart` `_buildWinnerSection` hides Draw when `isElo` (alias check `isFargo || isElo`). `create_fargo_rate_league_screen.dart` still named legacy but now constructs `EloRankingPolicy(categoryIds: kEloCategoryIds, ...)` and `TextFormField` for `Starting Elo Rating` (was Fargo); validator delegates to `EloRankingPolicy.validateInitialRating`.
- **Docs:** `docs/architecture/scoring-system-categories.md` section `Elo Domain — Calculator` (was `FargoRate Domain`), `typeId 12 = Elo`, `K=20`, `hiveDbVersion stays 3` rationale, seed `elo` whitelist, provider `elo` whitelist, operational `defaultValue:500` hand-patch note, V3 no-op retained. `docs/domain-language.md` `Elo` entry (was `FargoRate`) with `RankingPolicyType.elo`, `K=20`, Hive literal note. `docs/architecture/provider-invalidation.md` `Elo whitelist`, `isElo`/`K=20`. `docs/architecture/league-presentation.md` `isElo`, `P W L Win% Elo`, header `Elo`, `eloStats`/`policy.initialRating` fallback, `LogMatchScreen hide draw when isElo`.

### Deprecated Aliases — Removal Timeline

All `Fargo*` names remain as `@Deprecated` shims/typedefs for one release to ease migration. They will be removed in the next **minor** after this release (target `0.2.0`):

| Deprecated | Use instead | File |
|------------|-------------|------|
| `FargoRateRankingPolicy` | `EloRankingPolicy` | `elo_ranking_policy.dart` |
| `FargoRateRankingPolicyHiveModel` / `FargoRateRankingPolicyHiveModelAdapter` | `EloRankingPolicyHiveModel` / `EloRankingPolicyHiveModelAdapter` | `elo_ranking_policy_hive_model.dart` |
| `FargoRateCalculator` | `EloCalculator` | `elo_calculator.dart` |
| `FargoPlayerStats` | `EloPlayerStats` | `elo_player_stats.dart` |
| `kFargoCategoryIds` | `kEloCategoryIds` | `hive_box_names.dart` |
| `kFargoInitialRating` / `kFargoMinRating` / `kFargoMaxRating` / `kFargoDefaultInitialRating` / `kFargoLegacyInitialRating` / `kFargoDefaultKFactor` | `kElo*` equivalents | `elo_constants.dart` |
| `RankingPolicyType.fargoRate` | `RankingPolicyType.elo` | `ranking_policy_type.dart` |
| `LeagueDetailState.isFargo` / `.fargoStats` | `isElo` / `eloStats` | `league_detail_provider.dart` |
| `fargo_constants.dart` / `fargo_rate_*` files | `elo_*` counterparts | `lib/domain/constants/`, `lib/domain/services/`, etc. |

Migration: search for `Fargo` (case-insensitive) and replace per table above. `dart analyze` will surface `@Deprecated` warnings. Tests now expect `K=20` and `elo` — update any hard-coded `32`/`416` expectations.

### Operational

- `dart run build_runner build --delete-conflicting-outputs` after pulling — then **hand-patch** `elo_ranking_policy_hive_model.g.dart` to restore `fields[7] == null ? 500 : fields[7] as int` literal if overwritten (codegen cannot emit const refs). Verify `hiveDbVersion == 3` still holds (`test/data/services/hive/hive_database_migration_service_test.dart` `3→3` no-op).
- No data migration for `K` change — recalc is automatic. If you need to compare old vs new ratings, run `elo_calculator_test.dart` with `K=20` vs historical `32` helper.

## [0.1.1] - 2026-09-18

- See git history prior to changelog introduction.

