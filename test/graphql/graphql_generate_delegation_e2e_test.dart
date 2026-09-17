@Tags(['e2e'])
// Spec 1653-trim-heavy-deps (issue #1661) — the enabled-path end-to-end.
//
// Proves the maintainer's directive: with the graphql capability enabled
// and its companion resolvable, `zfa graphql generate` completes as a
// seamless zfa command — the core gate passes, delegates through the
// `ZfaExecutable` no-JIT seam to the companion's
// `bin/zuraffa_graphql.dart`, and the real generation flow runs.
//
// Issue #1690: the fixture is the DOCUMENTED `path:` install
// (`packages/zuraffa_graphql/README.md`) — a real `dart pub get` against
// relative path deps, so the project's `package_config.json` carries the
// RELATIVE rootUris pub actually writes (the pre-#1690 suite hand-wrote
// an absolute `file://` rootUri and masked the relative shape), and the
// companion compiles through the project's package config instead of an
// implicit `pub get` inside the candidate's own root. The spawned child
// is the genuine in-repo companion implementation, not a fake.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

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
  late Directory fixture;
  late String repoRoot;

  setUp(() {
    repoRoot = _repoRoot(Directory.current.path);
    fixture = Directory.systemTemp.createTempSync('graphql_delegate_');
    // The capability facet + the generation-plugin facet (both required:
    // the facet makes the gate pass, the default registers the command).
    File(p.join(fixture.path, '.zfa.json')).writeAsStringSync(
      jsonEncode({
        'capabilities': {'graphql': true},
        'plugins': {
          'defaults': {'graphql': true},
        },
      }),
    );
    // The documented path: install, verbatim shape: relative path deps to
    // the core and the companion, resolved by a REAL `dart pub get` (the
    // setUp below). Pub anchors relative rootUris at the package_config's
    // own directory — the shape issue #1690 §1 pins.
    //
    // The relative values are computed from the fixture's RESOLVED path:
    // pub canonicalizes the pubspec's directory before joining, and on
    // macOS `Directory.systemTemp` sits under `/var/folders/…`, one
    // symlink hop shallower than its `/private/var/folders/…` target — a
    // lexical `p.relative` then lands one level short and the resolve
    // fails with "package … doesn't exist" before the test begins.
    final fixtureBase = Directory(fixture.path).resolveSymbolicLinksSync();
    File(p.join(fixture.path, 'pubspec.yaml')).writeAsStringSync(
      'name: graphql_delegate_fixture\n'
      'publish_to: none\n'
      'environment:\n'
      '  sdk: ^3.11.0\n'
      'dependencies:\n'
      '  zuraffa:\n'
      '    path: ${p.relative(repoRoot, from: fixtureBase)}\n'
      '  zuraffa_graphql:\n'
      '    path: ${p.relative(p.join(repoRoot, 'packages', 'zuraffa_graphql'), from: fixtureBase)}\n',
    );
    // A minimal introspection schema (one Product type) — enough for the
    // generate flow to parse, plan, and emit.
    File(p.join(fixture.path, 'schema.json')).writeAsStringSync(
      jsonEncode({
        'data': {
          '__schema': {
            'types': [
              {
                'kind': 'OBJECT',
                'name': 'Product',
                'fields': [
                  {
                    'name': 'id',
                    'type': {
                      'kind': 'NON_NULL',
                      'name': null,
                      'ofType': {
                        'kind': 'SCALAR',
                        'name': 'ID',
                        'ofType': null,
                      },
                    },
                  },
                ],
              },
            ],
          },
        },
      }),
    );
  });

  tearDown(() {
    // The delegation runs the child with workingDirectory = fixture, so
    // restore the runner cwd for the rest of the suite.
    Directory.current = repoRoot;
    fixture.deleteSync(recursive: true);
  });

  test('A2: enabled + resolvable → zfa graphql generate completes '
      'through the companion (documented path: install, relative '
      'rootUris)', () async {
    // The real resolve — this is what a developer's terminal runs after
    // writing the pubspec above. The fixture's package_config.json is
    // then pub's genuine output: relative rootUris for the path deps.
    final pub = await Process.run(
      Platform.resolvedExecutable,
      ['pub', 'get'],
      workingDirectory: fixture.path,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    expect(
      pub.exitCode,
      0,
      reason:
          'dart pub get in the fixture — '
          '${pub.stdout}\n${pub.stderr}',
    );
    final config =
        jsonDecode(
              File(
                p.join(fixture.path, '.dart_tool', 'package_config.json'),
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final graphqlEntry = (config['packages'] as List)
        .whereType<Map<String, dynamic>>()
        .firstWhere((e) => e['name'] == 'zuraffa_graphql');
    expect(
      (graphqlEntry['rootUri'] as String).startsWith('file://'),
      isFalse,
      reason:
          'pub must write a RELATIVE rootUri for the relative path dep — '
          'the pre-#1690 fixture masked this shape with a hand-written '
          'file:// URI',
    );

    Directory.current = fixture.path;
    // Issue #1690 §2 at flow level: snapshot the companion package's CONTENT
    // (path + size) before the delegation. The old guard compared
    // `.dart_tool` EXISTENCE only — vacuous on any checkout where the
    // companion was already resolved, and blind to a rewrite inside an
    // existing one. The SDK's own entrypoint-root resolve is excluded from
    // the snapshot: `dart compile exe` writes `<candidate>/.dart_tool/
    // package{_config,_graph}.json` and `pubspec.lock` regardless of
    // `--packages=` (upstream, Dart 3.13.3, no suppressing switch). The
    // delegation's OWN outputs — the artifact, its cache slot, any other
    // file — must not appear.
    final companionRoot = Directory(
      p.join(repoRoot, 'packages', 'zuraffa_graphql'),
    );
    final companionBefore = _contentSnapshot(companionRoot);
    final out = await CliRunner(exitOnCompletion: false).runCapturing([
      'graphql',
      'generate',
      '--schema',
      p.join(fixture.path, 'schema.json'),
      '--output',
      'lib/graphql_generated',
    ]);

    expect(exitCode, 0, reason: out);
    expect(out, contains('✅ Generated'), reason: out);
    expect(
      Directory(p.join(fixture.path, 'lib', 'graphql_generated')).existsSync(),
      isTrue,
      reason: 'the companion generated into the project — output: $out',
    );
    // Issue #1690 §2 at flow level: the compiled companion lands in THIS
    // project's cache (per-project keying), not in the (hosted, in
    // production) candidate root — the content snapshot below is what
    // holds the delegation to that.
    final projectCache = Directory(
      p.join(fixture.path, '.dart_tool', 'zfa_cli_bin'),
    );
    expect(
      projectCache.existsSync() &&
          projectCache.listSync().any(
            (e) => p.basename(e.path).startsWith('zfa_exe'),
          ),
      isTrue,
      reason:
          'the companion artifact is cached in the CONSUMING project '
          '(per-project keying) — issue #1690 §2',
    );
    expect(
      _contentSnapshot(companionRoot),
      companionBefore,
      reason:
          'the delegation must keep its artifact and its cache slot out of '
          'the companion package (issue #1690 §2). The SDK\'s own '
          'candidate-root resolve — `pubspec.lock` and '
          '`.dart_tool/package{_config,_graph}.json` — is the only write '
          'this flow may cause there, and [_contentSnapshot] excludes it: '
          'it is upstream `dart compile exe` behavior with no suppressing '
          'flag',
    );
  });
}

/// Path → size for every file under [root], minus the SDK's own
/// candidate-root resolve outputs (`pubspec.lock`,
/// `.dart_tool/package_config.json`, `.dart_tool/package_graph.json`).
///
/// `dart compile exe` writes those at the ENTRYPOINT's package root when
/// that root has no up-to-date package config (the pub-cache shape) and no
/// switch suppresses it (issue #1690 §2 residual, Dart 3.13.3). Everything
/// else is the delegation's to keep out — including anything at all inside
/// `.dart_tool/`, where the pre-#1690 artifact used to land.
Map<String, int> _contentSnapshot(Directory root) {
  final snapshot = <String, int>{};
  for (final entity in root.listSync(recursive: true)) {
    if (entity is! File) continue;
    final rel = p.relative(entity.path, from: root.path);
    if (_isSdkResolveOutput(rel)) continue;
    snapshot[rel] = entity.lengthSync();
  }
  return snapshot;
}

bool _isSdkResolveOutput(String rel) =>
    rel == 'pubspec.lock' ||
    rel == p.join('.dart_tool', 'package_config.json') ||
    rel == p.join('.dart_tool', 'package_graph.json');
