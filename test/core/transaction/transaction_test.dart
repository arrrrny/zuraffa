import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('GenerationTransaction', () {
    test('commits create operations', () async {
      final dir = await Directory.systemTemp.createTemp('zuraffa_tx_');
      addTearDown(() => dir.delete(recursive: true));

      final filePath = '${dir.path}/created.txt';
      final transaction = GenerationTransaction(dryRun: false);
      transaction.addOperation(
        FileOperation.create(path: filePath, content: 'created'),
      );

      final result = await transaction.commit();

      expect(result.success, isTrue);
      expect(File(filePath).readAsStringSync(), equals('created'));
    });

    test('commits update operations', () async {
      final dir = await Directory.systemTemp.createTemp('zuraffa_tx_');
      addTearDown(() => dir.delete(recursive: true));

      final filePath = '${dir.path}/updated.txt';
      await File(filePath).writeAsString('before');

      final transaction = GenerationTransaction(dryRun: false);
      transaction.addOperation(
        await FileOperation.update(path: filePath, content: 'after'),
      );

      final result = await transaction.commit();

      expect(result.success, isTrue);
      expect(File(filePath).readAsStringSync(), equals('after'));
    });

    test('commits delete operations', () async {
      final dir = await Directory.systemTemp.createTemp('zuraffa_tx_');
      addTearDown(() => dir.delete(recursive: true));

      final filePath = '${dir.path}/deleted.txt';
      await File(filePath).writeAsString('remove');

      final transaction = GenerationTransaction(dryRun: false);
      transaction.addOperation(
        await FileOperation.delete(path: filePath),
      );

      final result = await transaction.commit();

      expect(result.success, isTrue);
      expect(File(filePath).existsSync(), isFalse);
    });

    test('detects conflicts before commit', () async {
      final dir = await Directory.systemTemp.createTemp('zuraffa_tx_');
      addTearDown(() => dir.delete(recursive: true));

      final filePath = '${dir.path}/conflict.txt';
      await File(filePath).writeAsString('original');

      final transaction = GenerationTransaction(dryRun: false);
      transaction.addOperation(
        await FileOperation.update(path: filePath, content: 'new'),
      );

      await File(filePath).writeAsString('changed');

      final result = await transaction.commit();

      expect(result.success, isFalse);
      expect(result.conflicts, isNotEmpty);
      expect(File(filePath).readAsStringSync(), equals('changed'));
    });

    test('rolls back on failed commit', () async {
      final dir = await Directory.systemTemp.createTemp('zuraffa_tx_');
      addTearDown(() => dir.delete(recursive: true));

      final blockerPath = '${dir.path}/blocker';
      await File(blockerPath).writeAsString('block');

      final okPath = '${dir.path}/ok.txt';
      final nestedPath = '$blockerPath/nested.txt';

      final transaction = GenerationTransaction(dryRun: false);
      transaction.addOperation(
        FileOperation.create(path: okPath, content: 'ok'),
      );
      transaction.addOperation(
        FileOperation.create(path: nestedPath, content: 'fail'),
      );

      final result = await transaction.commit();

      expect(result.success, isFalse);
      expect(File(okPath).existsSync(), isFalse);
    });
  });
}
