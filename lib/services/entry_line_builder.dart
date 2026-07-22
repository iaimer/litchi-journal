String rebuildTimelineLine({
  required String rawLine,
  required String content,
  required List<String> tags,
  String? time,
}) {
  final prefix = _buildTimelinePrefix(rawLine, time);
  final tagStr = tags.isEmpty ? '' : ' ${tags.map((t) => '#$t').join(' ')}';
  return '$prefix${content.trim()}$tagStr';
}

String _buildTimelinePrefix(String rawLine, String? time) {
  final match = RegExp(
    r'^(-\s*|>\s*)\*\*((\d{2}:\d{2}))\*\*\s*',
  ).firstMatch(rawLine);
  if (match == null) {
    throw ArgumentError('Cannot extract timeline prefix from: $rawLine');
  }
  final selectedTime = time ?? match.group(2)!;
  if (!RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(selectedTime)) {
    throw ArgumentError('Invalid timeline time: $selectedTime');
  }
  return '${match.group(1)}**$selectedTime** ';
}
