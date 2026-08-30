/// ImportVerifier (spec 043): import resolution checks (FR-013).
///
/// Fast-mode verification (research R-009): parse every `.dart` file in the
/// sandbox and check each import resolves to another file in the sandbox,
/// a package declared in the project's pubspec.yaml, or a `dart:` SDK
/// library. Failures report the exact file, line, and import path (U46).
library;

import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../../../core/ast/file_parser.dart';

/// One unresolved import.
class ImportIssue {
  /// Creates the issue record.
  const ImportIssue(this.file, this.line, this.importPath, this.reason);

  /// Sandbox-relative path of the importing file.
  final String file;

  /// 1-based line of the import directive.
  final int line;

  /// The unresolved import URI.
  final String importPath;

  /// Why it failed.
  final String reason;

  @override
  String toString() => '$file:$line: "$importPath" — $reason';
}

/// The verification outcome.
class VerifyReport {
  /// Creates the report.
  const VerifyReport({
    required this.passed,
    required this.issues,
    required this.filesChecked,
  });

  /// True when every import resolved.
  final bool passed;

  /// The unresolved imports, if any.
  final List<ImportIssue> issues;

  /// Number of Dart files checked.
  final int filesChecked;
}

/// Verifies that every import in a sandbox resolves.
class ImportVerifier {
  /// Creates the verifier with an optional [parser].
  ImportVerifier({FileParser? parser}) : _parser = parser ?? const FileParser();

  final FileParser _parser;

  /// Verifies the sandbox at [sandboxDir] against the project at
  /// [projectRoot] (whose pubspec.yaml names the self package and the
  /// allowed external dependencies).
  Future<VerifyReport> verify({
    required String sandboxDir,
    required String projectRoot,
  }) async {
    final pubspecFile = File(p.join(projectRoot, 'pubspec.yaml'));
    final pubspec = pubspecFile.existsSync()
        ? (loadYaml(pubspecFile.readAsStringSync()) as Map)
        : <String, dynamic>{};
    final selfPackage = pubspec['name'] as String? ?? '';
    final declaredPackages = <String>{
      ..._depNames(pubspec['dependencies']),
      ..._depNames(pubspec['dev_dependencies']),
    };

    final issues = <ImportIssue>[];
    var filesChecked = 0;

    final sandboxRoot = Directory(sandboxDir);
    if (!sandboxRoot.existsSync()) {
      return const VerifyReport(
        passed: false,
        issues: [ImportIssue('', 0, '', 'sandbox directory does not exist')],
        filesChecked: 0,
      );
    }

    final dartFiles =
        sandboxRoot
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in dartFiles) {
      filesChecked++;
      final source = file.readAsStringSync();
      final rel = p.relative(file.path, from: sandboxDir);
      final unit = _parser.parseSource(source, path: file.path).unit;
      if (unit == null) continue;

      for (final directive in unit.directives) {
        if (directive is! ImportDirective) continue;
        final uri = directive.uri.stringValue;
        if (uri == null) continue;
        final line = source.substring(0, directive.offset).split('\n').length;

        if (uri.startsWith('dart:')) continue;

        if (uri.startsWith('package:')) {
          final package = uri.substring('package:'.length).split('/').first;
          if (package == selfPackage) {
            // Self-package imports must resolve inside the sandbox tree.
            final packagePath = uri.substring(
              'package:'.length + package.length + 1,
            );
            final target = p.canonicalize(p.join(sandboxDir, 'lib', packagePath));
            if (!p.isWithin(sandboxDir, target)) {
              issues.add(
                ImportIssue(
                  rel,
                  line,
                  uri,
                  'escapes the slice sandbox via a path traversal in package import',
                ),
              );
            } else if (!File(target).existsSync()) {
              issues.add(
                ImportIssue(
                  rel,
                  line,
                  uri,
                  'missing from the slice (no sandbox file at lib/$packagePath)',
                ),
              );
            }
          } else if (!declaredPackages.contains(package)) {
            issues.add(
              ImportIssue(
                rel,
                line,
                uri,
                'package "$package" is not declared in pubspec.yaml',
              ),
            );
          }
          continue;
        }

        // Relative import: must resolve to a sibling in the sandbox.
        final target = p.canonicalize(
          p.normalize(p.join(p.dirname(file.path), uri)),
        );
        if (!p.isWithin(sandboxDir, target)) {
          issues.add(
            ImportIssue(
              rel,
              line,
              uri,
              'escapes the slice sandbox via a relative path traversal',
            ),
          );
        } else if (!File(target).existsSync()) {
          issues.add(
            ImportIssue(rel, line, uri, 'missing file (dangling import)'),
          );
        }
      }
    }

    return VerifyReport(
      passed: issues.isEmpty,
      issues: issues,
      filesChecked: filesChecked,
    );
  }

  Set<String> _depNames(dynamic node) {
    if (node is! Map) return const {};
    return node.keys.whereType<String>().toSet();
  }
}
