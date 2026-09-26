# Versioning

## Overview

This document describes the versioning strategy for the Game On Flutter application, covering both the human-readable version name (from `pubspec.yaml`) and the Android version code (derived from CI/CD).

## Version Naming Scheme

### Version Name (`versionName`)

**Source**: `pubspec.yaml` → `version` field

```yaml
version: 0.3.0
```

Format: `MAJOR.MINOR.PATCH` following [Semantic Versioning](https://semver.org/).

| Component | When to Increment |
|-----------|-------------------|
| MAJOR     | Breaking changes, incompatible API changes |
| MINOR     | New features, backwards compatible |
| PATCH     | Bug fixes, backwards compatible |

**Example**: `0.3.0` → `0.3.1` (bug fix), `0.4.0` (new feature), `1.0.0` (stable release)

> **Current:** `0.3.0` is a **BREAKING** release — Fargo purge (hard delete, no shim), file rename `create_elo_rate_league_screen.dart` → `create_elo_league_screen.dart`, `RankingPolicyType.elo` removed, provider `isElo`/`eloStats` canonical only, Hive `typeId 12` retained for Elo (`@HiveField(7, defaultValue:500)` literal), `K=20`, `initialRating` 100..500, `hiveDbVersion` stays `3` (no migration bump). See `CHANGELOG.md` → `0.3.0`.

### Version Code (`versionCode`)

**Source**: GitHub Actions `github.run_number`

- Auto-increments on every workflow run
- Unique per build (required by Play Store)
- Integer only, must increase monotonically

```yaml
# In workflow (auto-populated)
versionCode: ${{ github.run_number }}
```

**Example**: Run #42 → `versionCode: 42`

## Releasing a New Version

### 1. Update Version Name

Edit `pubspec.yaml`:

```yaml
version: 0.3.0
```

Commit and push:

```bash
git add pubspec.yaml
git commit -m "chore: bump version to 0.3.0"
git push
```

### 2. Create Release Tag

Tag format: `v<MAJOR>.<MINOR>.<PATCH>`

```bash
git tag v0.3.0
git push origin v0.3.0
```

### 3. Workflow Trigger

The release workflow triggers on tag push matching `v*`:

```yaml
# .github/workflows/release.yml
on:
  push:
    tags:
      - 'v*'
```

This workflow:
- Builds Android App Bundle (`.aab`)
- Builds iOS Archive (`.xcarchive`)
- Publishes to Play Store / TestFlight (when configured)
- Creates GitHub Release with artifacts

## VersionCode Collision Warning

### The Problem

If you have **multiple workflows** that build Android artifacts (e.g., `release.yml`, `pr-check.yml`, `nightly.yml`), they **share the same `github.run_number` counter**.

| Workflow | Run # | versionCode |
|----------|-------|-------------|
| release  | 10    | 10          |
| pr-check | 11    | 11 ← **collision!** |
| nightly  | 12    | 12 ← **collision!** |

Play Store rejects uploads with duplicate `versionCode`.

### Solutions

**Option 1: Separate counters (recommended)**

Use a workflow-specific offset:

```yaml
# release.yml
versionCode: ${{ github.run_number }}

# pr-check.yml
versionCode: ${{ github.run_number + 100000 }}

# nightly.yml
versionCode: ${{ github.run_number + 200000 }}
```

**Option 2: Single release workflow**

Only build Android artifacts in one workflow. Other workflows skip Android build or build debug-only APKs with `versionCode: 0` (not uploadable).

**Option 3: Manual versionCode**

See [Manual Build](#manual-build-with-custom-versioncode) below.

### ⚠️ Critical Invariant

> **Never reuse a versionCode.** Once uploaded to Play Console (even internal testing), that integer is permanently consumed.

## Manual Build with Custom versionCode

### Local Build (Development)

```bash
# Debug APK (versionCode from pubspec.yaml not used)
flutter build apk --debug

# Release App Bundle with explicit versionCode
flutter build appbundle --release \
  --build-number=42
```

The `--build-number` flag sets `versionCode` directly.

### CI Override

For one-off builds with specific versionCode:

```yaml
# .github/workflows/manual-release.yml
on:
  workflow_dispatch:
    inputs:
      version_code:
        description: 'Custom versionCode (integer)'
        required: true
        type: string

jobs:
  build:
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter build appbundle --release --build-number=${{ inputs.version_code }}
```

Trigger via GitHub UI: **Actions → Manual Release → Run workflow**

## Troubleshooting "App Not Installed" Errors

### Common Causes

| Error | Cause | Fix |
|-------|-------|-----|
| `INSTALL_FAILED_VERSION_DOWNGRADE` | New build has lower versionCode than installed | Increment versionCode |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | Signature mismatch (debug vs release) | Uninstall old version first |
| `INSTALL_PARSE_FAILED_NO_CERTIFICATES` | Unsigned or corrupt APK | Build with `--release` and proper signing |
| `INSTALL_FAILED_DUPLICATE_PERMISSION` | Duplicate `android:permission` in manifest | Check `AndroidManifest.xml` for duplicates |

### Debug vs Release Signatures

**Debug builds** are signed with debug keystore (`~/.android/debug.keystore`).

**Release builds** use your upload keystore.

> **You cannot update a debug install with a release build (or vice versa) without uninstalling first.**

```bash
# Check installed version
adb shell dumpsys package com.example.game_on | grep versionCode

# Uninstall before switching build types
adb uninstall com.example.game_on
```

### VersionCode Stuck at 1

If `versionCode` shows as `1` despite `github.run_number` being higher:

1. Check `android/app/build.gradle.kts` — ensure `versionCode` is **not hardcoded**
2. Verify workflow passes `--build-number` correctly
3. Confirm `flutter build appbundle` receives the argument

```kotlin
// android/app/build.gradle.kts - CORRECT (dynamic)
versionCode = flutterVersionCode.toInt()
versionName = flutterVersionName

// WRONG - hardcoded
versionCode = 1
```

### Play Store "Version code already used"

If upload fails with "Version code X has already been used":

1. Check Play Console → **Release → Testing → Internal testing** → **Release history**
2. Find the highest used versionCode
3. Next build must use `highest + 1` at minimum
4. Use manual workflow with `--build-number=<next_available>`

## Hive Persistence — Boxes, Versions & `app_preferences`

This project persists domain entities in typed Hive boxes (adapters with
`@HiveType(typeId: ...)`) and, since the sort preference feature, a primitive
`Box<String>` for UI preferences. The two versioning concerns are independent:

### `hiveDbVersion` (`lib/core/config.dart` + `HiveDatabaseMigrationService`)

- `hiveDbVersion` (currently `3`) tracks **schema migrations** for typed boxes
  (`HiveDatabaseMigrationService._migrations`). Bump it only when a migration
  script is required (field type change, box move, `typeId` rename, computed
  field). See `CONTRIBUTING.md` → *Database Migrations*.
- The migration map in `lib/data/services/hive/hive_database_migration_service.dart`
  is currently `0→2` (five seeds + backfill) and `2→3` (add `cat_pubgames` at 3500 + gap<2 normalize + rebuild indexes). `3→3` is no-op (idempotent guard `if (current >= target) return`). Tests `expect(AppConfig().hiveDbVersion, 3)` enforce this.
- **Fargo purge (0.3.0) did NOT bump `hiveDbVersion`.** `EloRankingPolicyHiveModel` `typeId 12` was retained from Fargo (`@HiveType(typeId: 12)`) with `@HiveField(7, defaultValue:500)` literal for `initialRating` (hand-patched `.g.dart` `fields[7] == null ? 500 : fields[7] as int`). New leagues default `400` (`kEloDefaultInitialRating`), legacy rows read as `500` (`kEloLegacyInitialRating`). `K=20` (`kEloDefaultKFactor`) is in-memory recalc only. No migration was needed — additive field via literal default is backward-compatible. The hard delete (`RankingPolicyType.elo` removed, `create_elo_rate_league_screen.dart` → `create_elo_league_screen.dart`, shims deleted, provider `isElo`/`eloStats` canonical) is BREAKING at the API level but not at the Hive schema level.

### Box inventory

| Box name | Type | Adapter `typeId` | Versioned? |
|----------|------|------------------|------------|
| `users` | `UserHiveModel` | `0` | yes |
| `league_players` | `LeaguePlayerHiveModel` | `1` | yes |
| `leagues` | `LeagueHiveModel` | `3` | yes |
| `simple_matches` | `SimpleMatchHiveModel` | `6` | yes |
| `side` (embedded) | `SideHiveModel` | `8` | yes |
| `ranking_policies` | `SimpleRankingPolicyHiveModel` / `GoalDifferenceRankingPolicyHiveModel` / `EloRankingPolicyHiveModel` | `9`, `10`, `12` | yes |
| `categories` | `CategoryHiveModel` | `11` | yes |
| `category_slug_index` | `String` (`slug → id`) | — (primitive) | no |
| `category_parent_index` | `String` (`parentKey → comma-joined ids`) | — (primitive) | no |
| `category_policy_index` | `String` (`categoryId → comma-joined policyIds`) | — (primitive) | no |
| `league_players_unique_index` | `String` | — (primitive) | no |
| `app_preferences` | `String` (primitive `Box<String>`) | — (no adapter) | no |
| `meta` | `int` | — (primitive) | no |

Highest consumed `typeId` is `12` (`EloRankingPolicyHiveModel` `@HiveType(typeId: 12)` with `@HiveField(7, defaultValue:500)` literal). `typeId`s `2,4,5,7` remain unused; do not reuse `11` or `12` without checking `lib/data/models/hive/` and `lib/hive_registrar.g.dart`.

### `app_preferences` — why no version bump

Added in the *Sort my leagues* feature (`lib/data/repositories/hive/hive_sort_preference_repository.dart`):

- `Box<String>` `app_preferences` (constant `HiveSortPreferenceRepository.boxName`)
  stores two **primitive string** keys: `sort_mode` (`lastPlayed` | `alphabetical`)
  and `sort_descending` (`true` | `false`). Representative persistence path:
  `Box<String>` via `Hive.openBox<String>(boxName)` — no `TypeAdapter`, no
  `@HiveType` annotation.
- Because the box holds primitives, no `typeId` is consumed and no schema
  migration is needed — existing installs simply open an empty box and read
  defaults. `hiveDbVersion` therefore **stays at 3**; `injection_container`
  opens the box idempotently:

  ```dart
  final Box<String> appPreferencesBox;
  if (Hive.isBoxOpen(HiveSortPreferenceRepository.boxName)) {
    appPreferencesBox = Hive.box<String>(HiveSortPreferenceRepository.boxName);
  } else {
    appPreferencesBox = await Hive.openBox<String>(HiveSortPreferenceRepository.boxName);
  }
  ```

  The `Hive.isBoxOpen` guard makes `initInjection` / `_initHive` safe to call
  multiple times (tests, hot restart) without `HiveError: Box already open`.

- Keys and defaults are documented in the repository and service:
  `sort_mode` / `sort_descending` (see `lib/data/repositories/hive/hive_sort_preference_repository.dart:sortModeKey` / `sortDescendingKey`),
  `LeagueSortPreference.defaultPreference` (`lastPlayed` descending) in
  `lib/application/preferences/sort_preference.dart`. Malformed values fallback
  to `defaultPreference` (full default if mode is unknown, mode kept + descending
  default if only `sort_descending` is malformed).

- Related persistence files:
  `lib/domain/repositories/preferences/sort_preference_repository.dart`
  (abstract `get`/`set` + `getPreference`/`setPreference` aliases),
  `lib/providers/sort_preference_provider.dart` (write-then-invalidate),
  `lib/providers/sorted_leagues_provider.dart` (reads preference via `ref.read`).

### Fargo purge verification gate

`tool/verify_no_elo.sh` is the **BREAKING 0.3.0 gate** — it must pass before merge and in CI:

```bash
tool/verify_no_elo.sh
# PASS: No elo mentions in content
# PASS: No elo in git tracked paths
```

- Content check: `rg -i elo` excluding `.git/.dart_tool/build/** /AGENTS.md/tool/verify_no_elo.sh/test/elo_purge_verification_test.dart` (the verifier test intentionally contains the string `elo` to assert absence elsewhere).
- Path check: `git ls-files | grep -i elo` excluding `tool/verify_no_elo.sh`.
- Zero `elo` in `lib/` and `git ls-files` is an invariant — the hard delete removed `RankingPolicyType.elo`, `elo_rate_ranking_policy.dart`, `elo_player_stats.dart`, `elo_rate_calculator.dart`/`elo_rate_calculator.dart` shims, `elo_constants.dart`, `elo_rate_ranking_policy_hive_model.dart` (+ `.g.dart`), provider aliases `isFargo`/`eloStats`, `kFargoCategoryIds`/`kFargoInitialRating`, tests, and renamed `create_elo_rate_league_screen.dart` → `create_elo_league_screen.dart` (`New Pool League`, `Starting Elo Rating`). `660 tests pass`, `dart analyze` clean.

## Related Files

- `pubspec.yaml` — Version name source (`0.3.0` BREAKING Fargo purge)
- `.github/workflows/release.yml` — Release automation (when created)
- `android/app/build.gradle.kts` — Version code/name injection
- `android/app/src/main/AndroidManifest.xml` — Package name for adb commands
- `lib/core/config.dart` — `hiveDbVersion` (currently `3`)
- `lib/data/services/hive/hive_database_migration_service.dart` — migration runner (`_migrations` map `2` + `3`, `3→3` no-op)
- `lib/core/injection_container.dart` — `Hive.isBoxOpen` idempotent guard, `app_preferences` `Box<String>` open, `_initHive` ordered init (`registerAdapters` `typeId 11`+`12` → `migrate(3)` → `openBox` → `rebuildIfNeeded`)
- `lib/data/repositories/hive/hive_sort_preference_repository.dart` — `Box<String>` `app_preferences`, keys `sort_mode` / `sort_descending`, `boxName` constant
- `lib/hive_registrar.g.dart` — generated adapter registrars (`typeId` `0`, `1`, `3`, `6`, `8`, `9`, `10`, `11`, `12`)
- `lib/domain/constants/elo_constants.dart` — `kEloMinRating`/`kEloMaxRating`/`kEloDefaultInitialRating`/`kEloLegacyInitialRating`/`kEloDefaultKFactor` (`100`/`500`/`400`/`500`/`20`)
- `lib/domain/entities/ranking_policies/elo_ranking_policy.dart` — `EloRankingPolicy` (`categoryIds` `kEloCategoryIds`, `initialRating` 100..500, `K=20`)
- `lib/data/models/hive/ranking_policies/elo_ranking_policy_hive_model.dart` — `@HiveType(typeId: 12)` `@HiveField(7, defaultValue:500)` literal
- `CHANGELOG.md` — `0.3.0` BREAKING Fargo purge entry (hard delete, no shim, `hiveDbVersion` stays `3`, error message `Elo leagues must have categoryIds exactly [cat_sports, cat_pubgames]. Got: ...`, file renames)
- `tool/verify_no_elo.sh` — purge verification gate (content + path)

## Quick Reference

```bash
# Current version
grep '^version:' pubspec.yaml

# Build release with explicit versionCode
flutter build appbundle --release --build-number=123

# Check installed versionCode
adb shell dumpsys package com.example.game_on | grep versionCode

# Create release tag
git tag v0.3.0 && git push origin v0.3.0

# Verify Fargo purge (must pass)
tool/verify_no_elo.sh
```
