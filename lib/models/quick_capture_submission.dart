class QuickCaptureSubmission {
  final String content;
  final List<String> tags;
  final String time;
  final String? entryId;
  final String operationId;

  const QuickCaptureSubmission({
    required this.content,
    required this.tags,
    required this.time,
    required this.operationId,
    this.entryId,
  });
}
