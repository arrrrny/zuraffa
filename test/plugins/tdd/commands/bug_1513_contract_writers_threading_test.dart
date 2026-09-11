// Issue #1513 — command-level pin: `gen_command._writersFor` constructs the
// contract pair WITHOUT threading the resolved `flutterTest` flag, so a gen
// for a contract behavior on a Flutter host emits the unresolvable plain
// `package:test` import (while unit/acceptance get the #1351 surface).
//
// The fixture pair:
//   - a pubspec declaring `dependencies: flutter:` (detection is YAML-only,
//     #1458-safe — no Flutter SDK needed to run this suite), and
//   - the same Layer Contracts spec the contract lane derives contract:A1
//     from in test/plugins/tdd/commands/contract_kind_1007_test.dart.
//
// Behaviors:
//   B7 — zfa tdd gen contract:A1 on a flutter-dependency fixture emits a
//        contract test importing flutter_test (and the package subject URI);
//        the pure-Dart fixture keeps the plain package:test import.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

/// The 004-login-ui spec shape (one entity method contract) the #1007
/// suite drives contract:A1 from.
const kLoginUiSpec = '''
**Template Version**: `zuraffa-1.0`

# Spec: 1513-repro

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

const flutterPubspec = '''
name: tdd_fixture
environment:
  sdk: ^3.11.0
dependencies:
  flutter:
    sdk: flutter
dev_dependencies:
  test: ^1.25.0
''';

Future<String> _genContractA1(TddFixture fx, {int runs = 1}) async {
  await Directory(fx.featureDir).create(recursive: true);
  await File(p.join(fx.featureDir, 'spec.md')).writeAsString(kLoginUiSpec);
  await CliRunner(
    exitOnCompletion: false,
  ).runCapturing(['tdd', 'plan', fx.featureName, '--project', fx.root.path]);
  var out = '';
  for (var i = 0; i < runs; i++) {
    out = await CliRunner(
      exitOnCompletion: false,
    ).runCapturing(['tdd', 'gen', 'contract:A1', '--project', fx.root.path]);
    expect(
      out,
      contains('behavior_id: contract:A1'),
      reason: 'gen must produce the contract behavior: $out',
    );
  }
  final record = await fx.registryRecordOf('contract:A1');
  final testPath = record['test_path'] as String;
  return File(
    p.isAbsolute(testPath) ? testPath : p.join(fx.root.path, testPath),
  ).readAsString();
}

void main() {
  test('B7a: gen contract:A1 on a Flutter host emits the flutter_test import '
      '(issue #1513)', () async {
    final fx = await TddFixture.create(featureName: '1513-repro');
    try {
      // Overwrite the fixture pubspec AFTER create so gen's
      // `_isFlutterProject` reads the flutter dependency.
      await File(
        p.join(fx.root.path, 'pubspec.yaml'),
      ).writeAsString(flutterPubspec);
      final generated = await _genContractA1(fx);
      expect(
        generated,
        contains("import 'package:flutter_test/flutter_test.dart';"),
        reason:
            'the contract lane must honor the host runner the way the '
            'unit/acceptance lanes do (#1351):\n$generated',
      );
      expect(
        generated,
        isNot(contains("import 'package:test/test.dart';")),
        reason:
            'the unresolvable plain import must not survive on a Flutter '
            'host — this is the exact compile error #1513 reports:\n$generated',
      );
      // The seam import rides the same #1035 rule the unit lane answers.
      expect(
        generated,
        contains("import 'package:tdd_fixture/tdd/1513-repro/"),
        reason:
            'the subject under lib/ must import through the package URI '
            '(#1035 parity):\n$generated',
      );
    } finally {
      fx.dispose();
      exitCode = 0;
    }
  });

  test('B7b: gen contract:A1 on a pure-Dart host keeps package:test '
      '(default unchanged)', () async {
    final fx = await TddFixture.create(featureName: '1513-repro');
    try {
      final generated = await _genContractA1(fx);
      expect(
        generated,
        contains("import 'package:test/test.dart';"),
        reason:
            'the pure-Dart default must stay byte-stable (#1513 FR-5):\n'
            '$generated',
      );
      expect(generated, isNot(contains('flutter_test')));
    } finally {
      fx.dispose();
      exitCode = 0;
    }
  });

  test('B9: a second gen keeps the package subject import — the stale-stub '
      'mirror must not revert it (finding 1)', () async {
    final fx = await TddFixture.create(featureName: '1513-repro');
    try {
      await File(
        p.join(fx.root.path, 'pubspec.yaml'),
      ).writeAsString(flutterPubspec);
      // First gen writes the package-shaped pair; the second run exercises
      // `_regenerateStaleStub` (the on-disk subject is still an
      // UnimplementedError stub). Without the mirror's package context the
      // re-render falls back to the relative shape and rewrites the file.
      final generated = await _genContractA1(fx, runs: 2);
      expect(
        generated,
        contains("import 'package:tdd_fixture/tdd/1513-repro/"),
        reason:
            'the second gen reverted the promoted package import to the '
            'relative shape — the stale-stub mirror has no package '
            'identity:\n$generated',
      );
      expect(
        generated,
        isNot(contains("import '../../../lib/")),
        reason:
            'the relative fallback must not survive a re-render:\n'
            '$generated',
      );
      // The #1513 half must remain stable across the re-render too.
      expect(
        generated,
        contains("import 'package:flutter_test/flutter_test.dart';"),
        reason:
            'the flutter_test import must survive a re-render:\n'
            '$generated',
      );
    } finally {
      fx.dispose();
      exitCode = 0;
    }
  });
}
