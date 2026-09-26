# Contributing to Game On

Thank you for your interest in contributing! This project follows strict guidelines to ensure stability and reliability.

## Database Migrations

This project uses **Hive** (NoSQL) for local storage. Since Hive is schemaless, changes to data models must be handled carefully to avoid data loss or corruption.

### When to Create a Migration

You must create a migration whenever you make a **breaking change** to the data model that cannot be handled by simple field addition/removal rules. Examples include:
- Changing the type of an existing field.
- Moving data from one box to another.
- Calculating new field values based on existing data.
- Renaming classes (that affect `hiveTypeId`).

### How to Create a Migration

1.  **Increment Version**: Open `lib/core/config.dart` and increment `hiveDbVersion`.
2.  **Add Migration Logic**:
    - Open `lib/data/services/hive/hive_database_migration_service.dart`.
    - Add a new entry to the `_migrations` map where the key is the *new* version number.
    - Implement the migration logic in the values function.
    
    ```dart
    final Map<int, Future<void> Function()> _migrations = {
      // ... existing migrations
      2: () async {
        final box = await Hive.openBox('my_box');
        // perform data transformation
      },
    };
    ```

3.  **Verify**: creating a test case in `test/data/services/hive/hive_database_migration_service_test.dart` to verify the migration.

> **Legacy purge (0.3.0) — no migration bump.** `EloRankingPolicyHiveModel` `typeId 12` was retained from legacy with `@HiveField(7, defaultValue:500)` literal (`fields[7] == null ? 500 : fields[7] as int`, hand-patched after `build_runner`). `hiveDbVersion` stays `3` — additive field via literal default is backward-compatible. The hard delete (legacy `RankingPolicyType` value removed, `create_legacy_rate_league_screen.dart` → `create_elo_league_screen.dart`, shims deleted, `isElo`/`eloStats` canonical) is BREAKING at the API level but not at the Hive schema level. Do not bump `hiveDbVersion` for literal-default additions.

## Verification Gate — Legacy Purge

Before pushing, run the purge verifier (must pass in CI and locally):

```bash
tool/verify_no_fargo.sh
# PASS: No legacy mentions in content
# PASS: No legacy in git tracked paths
```

- Content check: `rg -i <legacy>` excluding `.git/.dart_tool/build/** /AGENTS.md/tool/verify_no_fargo.sh/test/elo_purge_verification_test.dart` (verifier test intentionally contains the legacy string).
- Path check: `git ls-files | grep -i <legacy>` excluding `tool/verify_no_fargo.sh`.
- Also verify: `dart analyze` clean and `flutter test` (660 tests).

See `docs/versioning.md` → *Purge verification gate* and `CHANGELOG.md` → `0.3.0`.

## Running Tests

### Unit Tests
Run unit tests (no external dependencies):
```bash
flutter test test/unit
```

### Integration Tests
Run integration tests (repositories and UI):
```bash
flutter test test/integration
```

### All Tests & Coverage
Run all tests and update the `README.md` coverage table:

- **Fast local (parallel)** — for quick iteration:
  ```bash
  make coverage-fast   # also: make coverage (alias)
  ```
  Runs `flutter test --coverage` (parallel) + `dart scripts/update_coverage.dart`.

- **Deterministic (mirrors CI)** — single-threaded, reproducible:
  ```bash
  make coverage-deterministic   # also: make coverage-ci
  ```
  Runs `flutter test --coverage --concurrency=1` + `dart scripts/update_coverage.dart`.
  Hard-fails with `::error::` if your Flutter does not support `--concurrency`.

Manually (without Make):
```bash
flutter test --coverage
dart scripts/update_coverage.dart
```

> [!IMPORTANT]
> **CI — `Test and Coverage` (`.github/workflows/test.yml`)**
> - CI always generates coverage deterministically via `make coverage-deterministic` (`--concurrency=1`).
> - **Same-repo PRs:** if only `README.md` is stale (scoped `git diff -- README.md`), CI auto-commits `chore: update coverage` with `fetch` + `rebase` and a push retry on conflict. The commit does **not** use `[skip ci]` (so checks re-run) and is **idempotent** — if the rebase resolves the diff, no extra commit is created.
> - **Fork PRs and pushes to `main`:** verify-only — CI fails with `::error::` and prints the `README.md` diff. Run `make coverage-deterministic` locally, commit `README.md`, and push to your fork / branch.
> - Auto-push requires the `COVERAGE_PAT` repository secret (PAT). The default `GITHUB_TOKEN` push would not trigger checks, so CI validates `COVERAGE_PAT` is set and fails explicitly if it is missing on a same-repo PR that needs an update.
> - Concurrency is per-branch (`concurrency.group: coverage-${{ github.head_ref || github.ref_name }}`, `cancel-in-progress: false`): pushes to the same branch are serialized; different branches do not cancel each other. See `docs/ci-coverage.md` for the full flow.

## Testing Philosophy
- **Unit Layer (`test/unit`)**: 100% coverage preferred. No external dependencies. Includes Domain and Provider logic.
- **Integration Layer (`test/integration`)**: Test interactions with Hive and UI components.

## Test Naming Conventions
- Test files should be located in `test/unit/` or `test/integration/`, mirroring `lib/`.
- Test files must end with `_test.dart`.
- Group related tests using `group()` and provide descriptive `test()` names.
