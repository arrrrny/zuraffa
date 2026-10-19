import 'dart:io';

import 'package:test/test.dart';

import 'package:zuraffa/src/core/policy/sign_off_ledger.dart';

void main() {
  late Directory tmp;
  late SignOffLedger ledger;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ledger_');
    ledger = SignOffLedger(projectRoot: tmp.path);
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('append + readAll round trips', () async {
    final e = await ledger.append(
      missionId: 'm1',
      gate: 'entity.remove',
      requestPayload: <String, dynamic>{'entity': 'Foo'},
      decision: 'approved',
      identity: 'tester',
    );
    expect(e.hash, isNotEmpty);
    final all = await ledger.readAll();
    expect(all.length, 1);
    expect(all.first.gate, 'entity.remove');
    expect(all.first.decision, 'approved');
  });

  test('hash chain verifies', () async {
    await ledger.append(
      missionId: 'm1',
      gate: 'entity.remove',
      requestPayload: <String, dynamic>{'entity': 'Foo'},
      decision: 'approved',
      identity: 'tester',
    );
    await ledger.append(
      missionId: 'm2',
      gate: 'pubspec.mutate',
      requestPayload: <String, dynamic>{
        'packages': ['foo'],
      },
      decision: 'approved',
      identity: 'tester',
    );
    expect(await ledger.verify(), isTrue);
  });

  test('tampering breaks the chain', () async {
    await ledger.append(
      missionId: 'm1',
      gate: 'entity.remove',
      requestPayload: <String, dynamic>{'entity': 'Foo'},
      decision: 'approved',
      identity: 'tester',
    );
    final f = File(ledger.path);
    final lines = f.readAsLinesSync();
    final tampered = lines.first.replaceFirst('approved', 'denied');
    f.writeAsStringSync('$tampered\n');
    expect(await ledger.verify(), isFalse);
  });

  test('empty ledger verifies', () async {
    expect(await ledger.verify(), isTrue);
    expect(await ledger.readAll(), isEmpty);
  });
}
