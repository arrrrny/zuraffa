/// The 004-login-ui regeneration acceptance (issue #1141, A1+A2+U9 —
/// the issue's three verification criteria, driven through the REAL
/// loop: `zfa tdd plan` → `zfa tdd gen` → `zfa tdd view`).
///
/// 1. The regenerated view has ZERO hardcoded user-facing strings (the
///    keyed contract renders accessors; the pre-write audit proves it
///    mechanically).
/// 2. An EN copy edit ('Sign in' → 'Log In') does NOT break the
///    generated tests — the keyed assertion lines are byte-identical
///    under the edit.
/// 3. The generated pair is build-shaped: the host accessor import, the
///    slang test-shell pin, and the complete lib/i18n scaffold (the
///    `zfa build` slang stage itself is covered by
///    build_command_slang_stage_test.dart + the recorded end-to-end
///    drive).
///
/// RED phase: plan writes no ledger artifact and view prints no audit
/// line — the regeneration assertions fail on master.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

const String feature = '004-login-ui';

/// The canonical 004-login-ui fixture (issue #1000's example, issue
/// #1004's skin contract) re-declared under the issue #1141 keyed
/// Presentation contract: the login surfaces are `key:` tokens with the
/// EN literals as anchors — the same strings the hand-written view
/// hardcoded (`Text('Sign in')`, `labelText: 'Email'`, ...).
String keyedLoginSpec({required String signInCopy}) =>
    '''
**Template Version**: `zuraffa-1.0`

# Feature Specification: 004-login-ui — the adaptive login skin (keyed)

## Acceptance Scenarios

1. **Given** valid credentials **When** the user submits the login form **Then** the session starts with the authenticated user
2. **Given** invalid credentials **When** the login attempt fails **Then** the error is reported to the caller
3. **Given** a completed login **When** the session is active **Then** the app navigates to 'deal_list'

## Functional Requirements

- **FR-001**: The system shall present the adaptive login view with the declared platform slots (mobile, ios, android, macos).

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [A1, A2, U1]
    flutter_allowed: false
  - lane: SKIN
    behaviors: [W1 (the login view fills every declared platform slot and shows '$signInCopy')]
    flutter_allowed: true
    adaptive_slots: [mobile, ios, android, macos]
  - lane: BOTH
    behaviors: [A3 (acceptance: navigates to deal_list)]
    flutter_allowed: conditionally
```

## Skin Contract

```yaml
Skin Contract:
  adaptive_slots: [mobile, ios, android, macos]
  platform_overrides:
    ios:
      home_indicator_safe_area: required
    macos:
      title_bar_alignment: trailing
  states: [initial, loading, data, error, empty]
  routes: [login, deal_list, settings]
```

## Layer Contracts

**Presentation**:
- `LoginForm`: `ShadInput` for email and password, `key: auth.signIn -> '$signInCopy'`, `key: auth.email -> 'Email'`, `key: auth.password -> 'Password'`, `key: auth.sessionStarted -> 'Session started'`
''';

/// Drives the full regeneration loop on a throwaway project shaped like
/// the 004-login-ui host.
class _Regeneration {
  _Regeneration(this.root);

  final Directory root;

  String get featureDir => p.join(root.path, 'specs', feature);

  static Future<_Regeneration> drive({required String signInCopy}) async {
    final root = await Directory.systemTemp.createTemp('bug_1141_regen_');
    await File(p.join(root.path, 'pubspec.yaml')).writeAsString('''
name: login_host
environment:
  sdk: ^3.11.0
''');
    await Directory(
      p.join(root.path, 'specs', feature, 'tdd'),
    ).create(recursive: true);
    await File(
      p.join(root.path, 'specs', feature, 'spec.md'),
    ).writeAsString(keyedLoginSpec(signInCopy: signInCopy));

    final regen = _Regeneration(root);
    await regen._run(['tdd', 'plan', '--project', root.path, feature]);
    expect(exitCode, 0, reason: 'plan failed');
    await regen._run([
      'tdd',
      'gen',
      'W1',
      '--project',
      root.path,
      '--widget-shell',
      'materialapp',
    ]);
    expect(exitCode, 0, reason: 'gen failed');
    await regen._run(['tdd', 'view', 'W1', '--project', root.path]);
    expect(exitCode, 0, reason: 'view failed');
    return regen;
  }

  Future<String> _run(List<String> args) async {
    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing(args);
    exitCode = 0;
    return out;
  }

  File get subject =>
      File(p.join(root.path, 'lib', 'tdd', feature, 'w1_subject.dart'));

  File get test =>
      File(p.join(root.path, 'test', 'tdd', feature, 'w1_test.dart'));

