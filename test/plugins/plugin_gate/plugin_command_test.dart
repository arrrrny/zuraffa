// Spec 1653-trim-heavy-deps (issue #1661) — the `zfa plugin` command pins.
//
// U5: `zfa plugin enable <name>` persists `capabilities.<name>: true` in
//     the project's `.zfa.json` ADDITIVELY (every other key untouched)
//     and is idempotent — re-enabling succeeds as an explicit no-op.
//     Disabling persists the false state.
// U7: `zfa plugin list` renders one line per capability with name /
//     enabled / backing package / resolvable, and ALWAYS exits 0 —
//     listing is never a failure, even with no `.zfa.json` at all.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('plugin_command_');
    addTearDown(() => tmp.deleteSync(recursive: true));
  });

  Future<String> drive(List<String> args) async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing([...args, '--root', tmp.path]);
  }

  Map<String, dynamic> readConfig() =>
      jsonDecode(File(p.join(tmp.path, '.zfa.json')).readAsStringSync())
          as Map<String, dynamic>;

  group('U5: enable persists capabilities additively (FR-006)', () {
    test(
      'enable writes capabilities.<name>: true, preserving other keys',
      () async {
        File(
          p.join(tmp.path, '.zfa.json'),
        ).writeAsStringSync(jsonEncode({'formatByDefault': true}));

        final out = await drive(['plugin', 'enable', 'graphql']);

        expect(exitCode, 0, reason: out);
        final config = readConfig();
        expect(
          (config['capabilities'] as Map<String, dynamic>)['graphql'],
          true,
          reason: out,
        );
        expect(
          config['formatByDefault'],
          true,
          reason: 'the write must be additive — other keys untouched',
        );
      },
    );

    test(
      're-enabling an enabled plugin is an explicit no-op success',
      () async {
        await drive(['plugin', 'enable', 'graphql']);
        final out = await drive(['plugin', 'enable', 'graphql']);

        expect(exitCode, 0, reason: out);
        expect(out, contains('already enabled'), reason: out);
        final config = readConfig();
        expect(
          (config['capabilities'] as Map<String, dynamic>)['graphql'],
          true,
        );
      },
    );

    test('an unknown id refuses non-zero naming the catalog', () async {
      final out = await drive(['plugin', 'enable', 'nope']);

      expect(exitCode, isNot(0), reason: out);
      expect(out, contains('graphql'), reason: out);
      expect(out, contains('observability'), reason: out);
      expect(
        File(p.join(tmp.path, '.zfa.json')).existsSync(),
        isFalse,
        reason: 'a refused enable must not fabricate a config file',
      );
    });

    test('disable persists the false state', () async {
      await drive(['plugin', 'enable', 'storage']);
      final out = await drive(['plugin', 'disable', 'storage']);

      expect(exitCode, 0, reason: out);
      final config = readConfig();
      expect(
        (config['capabilities'] as Map<String, dynamic>)['storage'],
        false,
      );
    });
  });

  group('U7: plugin list renders the catalog (FR-005)', () {
    test('lists every capability with package and state, exit 0, even '
        'with no .zfa.json', () async {
      final out = await drive(['plugin', 'list']);

      expect(exitCode, 0, reason: out);
      expect(out, contains('graphql'), reason: out);
      expect(out, contains('storage'), reason: out);
      expect(out, contains('observability'), reason: out);
      expect(out, contains('zuraffa_graphql'), reason: out);
      expect(out, contains('zuraffa_storage'), reason: out);
      expect(out, contains('zuraffa_observability'), reason: out);
      expect(out, contains('disabled'), reason: out);
    });

    test('reflects enablement in the state column', () async {
      await drive(['plugin', 'enable', 'observability']);
      final out = await drive(['plugin', 'list']);

      expect(exitCode, 0, reason: out);
      final observabilityLine = out
          .split('\n')
          .firstWhere((line) => line.contains('observability'));
      expect(observabilityLine, contains('enabled'));
      expect(observabilityLine, isNot(contains('disabled')));
    });
  });
}
