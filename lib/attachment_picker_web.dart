import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'picked_attachment.dart';

/// Browser-native file input (file_picker plugin fails on Flutter web).
Future<PickedAttachment?> pickAttachment() async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/*,.jpg,.jpeg,.png,.pdf,.doc,.docx'
    ..multiple = false
    ..style.display = 'none';

  html.document.body?.children.add(input);

  final completer = Completer<PickedAttachment?>();
  var finished = false;

  void done(PickedAttachment? value) {
    if (finished) return;
    finished = true;
    input.remove();
    if (!completer.isCompleted) completer.complete(value);
  }

  StreamSubscription<html.Event>? focusSub;
  focusSub = html.window.onFocus.listen((_) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!finished && (input.files == null || input.files!.isEmpty)) {
        focusSub?.cancel();
        done(null);
      }
    });
  });

  input.onChange.listen((_) async {
    focusSub?.cancel();
    final file = input.files?.first;
    if (file == null) {
      done(null);
      return;
    }
    final reader = html.FileReader()..readAsArrayBuffer(file);
    await reader.onLoad.first;
    final raw = reader.result;
    Uint8List? bytes;
    if (raw is ByteBuffer) {
      bytes = raw.asUint8List();
    } else if (raw is Uint8List) {
      bytes = raw;
    }
    if (bytes == null || bytes.isEmpty) {
      done(null);
      return;
    }
    done(PickedAttachment(name: file.name, bytes: bytes));
  });

  input.click();

  return completer.future.timeout(
    const Duration(minutes: 2),
    onTimeout: () {
      focusSub?.cancel();
      done(null);
      return null;
    },
  );
}
