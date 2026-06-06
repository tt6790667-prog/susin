import 'dart:io';

void main() {
  final files = [
    'assets/s.png',
    'assets/susin-logo-hkea57kH.png',
    'assets/susin-logo-padded.png',
    'assets/susin-logo-centered.png',
  ];

  for (final f in files) {
    final file = File(f);
    if (!file.existsSync()) {
      print('$f does not exist');
      continue;
    }
    final bytes = file.readAsBytesSync();
    if (bytes.length < 24 ||
        bytes[0] != 0x89 ||
        bytes[1] != 0x50 ||
        bytes[2] != 0x4E ||
        bytes[3] != 0x47) {
      print('$f is not a valid PNG');
      continue;
    }
    // Read PNG width/height (Big Endian 4 bytes at offset 16 and 20)
    final width = (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
    final height = (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
    print('$f: ${width}x${height} (${bytes.length} bytes)');
  }
}
