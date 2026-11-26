// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<void> openHtmlReport(String content, String fileName) async {
  final blob = html.Blob([content], 'text/html');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..target = '_blank'
    ..rel = 'noopener';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  // Do not add a download attribute here: it would save the report instead of
  // opening it. The URL is intentionally not revoked immediately because the
  // new tab still needs to read the blob after this function returns.
  // `fileName` is used by the desktop launcher, where the report is saved.
  assert(fileName.isNotEmpty);
}
