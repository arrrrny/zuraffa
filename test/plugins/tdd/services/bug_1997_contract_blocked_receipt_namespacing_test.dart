// Issue #1997 — the contract-blocked receipt's FILE NAME must carry the
// feature, so two features that declare the same behavior id never write
// the same file (one feature's receipt used to overwrite another's).
//
// Before the fix the name was built from the behavior id alone
// (`contract:A1` -> `contract-blocked.A1.json`), so `001-purchase-store`
// and `002-subscription-error-vocabulary` — both declaring `contract:A1`
// — collided on ONE path and the second write clobbered the first.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/contract_blocked_receipt.dart';

void main() {
  group('contract-blocked receipts are namespaced per feature '
      '(issue #1997)', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('contract_blocked_ns_');
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

        expect(first, isNot(second));
        expect(
          p.basename(first),
          'contract-blocked.001-purchase-store.A1.json',
        );
        expect(
          p.basename(second),
          'contract-blocked.002-subscription-error-vocabulary.A1.json',
        );

        // Each file keeps ITS OWN feature — the second write did not
        // clobber the first one.
        expect(
          ContractBlockedReceipt.fromFile(first)?.feature,
          '001-purchase-store',
        );
        expect(
          ContractBlockedReceipt.fromFile(second)?.feature,
          '002-subscription-error-vocabulary',
        );

        // The legacy, feature-less name is never written any more.
        expect(
          File(
            p.join(tmp.path, '.zfa', 'receipts', 'contract-blocked.A1.json'),
          ).existsSync(),
          isFalse,
        );
      },
    );

    test(
      'a feature reads back ITS OWN receipt, never another feature\'s',
      () async {
        final store = ContractBlockedReceiptStore(projectRoot: tmp.path);
        await store.write(receiptFor('001-purchase-store'));

        expect(
          store
              .read(behaviorId: 'contract:A1', feature: '001-purchase-store')
              ?.feature,
          '001-purchase-store',
        );
        expect(
          store.read(
            behaviorId: 'contract:A1',
            feature: '002-subscription-error-vocabulary',
          ),
          isNull,
        );
      },
    );

    test(
      'a legacy (pre-#1997) receipt is adopted by its OWN feature only',
      () async {
        // The shape a pre-#1997 run left behind: one feature-less file that
        // carries its owner in the body.
        final legacy = File(
          p.join(tmp.path, '.zfa', 'receipts', 'contract-blocked.A1.json'),
        );
        legacy.parent.createSync(recursive: true);
        legacy.writeAsStringSync(
          jsonEncode(receiptFor('001-purchase-store').toJson()),
        );

        final store = ContractBlockedReceiptStore(projectRoot: tmp.path);

        expect(
          store
              .read(behaviorId: 'contract:A1', feature: '001-purchase-store')
              ?.feature,
          '001-purchase-store',
        );
        expect(
          store.read(
            behaviorId: 'contract:A1',
            feature: '002-subscription-error-vocabulary',
          ),
          isNull,
        );
      },
    );

    test('the file name folds a non-portable feature character', () {
      expect(
        ContractBlockedReceiptStore.fileNameFor(
          'contract:A1',
          feature: '004-login/ui',
        ),
        'contract-blocked.004-login-ui.A1.json',
      );
    });
  });
}
