// Spec 034 — Track 4.3: XRayControlDeck runtime registry tests.
//
// Behaviors B06..B13: registry + Stream + release guard.
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/xray/xray_control_deck.dart';
import 'package:zuraffa/src/plugins/xray/xray_mock_entry.dart';

void main() {
  group('XRayControlDeck', () {
    late XRayControlDeck deck;

    setUp(() {
      deck = XRayControlDeck(isReleaseMode: false);
    });

    test('B06 — entries starts empty', () {
      expect(deck.entries, isEmpty);
    });

    test('B07 — registerEntries populates the registry', () {
      deck.registerEntries(const [XRayMockEntry(name: 'A', payload: 'p1')]);
      expect(deck.entries.length, 1);
      expect(deck.entries.first.name, 'A');
    });

    test('B08 — duplicate name+payload is deduped', () {
      deck.registerEntries(const [
        XRayMockEntry(name: 'A', payload: 'p1'),
        XRayMockEntry(name: 'A', payload: 'p1'),
      ]);
      expect(deck.entries.length, 1);
    });

    test('B08b — same name but different payload is NOT deduped', () {
      deck.registerEntries(const [
        XRayMockEntry(name: 'A', payload: 'p1'),
        XRayMockEntry(name: 'A', payload: 'p2'),
      ]);
      expect(deck.entries.length, 2);
    });

    test(
      'B08c — registerEntries is incremental (existing entries retained)',
      () {
        deck.registerEntries(const [XRayMockEntry(name: 'A', payload: 'p1')]);
        deck.registerEntries(const [XRayMockEntry(name: 'B', payload: 'p2')]);
        expect(deck.entries.length, 2);
      },
    );

    test('B09 — clear empties the registry', () {
      deck.registerEntries(const [XRayMockEntry(name: 'A', payload: 'p1')]);
      deck.clear();
      expect(deck.entries, isEmpty);
    });

    test('B10 — find returns the entry or null', () {
      deck.registerEntries(const [XRayMockEntry(name: 'A', payload: 'p1')]);
      final found = deck.find('A', 'p1');
      expect(found, isNotNull);
      expect(found!.name, 'A');
      final missing = deck.find('A', 'p99');
      expect(missing, isNull);
    });

    test(
      'B11 — inject returns payload for registered entry, null for unknown',
      () {
        deck.registerEntries(const [
          XRayMockEntry(name: 'A', payload: 'p1'),
          XRayMockEntry(name: 'B', payload: 'p2'),
        ]);
        expect(deck.inject('A'), 'p1');
        expect(deck.inject('B'), 'p2');
        expect(deck.inject('does-not-exist'), isNull);
      },
    );

    test('B11b — inject returns the FIRST matching payload when multiple '
        'entries share the name', () {
      // Edge case from spec: same name, different payloads are NOT deduped.
      // inject by name returns the first one.
      deck.registerEntries(const [
        XRayMockEntry(name: 'A', payload: 'p1'),
        XRayMockEntry(name: 'A', payload: 'p2'),
      ]);
      final r = deck.inject('A');
      expect(r, isNotNull);
      expect(['p1', 'p2'], contains(r));
    });

    test(
      'B12 — changes stream emits new snapshot after registerEntries',
      () async {
        final completer = Completer<List<XRayMockEntry>>();
        final sub = deck.changes.listen(completer.complete);
        deck.registerEntries(const [XRayMockEntry(name: 'A', payload: 'p1')]);
        final snapshot = await completer.future.timeout(
          const Duration(seconds: 1),
        );
        expect(snapshot.length, 1);
        expect(snapshot.first.name, 'A');
        await sub.cancel();
      },
    );

    test('B12b — changes stream emits empty after clear', () async {
      deck.registerEntries(const [XRayMockEntry(name: 'A', payload: 'p1')]);
      final completer = Completer<List<XRayMockEntry>>();
      final sub = deck.changes.listen(completer.complete);
      deck.clear();
      final snapshot = await completer.future.timeout(
        const Duration(seconds: 1),
      );
      expect(snapshot, isEmpty);
      await sub.cancel();
    });

    test('B13 — release-mode registerEntries is a no-op', () {
      final release = XRayControlDeck(isReleaseMode: true);
      release.registerEntries(const [XRayMockEntry(name: 'A', payload: 'p1')]);
      expect(release.entries, isEmpty);
    });

    test('B13b — release-mode changes stream emits nothing', () async {
      final release = XRayControlDeck(isReleaseMode: true);
      var emitted = false;
      final sub = release.changes.listen((_) => emitted = true);
      release.registerEntries(const [XRayMockEntry(name: 'A', payload: 'p1')]);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(emitted, isFalse);
      await sub.cancel();
    });

    test('B14 — release-mode inject returns null', () {
      final release = XRayControlDeck(isReleaseMode: true);
      expect(release.inject('A'), isNull);
    });

    test('B15 — release-mode find returns null', () {
      final release = XRayControlDeck(isReleaseMode: true);
      expect(release.find('A', 'p1'), isNull);
    });

    test('B16 — release-mode toJson reports release_mode true', () {
      final release = XRayControlDeck(isReleaseMode: true);
      final j = release.toJson();
      expect(j['release_mode'], isTrue);
      expect(j['active'], isFalse);
      expect(j['entries'], isEmpty);
    });

    test('toJson in non-release mode reports entries', () {
      deck.registerEntries(const [XRayMockEntry(name: 'A', payload: 'p1')]);
      final j = deck.toJson();
      expect(j['release_mode'], isFalse);
      expect(j['active'], isTrue);
      expect(j['entries'], isA<List>());
      expect((j['entries'] as List).length, 1);
    });
  });
}
