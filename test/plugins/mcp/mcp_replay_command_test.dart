// Issue #1358 — `zfa mcp replay <session-file>`: re-execute a committed
// JSON scenario of MCP tool calls against the REAL scaffolded
// `bin/mcp_server.dart` over the stdio JSON-RPC wire (spec
// 1358-mcp-replay-subcommand).
//
// Behaviors (test-list):
//   B1 — happy scenario: exit 0, `mcp-replay: ... ok=2 failed=0`, receipt.
//   B2 — unregistered tool → exit 1, verdict `missing-tool`.
//   B3 — unsatisfied expect_contains → exit 1, verdict `mismatch`.
//   B4 — unscaffolded project → exit 1 with the scaffold hint, no spawn.
//   B5 — missing scenario file → exit 2 with the usage line.
//   B6 — malformed scenario → exit 1 naming the file.
//   B7 — `zfa mcp --help` lists `replay`.

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

const fixtureServer = r'''
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  await for (final line in stdin
      .transform(utf8.decoder)
      .transform(const LineSplitter())) {
    if (line.trim().isEmpty) continue;
    final req = jsonDecode(line) as Map<String, dynamic>;
    final id = req['id'];
    final method = req['method'] as String?;
    if (method == 'initialize') {
      stdout.writeln(jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        'result': {
          'protocolVersion': '2024-11-05',
          'serverInfo': {'name': 'fixture-mcp', 'version': '1.0.0'},
        },
      }));
    } else if (method == 'tools/call') {
      final params = req['params'] as Map<String, dynamic>;
      final name = params['name'] as String;
      if (name == 'echo') {
        final args = params['arguments'] as Map<String, dynamic>? ?? {};
        stdout.writeln(jsonEncode({
          'jsonrpc': '2.0',
          'id': id,
          'result': {
            'content': [
              {'type': 'text', 'text': 'echo:${args['message'] ?? ''}'},
            ],
          },
        }));
      } else {
        stdout.writeln(jsonEncode({
          'jsonrpc': '2.0',
          'id': id,
          'error': {
            'code': -32602,
            'message': 'Unknown tool: $name',
          },
        }));
      }
    }
  }
}
''';

void main() {
  late Directory root;
  late String originalCwd;

  /// Seeds a scaffolded project: `bin/mcp_server.dart` (the fixture
  /// stdio server) + a no-dependency pubspec so `dart run` resolves.
  Future<void> seedScaffoldedProject() async {
    File(
      p0(root.path, 'pubspec.yaml'),
    ).writeAsStringSync('name: fixture_app\nenvironment:\n  sdk: ^3.0.0\n');
    final bin = File(p0(root.path, 'bin', 'mcp_server.dart'))
      ..createSync(recursive: true);
    bin.writeAsStringSync(fixtureServer);
  }

  Future<(int, String)> runReplay(String scenarioPath) async {
    final runner = CliRunner(exitOnCompletion: false);
    final output = await runner.runCapturing([
      'mcp',
      'replay',
      scenarioPath,
    ]);
    return (exitCode, output);
  }

  String writeScenario(Map<String, dynamic> scenario, {String name = 's.json'}) {
    final file = File(p0(root.path, name))
      ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(scenario));
    return file.path;
  }

  setUp(() async {
    originalCwd = Directory.current.path;
    root = await Directory.systemTemp.createTemp('zfa-1358');
    Directory.current = root.path;
    await seedScaffoldedProject();
  });

  tearDown(() async {
    Directory.current = originalCwd;
    await root.delete(recursive: true);
    exitCode = 0;
  });

  test('B1: a committed scenario replays GREEN against the real server',
      () async {
    final scenarioPath = writeScenario({
      'session': 'signin',
      'calls': [
        {
          'tool': 'echo',
          'arguments': {'message': 'hello'},
        },
        {
          'tool': 'echo',
          'arguments': {'message': 'world'},
          'expect_contains': 'echo:world',
        },
      ],
    });

    final (code, output) = await runReplay(scenarioPath);

    expect(code, 0, reason: output);
    expect(output, contains('mcp-replay: session=signin calls=2 ok=2 failed=0'));
    expect(
      File(p0(root.path, '.zfa', 'receipts', 'mcp-replay-signin.json'))
          .existsSync(),
      isTrue,
      reason: 'the proof-carrying receipt lands on disk',
    );
  });

  test('B2: a call to an unregistered tool is missing-tool (exit 1)',
      () async {
    final scenarioPath = writeScenario({
      'session': 'broken',
      'calls': [
        {'tool': 'ghost_tool'},
      ],
    });

    final (code, output) = await runReplay(scenarioPath);

    expect(code, 1, reason: output);
    expect(output, contains('missing-tool'));
    expect(output, contains('failed=1'));
  });

  test('B3: an unsatisfied expect_contains is mismatch (exit 1)', () async {
    final scenarioPath = writeScenario({
      'session': 'mismatch',
      'calls': [
        {
          'tool': 'echo',
          'arguments': {'message': 'hello'},
          'expect_contains': 'echo:absent-substring',
        },
      ],
    });

    final (code, output) = await runReplay(scenarioPath);

    expect(code, 1, reason: output);
    expect(output, contains('mismatch'));
  });

  test('B4: an unscaffolded project refuses before spawning', () async {
    await File(p0(root.path, 'bin', 'mcp_server.dart')).delete();
    final scenarioPath = writeScenario({
      'session': 's',
      'calls': [],
    });

    final (code, output) = await runReplay(scenarioPath);

    expect(code, 1, reason: output);
    expect(output, contains('zfa mcp scaffold'));
  });

  test('B5: a missing scenario file is a usage error (exit 2)', () async {
    final (code, output) = await runReplay('does-not-exist.json');

    expect(code, 2, reason: output);
    expect(output, contains('Usage'));
  });

  test('B6: a malformed scenario names the file (exit 1)', () async {
    final scenarioPath = File(p0(root.path, 'broken.json'))
      ..writeAsStringSync('{ not json');

    final (code, output) = await runReplay(scenarioPath.path);

    expect(code, 1, reason: output);
    expect(output, contains('broken.json'));
  });

  test('B7: --help lists replay', () async {
    final runner = CliRunner(exitOnCompletion: false);
    final output = await runner.runCapturing(['mcp', '--help']);
    expect(output, contains('replay'));
  });
}

/// p.join without importing path (kept local to the fixture).
String p0(String a, [String? b, String? c, String? d]) {
  var out = a;
  for (final part in [b, c, d]) {
    if (part != null) out = '$out/$part';
  }
  return out;
}
