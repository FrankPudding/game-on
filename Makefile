.PHONY: all format lint fix check check-format coverage coverage-fast coverage-deterministic coverage-ci serve rc-tag

# Default target - fix, format, lint, then coverage
all: fix format lint coverage

# Format code (like black)
format:
	dart format .

# Lint code (like ruff check)
lint:
	flutter analyze

# Fix issues automatically (like ruff check --fix)
# This handles unused imports and other quick fixes
fix:
	dart fix --apply

# Check formatting without changing files (for CI)
check-format:
	dart format --set-exit-if-changed .

# Update README with current coverage (alias for compatibility)
coverage: coverage-fast

# Fast local coverage (parallel)
coverage-fast:
	flutter test --coverage
	dart scripts/update_coverage.dart

# Deterministic CI coverage (single-threaded)
coverage-deterministic:
	@if ! flutter test --help | grep -q -- --concurrency; then \
		echo "::error::flutter test does not support --concurrency flag; cannot run deterministic coverage"; \
		exit 1; \
	fi
	flutter test --coverage --concurrency=1
	dart scripts/update_coverage.dart

# CI alias for deterministic coverage
coverage-ci: coverage-deterministic

# Run all checks (for CI or pre-commit)
check: check-format lint

# Serve the app at 0.0.0.0:6066
serve:
	flutter run -d web-server --web-port 6066 --web-hostname 0.0.0.0

# Create a release candidate tag based on pubspec.yaml version
# Increments the rc number: v<VERSION>-rc.<N>
rc-tag:
	@VERSION=$$(grep '^version:' pubspec.yaml | sed 's/version: //' | tr -d ' \r'); \
	PATTERN="v$$VERSION-rc.*"; \
	LATEST_TAG=$$(git tag -l "$$PATTERN" | sort -V | tail -1); \
	if [ -n "$$LATEST_TAG" ]; then \
		RC_NUM=$$(echo "$$LATEST_TAG" | sed 's/.*-rc\.//'); \
		NEXT_RC=$$((RC_NUM + 1)); \
	else \
		NEXT_RC=0; \
	fi; \
	NEW_TAG="v$$VERSION-rc.$$NEXT_RC"; \
	git tag -a "$$NEW_TAG" -m "Release candidate $$NEW_TAG"; \
	echo "$$NEW_TAG"
