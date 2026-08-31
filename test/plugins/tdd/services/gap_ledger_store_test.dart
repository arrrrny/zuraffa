// Tests for GapLedgerStore (spec 051-corpus-harness, U12-U14): the
// append-only gap ledger at `.zfa/corpus/gap-ledger.json`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/corpus_ledger.dart';
import 'package:zuraffa/src/plugins/tdd/models/corpus_progress.dart';
import 'package:zuraffa/src/plugins/tdd/services/gap_ledger_store.dart';

void main() {
  late Directory root;
  late GapLedgerStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('corpus_ledger_');
    store = GapLedgerStore(root.path);
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  group('GapLedgerStore (U12)', () {
    test(
      'appending a gap produces a monotonic id and the complete entry',
      () async {
        final first = await store.appendGap(
          feature: 'f2-gap',
          behavior: 'B-002',
          step: 'run',
          outcome: 'stopped',
          failingCommand: 'zfa tdd run f2-gap --project /app',
        );
        expect(first.id, 'gap-001');
        expect(first.kind, GapLedgerKind.gap);
        expect(first.at, isNotEmpty);
        expect(first.issueLink, isNull, reason: 'the placeholder starts null');
        expect(first.status, 'open');

        final second = await store.appendGap(
          feature: 'f3-gap',
          step: 'verify',
          outcome: 'not_assessed',
          failingCommand: 'zfa tdd verify --feature f3-gap',
        );
        expect(second.id, 'gap-002');

        final reloaded = await store.load();
        expect(reloaded, hasLength(2));
        expect(reloaded.first.feature, 'f2-gap');
        expect(reloaded.first.behavior, 'B-002');
        expect(reloaded.first.failingCommand, contains('tdd run'));
      },
    );

    test('an absent ledger loads as empty', () async {
      expect(await store.load(), isEmpty);
    });

    test('a corrupt ledger is a corrupt-state stop naming the file', () async {
      final file = File(store.path);
      await file.parent.create(recursive: true);
      await file.writeAsString('[{nonsense');
      expect(
        () => store.load(),
        throwsA(
          isA<CorpusCorruptException>().having(
            (e) => e.message,
            'message',
            allOf(contains('gap-ledger.json'), contains('Recovery')),
          ),
        ),
      );
    });
  });

  group('GapLedgerStore (U13)', () {
    test(
      'appends never modify prior entries and the file stays decodable',
      () async {
        await store.appendGap(
          feature: 'f1',
          step: 'run',
          outcome: 'stopped',
          failingCommand: 'zfa tdd run f1',
        );
        final afterFirst = await File(store.path).readAsString();
        final firstEntries = await store.load();

        await store.appendGap(
          feature: 'f2',
          step: 'verify',
          outcome: 'fail_survived',
          failingCommand: 'zfa tdd verify --feature f2',
        );
        final afterSecond = await File(store.path).readAsString();

        // The first entry's serialized block survives byte-identical.
        final firstBlock = _entryBlock(afterFirst);
        expect(afterSecond, contains(firstBlock));
        // The file decodes as JSON after every append.
        expect(jsonDecode(afterSecond), isA<List<dynamic>>());
        // And the reloaded first entry is unchanged.
        final reloaded = await store.load();
        expect(reloaded.first.toJson(), firstEntries.first.toJson());
      },
    );
  });

  group('GapLedgerStore (U14)', () {
    test(
      'a resolution appends with resolves and the gap is untouched',
      () async {
        final gap = await store.appendGap(
          feature: 'f2-gap',
          step: 'run',
          outcome: 'stopped',
          failingCommand: 'zfa tdd run f2-gap',
        );
        final gapBlock = _entryBlock(await File(store.path).readAsString());

        final resolution = await store.appendResolution(
          feature: 'f2-gap',
          resolves: gap.id,
        );
        expect(resolution.kind, GapLedgerKind.resolution);
        expect(resolution.resolves, 'gap-001');
        expect(resolution.id, 'res-001');

        final content = await File(store.path).readAsString();
        expect(content, contains(gapBlock), reason: 'the gap is never edited');
        final entries = await store.load();
        expect(entries, hasLength(2));
        expect(
          entries.first.status,
          'open',
          reason: 'gap stays open-as-written',
        );
        expect(entries.last.resolves, 'gap-001');
      },
    );
  });

  group('GapLedgerStore (T036 — injected clock)', () {
    test(
      'an injected fixed clock stamps every appended entry deterministically',
      () async {
        final fixed = DateTime.utc(2026, 8, 31, 12, 0, 0);
        final clockStore = GapLedgerStore(root.path, clock: () => fixed);
        final gap = await clockStore.appendGap(
          feature: 'f2-gap',
          step: 'run',
          outcome: 'stopped',
          failingCommand: 'zfa tdd run f2-gap',
        );
        expect(
          gap.at,
          '2026-08-31T12:00:00.000Z',
          reason: 'the entry timestamp comes from the injected clock',
        );
        final resolution = await clockStore.appendResolution(
          feature: 'f2-gap',
          resolves: gap.id,
        );
        expect(
          resolution.at,
          '2026-08-31T12:00:00.000Z',
          reason: 'resolution entries take the same clock',
        );
        // The persisted JSON carries the fixed stamp too (future
        // timestamp assertions stay deterministic).
        final raw = await File(clockStore.path).readAsString();
        expect(raw, contains('2026-08-31T12:00:00.000Z'));
      },
    );

    test('the default clock is the real wall clock', () async {
      final before = DateTime.now().toUtc();
      final entry = await store.appendGap(
        feature: 'f1',
        step: 'run',
        outcome: 'stopped',
        failingCommand: 'zfa tdd run f1',
      );
      final after = DateTime.now().toUtc();
      final stamped = DateTime.parse(entry.at);
      expect(!stamped.isBefore(before), isTrue);
      expect(!stamped.isAfter(after), isTrue);
    });
  });
}

/// The serialized block of the first ledger entry (between the first `{`
/// and its matching `}`), for byte-stability assertions.
String _entryBlock(String fileContent) {
  final start = fileContent.indexOf('{');
  var depth = 0;
  var inString = false;
  for (var i = start; i < fileContent.length; i++) {
    final ch = fileContent[i];
    if (ch == '"' && (i == 0 || fileContent[i - 1] != r'\\')) {
      inString = !inString;
    } else if (!inString && ch == '{') {
      depth++;
    } else if (!inString && ch == '}') {
      depth--;
      if (depth == 0) return fileContent.substring(start, i + 1);
    }
  }
  throw StateError('unbalanced ledger JSON');
}
