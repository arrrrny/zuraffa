/// SandboxComposition (feature 073, issue #961): the sync core of the
/// runnable-sandbox composition `slice cut` performs on top of the
/// artifact export — shell bootstrap, router harness, certified mock
/// artifacts, and the feature's receipts, all from declared facts.
///
/// Pure and synchronous: identical inputs write byte-identical files
/// (FR-007 determinism). `CutSliceCapability.execute` runs this as its
/// composition step; subjects exercise it directly.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'sandbox_scaffold.dart';
import '../models/slice_manifest.dart';

/// Composes the runnable sandbox over a cut tree.
class SandboxComposition {
  /// Creates the composer (stateless; injectable only for tests).
  const SandboxComposition();

  /// Emit `lib/main.dart`, `lib/router.dart`, `lib/di.dart`, one
  /// certified fake per declared dependency, and the feature's receipts
  /// (`specs/<feature>/**`) into [sandboxDir]. Appends every written
  /// path to [generatedFiles] (manifest bookkeeping).
  void compose({
    required String projectRoot,
    required String sandboxDir,
    required String feature,
    required List<ManifestRoute> routes,
    required List<ManifestDependency> dependencies,
    required List<String> generatedFiles,
  }) {
    final scaffoldRoutes = [
      for (final route in routes) SandboxRoute(path: route.path, page: route.page),
    ];
    final scaffoldBindings = [
      for (final dependency in dependencies)
        SandboxBinding(
          dependency: dependency.dependency,
          kind: dependency.kind,
          mockArtifact: dependency.mockArtifact,
        ),
    ];

    _write(
      sandboxDir: sandboxDir,
      path: p.join(sandboxDir, 'lib', 'main.dart'),
      content: SandboxScaffold.main(feature: feature),
      generatedFiles: generatedFiles,
    );
    _write(
      sandboxDir: sandboxDir,
      path: p.join(sandboxDir, 'lib', 'router.dart'),
      content: SandboxScaffold.router(routes: scaffoldRoutes),
      generatedFiles: generatedFiles,
    );
    _write(
      sandboxDir: sandboxDir,
      path: p.join(sandboxDir, 'lib', 'di.dart'),
      content: SandboxScaffold.di(bindings: scaffoldBindings),
      generatedFiles: generatedFiles,
    );

    // Certified mock artifacts for every declared dependency — the 072
    // rail: one fake per row, carrying every declared member.
    for (final dependency in dependencies) {
      _write(
        sandboxDir: sandboxDir,
        path: p.join(sandboxDir, dependency.mockArtifact),
        content: certifiedFakeSource(dependency),
        generatedFiles: generatedFiles,
      );
    }

    // The feature's receipts travel: spec + tdd artifacts (journal,
    // registry, cycle log) so an agent in the sandbox needs nothing
    // from the host.
    final receipts = Directory(p.join(projectRoot, 'specs', feature));
    if (receipts.existsSync()) {
      for (final entity in receipts.listSync(recursive: true)) {
        if (entity is! File) continue;
        final rel = p.relative(entity.path, from: projectRoot);
        _write(
          sandboxDir: sandboxDir,
          path: p.join(sandboxDir, rel),
          content: entity.readAsStringSync(),
          generatedFiles: generatedFiles,
        );
      }
    }
  }

  /// The certified fake installed for a declared dependency row —
  /// carries every declared member so parity certifies it (072 rail).
  static String certifiedFakeSource(ManifestDependency dependency) {
    final buffer = StringBuffer()
      ..writeln(
        '// GENERATED — certified mock for ${dependency.dependency} '
        '(${dependency.kind}, ${dependency.priority}) (issue #961).',
      )
      ..writeln('//')
      ..writeln('// Declared contract: ${dependency.contract}')
      ..writeln('class Fake${_pascal(dependency.dependency)} {');
    for (final signature in declaredSignatures(dependency.contract)) {
      buffer
        ..writeln()
        ..writeln(
          '  dynamic ${signature.name}'
          '(${signature.params}) => throw UnsupportedError(',
        )
        ..writeln(
          "      'certified fake: bind a simulation for "
          '${dependency.dependency}.${signature.name} (issue #961)\');',
        );
    }
    buffer
      ..writeln()
      ..writeln('}');
    return buffer.toString();
  }

  /// Splits a declared contract into `(name, params)` signatures,
  /// splitting on signature boundaries (a `,` before `name(`), never
  /// inside parameter lists.
  static List<({String name, String params})> declaredSignatures(
    String contract,
  ) {
    final parts = contract
        .split(RegExp(r',\s*(?=[A-Za-z_][A-Za-z0-9_]*\s*\()'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    return [
      for (final part in parts)
        () {
          final arrow = part.indexOf('->');
          final head = (arrow >= 0 ? part.substring(0, arrow) : part).trim();
          final paren = head.indexOf('(');
          if (paren < 0) return (name: head, params: '');
          return (
            name: head.substring(0, paren).trim(),
            params: head.substring(paren + 1).replaceFirst(RegExp(r'\)\s*$'), ''),
          );
        }(),
    ];
  }

  static void _write({
    required String sandboxDir,
    required String path,
    required String content,
    required List<String> generatedFiles,
  }) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    generatedFiles.add(p.relative(file.path, from: sandboxDir));
  }
}

String _pascal(String raw) {
  final parts = raw
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return raw;
  return parts
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join();
}
