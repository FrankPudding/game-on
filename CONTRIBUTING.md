# Contributing to Game On

Thank you for your interest in contributing! This project follows strict testing guidelines to ensure stability and reliability.

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
Run all tests and automatically update the `README.md` coverage table:
```bash
make coverage
```
Alternatively, you can run the commands manually:
```bash
flutter test --coverage
dart scripts/update_coverage.dart
```

> [!IMPORTANT]
> **CI Enforcement**: GitHub Actions will fail if your `README.md` is not in sync with the current test results. Always run `make coverage` before pushing your changes to `main`.

## Testing Philosophy
- **Unit Layer (`test/unit`)**: 100% coverage preferred. No external dependencies. Includes Domain and Provider logic.
- **Integration Layer (`test/integration`)**: Test interactions with Hive and UI components.

## Test Naming Conventions
- Test files should be located in `test/unit/` or `test/integration/`, mirroring `lib/`.
- Test files must end with `_test.dart`.
- Group related tests using `group()` and provide descriptive `test()` names.
