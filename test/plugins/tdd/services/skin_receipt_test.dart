// Issue #1005 ([ZIKZAK-REBUILD] skin hand-written seam): the
// `04-skin-receipt.json` writer (schema skin.v1) — per-behavior
// conformance, platform slot fills, hand-edits, and the skin event
// trace digest.
//
// RED phase: `skin_receipt.dart` does not exist — the import fails.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/skin_receipt.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('skin_receipt_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  SkinReceipt behaviorReceipt({
    String behavior = 'W1',
    bool conformance = true,
    List<String> slots = const ['mobile', 'ios', 'android', 'macos'],
  }) => SkinReceipt(
    behavior: behavior,
    conformance: conformance,
    testPath: 'test/presentation/pages/login/login_view_test.dart',
    subjectPath: 'lib/src/presentation/pages/login/login_view.dart',
    platformSlotFills: slots,
  );

  test('round-trips through JSON', () {
    const receipt = SkinReceipt(
      behavior: 'W1',
      conformance: true,
      testPath: 'test/a_test.dart',
      subjectPath: 'lib/a.dart',
      platformSlotFills: ['mobile', 'ios', 'android', 'macos'],
    );
    final json = receipt.toJson();
    final back = SkinReceipt.fromJson(json);
    expect(back.behavior, 'W1');
    expect(back.conformance, isTrue);
    expect(back.platformSlotFills, ['mobile', 'ios', 'android', 'macos']);
    expect(back.testPath, 'test/a_test.dart');
    expect(back.subjectPath, 'lib/a.dart');
  });

  test('writes 04-skin-receipt.json under the feature tdd dir', () async {
    final featureDir = p.join(tmp.path, 'specs', '004-login-ui');
    final doc = SkinReceiptDocument(
      feature: '004-login-ui',
      command: 'zfa tdd run-skin 004-login-ui',
      behaviors: [behaviorReceipt()],
      handEdits: const [
        SkinHandEditRecord(
          behavior: 'W1',
          file: 'lib/src/presentation/pages/login/login_view.dart',
          loggedAt: '2026-09-05T00:00:00Z',
        ),
      ],
      skinEventTraceDigest: 'a'.padRight(64, '0'),
      redWitness: true,
      generatedAt: '2026-09-05T00:00:00Z',
    );
    final path = await SkinReceiptWriter(featureDir: featureDir).write(doc);

    expect(p.basename(path), '04-skin-receipt.json');
    expect(p.dirname(path), p.join(featureDir, 'tdd'));

    final decoded =
        jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
    expect(decoded['schema'], 'skin.v1');
    expect(decoded['feature'], '004-login-ui');
    expect(decoded['platform_slot_fills'], [
      'mobile',
      'ios',
      'android',
      'macos',
    ]);
    final behaviors = decoded['behaviors'] as List;
    expect(behaviors, hasLength(1));
    expect(behaviors.first['conformance'], isTrue);
    expect(behaviors.first['behavior'], 'W1');
    final handEdits = decoded['hand_edits'] as List;
    expect(handEdits, hasLength(1));
    expect(handEdits.first['behavior'], 'W1');
    expect(
      handEdits.first['file'],
      'lib/src/presentation/pages/login/login_view.dart',
    );
    expect(handEdits.first['logged_at'], '2026-09-05T00:00:00Z');
    expect(decoded['skin_event_trace_digest'], 'a'.padRight(64, '0'));
    expect(decoded['red_witness'], isTrue);
  });

  test('the document aggregates the union of slot fills', () {
    final doc = SkinReceiptDocument(
      feature: '004-login-ui',
      command: 'zfa tdd run-skin 004-login-ui',
      behaviors: [
        behaviorReceipt(behavior: 'W1', slots: const ['mobile', 'ios']),
        behaviorReceipt(behavior: 'W2', slots: const ['android', 'macos']),
      ],
      handEdits: const [],
      skinEventTraceDigest: 'b'.padRight(64, '0'),
      redWitness: true,
      generatedAt: '2026-09-05T00:00:00Z',
    );
    final json = doc.toJson();
    expect(json['platform_slot_fills'], ['mobile', 'ios', 'android', 'macos']);
  });

  test('a stopped run writes its honest partial state too', () async {
    final featureDir = p.join(tmp.path, 'specs', '004-login-ui');
    final doc = SkinReceiptDocument(
      feature: '004-login-ui',
      command: 'zfa tdd run-skin 004-login-ui',
      behaviors: [behaviorReceipt(conformance: false, slots: const [])],
      handEdits: const [],
      skinEventTraceDigest: 'c'.padRight(64, '0'),
      redWitness: false,
      generatedAt: '2026-09-05T00:00:00Z',
    );
    final path = await SkinReceiptWriter(featureDir: featureDir).write(doc);
    final decoded =
        jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
    expect((decoded['behaviors'] as List).first['conformance'], isFalse);
    expect(decoded['platform_slot_fills'], isEmpty);
  });
}
