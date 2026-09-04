/// Shared PascalCase converter for slice generators.
library;

/// Converts a raw string (snake_case, kebab-case, or space-separated)
/// to PascalCase.
String pascalCase(String raw) {
  final parts = raw
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return raw;
  return parts.map((p) => '${p[0].toUpperCase()}${p.substring(1)}').join();
}
