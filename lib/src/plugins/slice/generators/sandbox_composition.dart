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

import '_pascal_case.dart';
import 'sandbox_scaffold.dart';
import '../../../domain/entities/feature_contract/feature_contract_decorators.dart';
import '../models/slice_manifest.dart';

/// Composes the runnable sandbox over a cut tree.
class SandboxComposition {
  /// Creates the composer (stateless; injectable only for tests).
  const SandboxComposition();

  /// Emit `lib/main.dart`, `lib/router.dart`, `lib/di.dart`, one
  /// certified fake per declared dependency, and the feature's receipts
  /// (`specs/<feature>/**`) into [sandboxDir]. Appends every written
  /// path to [generatedFiles] (manifest bookkeeping).
  ///
  /// Spec 1098: when [feature] is set, every emitted harness artifact is
  /// stamped with the `@FeatureOwned('<feature>')` comment decorator so
  /// the ownership knowledge survives round-trips through hand-edits,
  /// re-generation and xray scans — read back by
  /// `FeatureContractDecorators.scan`, not guessed from path conventions.
  void compose({
    required String projectRoot,
    required String sandboxDir,
    required String feature,
    required List<ManifestRoute> routes,
    required List<ManifestDependency> dependencies,
    required List<String> generatedFiles,
  }) {
    final scaffoldRoutes = [
      for (final route in routes)
        SandboxRoute(path: route.path, page: route.page),
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
      content: _withFeatureDecorator(
        feature: feature,
        source: SandboxScaffold.main(feature: feature),
      ),
      generatedFiles: generatedFiles,
    );
    _write(
      sandboxDir: sandboxDir,
      path: p.join(sandboxDir, 'lib', 'router.dart'),
      content: _withFeatureDecorator(
        feature: feature,
        source: SandboxScaffold.router(routes: scaffoldRoutes),
      ),
      generatedFiles: generatedFiles,
    );
    _write(
      sandboxDir: sandboxDir,
      path: p.join(sandboxDir, 'lib', 'di.dart'),
      content: _withFeatureDecorator(
        feature: feature,
        source: SandboxScaffold.di(bindings: scaffoldBindings),
      ),
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

  /// Stamps the `@FeatureOwned` decorator onto [source] when [feature] is
  /// non-empty (spec 1098). Deterministic: identical inputs yield
  /// byte-identical output (FR-007).
  static String _withFeatureDecorator({
    required String? feature,
    required String source,
  }) {
    if (feature == null || feature.isEmpty) return source;
    return '${FeatureContractDecorators.ownedLine(feature)}\n$source';
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
      ..writeln('class Fake${pascalCase(dependency.dependency)} {');
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
            params: head
                .substring(paren + 1)
                .replaceFirst(RegExp(r'\)\s*$'), ''),
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
