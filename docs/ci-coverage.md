# CI Coverage — Fast Local vs Deterministic CI

## Purpose

Documents the split between fast local iteration and reproducible CI coverage,
and the auto-commit flow in `.github/workflows/test.yml`.

Related: `Makefile` (`coverage*` targets), `CONTRIBUTING.md` → *Running Tests*,
`scripts/update_coverage.dart`.

## Makefile Targets

| Target | Command | Invariant |
|--------|---------|-----------|
| `coverage` | alias for `coverage-fast` | Backwards-compatible default; **not** deterministic. |
| `coverage-fast` | `flutter test --coverage` → `dart scripts/update_coverage.dart` | Parallel (Flutter default); fastest for local loops. May produce line-order nondeterminism across machines. |
| `coverage-deterministic` | `flutter test --coverage --concurrency=1` → `dart scripts/update_coverage.dart` | Single-threaded; hard-fails (`::error::`, exit 1) if `flutter test --help` does not advertise `--concurrency`. Guarantees stable `lcov.info` → `README.md` output. |
| `coverage-ci` | alias for `coverage-deterministic` | Semantic alias used by CI; same invariant as above. |

> **Rule:** CI must use `coverage-deterministic` / `coverage-ci`. Local contributors should use `coverage-deterministic` before pushing if they want the CI result to match first try; `coverage-fast` is fine for iteration but may require a follow-up `coverage-deterministic` run.

## Workflow — `Test and Coverage`

File: `.github/workflows/test.yml`

```
on: push[main], pull_request[main]
concurrency: group: coverage-${{ github.head_ref || github.ref_name }}, cancel-in-progress: false
permissions: contents: write, pull-requests: write
checkout: fetch-depth: 0, persist-credentials: true
steps: flutter setup → pub get → build_runner → check-format → lint → make coverage-deterministic
       → scoped git diff -- README.md → branch/fork-aware gate → auto-commit (same-repo PRs only)
```

### Why `fetch-depth: 0`

A full clone (not shallow) is required so the auto-commit step can `git fetch origin <head_ref>` and `git rebase origin/<head_ref>` before pushing. A shallow clone would not have the base to rebase against and would fail or create a divergent history.

### Why `persist-credentials: true` + `COVERAGE_PAT`

The checkout's persisted credentials are replaced with a PAT (`COVERAGE_PAT`) before pushing:

```
git remote set-url origin https://x-access-token:${COVERAGE_PAT}@github.com/${{ github.repository }}.git
```

Pushes authenticated with the default `GITHUB_TOKEN` do **not** trigger further workflow runs (intentional GitHub loop prevention). The coverage auto-commit must trigger checks to move the PR to green, so a PAT is required. The workflow validates this explicitly: if `README.md` is stale on a same-repo PR and `secrets.COVERAGE_PAT` is empty, it fails with `::error::` and instructs the contributor to set the secret or push the update manually.

### Scoped Diff

Only `README.md` is considered for the coverage gate:

```bash
git diff --quiet -- README.md
```

Other unstaged changes (e.g., `coverage/lcov.info` itself) do not affect the gate. `README.md` is the only committed coverage artifact.

### Per-Branch Concurrency

```yaml
concurrency:
  group: coverage-${{ github.head_ref || github.ref_name }}
  cancel-in-progress: false
```

- `github.head_ref` on PRs (source branch name), `github.ref_name` on pushes (e.g., `main`).
- Different branches do not cancel each other.
- Sequential pushes to the **same** branch (including the auto-commit push) are queued (`cancel-in-progress: false`), not cancelled — prevents a race where a coverage commit is cancelled before it lands.
- The auto-commit step itself handles concurrent updates with fetch + rebase + retry:

  ```bash
  git fetch origin "${{ github.head_ref }}"
  git rebase "origin/${{ github.head_ref }}"
  git add -- README.md
  git commit -m "chore: update coverage"
  if ! git push origin "HEAD:${{ github.head_ref }}"; then
    git fetch origin "${{ github.head_ref }}"
    git rebase "origin/${{ github.head_ref }}"
    git push origin "HEAD:${{ github.head_ref }}"
  fi
  ```

## Auto-Commit vs Verify-Only Matrix

| Event | Repo | `README.md` stale? | Result |
|-------|------|---------------------|--------|
| `pull_request` | same-repo (`head.repo == base.repo`) | yes | Validate `COVERAGE_PAT` present; `fetch` + `rebase` + `commit` + `push` (retry). No `[skip ci]`; idempotent — if rebase makes diff clean, no commit is created (guarded by `changed == true` before the step). Re-triggered workflow then sees `changed == false` and passes. |
| `pull_request` | fork (`head.repo != base.repo`) | yes | `::error::` + diff printed + `exit 1`. Auto-commit is not permitted from forks (no write permission / PAT). Contributor must run `make coverage-deterministic` locally and push to fork. |
| `push` (to `main`) | any | yes | `::error::` + diff printed + `exit 1`. Direct pushes must include the updated `README.md`; CI never auto-commits to `main`. |
| any | any | no | No-op; workflow passes. |

### Idempotency

The commit message is fixed (`chore: update coverage`) and the diff scope is fixed (`README.md`). After the rebase+push, GitHub re-runs the workflow on the new HEAD. That run will generate identical coverage and find `changed == false`, so no second auto-commit is attempted.

### No `[skip ci]`

The auto-commit deliberately omits `[skip ci]` / `[no ci]`. Skipping would leave the PR without a passing coverage check, defeating the purpose of the automation.

## Operational Notes

- **First-time setup (maintainers):** create a fine-grained or classic PAT with `contents: write` on this repository and store it as repository secret `COVERAGE_PAT`. Without it, every same-repo PR that touches coverage will fail at the validation step.
- **Fork contributors:** expect a CI failure with instructions; the fix is always `make coverage-deterministic` + commit `README.md`.
- **Direct pushes to `main`:** same as forks — CI is verify-only; include `README.md` in the push.

## Boundaries

- Domain / app code (`lib/`) is independent of this flow. The only coupling is `scripts/update_coverage.dart` parsing `coverage/lcov.info` (categories: `Total`, `Domain & Providers` (`lib/domain` + `lib/providers`), `Data Layer` (`lib/data`)) and patching the `README.md` table via regex.
- Do not extend the auto-commit to other files without updating the scoped diff check and the `git add -- README.md` line in lockstep.
