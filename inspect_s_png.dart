import 'dart:io';

void main() {
  final file = File('assets/s.png');
  if (!file.existsSync()) {
    print('s.png does not exist');
    return;
  }
  final bytes = file.readAsBytesSync();
  print('File size: ${bytes.length} bytes');
  
  // Let's check the first few bytes
  print('First 10 bytes: ${bytes.sublist(0, 10)}');
}
