/// `PubspecDevDependenciesPatcher` — merges the testing `dev_dependencies`
/// into a generated project's `pubspec.yaml`.
library;

import 'dart:io';

import 'package:yaml/yaml.dart';

class PubspecDevDependenciesPatcher {
  const PubspecDevDependenciesPatcher({this.isFlutter = true});

  final bool isFlutter;

  static const Map<String, String> flutterDevDependencies = {
    'flutter_test': 'sdk: flutter',
    'mocktail': '^1.0.0',
    'build_runner': '^2.4.0',
    'json_serializable': '^6.7.0',
    'coverage': '^1.6.0',
    'mutation_test': '^1.0.0',
  };

  static const Map<String, String> dartDevDependencies = {
    'test': '^1.25.0',
    'mocktail': '^1.0.0',
    'build_runner': '^2.4.0',
    'json_serializable': '^6.7.0',
    'coverage': '^1.6.0',
    'mutation_test': '^1.0.0',
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

  Future<List<String>> ensure(
    String projectRoot, {
    bool dryRun = false,
  }) async {
    final file = File('$projectRoot/pubspec.yaml');

    // In dry-run mode, report what would be added without touching disk.
    // The pubspec.yaml may not exist (the project is being scaffolded and
    // the dry-run is previewing what the TDD baseline writers would emit).
    if (dryRun) {
      if (!await file.exists()) {
        return flutterDevDependencies.keys.toList();
      }
      final raw = await file.readAsString();
      final doc = loadYaml(raw);
      final existing = (doc is Map ? (doc['dev_dependencies'] as Map?) : null) ?? const {};
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
      final devDepMatch = RegExp(r'^dev_dependencies:\s*(.*)$').firstMatch(line);
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
