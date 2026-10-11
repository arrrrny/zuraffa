/// PubspecFilter (spec 043): filtered `pubspec.yaml` generation for exports
/// (US8, FR-017).
///
/// Reads the source project's pubspec.yaml, scans the sliced Dart files for
/// `package:` imports, and emits a self-contained pubspec that keeps only the
/// dependencies the slice actually uses (plus `flutter` and `flutter_test`,
/// always), preserving git/path/hosted sources verbatim. Emission is
/// hand-rolled (the repo pins no yaml_writer).
///
/// Issue #1304: a package imported by the copied closure but only TRANSITIVE
/// in the host (resolved via another dependency, e.g. `zuraffa` via
/// `zuraffa_flutter`) used to be silently dropped — the sandbox could not
/// resolve its own imports and `slice verify` self-containment failed by
/// construction. The writer now derives every imported package from the cut
/// closure: host-declared packages keep the host constraint verbatim, and a
/// transitive-only import is declared with the version resolved in the
/// host's pubspec.lock (falling back to `any` + an inline warning when the
/// lock has no entry).
library;

import 'dart:collection';
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
  /// `package:` imports (imports of the self package are ignored). Every
  /// imported package is declared in the emitted pubspec: host-declared
  /// packages keep the host entry verbatim, and an imported package the host
  /// only resolves transitively is declared from the host's pubspec.lock
  /// entry with its source preserved (hosted version constraint, or the
  /// git/path/sdk descriptor; or `any` + a warning when the lock has no
  /// usable entry — issue #1304). Returns the filtered pubspec.yaml content.
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
      final unit = _parser.parseSource(file.readAsStringSync(), path: rel).unit;
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

    // Issue #1304: the sandbox must declare every package the copied
    // closure imports. Packages the host declares keep the host entry
    // (handled by _emitSection); packages the host only resolves
    // transitively are synthesized here so the sandbox stays
    // self-contained by construction.
    final hostDeps = source['dependencies'];
    final hostDevDeps = source['dev_dependencies'];
    bool hostDeclares(String name) =>
        (hostDeps is Map && hostDeps.containsKey(name)) ||
        (hostDevDeps is Map && hostDevDeps.containsKey(name));
    final derived = SplayTreeMap<String, Object?>();
    final unresolved = SplayTreeSet<String>();
    for (final name in usedPackages) {
      if (hostDeclares(name)) continue;
      final locked = _lockConstraint(projectRoot, name);
      if (locked != null) {
        derived[name] = locked;
      } else {
        derived[name] = 'any';
        unresolved.add(name);
      }
    }

    final buffer = StringBuffer();
    source.forEach((key, value) {
      final section = key.toString();
      if (section == 'dependencies' || section == 'dev_dependencies') {
        final always = section == 'dependencies'
            ? _alwaysKeepDeps
            : _alwaysKeepDevDeps;
        _emitSection(
          buffer,
          section,
          value,
          usedPackages,
          always,
          derived: section == 'dependencies' ? derived : const {},
          unresolved: section == 'dependencies' ? unresolved : const {},
        );
      } else {
        _emitEntry(buffer, section, value, 0);
      }
    });
    // Hosts without a `dependencies:` key (e.g. dev_dependencies-only
    // packages) never hit the section branch above — emit the derived
    // entries in their own section so the sandbox stays self-contained.
    if (derived.isNotEmpty && source['dependencies'] is! Map) {
      _emitSection(
        buffer,
        'dependencies',
        null,
        usedPackages,
        _alwaysKeepDeps,
        derived: derived,
        unresolved: unresolved,
      );
    }
    return buffer.toString();
  }

  /// The pubspec dependency descriptor [name] resolves to in the host's
  /// pubspec.lock, or null when the lock is missing/unreadable or has no
  /// entry for [name].
  ///
  /// The lock entry's `source` is preserved rather than flattened to a
  /// caret constraint: a `hosted` entry on the default pub.dev host yields
  /// `^<version>` (or a `{hosted: ..., version: ...}` map for a custom
  /// hosted repository); `git`, `path`, and `sdk` entries yield their
  /// pubspec descriptor form so the sandbox re-resolves the same source
  /// instead of the default host (which could name a different package
  /// entirely or fail `pub get`).
  Object? _lockConstraint(String projectRoot, String name) {
    final lockFile = File(p.join(projectRoot, 'pubspec.lock'));
    if (!lockFile.existsSync()) return null;
    final dynamic doc;
    try {
      doc = loadYaml(lockFile.readAsStringSync());
    } on YamlException {
      return null;
    } on FileSystemException {
      // Unreadable lock (permissions, transient I/O): fall back to the
      // `any` + warning path instead of aborting the whole export.
      return null;
    }
    if (doc is! Map) return null;
    final packages = doc['packages'];
    if (packages is! Map) return null;
    final entry = packages[name];
    if (entry is! Map) return null;
    final description = entry['description'];
    switch (entry['source']?.toString()) {
      case 'git':
        if (description is Map) {
          final git = <String, Object?>{};
          for (final key in ['url', 'ref', 'path']) {
            final value = description[key];
            if (value != null) git[key] = value;
          }
          if (git.isNotEmpty) return {'git': git};
        }
        return null;
      case 'path':
        if (description is Map && description['path'] != null) {
          return {'path': description['path']};
        }
        return null;
      case 'sdk':
        final sdkName = description is Map ? description['name'] : description;
        return sdkName == null ? null : {'sdk': sdkName};
      default: // hosted (explicit or legacy locks without `source`)
        final version = entry['version'];
        if (version == null) return null;
        final text = version.toString().trim();
        if (text.isEmpty) return null;
        final url = description is Map ? description['url']?.toString() : null;
        if (url != null && url != 'https://pub.dev') {
          return {
            'version': '^$text',
            'hosted': {'name': name, 'url': url},
          };
        }
        return '^$text';
    }
  }

  /// Emits a filtered `dependencies:`/`dev_dependencies:` section.
  ///
  /// [derived] carries the issue-#1304 synthesized entries for imported
  /// packages the host only resolves transitively (name -> constraint,
  /// sorted); [unresolved] names the entries that fell back to `any` and
  /// carry an inline warning.
  void _emitSection(
    StringBuffer buffer,
    String section,
    dynamic value,
    Set<String> used,
    Set<String> always, {
    Map<String, Object?> derived = const {},
    Set<String> unresolved = const {},
  }) {
    final deps = value is Map ? value : const <String, dynamic>{};
    final kept = <MapEntry<dynamic, dynamic>>[
      for (final entry in deps.entries)
        if (always.contains(entry.key.toString()) ||
            used.contains(entry.key.toString()))
          entry,
    ];
    if (kept.isEmpty && derived.isEmpty) {
      buffer.writeln('$section: {}');
      return;
    }
    buffer.writeln('$section:');
    for (final entry in kept) {
      _emitEntry(buffer, entry.key.toString(), entry.value, 1);
    }
    for (final entry in derived.entries) {
      if (unresolved.contains(entry.key)) {
        buffer.writeln(
          "  # WARNING (issue #1304): '${entry.key}' is imported by this "
          'slice but is not declared by the host pubspec and has no '
          "pubspec.lock entry; declared as 'any' — pin it if resolution "
          'drifts.',
        );
      } else {
        buffer.writeln(
          "  # derived (issue #1304): '${entry.key}' is imported by this "
          'slice and resolved transitively by the host; pinned from the '
          "host's pubspec.lock.",
        );
      }
      _emitEntry(buffer, entry.key, entry.value, 1);
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
          buffer.write('$pad  -');
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
          buffer.writeln('$pad  - ${_scalar(item)}');
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
      '.',
      '~',
      'true',
      'false',
      'null',
      'yes',
      'no',
      'on',
      'off',
    };
    return reserved.contains(text);
  }
}
