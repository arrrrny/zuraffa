// T002 (issue #970, FR-002 / AC-2): `--json` output mode on
// `zfa mock create|data|json`.
//
// RED evidence (pre-fix master): `--json` on the auto-registered `create`
// subcommand is an INPUT option (a JSON args string), so `zfa mock create
// Product --json` dies with "Missing argument for --json" (UsageException);
// `data` and `json` have no `--json` flag at all. No envelope is ever
// printed.
//
// Contract pinned here (remediation): on success the `--json` invocation
// prints EXACTLY one machine envelope on stdout — every other diagnostic
// goes to stderr — with the exact key set
// `{files, actions, fixturesDir, certification, schema}` and `schema == 1`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  late Directory tempDir;
  var exitCodeAtEntry = 0;

  setUp(() async {
    exitCodeAtEntry = exitCode;
    tempDir = await Directory.systemTemp.createTemp('mock_json_out_970_');
  });

  tearDown(() async {
    exitCode = exitCodeAtEntry;
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<String> runCli(List<String> args) async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing(['-C', tempDir.path, ...args]);
  }

  /// The exact envelope contract (issue #970 order 2):
  /// `{files[], actions, fixturesDir, certification, schema:1}`.
  void expectEnvelope(Object? decoded) {
    expect(
      decoded,
      isA<Map<String, dynamic>>(),
      reason: 'the envelope must be a JSON object',
    );
    final envelope = decoded! as Map<String, dynamic>;
    expect(envelope.keys.toSet(), {
      'schema',
      'files',
      'actions',
      'fixturesDir',
      'certification',
    }, reason: 'the envelope key set is the published contract');
    expect(envelope['schema'], 1, reason: 'envelope schema version is 1');

    // files[]: one entry per emitted file, exactly {path, action, type}.
    final files = envelope['files'];
    expect(files, isA<List<dynamic>>());
    expect(
      (files! as List).isNotEmpty,
      isTrue,
      reason: 'a successful generation emits at least one file',
    );
    for (final entry in files as List) {
      expect(entry, isA<Map<String, dynamic>>());
      expect((entry! as Map).keys.toSet(), {
        'path',
        'action',
        'type',
      }, reason: 'every files[] entry is {path, action, type}');
    }

    // actions: per-action counts.
    final actions = envelope['actions'];
    expect(actions, isA<Map<String, dynamic>>());
    expect((actions! as Map).keys.toSet(), {
      'created',
      'overwritten',
      'updated',
      'skipped',
      'deleted',
    }, reason: 'actions carries the canonical action counts');
    for (final value in (actions as Map).values) {
      expect(value, isA<int>(), reason: 'action counts are integers');
    }

    // fixturesDir: where the mock fixtures for this run live.
    expect(envelope['fixturesDir'], isA<String>());

    // certification: the mock-certification record (issue #970 order 3).
    final certification = envelope['certification'];
    expect(certification, isA<Map<String, dynamic>>());
    expect((certification! as Map).keys.toSet(), {
      'registryId',
      'interface',
      'interfaceMethods',
      'implementedMethods',
      'conformance',
      'receipt',
    }, reason: 'the certification sub-object is the published contract');
    final cert = certification as Map<String, dynamic>;
    expect(cert['conformance'], isA<bool>());
    expect(cert['interfaceMethods'], isA<List<dynamic>>());
    expect(cert['implementedMethods'], isA<List<dynamic>>());
    expect(cert['registryId'], isA<String>());
  }

  test(
    'A2: zfa mock create Product --json prints the exact envelope schema',
    () async {
      await _scaffoldProduct(tempDir.path);
      final out = await runCli(['mock', 'create', 'Product', '--json']);
      exitCode = exitCodeAtEntry;

      // stdout is EXACTLY the envelope: the whole captured output must be
      // one parseable JSON document (diagnostics went to stderr).
      final Object? decoded;
      try {
        decoded = jsonDecode(out);
      } on FormatException catch (e) {
        fail('--json stdout must be a single JSON document, got:\n$out\n$e');
      }
      expectEnvelope(decoded);

      final envelope = decoded! as Map<String, dynamic>;
      final files = (envelope['files']! as List).cast<Map<String, dynamic>>();
      expect(
        files.any(
          (f) =>
              f['path'] == 'lib/src/data/mock/product_mock_data.dart' &&
              f['type'] == 'mock_data',
        ),
        isTrue,
        reason: 'the Product fixture is in the envelope',
      );
      expect(envelope['fixturesDir'], 'lib/src/data/mock');
      final cert = envelope['certification']! as Map<String, dynamic>;
      expect(
        cert['interface'],
        'lib/src/data/datasources/product/product_datasource.dart',
        reason: 'entity mode certifies against the datasource interface',
      );
      expect((cert['interfaceMethods']! as List).toSet(), {
        'get',
        'update',
        'toggle',
      }, reason: 'the interface methods are the default CRUD surface');
      expect((cert['implementedMethods']! as List).toSet(), {
        'get',
        'update',
        'toggle',
      });
      expect(cert['conformance'], isTrue);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'A3a: zfa mock data Product --json prints the same envelope schema',
    () async {
      await _scaffoldProduct(tempDir.path);
      final out = await runCli(['mock', 'data', 'Product', '--json']);
      exitCode = exitCodeAtEntry;

      final decoded = jsonDecode(out);
      expectEnvelope(decoded);
      final envelope = decoded! as Map<String, dynamic>;
      expect(envelope['fixturesDir'], 'lib/src/data/mock');
      final cert = envelope['certification']! as Map<String, dynamic>;
      expect(
        cert['interface'],
        isNull,
        reason: 'data-only mode certifies fixtures, not an interface',
      );
      expect(
        cert['conformance'],
        isTrue,
        reason: 'vacuously conforming: no interface to satisfy',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'A3b: zfa mock json Product --json prints the same envelope schema',
    () async {
      await _scaffoldProduct(tempDir.path);
      final out = await runCli(['mock', 'json', 'Product', '--json']);
      exitCode = exitCodeAtEntry;

      final decoded = jsonDecode(out);
      expectEnvelope(decoded);
      final envelope = decoded! as Map<String, dynamic>;
      expect(
        envelope['fixturesDir'],
        'lib/src/data/mock_json/product',
        reason: 'json mode fixtures land under data/mock_json/<domain>',
      );
      final files = (envelope['files']! as List).cast<Map<String, dynamic>>();
      expect(
        files.any(
          (f) =>
              (f['path']! as String).endsWith('product.mock.json') &&
              f['type'] == 'mock_json',
        ),
        isTrue,
        reason: 'the .mock.json fixture is in the envelope',
      );
      final cert = envelope['certification']! as Map<String, dynamic>;
      expect(cert['conformance'], isTrue);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'A2b: --json failure path keeps a non-zero exit code (no lying exit 0)',
    () async {
      // No entity scaffolded: the generation cannot produce anything for a
      // missing entity — the refusal must not dress up as success.
      final out = await runCli(['mock', 'data', 'NoSuchEntity', '--json']);
      expect(exitCode, 1, reason: 'a failed generation exits 1');
      expect(
        out,
        isNot(contains('"schema": 1')),
        reason: 'no success envelope on failure',
      );
      exitCode = exitCodeAtEntry;
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

/// Scaffolds a minimal Product entity at the canonical v5 location so the
/// mock generators can resolve it.
Future<void> _scaffoldProduct(String root) async {
  final dir = Directory(
    p.join(root, 'lib', 'src', 'domain', 'entities', 'product'),
  );
  await dir.create(recursive: true);
  await File(p.join(dir.path, 'product.dart')).writeAsString('''
class Product {
  final String id;
  final String name;
  const Product({required this.id, required this.name});
}
''');
}
