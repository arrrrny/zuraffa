// Spec 1653-trim-heavy-deps (issue #1661) — the lean-core dependency pin.
//
// U1: the core package's manifest declares none of the heavyweight
//     integration packages (graphql, gql, minio, opentelemetry) — a
//     core-only consumer's resolved graph must stop carrying them
//     (FR-001..003).
// U2: no file under `lib/` imports any of the four, and the public
//     barrel's export lines reference none of the moved heavy surfaces
//     (FR-004).
//
// This suite is the PERMANENT pin: a future manifest or import that
// reintroduces a heavy package fails the default lane, not a slow tier.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The heavyweight packages the issue names (the `...` is scoped to these
/// three stacks for this feature — see spec.md Assumptions).
const heavyPackages = {'graphql', 'gql', 'minio', 'opentelemetry'};

/// Barrel export paths (and the otel re-export) that must not appear in
/// `lib/zuraffa.dart` after the split — the moved heavy surfaces.
const heavyBarrelMarkers = [
  "export 'package:opentelemetry/",
  'core/minio_client.dart',
  'core/telemetry_hook.dart',
  'core/otel_tracer.dart',
  'core/otel_failure_reporter.dart',
  'client/graphql_client_factory.dart',
  'client/graphql_client_provider.dart',
  'client/subscription_stream.dart',
  'gql/documents_dart_generator.dart',
  'gql/graphql_document_builder.dart',
  'gql/naming_utils.dart',
  'preservers/gql_file_preserver.dart',
  'validators/graphql_validator.dart',
  'codegen/datasource_generator.dart',
  'codegen/di_generator.dart',
];

String _repoRoot(String from) {
  var dir = Directory(from).absolute.path;
  while (!File(p.join(dir, 'pubspec.yaml')).existsSync()) {
    final parent = p.dirname(dir);
    if (parent == dir) {
      throw StateError('repo root with pubspec.yaml not found above $from');
    }
    dir = parent;
  }
  return dir;
}

void main() {
  final root = _repoRoot(Directory.current.path);
  final pubspec = File(p.join(root, 'pubspec.yaml')).readAsStringSync();

  group('U1: the core manifest declares no heavy packages (FR-001..003)', () {
    for (final pkg in heavyPackages) {
      test('dependencies: does not contain $pkg', () {
        // The `dependencies:` block ends at the next top-level key
        // (`dev_dependencies:`, `executables:`, ...).
        final depsBlock =
            RegExp(
              r'^dependencies:\n((?:[ \t]+.*\n|\n)*?)(?=^\w|\z)',
              multiLine: true,
            ).firstMatch(pubspec)?.group(1) ??
            '';
        expect(
          depsBlock,
          isNot(contains(RegExp('^  $pkg:'))),
          reason:
              'issue #1661: $pkg is a heavyweight optional integration — '
              'it belongs to its companion package under packages/, not '
              'the core manifest',
        );
      });
    }
  });

  group('U2: no heavy imports under lib/ and no heavy barrel exports '
      '(FR-004)', () {
    test('no lib/ source imports a heavy package', () {
      final offenders = <String>[];
      for (final entity in Directory(
        p.join(root, 'lib'),
      ).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final content = entity.readAsStringSync();
        for (final pkg in heavyPackages) {
          if (content.contains("import 'package:$pkg/")) {
            offenders.add(
              '${p.relative(entity.path, from: root)} '
              '(package:$pkg)',
            );
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'issue #1661: heavy-backed code moved to companion packages '
            '(packages/zuraffa_graphql, packages/zuraffa_storage, '
            'packages/zuraffa_observability) — these files still import '
            'heavy packages:\n${offenders.join('\n')}',
      );
    });

    test('the public barrel exports no heavy surface', () {
      final barrel = File(
        p.join(root, 'lib', 'zuraffa.dart'),
      ).readAsStringSync();
      final offenders = heavyBarrelMarkers.where(barrel.contains).toList();
      expect(
        offenders,
        isEmpty,
        reason:
            'the barrel must not re-export moved heavy surfaces '
            '(FR-004) — found: ${offenders.join(', ')}',
      );
    });
  });
}
