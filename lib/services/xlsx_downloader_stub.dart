Future<void> saveWorkbookBytes(List<int> bytes, String fileName) async {
  // Unsupported platform; keep the API total so the export still succeeds.
  assert(bytes.isNotEmpty && fileName.isNotEmpty);
}
