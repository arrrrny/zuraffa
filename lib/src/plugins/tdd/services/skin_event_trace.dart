/// The SkinEvent stream — machine-greppable event lines the skin emits
/// while its tests run, parsed from the runner transcript into the
/// ordered trace whose sha256 digest lands in `04-skin-receipt.json`
/// (issue #1005).
///
/// The skin (the hand-written view) reports every adaptive platform
/// slot it actually renders with a print the transcript carries:
///
/// ```text
/// skin-event: behavior=W1 slot=mobile
/// ```
///
/// Both `dart test` and `flutter test` forward prints to stdout, so the
/// stream is runner-agnostic. The cycle tags every parsed event with
/// the phase it was observed in (`red`/`green`); the digest is taken
/// over the canonical newline-joined `behavior|slot|phase` lines —
/// deterministic, no timestamps inside the events.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// The run phase a SkinEvent was observed in.
enum SkinPhase {
  red('red'),
  green('green');

  const SkinPhase(this.label);
  final String label;
}

/// One parsed skin event: the behavior whose skin emitted it, the
/// platform slot the skin rendered, and the phase of the run the event
/// was observed in.
class SkinEvent {
  const SkinEvent({
    required this.behavior,
    required this.slot,
    required this.phase,
  });

  final String behavior;
  final String slot;
  final SkinPhase phase;

  /// The canonical digest line: `behavior|slot|phase`.
  String get canonical => '$behavior|$slot|${phase.label}';

  @override
  String toString() =>
      'SkinEvent(behavior: $behavior, slot: $slot, phase: ${phase.label})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SkinEvent &&
          other.behavior == behavior &&
          other.slot == slot &&
          other.phase == phase);

  @override
  int get hashCode => Object.hash(behavior, slot, phase);
}

/// The ordered trace of skin events parsed from one or more runner
/// transcripts.
class SkinEventTrace {
  const SkinEventTrace(this.events);

  /// Every event, in observation order.
  final List<SkinEvent> events;

  /// The machine-greppable event line prefix.
  static const String lineToken = 'skin-event:';

  /// The event line pattern: `skin-event: behavior=<id> slot=<slot>`.
  static final RegExp _linePattern = RegExp(
    r'skin-event:\s*behavior=([A-Za-z0-9_-]+)\s+slot=([A-Za-z0-9_-]+)',
  );

  /// Parse every skin-event line out of [transcript], tagging each with
  /// [phase]. Look-alike lines (missing fields, other prefixes) are
  /// ignored — the pattern is the contract.
  static SkinEventTrace parse(String transcript, {required SkinPhase phase}) {
    final events = <SkinEvent>[];
    for (final m in _linePattern.allMatches(transcript)) {
      events.add(
        SkinEvent(behavior: m.group(1)!, slot: m.group(2)!, phase: phase),
      );
    }
    return SkinEventTrace(events);
  }

  /// Concatenate traces in run order (the red-run events before the
  /// green-run events — the order the cycle observed them).
  static SkinEventTrace merge(Iterable<SkinEventTrace> traces) {
    final events = <SkinEvent>[];
    for (final t in traces) {
      events.addAll(t.events);
    }
    return SkinEventTrace(events);
  }

  /// The slots observed for [behaviorId], in observation order
  /// (duplicates preserved — the trace is a log, not a set).
  List<String> slotsOf(String behaviorId) => [
    for (final e in events)
      if (e.behavior == behaviorId) e.slot,
  ];

  /// sha256 over the canonical trace lines, newline-joined — the
  /// `skin_event_trace_digest` the receipt records. Deterministic for
  /// the same event sequence; an empty trace digests the empty payload.
  String get digest {
    final payload = events.map((e) => e.canonical).join('\n');
    return sha256.convert(utf8.encode(payload)).toString();
  }
}
