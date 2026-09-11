// Issue #1393 — the flagship fixture `example/specs/004-login-ui` cannot
// complete its own engine cycle: U1 (FR-001, the adaptive view
// presentation) is mislaned CORE — a presentation behavior in the
// pure-Dart lane, contradicted by the CORE=engine-only contract — and
// the fixture declares zero engine-side unit behaviors with contract
// traces, so the acceptance makes are unexpressible (spec 052
// composition has no green unit subjects to compose from). This pin
// locks the re-split: U1 in SKIN, a CORE lane whose unit behaviors
// trace to engine-expressible callable contract rows, and the Skin
// Contract declaration parseable by the strict production parser.

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/skin/contract/adaptive_skin_contract_parser.dart';

void main() {
  final spec = File('example/specs/004-login-ui/spec.md');
  final splitReceipt = File(
    'example/specs/004-login-ui/tdd/split-receipt.json',
  );

  test('B1: U1 (FR-001, adaptive view presentation) is declared SKIN', () {
    expect(
      spec.existsSync(),
      isTrue,
      reason: 'example/specs/004-login-ui is the flagship fixture',
    );
    final source = spec.readAsStringSync();

    final lanes = RegExp(
      r'```yaml\s*Lanes:(.*?)```',
      dotAll: true,
    ).firstMatch(source);
    expect(lanes, isNotNull, reason: 'the fixture declares a `## Lanes` block');
    final block = lanes!.group(1)!;

    final coreList = RegExp(
      r'- lane:\s*CORE\s*\n\s*behaviors:\s*\[([^\]]*)\]',
    ).firstMatch(block);
    final skinList = RegExp(
      r'- lane:\s*SKIN\s*\n\s*behaviors:\s*\[([^\]]*)\]',
    ).firstMatch(block);
    expect(coreList, isNotNull, reason: 'a CORE lane row is declared');
    expect(skinList, isNotNull, reason: 'a SKIN lane row is declared');

    final core = coreList!
        .group(1)!
        .split(',')
        .map((e) => e.trim().split('(').first.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    final skin = skinList!
        .group(1)!
        .split(',')
        .map((e) => e.trim().split('(').first.trim())
        .where((e) => e.isNotEmpty)
        .toSet();

    expect(
      core.contains('U1'),
      isFalse,
      reason:
          'the #1393 re-split: U1 is a view-presentation behavior — the '
          'CORE lane is engine-only (noFlutter contract, issue #1000)',
    );
    expect(
      skin.contains('U1'),
      isTrue,
      reason: 'U1 belongs in the SKIN lane where the view work lives',
    );
  });

  test('B2: the CORE lane carries an engine-expressible unit with traces', () {
    final source = spec.readAsStringSync();

    // The re-split adds FR-002: an engine-expressible unit behavior
    // whose trace names a callable contract row (scalar-return
    // signature) — the anchor the acceptance makes compose from.
    final fr002 = RegExp(
      r'- \*\*FR-002\*\*:.*?(?=\n- \*\*FR-|\n## )',
      dotAll: true,
    ).firstMatch(source);
    expect(
      fr002,
      isNotNull,
      reason: 'the fixture declares an engine-side unit behavior (FR-002)',
    );
    expect(
      fr002!.group(0),
      contains('traces:'),
      reason: 'FR-002 carries the traces: grammar (issue #1313)',
    );

    final traceMatch = RegExp(
      r'traces:\s*(\S+)',
    ).firstMatch(fr002.group(0) ?? '')!;
    final trace = traceMatch.group(1)!;
    expect(
      trace,
      contains('.'),
      reason:
          'the trace names Row.method — a callable signature, not a '
          'layout-surface row (the #1377 class of guard-only make stops)',
    );
    final row = trace.split('.').first;

    expect(
      source,
      contains('`$row`'),
      reason: 'the traced row "$row" is declared in Layer Contracts',
    );
    // The traced row's signature is a scalar-return callable: the
    // shape gen can derive an outcome assertion from and make can
    // scaffold without a hand step (issues #1259/#1308).
    expect(
      source,
      contains('-> bool'),
      reason:
          'the traced row declares a scalar-return signature — '
          'engine-expressible (unattended green, EPIC #1012 exit 4)',
    );
  });

  test('B3: the Skin Contract yaml parses with the strict parser', () {
    final source = spec.readAsStringSync();

    final contract = parseAdaptiveSkinContract(source);
    expect(
      contract,
      isNotNull,
      reason: 'the fixture declares a `## Skin Contract` section',
    );
    expect(
      contract!.adaptiveSlots,
      isNotEmpty,
      reason:
          'the malformed `adaptive_slots: obile, ios, android, macos]` '
          'named in #1393 must never regress: the strict parser refuses '
          'a name outside ^[a-z][a-z0-9_]*\$',
    );
    expect(
      contract.adaptiveSlots,
      containsAll(<String>['mobile', 'ios', 'android', 'macos']),
      reason: 'the declared platform matrix is intact',
    );
  });

  test('B4: the committed split receipt carries the re-split lanes', () {
    expect(
      splitReceipt.existsSync(),
      isTrue,
      reason: 'the regenerated split receipt is committed (#1366)',
    );
    final decoded =
        jsonDecode(splitReceipt.readAsStringSync()) as Map<String, dynamic>;
    final classification = decoded['classification'] as Map<String, dynamic>;

    expect(
      classification['U1'],
      equals('SKIN'),
      reason: 'the committed re-split state: U1 routed SKIN',
    );
    expect(classification['A1'], equals('CORE'));
    expect(classification['A2'], equals('CORE'));
    expect(
      classification['U2'],
      equals('CORE'),
      reason: 'the engine-expressible unit is CORE',
    );
    expect(classification['W1'], equals('SKIN'));
    for (var i = 3; i <= 7; i++) {
      expect(classification['A$i'], equals('SKIN'));
    }
  });
}
