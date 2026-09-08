import 'package:image_picker/image_picker.dart';

enum ImageUploadStatus { selected, preparing, uploading, success, failed }

class ImageUploadItem {
  final String id;
  final XFile file;
  ImageUploadStatus status;
  int sentBytes;
  int totalBytes;
  String? errorMessage;

  ImageUploadItem({
    required this.id,
    required this.file,
    this.status = ImageUploadStatus.selected,
    this.sentBytes = 0,
    this.totalBytes = 0,
    this.errorMessage,
  });

  double get progress {
    if (totalBytes <= 0) return 0;
    return (sentBytes / totalBytes).clamp(0, 1);
  }
}
