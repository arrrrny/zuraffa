// SPEC 1136 lane 3 — MCP session replay from `McpSessionStore`
// (#1136 EPIC 5; builds on #1358's scenario-file replay).
//
// The agent's tool-call sequence is recorded INTO a persisted session
// (`.zfa/mcp_sessions/<id>.json`) via `McpSessionStore.appendCall`
// (and the v2 `session_record` tool during live sessions); `zfa mcp
// replay <session-id>` resolves the id in the store and re-executes
// the recorded calls against the REAL scaffolded server.
//
// Behaviors (test-list):
//   S1 — appendCall persists the call sequence to disk (fresh store
//        reads it back — not an in-memory cache artifact).
//   S2 — fromJson back-compat: a session without `calls` starts empty.
//   S3 — the v2 `session_record` tool appends a call through
//        handleV2ToolCall (the agent-side recording seam).
//   S4 — e2e: `zfa mcp replay <session-id>` (no file) resolves the
//        store, replays GREEN, and the receipt names
//        source=session-store.
//   S5 — e2e: a recorded session with no calls refuses honestly.
//   S6 — e2e: an unknown session id names what was looked up.

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/mcp/session_store.dart';
import 'package:zuraffa/src/mcp/v2_tools.dart';

import '../../helpers/cwd_mutex.dart';

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
  group('S1/S2/S3: session call recording (unit)', () {
    late Directory tempDir;
    late McpSessionStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('mcp_1136_unit');
      store = McpSessionStore(projectRoot: tempDir.path);
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('S1: appendCall persists the call sequence to disk', () async {
      await store.appendCall(
        'agent-1',
        tool: 'echo',
        arguments: {'message': 'hello'},
        expectContains: 'echo:hello',
      );
      await store.appendCall('agent-1', tool: 'ping');

      // A FRESH store over the same root reads the same calls back —
      // the sequence is durable session state, not a cache artifact.
      final fresh = McpSessionStore(projectRoot: tempDir.path);
      final calls = await fresh.callsOf('agent-1');
      expect(calls, hasLength(2));
      expect(calls.first['tool'], 'echo');
      expect(calls.first['arguments'], {'message': 'hello'});
      expect(calls.first['expect_contains'], 'echo:hello');
      expect(calls.last['tool'], 'ping');
      expect(calls.last.containsKey('expect_contains'), isFalse);
    });

    test('S2: a session without a calls key starts with no calls '
        '(back-compat)', () {
      final session = McpSession.fromJson({
        'id': 'legacy',
        'createdAt': '2026-09-18T00:00:00Z',
        'lastActiveAt': '2026-09-18T00:00:00Z',
        'state': {
          'subscribed': ['/lib'],
        },
      });
      expect(session.calls, isEmpty);
      expect(session.state['subscribed'], ['/lib']);
    });

    test('S2b: fromJson restores persisted calls', () {
      final session = McpSession.fromJson({
        'id': 's',
        'createdAt': '2026-09-18T00:00:00Z',
        'lastActiveAt': '2026-09-18T00:00:00Z',
        'state': {},
        'calls': [
          {
            'tool': 'echo',
            'arguments': {'message': 'hi'},
          },
        ],
      });
      expect(session.calls, hasLength(1));
      expect(session.calls.first['tool'], 'echo');
    });

    test('S3: the session_record v2 tool appends through the store', () async {
      final result = await handleV2ToolCall(
        toolName: 'session_record',
        args: {
          'sessionId': 'agent-live',
          'tool': 'echo',
          'arguments': {'message': 'recorded'},
          'expect_contains': 'echo:recorded',
        },
        projectRoot: tempDir.path,
        sessionStore: store,
      );
      final payload =
          jsonDecode((result!['content'] as List).first['text'] as String)
              as Map<String, dynamic>;
      expect(payload['success'], isTrue);
      expect(payload['sessionId'], 'agent-live');
      expect(payload['recorded'], 1);

      final calls = await store.callsOf('agent-live');
      expect(calls, hasLength(1));
      expect(calls.first['tool'], 'echo');

      // The tool list advertises the seam.
      final names = v2ToolDefinitions().map((t) => t['name']).toList();
      expect(names, contains('session_record'));
    });
  });

  group('S4/S5/S6: zfa mcp replay <session-id> (e2e)', () {
    late Directory root;
    late String originalCwd;

    setUp(() async {
      await CwdMutex.acquire();
      originalCwd = Directory.current.path;
      root = await Directory.systemTemp.createTemp('zfa-1136');
      Directory.current = root.path;
      File(
        '${root.path}/pubspec.yaml',
      ).writeAsStringSync('name: fixture_app\nenvironment:\n  sdk: ^3.0.0\n');
      final bin = File('${root.path}/bin/mcp_server.dart')
        ..createSync(recursive: true);
      bin.writeAsStringSync(fixtureServer);
    });

    tearDown(() async {
      Directory.current = originalCwd;
      await root.delete(recursive: true);
      CwdMutex.release();
    });

    Future<(int, String)> runReplay(String arg) async {
      final runner = CliRunner(exitOnCompletion: false);
      final output = await runner.runCapturing(['mcp', 'replay', arg]);
      return (exitCode, output);
    }

    test('S4: replay resolves the session id from McpSessionStore and '
        're-executes GREEN', () async {
      final store = McpSessionStore(projectRoot: root.path);
      await store.appendCall(
        'checkout-agent',
        tool: 'echo',
        arguments: {'message': 'pay'},
        expectContains: 'echo:pay',
      );
      await store.appendCall(
        'checkout-agent',
        tool: 'echo',
        arguments: {'message': 'done'},
        expectContains: 'echo:done',
      );

      final (code, output) = await runReplay('checkout-agent');
      expect(code, 0, reason: output);
      expect(output, contains('mcp-replay: session=checkout-agent'));
      expect(output, contains('ok=2 failed=0'));

      final receipt =
          jsonDecode(
                File(
                  '${root.path}/.zfa/receipts/mcp-replay-checkout-agent.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(receipt['source'], 'session-store');
      expect(receipt['session'], 'checkout-agent');
    });

    test('S5: a recorded session with no calls refuses honestly', () async {
      final store = McpSessionStore(projectRoot: root.path);
      final session = await store.getOrCreate('empty-session');
      await store.save(session);

      final (code, output) = await runReplay('empty-session');
      expect(code, 1, reason: output);
      expect(
        output,
        contains('session "empty-session" has no recorded tool calls'),
      );
    });

    test('S6: an unknown session id names what was looked up', () async {
      final (code, output) = await runReplay('no-such-session');
      expect(code, 2, reason: output);
      expect(output, contains('.zfa/mcp_sessions/no-such-session.json'));
    });
  });
}
