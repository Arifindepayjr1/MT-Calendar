import 'html_report_launcher_stub.dart'
    if (dart.library.html) 'html_report_launcher_web.dart'
    if (dart.library.io) 'html_report_launcher_io.dart';

/// Opens the generated workbook report in a new place appropriate to the
/// platform: a new browser tab on web, or a saved HTML file on desktop.
Future<void> openWorkbookReport(
  String html, {
  String fileName = 'Trading_Journal_Report.html',
}) {
  return openHtmlReport(html, fileName);
}
