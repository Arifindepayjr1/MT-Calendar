import 'statistics_export_stub.dart'
    if (dart.library.html) 'statistics_export_web.dart';

/// Downloads a generated CSV audit report in the web app.
///
/// The stub keeps the screen compilable in widget tests and desktop builds.
Future<void> downloadStatisticsCsv({
  required String fileName,
  required String csv,
}) =>
    downloadStatisticsCsvImpl(fileName: fileName, csv: csv);
