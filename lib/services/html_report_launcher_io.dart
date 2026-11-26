import 'dart:io';

Future<void> openHtmlReport(String content, String fileName) async {
  final file = await File(fileName).writeAsString(content);
  if (Platform.isWindows) {
    await Process.run('cmd', ['/c', 'start', '', file.path]);
  } else if (Platform.isMacOS) {
    await Process.run('open', [file.path]);
  } else {
    await Process.run('xdg-open', [file.path]);
  }
}
