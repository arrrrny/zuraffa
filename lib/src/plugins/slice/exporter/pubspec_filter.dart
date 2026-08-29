/// PubspecFilter (spec 043): filtered `pubspec.yaml` generation for exports
/// (US8, FR-017).
///
/// Reads the source project's pubspec.yaml, scans the sliced Dart files for
/// `package:` imports, and emits a self-contained pubspec that keeps only the
/// dependencies the slice actually uses (plus `flutter` and `flutter_test`,
/// always), preserving git/path/hosted sources verbatim. Emission is
/// hand-rolled (the repo pins no yaml_writer).
library;

import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../../../core/ast/file_parser.dart';

/// Produces filtered pubspec.yaml content for a slice sandbox.
class PubspecFilter {
  /// Creates the filter with an optional [parser].
  PubspecFilter({FileParser? parser}) : _parser = parser ?? const FileParser();

  final FileParser _parser;

  /// Dependencies that are always kept regardless of usage (U55).
  static const _alwaysKeepDeps = {'flutter'};

  /// Dev dependencies that are always kept regardless of usage (U55).
  static const _alwaysKeepDevDeps = {'flutter_test'};

  /// Filters the pubspec at `<projectRoot>/pubspec.yaml` down to what the
  /// slice needs.
  ///
  /// [sliceDartFiles] are paths relative to [sandboxDir]; each is scanned for
  /// `package:` imports (imports of the self package are ignored). Returns
  /// the filtered pubspec.yaml content.
  Future<String> filter({
    required String projectRoot,
    required String sandboxDir,
    required List<String> sliceDartFiles,
  }) async {
    final pubspecFile = File(p.join(projectRoot, 'pubspec.yaml'));
    final dynamic doc = pubspecFile.existsSync()
        ? loadYaml(pubspecFile.readAsStringSync())
        : null;
    final source = doc is Map ? doc : <String, dynamic>{};
    final selfPackage = source['name'] as String? ?? '';

    final usedPackages = <String>{};
    for (final rel in sliceDartFiles) {
      final file = File(p.join(sandboxDir, rel));
      if (!file.existsSync()) continue;
      final unit = _parser.parseSource(
        file.readAsStringSync(),
        path: rel,
      ).unit;
      if (unit == null) continue;
      for (final directive in unit.directives) {
        if (directive is! ImportDirective && directive is! ExportDirective) {
          continue;
        }
        final uri = (directive as dynamic).uri.stringValue as String?;
        if (uri == null || !uri.startsWith('package:')) continue;
        final name = uri.substring('package:'.length).split('/').first;
        if (name.isNotEmpty && name != selfPackage) {
          usedPackages.add(name);
        }
      }
    }

    final buffer = StringBuffer();
    source.forEach((key, value) {
      final section = key.toString();
      if (section == 'dependencies' || section == 'dev_dependencies') {
        final always = section == 'dependencies'
            ? _alwaysKeepDeps
            : _alwaysKeepDevDeps;
        _emitSection(buffer, section, value, usedPackages, always);
      } else {
        _emitEntry(buffer, section, value, 0);
      }
    });
    return buffer.toString();
  }

  /// Emits a filtered `dependencies:`/`dev_dependencies:` section.
  void _emitSection(
    StringBuffer buffer,
    String section,
    dynamic value,
    Set<String> used,
    Set<String> always,
  ) {
    final deps = value is Map ? value : const <String, dynamic>{};
    final kept = <MapEntry<dynamic, dynamic>>[
      for (final entry in deps.entries)
        if (always.contains(entry.key.toString()) ||
            used.contains(entry.key.toString()))
          entry,
    ];
    if (kept.isEmpty) {
      buffer.writeln('$section: {}');
      return;
    }
    buffer.writeln('$section:');
    for (final entry in kept) {
      _emitEntry(buffer, entry.key.toString(), entry.value, 1);
    }
  }

  /// Emits `key: value` at [indent] (0 = top level), recursing into maps and
  /// lists.
  void _emitEntry(StringBuffer buffer, String key, dynamic value, int indent) {
    final pad = '  ' * indent;
    if (value is Map) {
      if (value.isEmpty) {
        buffer.writeln('$pad$key: {}');
        return;
      }
      buffer.writeln('$pad$key:');
      value.forEach((k, v) {
        _emitEntry(buffer, k.toString(), v, indent + 1);
      });
    } else if (value is List) {
      if (value.isEmpty) {
        buffer.writeln('$pad$key: []');
        return;
      }
      buffer.writeln('$pad$key:');
      for (final item in value) {
        if (item is Map) {
          buffer.write('${pad}  -');
          var first = true;
          item.forEach((k, v) {
            if (first) {
              buffer.write(' ${_scalar(k)}: ');
              _emitInline(buffer, v);
              buffer.writeln();
              first = false;
            } else {
              _emitEntry(buffer, k.toString(), v, indent + 2);
            }
          });
        } else {
          buffer.writeln('${pad}  - ${_scalar(item)}');
        }
      }
    } else {
      buffer.writeln('$pad$key: ${_scalar(value)}');
    }
  }

  /// Emits a scalar or one-level value inline (list item payload).
  void _emitInline(StringBuffer buffer, dynamic value) {
    if (value is Map) {
      buffer.write('{');
      var first = true;
      value.forEach((k, v) {
        if (!first) buffer.write(', ');
        buffer.write('${_scalar(k)}: ${_scalar(v)}');
        first = false;
      });
      buffer.write('}');
    } else {
      buffer.write(_scalar(value));
    }
  }

  /// Renders [value] as a YAML scalar, quoting only when necessary.
  String _scalar(dynamic value) {
    if (value == null) return 'null';
    if (value is bool) return value ? 'true' : 'false';
    if (value is num) return value.toString();
    final text = value.toString();
    return _needsQuote(text) ? "'${text.replaceAll("'", "''")}'" : text;
  }

  /// Whether [text] would be misread unquoted in YAML.
  static bool _needsQuote(String text) {
    if (text.isEmpty) return true;
    if (text != text.trim()) return true; // leading/trailing whitespace
    const special = '-?:,[]{}#&*!|>\'"%@`';
    if (special.contains(text[0]) || special.contains(text[text.length - 1])) {
      return true;
    }
    if (text.contains(': ') || text.contains(' #')) return true;
    const reserved = {
      '.', '~', 'true', 'false', 'null', 'yes', 'no', 'on', 'off',
    };
    return reserved.contains(text);
  }
}
