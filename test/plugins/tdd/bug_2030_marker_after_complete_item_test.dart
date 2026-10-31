// Bug #2030 — `zfa tdd plan --migrate-spec` injected `**Type**` markers
// after the FIRST line of a multi-line acceptance-scenario item, splitting
// speckit-format prose mid-sentence:
//
//   1. **Given** a VARIATIONS parser whose `title` field declares the
//      **Type**: acceptance          <- injected here (broken)
//      variation-title cleaner, **When** ...
//
// The migrator anchored on the header line index and wrote the marker at
// index+1, assuming one-line zuraffa-template rows. Spec prose and the
// derived behavior names were corrupted on every speckit-authored spec.
//
// Contract under test:
//   U1: a multi-line item receives its marker AFTER the complete item —
//       between the item's last content line and the blank separator.
//   U2: single-line zuraffa-template rows keep the previous placement
//       (marker on the line directly after the row).
//   U3: the walk stays id-faithful when markers are inserted — ids align
//       with the parser's raw-line scenario numbering.
//   U4: idempotent — a second emit on the migrated spec emits nothing.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/spec_marker_emitter.dart';

void main() {
  const emitter = SpecMarkerEmitter();

  group('bug 2030: marker lands after the complete scenario item', () {
    test('U1: multi-line speckit item keeps its prose intact', () {
      const spec = '''
## Scenarios

1. **Given** a VARIATIONS parser whose `title` field declares the
   variation-title cleaner, **When** the payload parses in a run whose
   product title resolved, **Then** each record's `title` equals the
   cleaned value.

2. **Given** a payload with no title, **When** the run completes,
   **Then** the record is skipped.
''';
      final result = emitter.emit(spec, {
        'A1': BehaviorKind.acceptance,
        'A2': BehaviorKind.acceptance,
      });
      expect(result.emitted, hasLength(2));

      final lines = result.content.split('\n');
      // The A1 marker must sit AFTER the item's final prose line
      // ("cleaned value.") and BEFORE the blank separator — never
      // between the header line and its continuation.
      final markerA1 = lines.indexOf('   **Type**: acceptance');
      final header1 = lines.indexWhere((l) => l.startsWith('1. **Given**'));
      final proseEnd = lines.indexWhere((l) => l.contains('cleaned value.'));
      final blank1 = lines.indexWhere((l) => l.isEmpty, proseEnd);
      expect(
        markerA1,
        greaterThan(proseEnd),
        reason: 'the marker follows the complete item',
      );
      expect(
        markerA1,
        lessThan(blank1),
        reason: 'and hugs the item, before the separator',
      );
      expect(
        proseEnd,
        greaterThan(header1),
        reason: 'the prose lines are untouched and stay after the header',
      );
      expect(
        lines.take(markerA1).any((l) => l.contains('declares the **Type**')),
        isFalse,
        reason: 'no marker may split the sentence mid-clause',
      );
    });

    test('U2: single-line template rows keep header-adjacent placement', () {
      const spec = '''
## Scenarios

1. **Given** a wired project, **When** the plan runs, **Then** it routes.

2. **Given** a stray spec, **When** parsed, **Then** it fails closed.
''';
      final result = emitter.emit(spec, {
        'A1': BehaviorKind.acceptance,
        'A2': BehaviorKind.acceptance,
      });
      final lines = result.content.split('\n');
      final header1 = lines.indexOf(
        '1. **Given** a wired project, **When** the plan runs, **Then** it routes.',
      );
      expect(lines[header1 + 1], '   **Type**: acceptance');
    });

    test('U3: second item still derives A2 after the A1 insert', () {
      const spec = '''
1. **Given** first item
   spanning two lines, **Then** routed.

2. **Given** second item, **Then** routed.
''';
      final result = emitter.emit(spec, {
        'A1': BehaviorKind.acceptance,
        'A2': BehaviorKind.widget,
      });
      expect(result.emitted['A1'], BehaviorKind.acceptance);
      expect(result.emitted['A2'], BehaviorKind.widget);
      final lines = result.content.split('\n');
      final markerA2 = lines.indexOf('   **Type**: widget');
      final header2 = lines.indexWhere((l) => l.startsWith('2. **Given**'));
      expect(markerA2, header2 + 1);
    });

    test('U4: emitting on the migrated spec is a no-op', () {
      const spec = '''
1. **Given** first item
   spanning two lines, **Then** routed.
''';
      final first = emitter.emit(spec, {'A1': BehaviorKind.acceptance});
      final second = emitter.emit(first.content, {
        'A1': BehaviorKind.acceptance,
        'A2': BehaviorKind.acceptance,
      });
      expect(second.emitted, isEmpty);
      expect(second.content, first.content);
    });
  });
}
