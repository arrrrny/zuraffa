@Tags(['slow'])
// Issue #1005 ([ZIKZAK-REBUILD] skin hand-written seam): the
// `zfa tdd run-skin <feature>` driver — the cycle that accepts a
// hand-written skin implementation only when it conforms to the declared
// contract (platform slots), has widget tests, goes red before green
// (witnessed by the cycle's stub-revert), and carries a cycle-verified
// `_XRaySkinHandEdit` annotation — then writes `04-skin-receipt.json`.
//
// Drives the public CLI surface against a real temp fixture project whose
// registry records gen-style artifacts; the runner executes REAL
// `dart test` subprocesses inside the fixture (the
// verify_red_command_test pattern).
//
// RED phase: the command does not exist — `zfa tdd run-skin` prints the
// usage error / unknown command and exits non-zero.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

const feature = '004-login-ui';

/// The hand-written login view seeded into the fixture (pure Dart —
/// the cycle's contract is runner-agnostic; the REAL Flutter view lands
/// in example/lib/src/presentation/pages/login/login_view.dart).
const fixtureLoginView = '''
// _XRaySkinHandEdit(behavior: "W1", file: "lib/src/presentation/pages/login/login_view.dart", logged_at: "2026-09-05T00:00:00Z")
//
// LoginView — the first hand-written skin under the issue #1005 seam.
// The adaptive slot matrix the view must fill (issue #1000 lane
// contract): mobile, ios, android, macos.

/// The declared adaptive slots this view renders.
const List<String> kLoginPlatformSlots = [
  'mobile',
  'ios',
  'android',
  'macos',
];

/// The view-builder contract the paired widget test boots.
LoginView loginView() => LoginView();

/// The adaptive login view (AdaptiveViewState shape).
class LoginView {
  /// The platform slots this instance rendered, in pump order.
  final List<String> renderedSlots;

  LoginView({this.renderedSlots = kLoginPlatformSlots});

  /// Whether the view filled [slot].
  bool fills(String slot) => renderedSlots.contains(slot);
}
''';

/// The paired widget test (pure Dart in the fixture; the REAL test is a
/// testWidgets pair in example/test/presentation/pages/).
const fixtureLoginViewTest = '''
import 'package:test/test.dart';
import '../../../../lib/src/presentation/pages/login/login_view.dart' as subject;

void main() {
  test('W1 - the login view fills every declared platform slot', () {
    final view = subject.loginView();
    for (final slot in const ['mobile', 'ios', 'android', 'macos']) {
      expect(view.fills(slot), isTrue,
          reason: 'slot \$slot must be filled');
      print('skin-event: behavior=W1 slot=\$slot');
    }
  });
}
''';

