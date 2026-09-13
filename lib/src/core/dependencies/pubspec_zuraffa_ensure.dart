/// SPEC 1530 — the offline-safe `package:zuraffa` dependency ensure.
///
/// Generated files import `package:zuraffa/zuraffa.dart` (and
/// `package:zuraffa/mock.dart`); when the target pubspec declares only
/// `zuraffa_flutter` / `zuraffa_ui` (the dogfood todo app's shape) the
/// core `zuraffa` package is never declared, every generated import
/// fires `depend_on_referenced_packages`, and `zfa build`'s analyze
/// gate fails on zfa-generated code (issue #1530). The #1265 auto-add
/// heals the gap only when a network `pub add` can run and silently
/// degrades to a printed warning otherwise — the declaration was never
/// ENSURED.
///
/// This patcher ensures the declaration with the same textual discipline
/// `PubspecSkinDependencyPatcher` applies to the skin lane's certified
/// dependency (`zuraffa_ui`, issue #1260 remediation 2):
///
/// - the YAML is parsed for READ-ONLY detection (idempotent, hand-edit
///   preserving) and patched TEXTUALLY so comments and formatting
///   survive;
/// - the entry is a RUNTIME dependency (generated `lib/` imports need a
///   regular dependency — never `dev_dependencies:`);
/// - an inline `dependencies: {...}` mapping is refused loudly instead
///   of being mangled (`UnsupportedError`), an unparseable pubspec is
///   refused (`FormatException`), and an inline-empty mapping is
///   expanded to block style;
/// - NO process is spawned: the declaration itself is network-free
///   (FR-006). Re-resolution stays the existing flows' job (`zfa build`,
///   CI `pub get`, the #1265 auto-add when online).
library;

import 'dart:io';

import 'package:yaml/yaml.dart';

class PubspecZuraffaEnsureResult {
  const PubspecZuraffaEnsureResult({
    required this.added,
    required this.constraint,
  });

  /// Whether the declaration was written by this call (false when the
  /// pubspec already declared `zuraffa` under `dependencies:`).
  final bool added;

  /// The constraint written (or already present).
  final String constraint;
}

/// Ensures `zuraffa` is declared under a project pubspec's
/// `dependencies:` (issue #1530 FR-005/FR-006).
class PubspecZuraffaEnsure {
  /// The ensured package name.
  static const packageName = 'zuraffa';

  /// The standard constraint — mirrors `DependencyWirer.standardSet`'s
  /// pure-Dart `zuraffa` entry (single documented range; the generator
  /// emits framework-barrel imports that resolve against the 6.x API).
  static const constraint = '^6.0.0';

  const PubspecZuraffaEnsure();

  /// Ensures the declaration unconditionally (the caller has already
  /// decided the project needs it — e.g. the pubsync post-pass saw a
  /// `package:zuraffa/` import in the files this run wrote).
  Future<PubspecZuraffaEnsureResult> ensure(String projectRoot) async {
    final file = File('$projectRoot/pubspec.yaml');
    if (!await file.exists()) {
      throw StateError('pubspec.yaml not found at ${file.path}');
    }
    final raw = await file.readAsString();

    dynamic doc;
    try {
      doc = loadYaml(raw);
    } on YamlException catch (e) {
      throw FormatException(
        'pubspec.yaml at ${file.path} is not valid YAML: $e',
      );
    }
    if (doc is! Map) {
      throw FormatException(
        'pubspec.yaml at ${file.path} did not parse to a Map',
      );
    }
    final rawExisting = doc['dependencies'];
    if (rawExisting != null && rawExisting is! Map) {
      throw UnsupportedError(
        'Inline `dependencies: {...}` mappings are not supported by '
        'PubspecZuraffaEnsure; use a block-style `dependencies:` section '
        'instead.',
      );
    }
    final existing = (rawExisting as Map?) ?? const {};

    if (existing.containsKey(packageName)) {
      return const PubspecZuraffaEnsureResult(
        added: false,
        constraint: constraint,
      );
    }

    final newContent = _patchTextually(raw);
    await file.writeAsString(newContent);
    return const PubspecZuraffaEnsureResult(added: true, constraint: constraint);
  }

  /// The import-triggered seam: ensures the declaration only when
  /// [importedPackages] (the packages the files THIS RUN wrote import)
  /// contains `zuraffa`. A run whose files import no `package:zuraffa/`
  /// URI leaves the pubspec untouched (no drive-by declarations).
  Future<PubspecZuraffaEnsureResult> ensureForImports(
    String projectRoot,
    Iterable<String> importedPackages,
  ) {
    if (!importedPackages.contains(packageName)) {
      return Future.value(
        const PubspecZuraffaEnsureResult(added: false, constraint: constraint),
      );
    }
    return ensure(projectRoot);
  }

  /// Inserts `  zuraffa: ^6.0.0` at the END of the `dependencies:` block
  /// (before the next top-level key), preserving comments and formatting.
  ///
  /// Same textual contract as `PubspecSkinDependencyPatcher._patchTextually`.
  String _patchTextually(String raw) {
    final lines = raw.split('\n');
    var depsIdx = -1;
    var endIdx = lines.length;
    var inlineEmpty = false;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final depsMatch = RegExp(r'^dependencies:\s*(.*)$').firstMatch(line);
      if (depsMatch != null) {
        final rest = depsMatch.group(1)!.trim();
        if (rest.isEmpty || rest == '{}') {
          depsIdx = i;
          inlineEmpty = rest == '{}';
          continue;
        }
        if (rest.startsWith('{')) {
          throw UnsupportedError(
            'Inline `dependencies: {...}` mappings are not supported by '
            'PubspecZuraffaEnsure; use a block-style `dependencies:` '
            'section instead.',
          );
        }
      }
      if (depsIdx >= 0 && !inlineEmpty) {
        if (line.trim().isEmpty || line.trimLeft().startsWith('#')) {
          continue;
        }
        final leadingMatch = RegExp(r'^(\s*)').firstMatch(line);
        final leading = leadingMatch?.group(1) ?? '';
        if (leading.length < 2) {
          endIdx = i;
          break;
        }
      }
    }

    final entry = '  $packageName: $constraint';
    final buf = StringBuffer();
    if (depsIdx < 0) {
      // No dependencies section at all — append one.
      buf
        ..write(raw)
        ..write(raw.endsWith('\n') ? '' : '\n')
        ..writeln('dependencies:')
        ..writeln(entry);
      return buf.toString();
    }

    if (inlineEmpty) {
      for (var i = 0; i < lines.length; i++) {
        if (i == depsIdx) {
          buf
            ..writeln('dependencies:')
            ..writeln(entry);
        } else {
          buf.writeln(lines[i]);
        }
      }
      return buf.toString();
    }

    for (var i = 0; i < lines.length; i++) {
      if (i == endIdx) {
        buf.writeln(entry);
      }
      buf.writeln(lines[i]);
    }
    if (endIdx >= lines.length) {
      buf.writeln(entry);
    }
    return buf.toString();
  }
}
