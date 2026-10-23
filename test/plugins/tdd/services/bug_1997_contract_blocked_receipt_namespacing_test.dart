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
      final name = ContractBlockedReceiptStore.fileNameFor(
        'contract:A1',
        feature: '004-login/ui',
      );
      // The folded form carries the ORIGINAL name's digest behind a `~`
      // separator — `_sanitize` alone is lossy (`004-login/ui` and
      // `004-login-ui` fold to the SAME text), so without it the two
      // features would share one receipt path again.
      expect(
        name,
        allOf(
          startsWith('contract-blocked.004-login-ui~'),
          endsWith('.A1.json'),
        ),
      );
    });

    test('a portable feature name is kept verbatim (no digest)', () {
      expect(
        ContractBlockedReceiptStore.fileNameFor(
          'contract:A1',
          feature: '004-login-ui',
        ),
        'contract-blocked.004-login-ui.A1.json',
      );
    });

    test('two features whose names FOLD to the same text never share a '
        'receipt path', () {
      final verbatim = ContractBlockedReceiptStore.fileNameFor(
        'contract:A1',
        feature: '004-login-ui',
      );
      final slash = ContractBlockedReceiptStore.fileNameFor(
        'contract:A1',
        feature: '004-login/ui',
      );
      final colon = ContractBlockedReceiptStore.fileNameFor(
        'contract:A1',
        feature: '004-login:ui',
      );

      expect(verbatim, 'contract-blocked.004-login-ui.A1.json');
      expect(slash, isNot(verbatim));
      expect(colon, isNot(verbatim));
      expect(colon, isNot(slash));
    });

    test('a namespaced receipt is adopted only by its OWN feature', () async {
      final store = ContractBlockedReceiptStore(projectRoot: tmp.path);
      // Plant the shape a residual fold collision would leave behind: a
      // receipt at one feature's path whose BODY names another feature.
      final planted = store.pathFor(
        'contract:A1',
        feature: '001-purchase-store',
      );
      await Directory(p.dirname(planted)).create(recursive: true);
      await File(planted).writeAsString(
        jsonEncode(receiptFor('002-subscription-error-vocabulary').toJson()),
      );

      // The reader refuses to hand feature 001 a receipt owned by 002.
      expect(
        store.read(behaviorId: 'contract:A1', feature: '001-purchase-store'),
        isNull,
      );
      // The misowned verdict itself was not destroyed by the read.
      expect(
        ContractBlockedReceipt.fromFile(planted)?.feature,
        '002-subscription-error-vocabulary',
      );
    });

    test(
      'write refuses to overwrite a receipt owned by another feature',
      () async {
        final store = ContractBlockedReceiptStore(projectRoot: tmp.path);
        final planted = store.pathFor(
          'contract:A1',
          feature: '001-purchase-store',
        );
        await Directory(p.dirname(planted)).create(recursive: true);
        await File(planted).writeAsString(
          jsonEncode(receiptFor('002-subscription-error-vocabulary').toJson()),
        );

        await expectLater(
          store.write(receiptFor('001-purchase-store')),
          throwsA(isA<StateError>()),
        );
        // The other feature's verdict survived the refused write.
        expect(
          ContractBlockedReceipt.fromFile(planted)?.feature,
          '002-subscription-error-vocabulary',
        );
      },
    );

    test('an empty feature is refused instead of sharing the legacy path', () {
      final store = ContractBlockedReceiptStore(projectRoot: tmp.path);

      expect(
        () =>
            ContractBlockedReceiptStore.fileNameFor('contract:A1', feature: ''),
        throwsArgumentError,
      );
      expect(
        () => store.read(behaviorId: 'contract:A1', feature: ''),
        throwsArgumentError,
      );
      expect(() => store.write(receiptFor('')), throwsArgumentError);
      // The refusal is what keeps the shared feature-less name unwritten.
      expect(
        File(
          p.join(tmp.path, '.zfa', 'receipts', 'contract-blocked.A1.json'),
        ).existsSync(),
        isFalse,
      );
    });

    test('the legacy path is pinned by code, not by a default argument', () {
      // The pre-#1997 name is a frozen contract: `legacyFileNameFor`
      // builds it explicitly, so the namespaced naming can never move it.
      expect(
        ContractBlockedReceiptStore.legacyFileNameFor('contract:A1'),
        'contract-blocked.A1.json',
      );
      expect(
        ContractBlockedReceiptStore(
          projectRoot: tmp.path,
        ).legacyPathFor('contract:A1'),
        p.join(tmp.path, '.zfa', 'receipts', 'contract-blocked.A1.json'),
      );
    });

    test('readWithPath reports the path the receipt was read FROM', () async {
      final store = ContractBlockedReceiptStore(projectRoot: tmp.path);
      // The shape a pre-#1997 run left behind: only the feature-less file.
      final legacyFile = File(store.legacyPathFor('contract:A1'));
      await legacyFile.parent.create(recursive: true);
      legacyFile.writeAsStringSync(
        jsonEncode(receiptFor('001-purchase-store').toJson()),
      );

      final read = store.readWithPath(
        behaviorId: 'contract:A1',
        feature: '001-purchase-store',
      );

      // The namespaced file does not exist — the LEGACY file answered,
      // and that is the path the caller must report (`zfa tdd make` used
      // to print the namespaced path and send the user to a file that
      // was not there).
      expect(
        File(
          store.pathFor('contract:A1', feature: '001-purchase-store'),
        ).existsSync(),
        isFalse,
      );
      expect(read?.path, store.legacyPathFor('contract:A1'));
      expect(read?.receipt.feature, '001-purchase-store');
    });
  });
}
