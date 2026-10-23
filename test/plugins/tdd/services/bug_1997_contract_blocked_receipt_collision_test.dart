// Issue #1997 — the contract-blocked receipt's FILE NAME must carry the
// feature, so two features that declare the same behavior id never write
// the same file.
//
// Before the fix the name was built from the behavior id alone
// (`contract:A1` -> `contract-blocked.A1.json`), so `001-purchase-store`
// and `002-subscription-error-vocabulary` — both declaring `contract:A1`
// — collided on ONE path and the second write clobbered the first.
//
// This suite reproduces the collision through the store's CURRENT API
// (no new API is assumed), so it fails on the unfixed tree for the
// reported reason.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/contract_blocked_receipt.dart';

void main() {
  group('contract-blocked receipts do not collide across features '
      '(issue #1997)', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('contract_blocked_collision_');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    ContractBlockedReceipt receiptFor(String feature) => ContractBlockedReceipt(
      behavior: 'contract:A1',
      feature: feature,
      contract: 'User.validateEmail',
      command: 'dart test',
      exitCode: 1,
      outputExcerpt: "Expected: not <Instance of 'UnimplementedError'>",
      blockedAt: '2026-10-22T09:00:00.000Z',
    );

    test(
      'two features with the SAME behavior id write DIFFERENT receipts',
      () async {
        final store = ContractBlockedReceiptStore(projectRoot: tmp.path);

        final first = await store.write(receiptFor('001-purchase-store'));
        final second = await store.write(
          receiptFor('002-subscription-error-vocabulary'),
        );

        // The two features MUST land on different paths, so neither
        // write overwrites the other (issue #1997: before the fix both
        // landed on ONE path and the second write destroyed the first).
        expect(first, isNot(second));
      },
    );

    test(
      'the first feature\'s receipt survives the second feature\'s write',
      () async {
        final store = ContractBlockedReceiptStore(projectRoot: tmp.path);

        final first = await store.write(receiptFor('001-purchase-store'));
        await store.write(receiptFor('002-subscription-error-vocabulary'));

        // The first feature's receipt SURVIVES the second feature's write
        // — each feature owns its own file now (issue #1997: one
        // feature's receipt used to overwrite another's).
        expect(
          ContractBlockedReceipt.fromFile(first)?.feature,
          '001-purchase-store',
        );
      },
    );
  });
}
