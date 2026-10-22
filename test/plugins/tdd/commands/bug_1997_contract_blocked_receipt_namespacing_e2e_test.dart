// Issue #1997 — two features that declare the SAME contract behavior id
// (`contract:A1`) must not share ONE contract-blocked receipt.
//
// The receipt's file name used to be built from the behavior id alone
// (`contract-blocked.A1.json`), so the second feature's blocked verdict
// OVERWROTE the first feature's receipt: the first feature's blocked
// contract then had no receipt at all and could only be evidenced from
// `tdd/cycle-log.md`.
//
// This suite drives the real CLI (`zfa tdd plan` -> `gen` -> `verify-red`)
// over TWO features in ONE project and pins that each feature's BLOCKED
// verdict lands in ITS OWN namespaced receipt.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

/// The spec shape both features share — the same declared contract, so
/// BOTH features' plans emit the same behavior id (`contract:A1`).
String _specFor(String feature) =>
    '''
**Template Version**: `zuraffa-1.0`

# Spec: $feature

## Functional Requirements

- **FR-001**: The login form validates the email before submitting.
            traces: User.validateEmail

## Acceptance Scenarios

1. **Given** a valid email **When** the user submits the login form **Then** the session starts

### Key Entities

| Entity | Fields | Purpose |
| User | email: String, password: String | The account holder |

## Layer Contracts

**Entities**:
- `User`: `validateEmail(String email) -> bool`
''';

void main() {
  group('contract-blocked receipts are namespaced per feature '
      '(issue #1997)', () {
    late Directory tmp;
    late String fakeRunner;

    const features = ['004-login-ui', '005-second-feature'];

    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('contract_blocked_ns_e2e_');
      // A scripted runner that emits an HONEST assertion-failure
      // transcript for the generated contract test (the real `dart test`
      // lane is proven in the slow e2e suite; the classifier consuming
      // the transcript is real here).
      fakeRunner = p.join(tmp.path, '.fake-contract-runner');
      await File(fakeRunner).writeAsString('''
#!/bin/sh
echo "00:00 +0 -1: contract:A1 (User.validateEmail) [E]"
echo "  Expected: not <Instance of 'UnimplementedError'>"
echo "    Actual: UnimplementedError:<User.validateEmail is not implemented>"
exit 1
''');
      await Process.run('chmod', ['+x', fakeRunner]);
      await Directory(
        p.join(tmp.path, '.specify', 'memory'),
      ).create(recursive: true);
      await File(
        p.join(tmp.path, '.specify', 'memory', 'tdd-profile.md'),
      ).writeAsString('''
# TDD Profile — contract fixture

## Keys (machine-readable)

```yaml
single: '$fakeRunner {file} --plain-name "{name}"'
```
''');

      for (final feature in features) {
        final featureDir = p.join(tmp.path, 'specs', feature);
        await Directory(featureDir).create(recursive: true);
        await File(
          p.join(featureDir, 'spec.md'),
        ).writeAsString(_specFor(feature));
        final runner = CliRunner(exitOnCompletion: false);
        await runner.runCapturing([
          'tdd',
          'plan',
          feature,
          '--project',
          tmp.path,
        ]);
        await runner.runCapturing([
          'tdd',
          'gen',
          'contract:A1',
          '--feature',
          feature,
          '--project',
          tmp.path,
        ]);
      }
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      exitCode = 0;
    });

    test('each feature\'s BLOCKED verdict lands in ITS OWN receipt', () async {
      for (final feature in features) {
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing([
          'tdd',
          'verify-red',
          'contract:A1',
          '--feature',
          feature,
          '--project',
          tmp.path,
        ]);
        expect(
          out,
          contains('classification=blocked certified=false'),
          reason: out,
        );
        exitCode = 0;
      }

      final receipts = Directory(p.join(tmp.path, '.zfa', 'receipts'));
      final names =
          receipts
              .listSync()
              .whereType<File>()
              .map((f) => p.basename(f.path))
              .where((n) => n.startsWith('contract-blocked.'))
              .toList()
            ..sort();

      // ONE receipt per feature — neither overwrote the other.
      expect(
        names,
        containsAll([
          'contract-blocked.004-login-ui.A1.json',
          'contract-blocked.005-second-feature.A1.json',
        ]),
        reason: names.join(', '),
      );
      expect(names, hasLength(2), reason: names.join(', '));

      // The legacy, feature-less name is gone for good.
      expect(
        names.contains('contract-blocked.A1.json'),
        isFalse,
        reason: names.join(', '),
      );

      // Each receipt carries ITS OWN feature.
      for (final feature in features) {
        final receipt =
            jsonDecode(
                  File(
                    p.join(receipts.path, 'contract-blocked.$feature.A1.json'),
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        expect(receipt['feature'], feature);
        expect(receipt['behavior'], 'contract:A1');
      }
    });
  });
}
