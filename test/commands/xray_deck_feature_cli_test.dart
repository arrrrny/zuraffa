// Spec 1098 — `zfa xray deck --feature <id>` tests.
//
// Materialization step 6 (xray half): the deck subcommand resolves the
// feature contract by id, stamps the @FeatureOwned decorator onto the
// generated deck registration, and records the feature id in the proof
// receipt — so the deck answers file→feature via the same annotation the
// slice layer emits.
//
// Hermetic: the sandbox root is passed via `--root` (never chdir).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/zfa_cli.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('xray_deck_feature_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Directory specWithContract(String featureId) {
    final specDir = Directory(p.join(tempDir.path, 'specs', featureId))
      ..createSync(recursive: true);
    File(p.join(specDir.path, 'contract.yaml')).writeAsStringSync('''
id: $featureId
display_name: $featureId
routes:
  - /$featureId
''');
    return specDir;
  }

  File yamlMock(String name) {
    final yamlDir = Directory(p.join(tempDir.path, 'assets', 'mocks'))
      ..createSync(recursive: true);
    return File(p.join(yamlDir.path, '$name.yaml'))
      ..writeAsStringSync('- name: Valid\n  payload: "123"\n  type: valid\n');
  }

  List<String> deckArgs({
    required File yamlFile,
    required String output,
    required String usecase,
    String? feature,
  }) => [
    'xray',
    'deck',
    '--root=${tempDir.path}',
    '--yaml=${yamlFile.path}',
    '--output=$output',
    '--usecase-name=$usecase',
    if (feature != null) '--feature=$feature',
    '--force',
  ];

  group('zfa xray deck --feature', () {
    test('stamps @FeatureOwned onto the generated deck file', () async {
      specWithContract('login');
      final yamlFile = yamlMock('login_mocks');
      final output = p.join(tempDir.path, 'login_xray_deck.dart');

      await runCapturing(
        deckArgs(
          yamlFile: yamlFile,
          output: output,
          usecase: 'Login',
          feature: 'login',
        ),
      );

      final deckFile = File(output);
      expect(deckFile.existsSync(), isTrue);
      final source = deckFile.readAsStringSync();
      expect(source, contains("// @FeatureOwned('login')"));
    });

    test('records the feature id in the proof receipt input', () async {
      specWithContract('login');
      final yamlFile = yamlMock('login_mocks');
      final output = p.join(tempDir.path, 'login_xray_deck.dart');

      await runCapturing(
        deckArgs(
          yamlFile: yamlFile,
          output: output,
          usecase: 'Login',
          feature: 'login',
        ),
      );

      final receiptsDir = Directory(p.join(tempDir.path, '.zfa', 'receipts'));
      expect(receiptsDir.existsSync(), isTrue);
      final receiptFiles = receiptsDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();
      expect(receiptFiles, isNotEmpty);

      final anyReceipt = receiptFiles.first.readAsStringSync();
      expect(
        anyReceipt.contains('"feature"') && anyReceipt.contains('login'),
        isTrue,
        reason:
            'the proof receipt must attribute the deck generation to '
            'the feature contract',
      );
    });

    test('an unknown feature id fails with the known ids listed', () async {
      specWithContract('login');
      final yamlFile = yamlMock('login_mocks');
      final output = p.join(tempDir.path, 'login_xray_deck.dart');

      final outputLog = await runCapturing(
        deckArgs(
          yamlFile: yamlFile,
          output: output,
          usecase: 'Login',
          feature: 'nonexistent',
        ),
      );

      expect(outputLog, contains('nonexistent'));
      expect(
        File(output).existsSync(),
        isFalse,
        reason:
            'no deck artifact may be generated for an unresolvable '
            'feature contract',
      );
    });

    test(
      'without --feature the deck generates as before (back-compat)',
      () async {
        final yamlFile = yamlMock('plain_mocks');
        final output = p.join(tempDir.path, 'plain_xray_deck.dart');

        await runCapturing(
          deckArgs(yamlFile: yamlFile, output: output, usecase: 'Plain'),
        );

        final deckFile = File(output);
        expect(deckFile.existsSync(), isTrue);
        expect(
          deckFile.readAsStringSync(),
          isNot(contains('@FeatureOwned')),
          reason: 'no contract in play — no decorator',
        );
      },
    );
  });
}
