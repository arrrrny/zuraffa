// A1 (feature 071): declared lanes route end-to-end — a scenario's
// `**Type**` declaration decides its lane regardless of the verbs in
// its prose (the #950 func-verb hijack and the #936 past-tense
// misroute become unreachable for DECLARED scenarios), and rewording
// prose never changes routing (SC-001). During the fallback window an
// UNDECLARED scenario still routes by the legacy classifier (SC-005).
// Issue #951; spec FR-001/FR-013.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/spec_parser.dart';

Behavior? parseOne(String scenario) {
  final spec =
      '## Scenarios\n\n1. **Given** the app state, **When** it '
      'changes, **Then** $scenario\n';
  final behaviors = const SpecParser().parse('071-probe', spec);
  return behaviors.where((b) => b.id == 'A1').firstOrNull;
}

/// A3 harness: plan a full spec in a temp project and return stdout +
/// the rendered test list (mirrors the #833 persistence harness).
Future<(String out, String list)> planSpec(String body) async {
  final tmp = Directory.systemTemp.createTempSync('prov_a3_');
  try {
    final featureDir = p.join(tmp.path, 'specs', '071-prov');
    await Directory(featureDir).create(recursive: true);
    await File(p.join(featureDir, 'spec.md')).writeAsString('''
**Template Version**: `zuraffa-1.0`

# Spec: 071-prov

## Layer Contracts

**Function**:
- `Formatter`: `format(Template) -> String`

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
      '071-prov',
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
  group('A1: declarations decide the lane, prose does not', () {
    test('a marker-declared UNIT scenario whose prose says "renders the '
        'widget" stays in the unit lane', () {
      final b = parseOne(
        'the total equals the sum.\n   **Type**: unit\n',
        // prose mentions the widget noun — the #830 sniffer would
        // claim it pre-declarations
      );
      expect(b?.kind, BehaviorKind.unit);
    });

    test('a marker-declared WIDGET scenario whose prose says "returns" '
        'never falls to the acceptance lane', () {
      final b = parseOne(
        'the widget returns the rendered title.\n   **Type**: widget\n',
      );
      expect(b?.kind, BehaviorKind.widget);
    });

    test('reworded prose with identical markers routes identically '
        '(SC-001)', () {
      Behavior? parse(String prose) =>
          parseOne('$prose\n   **Type**: widget\n');
      final a = parse('the widget renders "Order placed".');
      final b = parse('the widget rendered the order confirmation.');
      final c = parse('the order screen computes its total.');
      expect(a?.kind, BehaviorKind.widget);
      expect(b?.kind, a?.kind, reason: 'past tense, same declaration');
      expect(c?.kind, a?.kind, reason: 'no UI verb at all, same declaration');
    });

    test('an UNDECLARED scenario keeps the legacy fallback routing '
        '(fallback window, SC-005)', () {
      final widgetProse = parseOne('the page shows the settings form.');
      final plainProse = parseOne('the total equals the sum of items.');
      expect(
        widgetProse?.kind,
        BehaviorKind.widget,
        reason: 'legacy classifier still routes undeclared scenarios',
      );
      expect(plainProse?.kind, BehaviorKind.acceptance);
    });
  });

  group('A3: routing provenance per behavior', () {
    test('a declared scenario prints a declared route line naming the '
        'marker and spec line', () async {
      final (out, list) = await planSpec(
        '- **FR-001**: returns 42 when invoked with no args',
      );
      expect(out, contains('route: A1 -> widget lane'));
      expect(out, contains('[declared: type marker'));
      expect(out, contains('spec line'));
      expect(list, contains('## Routing provenance'));
      expect(list, contains('route: A1 -> widget lane'));
    });

    test(
      'a unit FR traced to a function row prints its declared surface',
      () async {
        final (out, _) = await planSpec(
          '- **FR-001**: the label renders the template\n'
          '            traces: Formatter.format',
        );
        expect(out, contains('route: U1 -> unit lane'));
        expect(out, contains('func surface'));
        expect(out, contains('[declared: contract row: Formatter'));
      },
    );

    test('an undeclared widget scenario prints a labeled fallback line '
        'with the fix hint', () async {
      final tmp = Directory.systemTemp.createTempSync('prov_fb_');
      try {
        final featureDir = p.join(tmp.path, 'specs', '071-prov');
        await Directory(featureDir).create(recursive: true);
        await File(p.join(featureDir, 'spec.md')).writeAsString('''
**Template Version**: `zuraffa-1.0`

# Spec: 071-prov

## Functional Requirements

- **FR-001**: returns 42 when invoked with no args

## Acceptance Scenarios

1. **Given** the app **When** it starts **Then** the page shows the settings form.
''');
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing([
          'tdd',
          'plan',
          '071-prov',
          '--project',
          tmp.path,
        ]);
        expect(out, contains('route: A1 -> widget lane'));
        expect(out, contains('[fallback:'));
        expect(out, contains('**Type**'));
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });
  });

  group('A4: strict mode', () {
    test('--strict-routing refuses an undeclared behavior with a fix '
        'hint (exit 1, no fallback routes)', () async {
      final tmp = Directory.systemTemp.createTempSync('strict_a4_');
      try {
        final featureDir = p.join(tmp.path, 'specs', '071-prov');
        await Directory(featureDir).create(recursive: true);
        await File(p.join(featureDir, 'spec.md')).writeAsString('''
**Template Version**: `zuraffa-1.0`

# Spec: 071-prov

## Functional Requirements

- **FR-001**: returns 42 when invoked with no args

## Acceptance Scenarios

1. **Given** the app **When** it starts **Then** the page shows the settings form.
''');
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing([
          'tdd',
          'plan',
          '071-prov',
          '--project',
          tmp.path,
          '--strict-routing',
        ]);
        expect(exitCode, 1);
        expect(out, contains('U1'));
        expect(out, contains('--> fix:'));
        expect(out, isNot(contains('[fallback:')));
        expect(
          File(p.join(featureDir, 'tdd', 'test-list.md')).existsSync(),
          isFalse,
          reason: 'no artifact is written when the plan refuses',
        );
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });

    test('a fully declared spec plans clean under strict', () async {
      final tmp = Directory.systemTemp.createTempSync('strict_ok_');
      try {
        final featureDir = p.join(tmp.path, 'specs', '071-prov');
        await Directory(featureDir).create(recursive: true);
        await File(p.join(featureDir, 'spec.md')).writeAsString('''
**Template Version**: `zuraffa-1.0`

# Spec: 071-prov

## Layer Contracts

**Function**:
- `Formatter`: `format(Template) -> String`

## Functional Requirements

- **FR-001**: the label renders the template
            traces: Formatter.format

## Acceptance Scenarios

1. **Given** the app **When** it starts **Then** the widget renders "Ready".
   **Type**: widget
''');
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing([
          'tdd',
          'plan',
          '071-prov',
          '--project',
          tmp.path,
          '--strict-routing',
        ]);
        expect(exitCode, 0);
        expect(out, contains('[declared:'));
        expect(out, isNot(contains('[fallback:')));
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });
  });
}
