@Tags(['regression', 'slow', 'e2e'])
library;

// SPEC 1132 / EPIC 1 lane 4 — the openwiki docs drift guard.
//
// `docs/openwiki/cli.md` is GENERATED from the live dispatcher
// (`tool/generate_openwiki_cli_docs.dart`; issue #1383: "regenerate,
// never hand-edit"). This suite keeps the doc honest: every command the
// LIVE `zfa --help` lists must have a `## `zfa <cmd>`` entry in the
// committed doc. A command added to the CLI without regenerating the
// docs fails here on the exact name — docs cannot drift behind the
// dispatcher again (the #1383 exit criterion).
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/docs/openwiki_cli_docs.dart';

import '../helpers/run_zfa_source.dart';

void main() {
  group('#1132 — docs/openwiki/cli.md tracks the live dispatcher', () {
    late String liveHelp;

    setUpAll(() async {
      await initZfaSourceBin();
      final result = await runZfaSource([
        '--help',
      ], workingDirectory: zfaProjectRoot);
      expect(result.exitCode, 0, reason: 'zfa --help must succeed');
      liveHelp = (result.stdout as String) + (result.stderr as String);
    });

    test('every live command has a documented entry', () async {
      final liveCommands = parseCommandNames(liveHelp);
      expect(
        liveCommands.length,
        greaterThan(12),
        reason:
            'the parser must see the WHOLE fleet — the 2026-09-17 audit '
            'found the generator stopping at 12 (first wrapped '
            'description); anything ≤ 12 means the wrap bug is back.',
      );

      final doc = File('docs/openwiki/cli.md');
      expect(doc.existsSync(), isTrue, reason: 'the openwiki CLI doc');
      final content = doc.readAsStringSync();
      final documented = RegExp(
        r'^## `zfa ([a-z0-9-]+)`$',
        multiLine: true,
      ).allMatches(content).map((m) => m.group(1)!).toSet();

      final undocumented =
          liveCommands.where((c) => !documented.contains(c)).toList()..sort();
      expect(
        undocumented,
        isEmpty,
        reason:
            'commands in the live dispatcher but NOT in '
            'docs/openwiki/cli.md — regenerate the doc: '
            'dart run tool/generate_openwiki_cli_docs.dart '
            '(${liveCommands.length} live commands, '
            '${documented.length} documented)',
      );
    });

    test('the documented set introduces no phantom commands', () async {
      final liveCommands = parseCommandNames(liveHelp).toSet();
      final content = File('docs/openwiki/cli.md').readAsStringSync();
      final documented = RegExp(
        r'^## `zfa ([a-z0-9-]+)`$',
        multiLine: true,
      ).allMatches(content).map((m) => m.group(1)!).toSet();

      final phantoms =
          documented.where((c) => !liveCommands.contains(c)).toList()..sort();
      expect(
        phantoms,
        isEmpty,
        reason:
            'commands documented but REMOVED from the dispatcher — a '
            'stale entry lies to readers; regenerate the doc.',
      );
    });
  });
}
