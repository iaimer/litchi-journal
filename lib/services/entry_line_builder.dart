String rebuildTimelineLine({
  required String rawLine,
  required String content,
  required List<String> tags,
}) {
  final prefix = _extractTimelinePrefix(rawLine);
  final tagStr =
      tags.isEmpty ? '' : ' ${tags.map((t) => '#$t').join(' ')}';
  return '$prefix${content.trim()}$tagStr';
}

String _extractTimelinePrefix(String rawLine) {
  final match = RegExp(r'^(?:-\s*|>\s*)\*\*(\d{2}:\d{2})\*\*\s*').firstMatch(rawLine);
  if (match == null) {
    throw ArgumentError('Cannot extract timeline prefix from: $rawLine');
  }
  return match.group(0)!;
}
