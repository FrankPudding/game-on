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
