/// `PubspecDevDependenciesPatcher` — merges the testing `dev_dependencies`
/// into a generated project's `pubspec.yaml`.
library;

import 'dart:io';

import 'package:yaml/yaml.dart';

class PubspecDevDependenciesPatcher {
  const PubspecDevDependenciesPatcher({this.isFlutter = true});

  final bool isFlutter;

  // Bug #716: the generated test templates (tdd behavior tests, package
  // scaffold tests) import `package:test/test.dart`, which `flutter_test`
  // does NOT provide — `flutter_test` wraps test_api/matcher, not the
  // `test` runner package. Without an explicit `test` dependency, fresh
  // Flutter projects could not compile their generated tests.
  //
  // Bug #755: `mutation_test` was pinned at `^1.0.0`, but the toolchain's
  // own MutationVerifier (lib/src/plugins/tdd/services/mutation_verifier
  // .dart:235,255) parses v1.8.0+ reports — the generated baseline was
  // internally inconsistent out of the box. Bumped to `^1.8.0` so the
  // pin matches the verifier. `coverage` bumped to `^1.15.1` (current
  // latest per pub.dev at merge time). `mocktail` dropped: generated
  // test templates use zuraffa's native mocks (lib/src/mock/mock.dart,
  // test_builder_entity.dart:6) and never import `package:mocktail`,
  // so the dev dep was unused bloat.
  static const Map<String, String> flutterDevDependencies = {
    'flutter_test': 'sdk: flutter',
    'test': '^1.0.0',
    'build_runner': '^2.4.0',
    'json_serializable': '^6.7.0',
    'coverage': '^1.15.1',
    'mutation_test': '^1.8.0',
  };

  static const Map<String, String> dartDevDependencies = {
    'test': '^1.25.0',
    'build_runner': '^2.4.0',
    'json_serializable': '^6.7.0',
    'coverage': '^1.15.1',
    'mutation_test': '^1.8.0',
  };

  String _renderEntry(String name, String value) {
    if (value.contains(':') && !value.startsWith('"')) {
      return '$name:\n  $value';
    }
    return '$name: $value';
  }

  String _indentEntry(String entry) {
    return entry.split('\n').map((line) => '  $line').join('\n');
  }

  Future<List<String>> ensure(String projectRoot, {bool dryRun = false}) async {
    final file = File('$projectRoot/pubspec.yaml');

    // In dry-run mode, report what would be added without touching disk.
    // The pubspec.yaml may not exist (the project is being scaffolded and
    // the dry-run is previewing what the TDD baseline writers would emit).
    if (dryRun) {
      if (!await file.exists()) {
        return (isFlutter ? flutterDevDependencies : dartDevDependencies).keys
            .toList();
      }
      final raw = await file.readAsString();
      final doc = loadYaml(raw);
      final existing =
          (doc is Map ? (doc['dev_dependencies'] as Map?) : null) ?? const {};
      final wanted = isFlutter ? flutterDevDependencies : dartDevDependencies;
      return wanted.keys.where((pkg) => !existing.containsKey(pkg)).toList();
    }

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
    final existing = (doc['dev_dependencies'] as Map?) ?? const {};

    final wanted = isFlutter ? flutterDevDependencies : dartDevDependencies;
    final missing = <String>[];
    wanted.forEach((pkg, constraint) {
      if (!existing.containsKey(pkg)) {
        missing.add(_renderEntry(pkg, constraint));
      }
    });

    if (missing.isEmpty || dryRun) {
      return missing;
    }

    if (RegExp(r'dev_dependencies:\s*\{[^\}]').hasMatch(raw)) {
      throw UnsupportedError(
        'Inline `dev_dependencies: {...}` mappings are not supported by '
        'PubspecDevDependenciesPatcher; use a block-style `dev_dependencies:` '
        'section instead.',
      );
    }

    final newContent = _patchTextually(raw, missing);
    await file.writeAsString(newContent);
    return missing;
  }

  String _patchTextually(String raw, List<String> missing) {
    final lines = raw.split('\n');
    var devDepIdx = -1;
    var endIdx = lines.length;
    var inlineEmpty = false;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final devDepMatch = RegExp(
        r'^dev_dependencies:\s*(.*)$',
      ).firstMatch(line);
      if (devDepMatch != null) {
        final rest = devDepMatch.group(1)!.trim();
        if (rest.isEmpty || rest == '{}') {
          devDepIdx = i;
          inlineEmpty = rest == '{}';
          continue;
        }
      }
      if (devDepIdx >= 0 && !inlineEmpty) {
        if (line.trim().isEmpty) {
          continue;
        }
        final leadingMatch = RegExp(r'^(\s*)').firstMatch(line);
        final leading = leadingMatch?.group(1) ?? '';
        if (leading.length < 2 && !line.trimLeft().startsWith('#')) {
          endIdx = i;
          break;
        }
      }
    }

    final buf = StringBuffer();
    if (devDepIdx < 0) {
      buf
        ..write(raw)
        ..write(raw.endsWith('\n') ? '' : '\n')
        ..writeln('dev_dependencies:');
      for (final m in missing) {
        buf.writeln(_indentEntry(m));
      }
      return buf.toString();
    }

    if (inlineEmpty) {
      for (var i = 0; i < lines.length; i++) {
        if (i == devDepIdx) {
          buf.writeln('dev_dependencies:');
          for (final m in missing) {
            buf.writeln(_indentEntry(m));
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
          buf.writeln(_indentEntry(m));
        }
      }
      buf.writeln(lines[i]);
    }
    if (endIdx >= lines.length) {
      for (final m in missing) {
        buf.writeln(_indentEntry(m));
      }
    }
    return buf.toString();
  }
}
