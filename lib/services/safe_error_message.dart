import 'api_client.dart';

String safeErrorMessage(Object error, String fallback) {
  if (error is ApiException && error.message.trim().isNotEmpty) {
    return error.message;
  }
  if (error is UnsupportedError) return error.message ?? fallback;
  return fallback;
}
