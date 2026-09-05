@Tags(['slow'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:path/path.dart' as p;

import '../helpers/project_root.dart';

late String _fixturesDir;

void main() {
  setUpAll(() async {
    _fixturesDir = p.join(await findProjectRoot(), 'test', 'fixtures');
  });

  late CliRunner runner;
  late Directory tempDir;
  HttpServer? server;
  late Map<String, dynamic> fixture;

  setUp(() async {
    runner = CliRunner(exitOnCompletion: false);
    tempDir = Directory.systemTemp.createTempSync('zfa_pull_cmd_');
    fixture =
        jsonDecode(
              File(
                p.join(
                  _fixturesDir,
                  'graphql',
                  'vendure_shop_introspection_v1.json',
                ),
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    exitCode = 0;
  });

  tearDown(() async {
    exitCode = 0;
    await server?.close(force: true);
    tempDir.deleteSync(recursive: true);
  });

  Future<HttpServer> serve(Future<void> Function(HttpRequest) handler) async {
    final srv = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server = srv;
    srv.listen((request) async {
      try {
        await handler(request);
      } catch (_) {
        // test handler failure — close response anyway
      }
      await request.response.close();
    });
    return srv;
  }

  group('zfa graphql pull (CLI)', () {
    test('pull writes both artifacts within 10s (SC-001)', () async {
      final srv = await serve((request) async {
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(fixture));
      });
      final dir = '${tempDir.path}/.zfa/graphql';

      final sw = Stopwatch()..start();
      final output = await runner.runCapturing([
        'graphql',
        'pull',
        '--endpoint=http://127.0.0.1:${srv.port}/graphql',
        '--name=vendure',
        '--dir=$dir',
      ]);
      sw.stop();

      expect(sw.elapsed, lessThan(const Duration(seconds: 10)));
      expect(output, contains('vendure'));

      expect(
        File('$dir/vendure/vendure.schema.json').existsSync(),
        true,
        reason: 'introspection json not written',
      );
      expect(
        File('$dir/vendure/vendure.schema.graphql').existsSync(),
        true,
        reason: 'SDL not written',
      );
      expect(File('$dir/vendure.schema.json').existsSync(), true);
      expect(File('$dir/vendure.schema.graphql').existsSync(), true);

      final sdl = File(
        '$dir/vendure/vendure.schema.graphql',
      ).readAsStringSync();
      expect(sdl, contains('type Product implements Node'));
    });

    test('server 500 -> clear error, no files, non-zero exit', () async {
      final srv = await serve((request) async {
        request.response.statusCode = 500;
        request.response.write('boom');
      });
      final dir = '${tempDir.path}/.zfa/graphql';
      final output = await runner.runCapturing([
        'graphql',
        'pull',
        '--endpoint=http://127.0.0.1:${srv.port}/graphql',
        '--name=vendure',
        '--dir=$dir',
      ]);
      expect(output.toLowerCase(), contains('error'));
      expect(output, contains('500'));
      expect(File('$dir/vendure.schema.json').existsSync(), false);
      expect(File('$dir/vendure/vendure.schema.json').existsSync(), false);
      expect(exitCode, 1);
    });

    test('graphql errors body -> error names the failing part', () async {
      final srv = await serve((request) async {
        request.response.statusCode = 200;
        request.response.write(
          jsonEncode({
            'data': null,
            'errors': [
              {
                'message': 'Introspection disabled',
                'path': ['__schema'],
              },
            ],
          }),
        );
      });
      final dir = '${tempDir.path}/.zfa/graphql';
      final output = await runner.runCapturing([
        'graphql',
        'pull',
        '--endpoint=http://127.0.0.1:${srv.port}/graphql',
        '--name=vendure',
        '--dir=$dir',
      ]);
      expect(output, contains('Introspection disabled'));
      expect(File('$dir/vendure.schema.json').existsSync(), false);
      expect(exitCode, 1);
    });

    test('unreachable endpoint -> clear error, no files', () async {
      // Bind then close to get an unused port that nothing listens on.
      final probe = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final deadPort = probe.port;
      await probe.close();
      final dir = '${tempDir.path}/.zfa/graphql';
      final output = await runner.runCapturing([
        'graphql',
        'pull',
        '--endpoint=http://127.0.0.1:$deadPort/graphql',
        '--name=vendure',
        '--dir=$dir',
      ]);
      expect(output.toLowerCase(), contains('error'));
      expect(File('$dir/vendure.schema.json').existsSync(), false);
      expect(exitCode, 1);
    });

    test('missing --endpoint prints usage guidance', () async {
      final output = await runner.runCapturing([
        'graphql',
        'pull',
        '--name=vendure',
        '--dir=${tempDir.path}/.zfa/graphql',
      ]);
      expect(
        output.toLowerCase(),
        anyOf(contains('endpoint'), contains('usage')),
      );
    });

    test('pull is listed in zfa graphql help', () async {
      final output = await runner.runCapturing(['graphql', '--help']);
      expect(output, contains('pull'));
      expect(output, contains('diff'));
    });
  });
}