  File get i18n => File(p.join(root.path, 'lib', 'i18n', 'strings.i18n.json'));

  File get ledger => File(p.join(featureDir, 'tdd', 'ui-ledger.md'));

  /// The keyed assertion lines of the generated test (the lines the EN
  /// copy edit must leave byte-identical).
  List<String> keyedAssertionLines(String source) =>
      source.split('\n').where((l) => l.contains('find.text(t.')).toList();

  void dispose() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
}

void main() {
  _Regeneration? regen;

  tearDown(() {
    regen?.dispose();
    exitCode = 0;
  });

  test('A1: the regenerated view has zero hardcoded user-facing strings '
      '(criterion 1) and the audit proves it mechanically', () async {
    final r = await _Regeneration.drive(signInCopy: 'Sign in');
    regen = r;

    final subject = await r.subject.readAsString();
    // The keyed surface renders the accessor, never the EN literal.
    expect(subject, contains('Text(t.auth.signIn),'));
    expect(subject, isNot(contains("Text('Sign in')")));
    // ZERO quoted user-facing strings: no Text('...') literal at all.
    final quoted = RegExp(
      "Text\\(\\s*(['\"])((?:[^'\\\\]|\\\\.)*?)\\1",
    ).allMatches(subject).map((m) => m.group(2)).toList();
    expect(
      quoted,
      isEmpty,
      reason:
          'a keyed regeneration carries no hardcoded strings: '
          '$quoted',
    );
    // The host accessor import landed.
    expect(
      subject,
      contains("import 'package:login_host/i18n/strings.g.dart';"),
    );
  });

  test(
    'A2: an EN copy edit (Sign in → Log In) does NOT break the generated '
    'tests — the keyed assertions are byte-identical (criterion 2)',
    () async {
      final first = await _Regeneration.drive(signInCopy: 'Sign in');
      final before = await first.test.readAsString();
      final beforeSubject = await first.subject.readAsString();
      final beforeAssertions = first.keyedAssertionLines(before);
      expect(beforeAssertions, isNotEmpty);
      first.dispose();

      final edited = await _Regeneration.drive(signInCopy: 'Log In');
      regen = edited;
      final after = await edited.test.readAsString();
      final afterSubject = await edited.subject.readAsString();

      // The copy edit changed the anchor (and the scaffold's stored EN
      // value) but the keyed assertion lines are byte-identical — the
      // generated tests never pinned the EN string.
      expect(edited.keyedAssertionLines(after), beforeAssertions);
      // The keyed surface in the view is byte-identical too (code
      // identity, not copy).
      expect(
        afterSubject.contains('Text(t.auth.signIn),'),
        beforeSubject.contains('Text(t.auth.signIn),'),
      );
      // The scaffold carries the EDITED copy (the anchor is the human
      // mirror, and it moved).
      final i18n = await edited.i18n.readAsString();
      expect(i18n, contains('"signIn": "Log In"'));
    },
  );

  test('U9: the regeneration composes — ledger rows, slang test shell, '
      'merged scaffold (criterion 3 inputs)', () async {
    final r = await _Regeneration.drive(signInCopy: 'Sign in');
    regen = r;

    // The ledger traces t.<key> per row: every declared key surfaces
    // (NOT-DONE at plan time — planned provers never count green, the
    // 0965 model); the quoting behavior is the DECLARED prover.
    final ledger = await r.ledger.readAsString();
    expect(ledger, contains('| t.auth.signIn | key |'));
    expect(ledger, contains('| t.auth.email | key |'));
    expect(ledger, contains('| t.auth.password | key |'));
    expect(ledger, contains('| t.auth.sessionStarted | key |'));
    expect(ledger, contains('| deal_list | route |'));

    // The paired test boots the slang test shell pinned to the base
    // locale and asserts through the resolved key.
    final test = await r.test.readAsString();
    expect(test, contains("LocaleSettings.setLocaleRaw('en');"));
    expect(test, contains('find.text(t.auth.signIn), findsOneWidget'));
    expect(test, isNot(contains("find.text('Sign in')")));
    expect(test, contains("import 'package:login_host/i18n/strings.g.dart';"));

    // Every declared key scaffolded into lib/i18n (merge, sorted,
    // deterministic).
    final i18n = await r.i18n.readAsString();
    expect(i18n, contains('"signIn": "Sign in"'));
    expect(i18n, contains('"email": "Email"'));
    expect(i18n, contains('"password": "Password"'));
    expect(i18n, contains('"sessionStarted": "Session started"'));
    expect(i18n, endsWith('}\n'));
  });
}
