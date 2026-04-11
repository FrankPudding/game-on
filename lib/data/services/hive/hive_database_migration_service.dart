import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

class HiveDatabaseMigrationService {
  static const String _metaBoxName = 'meta';
  static const String _versionKey = 'db_version';

  // Define your migrations here.
  // The key is the version number we are migrating TO.
  // The value is the function that performs the migration.
  final Map<int, Future<void> Function()> _migrations = {
    // Example:
    // 2: () async {
    //   // logic to migrate from v1 to v2
    // }
  };

  Future<void> migrate(int targetVersion) async {
    final metaBox = await Hive.openBox(_metaBoxName);
    int currentVersion = metaBox.get(_versionKey, defaultValue: 0) as int;

    debugPrint(
        'Current DB version: $currentVersion. Target version: $targetVersion');

    if (currentVersion >= targetVersion) {
      debugPrint('Database is up to date.');
      return;
    }

    for (var version = currentVersion + 1;
        version <= targetVersion;
        version++) {
      if (_migrations.containsKey(version)) {
        debugPrint('Migrating to version $version...');
        try {
          await _migrations[version]!();
          await metaBox.put(_versionKey, version);
          debugPrint('Successfully migrated to version $version.');
        } catch (e) {
          debugPrint('Error migrating to version $version: $e');
          // Re-throw to stop further migrations and potentially crash app initialization
          // to prevent running with consistent data.
          rethrow;
        }
      } else {
        // If there's no migration for a version, we just bump the version number.
        // This assumes that the version bump might be for a code-only change
        // that doesn't strictly require data migration but we want to track it.
        // Or it could be an error if we strictly expect a migration script.
        // For now, let's assume valid version bumps must be sequential and documented,
        // but if no script is provided, we just update the version.
        debugPrint(
            'No migration script for version $version. Bumping version.');
        await metaBox.put(_versionKey, version);
      }
    }
  }
}
