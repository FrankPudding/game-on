.PHONY: all format lint fix check check-format coverage

# Default target
all: format lint

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

# Update README with current coverage
coverage:
	flutter test --coverage
	dart scripts/update_coverage.dart

# Run all checks (for CI or pre-commit)
check: check-format lint
