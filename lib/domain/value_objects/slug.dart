class Slug {
  Slug(String raw) : value = _normalizeAndValidate(raw);

  final String value;

  static final RegExp _validPattern = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

  static String _normalizeAndValidate(String raw) {
    final trimmed = raw.trim().toLowerCase();
    // replace one or more non-alphanumeric with single '-'
    String normalized = trimmed.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    // remove leading/trailing '-'
    normalized = normalized.replaceAll(RegExp(r'^-+'), '');
    normalized = normalized.replaceAll(RegExp(r'-+$'), '');
    // collapse multiple '-' (already done via + but keep)
    normalized = normalized.replaceAll(RegExp(r'-{2,}'), '-');

    if (normalized.length < 3 || normalized.length > 32) {
      throw ArgumentError(
          'Slug must be 3..32 characters after normalization, got: "$normalized" (${normalized.length})');
    }
    if (!_validPattern.hasMatch(normalized)) {
      throw ArgumentError('Invalid slug format: "$normalized"');
    }
    return normalized;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Slug && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
