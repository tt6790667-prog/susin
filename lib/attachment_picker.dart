import 'picked_attachment.dart';

import 'attachment_picker_stub.dart'
    if (dart.library.io) 'attachment_picker_io.dart'
    if (dart.library.html) 'attachment_picker_web.dart' as picker;

export 'picked_attachment.dart';

Future<PickedAttachment?> pickAttachment() => picker.pickAttachment();
