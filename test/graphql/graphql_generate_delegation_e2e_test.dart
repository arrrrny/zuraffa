@Tags(['e2e'])
// Spec 1653-trim-heavy-deps (issue #1661) — the enabled-path end-to-end.
//
// Proves the maintainer's directive: with the graphql capability enabled
// and its companion resolvable, `zfa graphql generate` completes as a
// seamless zfa command — the core gate passes, delegates through the
// `ZfaExecutable` no-JIT seam to the companion's
// `bin/zuraffa_graphql.dart`, and the real generation flow runs.
//
// The fixture's `package_config.json` points `zuraffa_graphql` at THIS
// repo's real companion package, so the spawned child is the genuine
// implementation, not a fake.
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
    // Resolvable: the project's package_config maps the companion to the
    // REAL in-repo package (the spawn compiles inside that root).
    final dotTool = Directory(p.join(fixture.path, '.dart_tool'))
      ..createSync(recursive: true);
    File(p.join(dotTool.path, 'package_config.json')).writeAsStringSync(
      jsonEncode({
        'configVersion': 2,
        'packages': [
          {
            'name': 'zuraffa_graphql',
            'rootUri': Uri.file(
              p.join(repoRoot, 'packages', 'zuraffa_graphql'),
            ).toString(),
            'languageVersion': '3.11',
          },
        ],
      }),
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
      'through the companion', () async {
    Directory.current = fixture.path;
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
  });
}
