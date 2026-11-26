Future<void> openHtmlReport(String html, String fileName) async {
  // Unsupported platform. Keeping the no-op means the import still succeeds.
  assert(html.isNotEmpty && fileName.isNotEmpty);
}
