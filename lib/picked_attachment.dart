import 'dart:typed_data';

class PickedAttachment {
  final String name;
  final Uint8List bytes;

  const PickedAttachment({required this.name, required this.bytes});

  bool get isImage {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
  }
}
