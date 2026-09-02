// Bug #833 (tdd-persistence-test-harness) — the `[persistence]` marker in
// the test-list format contract.
//
// The plan marks a persistence-kind behavior by appending ` [persistence]`
// to the behavior cell; the SHARED `TestListReader` must parse the marker
// into `BehaviorRow.persistence` and strip it from the description so the
// generated assertion prose never leaks the tag. Rows without the marker
// must be untouched (all existing dialects keep reading byte-for-byte the
// same).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/test_list_reader.dart';

void main() {
  /// Build a feature dir with the given test-list body.
  Future<String> seed(String testListBody) async {
    final dir = await Directory.systemTemp.createTemp(
      'reader_persistence_833_',
    );
    final tddDir = p.join(dir.path, 'tdd');
    await Directory(tddDir).create(recursive: true);
    await File(p.join(tddDir, 'test-list.md')).writeAsString(testListBody);
    return dir.path;
  }

  group('TestListReader — [persistence] marker (bug #833)', () {
    test(
      'canonical 4-col row with the marker parses persistence=true and strips the tag',
      () async {
        final featureDir = await seed('''
# Test List

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | cached entity survives a TTL expiry cycle [persistence] | FR-001 | PENDING |
''');
        final rows = await TestListReader(featureDir).read();
        expect(rows, hasLength(1));
        expect(rows.single.persistence, isTrue);
        expect(
          rows.single.description,
          'cached entity survives a TTL expiry cycle',
          reason: 'the marker must never leak into the assertion prose',
        );
      },
    );

    test(
      'canonical 4-col row without the marker parses persistence=false',
      () async {
        final featureDir = await seed('''
# Test List

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | returns 42 when invoked with no args | FR-001 | PENDING |
''');
        final rows = await TestListReader(featureDir).read();
        expect(rows, hasLength(1));
        expect(rows.single.persistence, isFalse);
        expect(rows.single.description, 'returns 42 when invoked with no args');
      },
    );

    test('gen-legacy 6-col row accepts the marker too', () async {
      final featureDir = await seed('''
# Test List

## Inner loop: unit behaviors

| id | behavior | traces | kind | state | target |
|----|----------|--------|------|-------|--------|
| U1 | offline queue replays after reconnect [persistence] | FR-002 | unit | PENDING | replayQueue |
''');
      final rows = await TestListReader(featureDir).read();
      expect(rows, hasLength(1));
      expect(rows.single.persistence, isTrue);
      expect(rows.single.target, 'replayQueue');
      expect(rows.single.description, 'offline queue replays after reconnect');
    });

    test(
      'the marker is recognized case-insensitively but only as a whole tag',
      () async {
        final featureDir = await seed('''
# Test List

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | box survives restart [Persistence] | FR-003 | PENDING |
| U2 | mentions the word persistence in prose | FR-004 | PENDING |
''');
        final rows = await TestListReader(featureDir).read();
        expect(rows, hasLength(2));
        expect(
          rows[0].persistence,
          isTrue,
          reason: 'case-insensitive tag match',
        );
        expect(rows[0].description, 'box survives restart');
        expect(
          rows[1].persistence,
          isFalse,
          reason: 'prose containing the word is NOT the tag',
        );
        expect(rows[1].description, 'mentions the word persistence in prose');
      },
    );

    test('an acceptance row can carry the marker as well', () async {
      final featureDir = await seed('''
# Test List

## Outer loop: acceptance behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | cached listing survives a full offline session [persistence] | AC-1 | PENDING |
''');
      final rows = await TestListReader(featureDir).read();
      expect(rows, hasLength(1));
      expect(rows.single.kind, BehaviorKind.acceptance);
      expect(rows.single.persistence, isTrue);
    });
  });
}
