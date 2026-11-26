import 'xlsx_downloader_stub.dart'
    if (dart.library.html) 'xlsx_downloader_web.dart'
    if (dart.library.io) 'xlsx_downloader_io.dart';

/// Saves generated XLSX bytes to a file on web or desktop.
Future<void> saveXlsxBytes(List<int> bytes, String fileName) {
  return saveWorkbookBytes(bytes, fileName);
}
