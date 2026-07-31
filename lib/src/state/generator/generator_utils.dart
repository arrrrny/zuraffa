import 'dart:io';

/// Shared helpers for the code-generation generators.
///
/// Extracted so `state_generator.dart` and `view_template_generator.dart`
/// do not diverge on file writing and name conversion.

/// Write [content] to [path], creating parent directories as needed.
void writeFile(String path, String content) {
  final file = File(path);
  file.createSync(recursive: true);
  file.writeAsStringSync(content);
}

/// Convert a PascalCase [name] to snake_case (e.g. `ProductDetail` →
/// `product_detail`).
String snakeCase(String name) {
  return name
      .replaceAllMapped(
        RegExp(r'[A-Z]'),
        (m) => '_${m.group(0)!.toLowerCase()}',
      )
      .replaceFirst(RegExp(r'^_'), '');
}
