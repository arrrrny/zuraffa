// Issue #1319 — plan-level contract: a `traces:` line that exists in an
// FR block but was not bound to a contract row must WARN LOUDLY instead
// of silently falling back to the legacy classifier (the #1308
// vacuous-green dead-end with zero author-facing hint), and the routing
// provenance must name the declared contract row instead of the
// anonymous "layer contracts section" label.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

/// Plans a full spec in a temp project and returns stdout + the rendered
/// test list (mirrors the plan_routing_provenance_test.dart harness).
Future<(String out, String list)> planSpec(String body) async {
  final tmp = Directory.systemTemp.createTempSync('traces_1319_');
  try {
    final featureDir = p.join(tmp.path, 'specs', '1319-repro');
    await Directory(featureDir).create(recursive: true);
    await File(p.join(featureDir, 'spec.md')).writeAsString('''
**Template Version**: `zuraffa-1.0`

# Spec: 1319-repro

## Layer Contracts

**Domain**:
- `RouteContentType`: `contentType() -> String`

**Entities**:
- `User`: `validateEmail(String email) -> bool`

## Functional Requirements

$body

## Acceptance Scenarios

1. **Given** the app **When** it starts **Then** the widget renders "Ready".
   **Type**: widget
''');
    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing([
      'tdd',
      'plan',
      '1319-repro',
      // Issue #1480: groups B/C exercise the UNBOUND-trace warning and the
      // labeled fallback on purpose — the unit-fallback gate stays out of
      // the way via the migration escape hatch.
      '--allow-unit-fallback',
      '--project',
      tmp.path,
    ]);
    final list = await File(
      p.join(featureDir, 'tdd', 'test-list.md'),
    ).readAsString();
    return (out, list);
  } finally {
    tmp.deleteSync(recursive: true);
  }
}

void main() {
  group('A: the #1319 repro — a multi-line FR binds its trace', () {
    test('plan routes the wrapped FR to the declared contract lane (no '
        'silent fallback)', () async {
      final (out, list) = await planSpec('''
- **FR-001**: System MUST expose POST /conversation/stream that returns
  Content-Type: text/event-stream with structured JSON events.
          traces: RouteContentType
''');
      expect(out, contains('route: U1 -> unit lane'));
      expect(out, contains('[declared: contract row: RouteContentType'));
      expect(
        out,
        isNot(contains('[fallback:')),
        reason: 'the trace binds; the legacy fallback must not fire',
      );
      expect(list, contains('route: U1 -> unit lane'));
    });
  });

  group('B: unbound traces lines warn loudly (no silent fallback)', () {
    test(
      'plan prints the exact WARNING line naming the offending FR',
      () async {
        final (out, list) = await planSpec('''
- **FR-001**: System MUST expose POST /conversation/stream that returns
  Content-Type: text/event-stream with structured JSON events.
          traces: `contentType() -> String`
''');
        expect(
          out,
          contains(
            'WARNING: traces: line found in FR-001 but was not bound to a '
            'contract row — check indentation',
          ),
          reason:
              'the lone inline signature token is dropped: nothing '
              'bound, and the fallback must not be silent',
        );
        // Feature 1484: an unbound FR routes MANUAL — no unit row at
        // all (stronger than the old fallback+warning: the dead-end
        // row the provenance warning used to ride is never derived),
        // so the durable provenance warning has no row to attach to.
        expect(
          list,
          isNot(contains('U1')),
          reason: 'the unbound FR derives no unit row:\n$list',
        );
        // Review fix: the 1484 defaulted-FR warning must not claim the
        // block has NO `traces:` line — it has one whose token was
        // dropped as signature-shaped (the warning just above says so).
        // Two adjacent, contradicting warnings send the author looking
        // in the wrong place.
        expect(
          out,
          contains(
            'zfa tdd plan: WARNING: FR-001 derives no unit behaviour — no '
            'surviving `traces:` binding',
          ),
        );
        expect(
          out,
          isNot(contains('[fallback:')),
          reason: 'the fallback lane is collapsed under 1484',
        );
      },
    );

    test('a bound trace emits no WARNING', () async {
      final (out, _) = await planSpec('''
- **FR-001**: System MUST expose POST /conversation/stream that returns
  Content-Type: text/event-stream with structured JSON events.
          traces: RouteContentType
''');
      expect(out, isNot(contains('WARNING: traces: line found in')));
    });

    test(
      'the warning fires BEFORE any artifact — even a strict refusal '
      'that writes nothing still announces the unbound traces line',
      () async {
        final tmp = Directory.systemTemp.createTempSync('traces_1319_strict_');
        try {
          final featureDir = p.join(tmp.path, 'specs', '1319-repro');
          await Directory(featureDir).create(recursive: true);
          await File(p.join(featureDir, 'spec.md')).writeAsString('''
**Template Version**: `zuraffa-1.0`

# Spec: 1319-repro

## Functional Requirements

- **FR-001**: System MUST expose POST /conversation/stream that returns
  Content-Type: text/event-stream with structured JSON events.
          traces: `contentType() -> String`

## Acceptance Scenarios

1. **Given** the app **When** it starts **Then** it streams.
''');
          final runner = CliRunner(exitOnCompletion: false);
          final out = await runner.runCapturing([
            'tdd',
            'plan',
            '1319-repro',
            '--project',
            tmp.path,
            '--strict-routing',
            '--no-emit-markers',
          ]);
          expect(
            exitCode,
            1,
            reason:
                'the strict gate refuses the undeclared '
                'behavior — no artifacts, no provenance print-out',
          );
          expect(
            out,
            contains(
              'zfa tdd plan: WARNING: traces: line found in FR-001 but was '
              'not bound to a contract row — check indentation',
            ),
            reason:
                'the loud warning prints during the declaration parse, '
                'before the strict gate can mute the provenance output',
          );
          expect(
            File(p.join(featureDir, 'tdd', 'test-list.md')).existsSync(),
            isFalse,
          );
        } finally {
          tmp.deleteSync(recursive: true);
        }
      },
    );
  });

  group('C: the provenance names the declared contract row', () {
    test('derived contract behaviors name their declared row instead of '
        'the anonymous layer-contracts label', () async {
      final (out, _) = await planSpec(
        '- **FR-001**: The system MUST validate the email before submitting.',
      );
      expect(
        out,
        contains(
          'route: contract:A1 -> contract lane '
          '[declared: RouteContentType]',
        ),
        reason:
            'the synthesized contract:A1 id must be traceable to the '
            'declared row it was derived from',
      );
      expect(
        out,
        contains('route: contract:A2 -> contract lane [declared: User]'),
      );
      expect(out, isNot(contains('[declared: layer contracts section]')));
    });
  });
}
