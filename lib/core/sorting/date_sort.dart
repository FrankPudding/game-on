// ignore_for_file: public_member_api_docs

/// Generic nullable date comparator with null-last semantics.
///
/// Contract:
/// - `null` (Never) always sorts last regardless of [descending].
/// - When both non-null: [descending] == true  → most recent first
///   (i.e. `b.compareTo(a)`), otherwise oldest first.
/// - No domain imports must be added to this core file.
///
/// Skeleton: structure only, no business logic.
int compareNullableDateNullLast(
  DateTime? a,
  DateTime? b, {
  required bool descending,
}) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  if (descending) {
    return b.compareTo(a);
  }
  return a.compareTo(b);
}
