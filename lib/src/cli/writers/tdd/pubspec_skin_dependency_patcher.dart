/// `PubspecSkinDependencyPatcher` — adds the skin lane's CERTIFIED
/// dependency (`zuraffa_ui`) to a generated project's `pubspec.yaml`
/// (issue #1260 remediation 2).
///
/// `zuraffa_ui` is the skin lane's certified vocabulary and `ZuraffaApp`
/// its certified app shell; a project that opts into skin lanes
/// (`zfa tdd init --skin`) must declare it under `dependencies:` — a
/// RUNTIME dependency, never a dev dependency: the real app runs under
/// `ZuraffaApp`, and the widget lane's certified-shell import resolves
/// against it.
///
/// Same textual-patching discipline as `PubspecDevDependenciesPatcher`:
/// the YAML is parsed for READ-ONLY detection (idempotent, hand-edit
/// preserving) and patched TEXTUALLY so comments and formatting survive.
/// Empty inline `dependencies: {}` mappings are expanded to block style;
/// non-empty inline mappings are refused loudly instead of being mangled.
library;

import 'dart:io';

import 'package:yaml/yaml.dart';

class PubspecSkinDependencyPatcher {
  const PubspecSkinDependencyPatcher();

  /// The certified dependency this patcher ensures (name → constraint).
  static const Map<String, String> skinDependencies = {'zuraffa_ui': '^0.1.0'};

  Future<List<String>> ensure(String projectRoot) async {
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
      throw FormatException(
        'pubspec.yaml at ${file.path} has a non-map dependencies value',
      );
    }
    final existing = (rawExisting as Map?) ?? const {};

    final missing = <String>[];
    skinDependencies.forEach((pkg, constraint) {
      if (!existing.containsKey(pkg)) {
        missing.add('$pkg: $constraint');
      }
    });

    if (missing.isEmpty) return missing;

    final newContent = _patchTextually(raw, missing);
    await file.writeAsString(newContent);
    return missing;
  }

  /// Inserts the missing entries at the END of the `dependencies:` block
  /// (before the next top-level key), preserving comments and formatting.
  String _patchTextually(String raw, List<String> missing) {
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
            'PubspecSkinDependencyPatcher; use a block-style `dependencies:` '
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

    final buf = StringBuffer();
    if (depsIdx < 0) {
      // No dependencies section at all — append one.
      buf
        ..write(raw)
        ..write(raw.endsWith('\n') ? '' : '\n')
        ..writeln('dependencies:');
      for (final m in missing) {
        buf.writeln('  $m');
      }
      return buf.toString();
    }

    if (inlineEmpty) {
      for (var i = 0; i < lines.length; i++) {
        if (i == depsIdx) {
          buf.writeln('dependencies:');
          for (final m in missing) {
            buf.writeln('  $m');
          }
        } else {
          buf.writeln(lines[i]);
        }
      }
      return buf.toString();
    }

    for (var i = 0; i < lines.length; i++) {
      if (i == endIdx) {
        for (final m in missing) {
          buf.writeln('  $m');
        }
      }
      buf.writeln(lines[i]);
    }
    if (endIdx >= lines.length) {
      for (final m in missing) {
        buf.writeln('  $m');
      }
    }
    return buf.toString();
  }
}
