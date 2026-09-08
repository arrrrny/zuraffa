// Tests for issue #1318 — noFlutter false-positive on event prose.
//
// RED contract: SSE/event-stream "shows" routes acceptance scenario
// widget-kind, hard-refusing an all-CORE server spec. The repro prose
// "the decision_made event shows outcome: clarify with the question,
// and the content_delta events contain the clarification." matched the
// #830/#936 UI-intent regex (`shows?|shown`) with no subject context,
// so the spec-1000 noFlutter guard rejected the entire plan (exit 1,
// zero artifacts) for a server-side streaming behavior.
//
// Pinned contract:
//   1. Event-noun subjects (`event shows`, `event includes`,
//      `event carries`, `message shows`, `response includes`) are
//      NEVER classifier-widget — even when a UI surface noun
//      co-occurs in the payload description.
//   2. Event-schema scenarios route CORE by default: verb-only weak
//      matches ("shows" with no surface noun) do not route widget.
//   3. Backward compat: "the screen shows", "the widget displays",
//      "the dialog appears", the #936 trio — still widget.
//   4. The `**Type**` marker escape hatch is untouched (declaration
//      outranks prose in both directions).
//   5. The noFlutter guard's fix message LEADS with the marker remedy
//      for classifier-routed behaviors: `--> fix: add **Type**:
//      acceptance to the scenario (classifier guess, not a
//      declaration)` — and keeps the lane-move remedy for DECLARED
//      behaviors.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/spec_parser.dart';

const String feature = '009-conversation-streaming';

/// The exact repro prose from issue #1318 (forklift
/// 009-conversation-streaming scenario A10).
const String reproThen =
    'the decision_made event shows outcome: clarify with the question, '
    'and the content_delta events contain the clarification.';

