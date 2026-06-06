import 'package:file_picker/file_picker.dart';
import 'picked_attachment.dart';

Future<PickedAttachment?> pickAttachment() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;
  final file = result.files.first;
  final bytes = file.bytes;
  if (bytes == null || bytes.isEmpty) return null;
  return PickedAttachment(name: file.name, bytes: bytes);
}
