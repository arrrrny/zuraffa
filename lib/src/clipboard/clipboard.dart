/// Clipboard seam: get/set/clear the system clipboard.
library;

/// The clipboard contract.
abstract class ClipboardPort {
  /// Writes [text] to the clipboard (overwrites).
  Future<void> setText(String text);

  /// Reads the clipboard, or `null` when empty.
  Future<String?> getText();

  /// Clears the clipboard.
  Future<void> clear();
}

/// Pure-Dart default adapter (test/dev): holds one string.
class InMemoryClipboardAdapter implements ClipboardPort {
  /// The current clipboard content (null = empty); directly settable in
  /// tests to simulate the user copying something.
  String? value;

  /// Writes recorded for assertions.
  final List<String> writes = [];

  @override
  Future<void> setText(String text) async {
    value = text;
    writes.add(text);
  }

  @override
  Future<String?> getText() async => value;

  @override
  Future<void> clear() async {
    value = null;
  }
}
