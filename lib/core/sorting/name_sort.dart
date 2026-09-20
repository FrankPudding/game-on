// ignore_for_file: public_member_api_docs

/// Compares two names for alphabetical ordering.
///
/// Contract:
/// - Trims surrounding whitespace before comparison.
/// - Empty (or whitespace-only) names sort first.
/// - Primary comparison is case-insensitive ([String.toLowerCase]).
/// - Secondary comparison is case-sensitive to ensure a deterministic
///   tie-break when lower-cased forms are equal (e.g. `Alice` < `alice`).
/// - No domain imports must be added to this core file.
///
/// Locale limitation:
/// This uses [String.toLowerCase] which is not locale-aware. It is
/// sufficient for the current ASCII / simple Latin names used by the app,
/// but does not handle locale-specific collation (e.g. Turkish İ/i,
/// German ß, or diacritics) or Unicode normalization. If proper
/// internationalised sorting is needed, replace with a locale-aware
/// collator (e.g. `intl` collation) and add tests for those cases.
int compareNames(String a, String b) {
  final trimmedA = a.trim();
  final trimmedB = b.trim();

  final isEmptyA = trimmedA.isEmpty;
  final isEmptyB = trimmedB.isEmpty;

  if (isEmptyA && isEmptyB) return 0;
  if (isEmptyA) return -1;
  if (isEmptyB) return 1;

  final lowerA = trimmedA.toLowerCase();
  final lowerB = trimmedB.toLowerCase();

  final primary = lowerA.compareTo(lowerB);
  if (primary != 0) return primary;

  // Secondary: case-sensitive to make ordering deterministic.
  return trimmedA.compareTo(trimmedB);
}