void main() {
  late TddFixture fx;
  late String subjectPath;
  late String testPath;

  /// Seed the 004-login-ui skin lane: a Lanes-declaring spec, a widget
  /// test-list row, and the W1 registry record pointing at the
  /// hand-written view + paired test.
  Future<void> seedSkinLane() async {
    await File(p.join(fx.featureDir, 'spec.md')).writeAsString('''
**Template Version**: `zuraffa-1.0`

## Acceptance Scenarios

1. **Given** valid credentials **When** the user submits the login form **Then** the session starts

## Functional Requirements

- **FR-001**: The system shall validate credentials.

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [U1]
    flutter_allowed: false
  - lane: SKIN
    behaviors: [W1]
    flutter_allowed: true
    adaptive_slots: [mobile, ios, android, macos]
```
''');
    await fx.seedTestList([
      (
        id: 'W1',
        description: 'the login view fills every declared platform slot',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'widget',
      ),
    ]);
    subjectPath = p.join(
      fx.root.path,
      'lib',
      'src',
      'presentation',
      'pages',
      'login',
      'login_view.dart',
    );
    testPath = p.join(
      fx.root.path,
      'test',
      'presentation',
      'pages',
      'login',
      'login_view_test.dart',
    );
    await fx.registerBehavior(
      id: 'W1',
      description: 'the login view fills every declared platform slot',
      testPath: testPath,
      testContent: fixtureLoginViewTest,
    );
    // Patch the registry record's subject to the hand-written view path
    // (registerBehavior's default subject path is the fixture layout).
    final registry = await File(fx.artifactsPath).readAsString();
    final decoded = jsonDecode(registry) as Map<String, dynamic>;
    for (final record in decoded['records'] as List) {
      if (record['behavior_id'] == 'W1') {
        record['subject_path'] = subjectPath;
        record['runnable_test_name'] =
            '$testPath::W1::the login view fills every declared platform slot';
      }
    }
    await File(
      fx.artifactsPath,
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(decoded));
    await File(subjectPath).parent.create(recursive: true);
    await File(subjectPath).writeAsString(fixtureLoginView);
    // Spec 1008 engine gate: run-skin refuses (exit 2) without a green
    // engine receipt — seed one so the fixture exercises the cycle.
    final tddDir = Directory(p.join(fx.featureDir, 'tdd'));
    await tddDir.create(recursive: true);
    await File(
      p.join(tddDir.path, '04-engine-receipt.json'),
    ).writeAsString(const JsonEncoder.withIndent('  ').convert({
      'schema': 1,
      'feature': feature,
      'lane': 'engine',
      'verdict': 'green',
      'result': 'complete',
      'behaviors': <String>[],
      'counts': {'total': 0, 'pending': 0, 'red': 0, 'green': 0, 'done': 0},
      'stopped_at': null,
      'at': '2026-09-05T00:00:00.000Z',
    }));
  }

  Future<String> drive([List<String> extra = const []]) async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing([
      'tdd',
      'run-skin',
      feature,
      '--project',
      fx.root.path,
      ...extra,
    ]);
  }

  setUp(() async {
    fx = await TddFixture.create(featureName: feature);
    await seedSkinLane();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  test('the cycle accepts the hand-written view end to end', () async {
    final before = await File(subjectPath).readAsString();

    final out = await drive();

    expect(exitCode, 0, reason: out);
    expect(
      out,
      contains(
        'run-skin: feature=$feature result=complete behaviors=1 '
        'conformed=1',
      ),
      reason: 'the summary line names the conformed behavior',
    );

    // The hand-written file is restored byte-exact after the red
    // witness (the mutation-audit FR-021 rule).
    final after = await File(subjectPath).readAsString();
    expect(after, before, reason: 'byte-exact restore after the stub run');

    // The receipt.
    final receiptPath = p.join(fx.featureDir, 'tdd', '04-skin-receipt.json');
    expect(
      File(receiptPath).existsSync(),
      isTrue,
      reason: 'the skin receipt exists',
    );
    final receipt =
        jsonDecode(await File(receiptPath).readAsString())
            as Map<String, dynamic>;
    expect(receipt['schema'], 'skin.v1');
    expect(receipt['feature'], feature);
    expect(receipt['platform_slot_fills'], [
      'mobile',
      'ios',
      'android',
      'macos',
    ], reason: '4 platform slot fills from the green SkinEvent stream');
    expect(receipt['hand_edits'], hasLength(1));
    expect(receipt['hand_edits'].first['behavior'], 'W1');
    expect(
      receipt['hand_edits'].first['file'],
      'lib/src/presentation/pages/login/login_view.dart',
    );
    expect(receipt['skin_event_trace_digest'], isNotNull);
    expect(receipt['red_witness'], isTrue);
    final behaviors = receipt['behaviors'] as List;
    expect(behaviors.first['behavior'], 'W1');
    expect(behaviors.first['conformance'], isTrue);

    // The cycle-log carries red-then-green evidence for W1.
    final cycleLog = await File(fx.cycleLogPath).readAsString();
    final redIndex = cycleLog.indexOf('- behavior: W1\n- kind: red');
    final greenIndex = cycleLog.indexOf('- behavior: W1\n- kind: green');
    expect(redIndex, greaterThanOrEqualTo(0), reason: 'red evidence exists');
    expect(
      greenIndex,
      greaterThan(redIndex),
      reason: 'red before green in the append-only log',
    );
  });

  test(
    'a view with no annotation is refused (conformance false, exit 1)',
    () async {
      final unannotated = fixtureLoginView.replaceAll(
        RegExp(
          r'// _XRaySkinHandEdit\(behavior: "W1", file: "[^"]+", logged_at: "[^"]+"\)',
        ),
        '// (annotation deliberately removed for the refusal test)',
      );
      await File(subjectPath).writeAsString(unannotated);

      final out = await drive();

      expect(exitCode, 1, reason: out);
      expect(
        out,
        contains('run-skin: feature=$feature result=stopped'),
        reason: 'the summary line reports the honest stop',
      );
      final receipt =
          jsonDecode(
                await File(
                  p.join(fx.featureDir, 'tdd', '04-skin-receipt.json'),
                ).readAsString(),
              )
              as Map<String, dynamic>;
      expect((receipt['behaviors'] as List).first['conformance'], isFalse);
      expect(receipt['hand_edits'], isEmpty);
    },
  );

  test('a view whose test is red after restore is refused', () async {
    // A view whose paired test cannot pass: the builder returns a view
    // that fills nothing (honest red at green time).
    final broken = fixtureLoginView.replaceFirst(
      'LoginView loginView() => LoginView();',
      'LoginView loginView() => LoginView(renderedSlots: []);',
    );
    await File(subjectPath).writeAsString(broken);

    final out = await drive();

    expect(exitCode, 1, reason: out);
    final receipt =
        jsonDecode(
              await File(
                p.join(fx.featureDir, 'tdd', '04-skin-receipt.json'),
              ).readAsString(),
            )
            as Map<String, dynamic>;
    final b = (receipt['behaviors'] as List).first;
    expect(b['conformance'], isFalse);
    expect(
      receipt['platform_slot_fills'],
      isEmpty,
      reason: 'no slot fills from a red green-run',
    );
  });

  test('--json emits the verdict.v1 envelope as the final line', () async {
    final out = await drive(['--json']);

    final lines = out
        .trim()
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    final last = lines.last;
    expect(last.startsWith('{'), isTrue, reason: 'last line is JSON: $last');
    final envelope = jsonDecode(last) as Map<String, dynamic>;
    expect(envelope['schema'], 'verdict.v1');
    expect(envelope['command'], 'run-skin');
    expect(envelope['verdict'], 'pass');
    expect(envelope['details']['result'], 'complete');
  });

  test('a feature with no SKIN lane is an honest empty complete', () async {
    // Rewrite the spec with no SKIN lane and drop the W1 row. With no
    // SKIN declaration (no adaptive slots) the composed driver runs the
    // spec-1008 lane mode: a vacuous skin lane completes green.
    await File(p.join(fx.featureDir, 'spec.md')).writeAsString('''
**Template Version**: `zuraffa-1.0`

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [U1]
    flutter_allowed: false
```
''');
    await fx.seedTestList([
      (
        id: 'U1',
        description: 'pure engine behavior',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);

    final out = await drive();

    expect(exitCode, 0, reason: out);
    expect(
      out,
      contains('run-skin: feature=$feature lane=skin result=complete'),
    );
    expect(out, contains('total=0'));
  });
}