void main() {
  // ------------------------------------------------------------------
  // 1. Classifier — event-schema prose routes acceptance (CORE)
  // ------------------------------------------------------------------
  group('bug1318 classifier: event-schema prose is acceptance kind', () {
    test('B1: the issue repro Then-clause parses acceptance (CORE)', () {
      final behaviors = const SpecParser().parse(feature, '''
# Spec: conversation streaming

## Acceptance Scenarios

1. **Given** an ambiguous message, **When** the engine decides to clarify, **Then** $reproThen

## Functional Requirements

- **FR-001**: the engine emits the decision event.
''');
      final a1 = behaviors.where((b) => b.id == 'A1').single;
      expect(
        a1.kind.name,
        'acceptance',
        reason:
            'an SSE event-schema assertion is not UI intent — the '
            'noFlutter guard must not see a widget-kind behavior here',
      );
    });

    test('B2: event-noun subject matrix never routes widget', () {
      // Each member: subject noun + content verb (optionally with a
      // modifier word). None carries UI intent.
      const matrix = <String>[
        'the event shows the outcome',
        'the event includes the field map',
        'the event carries the schema version',
        'the message shows the payload',
        'the response includes the schema',
        'the events contain the clarification',
        'the SSE response includes the trace id',
        'the decision_made event shows outcome: clarify',
        'the content_delta events contain the question',
        'the stream carries the frames',
        'the payload includes the checksum',
        'the frame shows the sequence number',
        'the notification includes the title field',
      ];
      for (final prose in matrix) {
        expect(
          SpecParser.isUiAcceptance(prose),
          isFalse,
          reason:
              '"$prose" is event/protocol schema prose — the '
              'classifier must not route it widget-kind',
        );
      }
    });

    test('B3: the exclusion holds even when a surface noun co-occurs '
        'in the payload description', () {
      expect(
        SpecParser.isUiAcceptance(
          'the event shows the dialog id in its payload',
        ),
        isFalse,
        reason:
            'the surface noun belongs to the payload schema, not a '
            'rendered UI — criterion: MUST NOT route widget-kind',
      );
      expect(
        SpecParser.isUiAcceptance(
          'the message shows the widget kinds it carries',
        ),
        isFalse,
      );
      expect(
        SpecParser.isUiAcceptance(
          'the event shows the dialog id in its payload, and the widget '
          'renders its status',
        ),
        isTrue,
        reason:
            'the event-content exclusion must not suppress UI intent '
            'expressed by a separate predicate clause',
      );
    });

    test('B4: verb-only weak matches no longer route widget', () {
      // "shows" with NO UI surface noun and NO strong UI verb: the
      // #936 verb matched with no subject context; #1318 narrows it.
      expect(
        SpecParser.isUiAcceptance('the app shows a spinner'),
        isFalse,
        reason:
            'a verb-only "shows" without any surface noun is '
            'ambiguous with event prose — CORE by default',
      );
      expect(SpecParser.isUiAcceptance('the report shows 0 errors'), isFalse);
    });
  });

  // ------------------------------------------------------------------
  // 2. Classifier — backward compatibility (criterion 4)
  // ------------------------------------------------------------------
  group('bug1318 classifier: genuine UI prose still routes widget', () {
    test('B5: surface-noun subjects stay widget', () {
      const ui = <String>[
        'the screen shows a spinner',
        'the widget displays the badge',
        'the dialog appears with the title',
        'the sidebar is visible on macOS and the bottom nav bar is hidden',
        'the dialog shows the error title',
        'the page shows the settings form.',
      ];
      for (final prose in ui) {
        expect(
          SpecParser.isUiAcceptance(prose),
          isTrue,
          reason:
              '"$prose" is genuine UI intent — the fix only narrows '
              'event-noun subjects',
        );
      }
    });

    test('B6: the #936 trio stays widget (bug_830 scenarios, unmodified)', () {
      const SpecParser()
          .parse('002-login', '''
# Spec: Login

## Acceptance Scenarios

1. **Given** I am on the login page, **When** I enter valid credentials and tap Sign In, **Then** a loading indicator is shown and I am navigated to the home screen.
2. **Given** I enter wrong credentials, **When** I tap Sign In, **Then** an error message is rendered on the login page.
3. **Given** the profile page, **When** it loads, **Then** the avatar is displayed with the user's initials.

## Functional Requirements

- **FR-001**: the login page exposes a loading indicator contract.
''')
          .forEach((b) {
            if (b.id.startsWith('A')) {
              expect(b.kind.name, 'widget', reason: '${b.id} is UI intent');
            }
          });
    });

    test('B7: the marker escape hatch is untouched (declaration '
        'outranks prose in both directions)', () {
      // The repro scenario, explicitly declared widget: the declaration
      // wins even though the prose now reads as event-schema.
      final behaviors = const SpecParser().parse(feature, '''
1. **Given** an ambiguous message, **When** the engine decides to clarify, **Then** $reproThen
   **Type**: widget
''');
      expect(behaviors.single.kind.name, 'widget');
      // And an explicit acceptance declaration keeps a UI-ish prose
      // scenario CORE.
      final declared = const SpecParser().parse(feature, '''
1. **Given** the shell, **When** the dashboard opens, **Then** it renders the brand theme.
   **Type**: acceptance
''');
      expect(declared.single.kind.name, 'acceptance');
    });
  });

  // ------------------------------------------------------------------
  // 3. CLI — plan end-to-end (the guard)
  // ------------------------------------------------------------------
  group('bug1318 plan: noFlutter guard and remedy ordering', () {
    late Directory tmpDir;
    late String featureDir;
    late String tddDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('bug1318_plan_');
      featureDir = p.join(tmpDir.path, 'specs', feature);
      tddDir = p.join(featureDir, 'tdd');
      Directory(tddDir).createSync(recursive: true);
    });

    tearDown(() {
      if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    });

    Future<void> seedSpec(String spec) async {
      await File(p.join(featureDir, 'spec.md')).writeAsString(spec);
    }

    List<String> planArgs() => [
      'tdd',
      'plan',
      '--project',
      tmpDir.path,
      feature,
    ];

    /// The forklift 009-conversation-streaming lane shape: all-CORE,
    /// pure Dart, `flutter_allowed: false` — with A2 carrying the
    /// issue's event-schema prose.
    final streamingSpec =
        '''
**Template Version**: `zuraffa-1.0`

## Acceptance Scenarios

1. **Given** a connected stream, **When** the session opens, **Then** the stream starts and the handshake completes.
2. **Given** an ambiguous message, **When** the engine decides to clarify, **Then** $reproThen

## Functional Requirements

- **FR-001**: The system shall open the conversation stream through the streaming client.
- **FR-002**: The system shall emit the decision_made event with the clarify outcome.

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [A1, A2, U1, U2]
    flutter_allowed: false
```
''';

    test('B8: the all-CORE SSE spec plans clean — exit 0, artifacts '
        'written, no noFlutter refusal', () async {
      await seedSpec(streamingSpec);
      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(planArgs());
      expect(exitCode, 0, reason: out);
      expect(
        File(p.join(tddDir, '04-ENGINE.md')).existsSync(),
        isTrue,
        reason: 'the engine plan is written',
      );
      expect(
        out.contains('noFlutter guard'),
        isFalse,
        reason: 'the event-schema scenario is not misrouted widget-kind',
      );
    });

    test('B9: classifier-routed widget in a CORE lane leads the fix '
        'with the marker remedy', () async {
      // A1's prose is UI-observable WITHOUT any declaration: the
      // fallback classifier guesses widget-kind.
      final spec = streamingSpec.replaceFirst(
        '**Then** the stream starts and the handshake completes.',
        '**Then** the login form renders the authenticated user badge.',
      );
      await seedSpec(spec);
      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(planArgs());
      expect(exitCode, 2, reason: out);
      expect(
        out.contains(
          '--> fix: add **Type**: acceptance to the scenario '
          '(classifier guess, not a declaration)',
        ),
        isTrue,
        reason:
            'the marker remedy LEADS the fix message (was buried '
            'third pre-#1318)\n$out',
      );
      expect(
        out.contains('declare it SKIN'),
        isFalse,
        reason:
            'the lane-move remedy belongs to DECLARED kinds, not '
            'classifier guesses',
      );
    });

    test('B10: DECLARED widget-kind in a CORE lane keeps the lane-move '
        'remedy (the marker is the author\'s word)', () async {
      final spec = streamingSpec.replaceFirst(
        '**Then** the stream starts and the handshake completes.',
        '**Then** the login form renders the authenticated user badge.\n'
            '   **Type**: widget',
      );
      await seedSpec(spec);
      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(planArgs());
      expect(exitCode, 2, reason: out);
      expect(
        out.contains('declare it SKIN (or BOTH)'),
        isTrue,
        reason:
            'a declared kind is not a classifier guess — the remedy '
            'is the lane move\n$out',
      );
      expect(
        out.contains('classifier guess'),
        isFalse,
        reason: 'no classifier-guess remedy for an explicit declaration',
      );
    });
  });
}
