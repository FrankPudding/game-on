// ignore_for_file: public_member_api_docs, unused_field

import 'package:hive_ce/hive_ce.dart';

import '../../../application/preferences/sort_preference.dart';
import '../../../domain/repositories/preferences/sort_preference_repository.dart';

/// Hive implementation of [SortPreferenceRepository].
///
/// Persistence:
/// - `Box<String>` `app_preferences` (R4)
/// - Keys: `sort_mode` (`lastPlayed` | `alphabetical`)
///         `sort_descending` (`true` | `false`)
/// - Returns [LeagueSortPreference.defaultPreference] when keys absent.
/// - Idempotent open via `Hive.isBoxOpen` guard (R7).
/// - Invalidation: write-then-invalidate via providers.
///
/// Skeleton: methods throw [UnimplementedError], no business logic.
class HiveSortPreferenceRepository implements SortPreferenceRepository {
  HiveSortPreferenceRepository(this._box);

  final Box<String> _box;

  static const String sortModeKey = 'sort_mode';
  static const String sortDescendingKey = 'sort_descending';

  // Box name constant for injection_container isBoxOpen guard.
  static const String boxName = 'app_preferences';

  LeagueSortPreference _read() {
    final modeStr = _box.get(sortModeKey);
    final descendingStr = _box.get(sortDescendingKey);
    if (modeStr == null && descendingStr == null) {
      return LeagueSortPreference.defaultPreference;
    }
    // Malformed mode -> full default fallback
    if (modeStr != null && modeStr != 'alphabetical' && modeStr != 'lastPlayed') {
      return LeagueSortPreference.defaultPreference;
    }
    LeagueSortMode mode;
    if (modeStr == 'alphabetical') {
      mode = LeagueSortMode.alphabetical;
    } else if (modeStr == 'lastPlayed') {
      mode = LeagueSortMode.lastPlayed;
    } else {
      mode = LeagueSortPreference.defaultPreference.mode;
    }

    // Malformed descending with valid mode -> keep mode, fallback descending
    if (descendingStr != null && descendingStr != 'true' && descendingStr != 'false') {
      return LeagueSortPreference(mode: mode, descending: LeagueSortPreference.defaultPreference.descending);
    }
    bool descending;
    if (descendingStr == 'true') {
      descending = true;
    } else if (descendingStr == 'false') {
      descending = false;
    } else {
      descending = LeagueSortPreference.defaultPreference.descending;
    }

    return LeagueSortPreference(mode: mode, descending: descending);
  }

  @override
  Future<LeagueSortPreference> get() async {
    return _read();
  }

  @override
  Future<void> set(LeagueSortPreference preference) async {
    await _box.put(sortModeKey, preference.mode == LeagueSortMode.alphabetical ? 'alphabetical' : 'lastPlayed');
    await _box.put(sortDescendingKey, preference.descending ? 'true' : 'false');
  }

  @override
  Future<LeagueSortPreference> getPreference() async {
    return _read();
  }

  @override
  Future<void> setPreference(LeagueSortPreference preference) async {
    await _box.put(sortModeKey, preference.mode == LeagueSortMode.alphabetical ? 'alphabetical' : 'lastPlayed');
    await _box.put(sortDescendingKey, preference.descending ? 'true' : 'false');
  }
}
