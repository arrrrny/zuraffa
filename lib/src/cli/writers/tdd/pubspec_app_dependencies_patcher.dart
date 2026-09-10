/// `PubspecAppDependenciesPatcher` — ensures the day-zero Flutter app
/// module's RUNTIME dependencies (`zuraffa_flutter`, `get_it`) are
/// declared under `dependencies:` in the project pubspec (issue #1349).
///
/// The Flutter branch of `zfa tdd init` writes `lib/app.dart`
/// (via AppModuleWriter) whose generated source imports
/// `package:zuraffa_flutter/zuraffa_flutter.dart` and uses `GetIt` — the
/// runtime deps the generated module requires were never declared, so
/// every test failed to compile on a fresh Flutter project: the day-zero
/// baseline init promises was red out of the box.
///
/// Same textual-patching discipline as `PubspecDevDependenciesPatcher` /
/// `PubspecSkinDependencyPatcher`: the YAML is parsed for READ-ONLY
/// detection (idempotent, hand-edit preserving) and patched TEXTUALLY so
/// comments and formatting survive. Empty inline `dependencies: {}`
/// mappings are expanded to block style; non-empty inline mappings are
/// refused loudly instead of being mangled.
///
/// Extracted from `InitCommand` (PR #1461): the tightened YAML-based
/// Flutter detection (`flutter:` under `dependencies:`) means init only
/// routes genuine Flutter projects here, so the empty-inline and
/// non-map fixture shapes are exercised directly at the writer level
/// (the init-level routing stays pinned by the bug_1349 init tests).
library;

import 'dart:io';

import 'package:yaml/yaml.dart';

class PubspecAppDependenciesPatcher {
  const PubspecAppDependenciesPatcher();

  /// The runtime dependencies the day-zero Flutter app module
  /// (`lib/app.dart`) requires. Constraints mirror the codebase's
  /// canonical wiring (`DependencyWirer.standardSet` pins
  /// `zuraffa_flutter: ^6.0.0`; the repo itself resolves `get_it
  /// ^9.2.1`) so a self-healed pubspec stays on the same resolver graph
  /// the toolchain ships (issue #1349).
  static const Map<String, String> appDependencies = {
    'zuraffa_flutter': '^6.0.0',
    'get_it': '^9.2.1',
  };

  /// Ensures the day-zero app module's runtime deps are declared under
  /// `dependencies:` in the project pubspec. Returns the entries that
  /// were added (empty when already complete).
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
    appDependencies.forEach((pkg, constraint) {
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
        // Strip a trailing `#` comment so `{} # note` still counts as an
        // empty inline mapping (the refusal below must only fire for
        // genuinely non-empty flow mappings).
        final flow = rest.split('#').first.trim();
        if (flow.isEmpty || flow == '{}') {
          depsIdx = i;
          inlineEmpty = flow == '{}';
          continue;
        }
        if (rest.startsWith('{')) {
          throw UnsupportedError(
            'Inline `dependencies: {...}` mappings are not supported by '
            'the tdd init app-dependency self-heal; use a block-style '
            '`dependencies:` section instead.',
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

    // A trailing blank line (file ending in "\n") never terminates the
    // block scan, so endIdx stays at lines.length and entries would land
    // after a stray blank line inside the block. Fall back to the last
    // non-blank line instead.
    if (endIdx >= lines.length) {
      endIdx = lines.lastIndexWhere((l) => l.trim().isNotEmpty) + 1;
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
