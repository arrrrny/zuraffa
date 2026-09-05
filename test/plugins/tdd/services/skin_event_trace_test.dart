// Issue #1005 ([ZIKZAK-REBUILD] skin hand-written seam): the SkinEvent
// stream — machine-greppable event lines the skin emits while its tests
// run, parsed from the runner transcript into the ordered trace whose
// sha256 digest lands in the skin receipt.
//
// RED phase: `skin_event_trace.dart` does not exist — the import fails.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/skin_event_trace.dart';

void main() {
  group('issue #1005 — SkinEventTrace parsing', () {
    test('parses skin-event lines out of a dart test transcript', () {
      const transcript = '''
00:00 +0: loading test/login/login_view_test.dart
skin-event: behavior=W1 slot=mobile
skin-event: behavior=W1 slot=ios
00:00 +1: all tests passed!
''';
      final trace = SkinEventTrace.parse(transcript, phase: SkinPhase.green);
      expect(trace.events, hasLength(2));
      expect(trace.events.first.behavior, 'W1');
      expect(trace.events.first.slot, 'mobile');
      expect(trace.events.first.phase, SkinPhase.green);
    });

    test('ignores non-event lines and partial look-alikes', () {
      const transcript = '''
skin-event: behavior=W1 slot=mobile
some other print about skin-events: behavior=W2 slot=macos
skin-event: behavior=W1
skin-event: slot=android
''';
      final trace = SkinEventTrace.parse(transcript, phase: SkinPhase.red);
      expect(trace.events, hasLength(1));
      expect(trace.events.first.slot, 'mobile');
    });

    test('empty transcript yields an empty trace', () {
      final trace = SkinEventTrace.parse('', phase: SkinPhase.red);
      expect(trace.events, isEmpty);
    });

    test('slotsOf returns the observed slot set for a behavior', () {
      const transcript = '''
skin-event: behavior=W1 slot=mobile
skin-event: behavior=W1 slot=ios
skin-event: behavior=W1 slot=android
skin-event: behavior=W1 slot=macos
skin-event: behavior=W2 slot=mobile
''';
      final trace = SkinEventTrace.parse(transcript, phase: SkinPhase.green);
      expect(
        trace.slotsOf('W1'),
        containsAll(['mobile', 'ios', 'android', 'macos']),
      );
      expect(trace.slotsOf('W2'), ['mobile']);
      expect(trace.slotsOf('W3'), isEmpty);
    });
  });

  group('issue #1005 — the trace digest', () {
    test('merge preserves run order: red events then green events', () {
      final red = SkinEventTrace.parse(
        'skin-event: behavior=W1 slot=mobile\n',
        phase: SkinPhase.red,
      );
      final green = SkinEventTrace.parse(
        'skin-event: behavior=W1 slot=mobile\n'
        'skin-event: behavior=W1 slot=ios\n',
        phase: SkinPhase.green,
      );
      final merged = SkinEventTrace.merge([red, green]);
      expect(merged.events, hasLength(3));
      expect(merged.events.first.phase, SkinPhase.red);
      expect(merged.events.last.phase, SkinPhase.green);
    });

    test('the digest is deterministic for the same trace', () {
      const transcript = 'skin-event: behavior=W1 slot=mobile\n';
      final a = SkinEventTrace.parse(transcript, phase: SkinPhase.green);
      final b = SkinEventTrace.parse(transcript, phase: SkinPhase.green);
      expect(a.digest, b.digest);
      expect(a.digest, hasLength(64));
    });

    test('the digest differs when the trace differs', () {
      final a = SkinEventTrace.parse(
        'skin-event: behavior=W1 slot=mobile\n',
        phase: SkinPhase.green,
      );
      final b = SkinEventTrace.parse(
        'skin-event: behavior=W1 slot=ios\n',
        phase: SkinPhase.green,
      );
      expect(a.digest, isNot(b.digest));
    });

    test('the digest covers the phase (red vs green)', () {
      final red = SkinEventTrace.parse(
        'skin-event: behavior=W1 slot=mobile\n',
        phase: SkinPhase.red,
      );
      final green = SkinEventTrace.parse(
        'skin-event: behavior=W1 slot=mobile\n',
        phase: SkinPhase.green,
      );
      expect(red.digest, isNot(green.digest));
    });

    test('empty trace digests to a stable value', () {
      final empty = SkinEventTrace.parse('', phase: SkinPhase.red);
      final alsoEmpty = SkinEventTrace.parse(
        'nothing here\n',
        phase: SkinPhase.green,
      );
      expect(empty.digest, alsoEmpty.digest);
    });
  });
}
