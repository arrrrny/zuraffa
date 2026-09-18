library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/docs/openwiki_cli_docs.dart';

/// SPEC 1132 / EPIC 1 lane 4 — the openwiki docs generator must be able
/// to regenerate (issue #1383's contract: "regenerate, never hand-edit").
///
/// The 2026-09-17 audit: command descriptions grew past the CLI's
/// 120-column `kUsageLineLength`, so `zfa --help` wraps descriptions
/// onto continuation lines; the generator's line-anchored regex stopped
/// at the first wrapped description (corpus) and "generated" a
/// 12-command doc — silently clobbering the committed 59-command file.
/// The docs cannot be refreshed after any command-surface change.
///
/// This suite pins the parser (pure function, shared by the tool and the
/// drift guard) and the committed doc's self-consistency.
void main() {
  group('SPEC 1132 L4 — the command-list parser handles wrapped help', () {
    test('parses all commands when descriptions wrap (the corpus case)', () {
      // Fixture: the exact wrapping shape `zfa --help` emits today —
      // the `corpus` entry wraps onto a continuation line at the
      // 120-column usage width (kUsageLineLength).
      const help = '''
Available commands:
  agent               Agent runtime (shell daemon, leases, missions, budgets)
  api                 Generate API bridge for a Zuraffa entity
  benchmark           Run, list, and compare Zuraffa benchmarks (metric-driven quality gates).
  bone                Generate, export, and validate feature bones for delegated agent builds.
  cli                 Generate a standardized CLI command for an entity (FR-011)
  config              Manage ZFA configuration
  corpus              Import and walk an extracted spec corpus: import, catalog (CORE/SKIN), run (failure budget),
                      ledger (merge gate). See specs/050-corpus-import and specs/076-corpus-walk for the contracts.
  create              Create architecture folders or pages
  datasource          Generate DataSources
  migrate             Migrate v5 artifacts to v6 equivalents (state, gql, di).
''';

      final names = parseCommandNames(help);

      expect(
        names,
        containsAllInOrder([
          'agent',
          'api',
          'benchmark',
          'bone',
          'cli',
          'config',
          'corpus',
          'create',
          'datasource',
          'migrate',
        ]),
        reason:
            'a wrapped description (corpus) must not terminate the '
            'command list — the parser must consume continuation lines',
      );
    });

    test('a wrapped description is never mistaken for a command name', () {
      const help = '''
Available commands:
  corpus              Import and walk an extracted spec corpus: import, catalog (CORE/SKIN), run (failure budget),
                      ledger (merge gate). See specs/050-corpus-import and specs/076-corpus-walk for the contracts.
  doctor              Show information about the installed tooling and v5 migration readiness.
''';
      final names = parseCommandNames(help);
      expect(names, ['corpus', 'doctor']);
      expect(
        names,
        isNot(contains('ledger')),
        reason: 'continuation text is not a command row',
      );
    });

    test('an empty or command-less block returns an empty list', () {
      expect(parseCommandNames('Zuraffa Code Generator'), isEmpty);
      expect(parseCommandNames(''), isEmpty);
      expect(parseCommandNames('Available commands:\n'), isEmpty);
    });

    test('parses the full live fleet shape (no early break)', () {
      // The regression the audit found: the parser stops after 12
      // commands. A help block with MANY wrapped entries must yield
      // every one.
      final buffer = StringBuffer('Available commands:\n');
      for (var i = 0; i < 40; i++) {
        buffer
          ..writeln(
            '  cmd$i              Command $i with a long description that '
            'certainly exceeds the wrap',
          )
          ..writeln(
            '                      width and therefore lands on a second '
            'continuation line.',
          );
      }
      final names = parseCommandNames(buffer.toString());
      expect(names, hasLength(40));
      expect(names.first, 'cmd0');
      expect(names.last, 'cmd39');
    });
  });

  group('SPEC 1132 L4 — the committed openwiki doc is self-consistent', () {
    final doc = File('docs/openwiki/cli.md');
    final content = doc.existsSync() ? doc.readAsStringSync() : '';

    test('docs/openwiki/cli.md exists and documents the fleet floor', () {
      expect(doc.existsSync(), isTrue, reason: 'the openwiki CLI doc');
      final entries = RegExp(
        r'^## `zfa ([a-z0-9-]+)`$',
        multiLine: true,
      ).allMatches(content).map((m) => m.group(1)!).toList();
      expect(
        entries.length,
        greaterThanOrEqualTo(50),
        reason:
            'the fleet floor: the doc must keep documenting the whole '
            'command fleet (found ${entries.length})',
      );
      expect(
        entries.toSet().length,
        entries.length,
        reason: 'no duplicate command entries',
      );
    });

    test('the header registry count matches the entry count', () {
      final match = RegExp(
        r'Registry: \*\*(\d+) commands\*\*',
      ).firstMatch(content);
      expect(match, isNotNull, reason: 'the header carries the count');
      final declared = int.parse(match!.group(1)!);
      final entries = RegExp(
        r'^## `zfa ([a-z0-9-]+)`$',
        multiLine: true,
      ).allMatches(content).length;
      expect(
        entries,
        declared,
        reason:
            'the header says $declared commands; the body documents '
            '$entries — the count must never drift from the entries',
      );
    });
  });
}
