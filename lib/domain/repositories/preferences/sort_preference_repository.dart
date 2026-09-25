// ignore_for_file: public_member_api_docs, unintended_html_in_doc_comment

import '../../../application/preferences/sort_preference.dart';

/// Abstract repository for persisted league sort preference.
///
/// Approved design allows either naming:
/// - `get()` / `set()`   OR
/// - `getPreference()` / `setPreference()`
///
/// Skeleton exposes both pairs as abstract to satisfy either import / test
/// expectation without inventing architecture. Data layer implements via
/// Hive Box<String> `app_preferences`.
///
/// Resilience (R7): write-then-invalidate, idempotent box open.
abstract class SortPreferenceRepository {
  // Primary spec naming
  Future<LeagueSortPreference> get();
  Future<void> set(LeagueSortPreference preference);

  // Alias naming (for alternative caller expectations)
  Future<LeagueSortPreference> getPreference();
  Future<void> setPreference(LeagueSortPreference preference);
}
