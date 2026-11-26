import 'dart:io';

Future<void> saveWorkbookBytes(List<int> bytes, String fileName) async {
  await File(fileName).writeAsBytes(bytes, flush: true);
}
