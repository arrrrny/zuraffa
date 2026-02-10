import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cli generate from flags creates output', () async {
    final tempDir = await Directory.systemTemp.createTemp('zfa_cli_');
    addTearDown(() => tempDir.delete(recursive: true));
    final outputDir = '${tempDir.path}/lib/src';

    final result = await Process.run('dart', [
      'run',
      'bin/zfa.dart',
      'generate',
      'Product',
      '--methods=get,getList',
      '--data',
      '--output',
      outputDir,
      '--force',
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, equals(0), reason: result.stderr.toString());
    expect(
      File(
        '$outputDir/domain/repositories/product_repository.dart',
      ).existsSync(),
      isTrue,
    );
  });

  test('cli generate from json keeps config format', () async {
    final tempDir = await Directory.systemTemp.createTemp('zfa_cli_');
    addTearDown(() => tempDir.delete(recursive: true));
    final outputDir = '${tempDir.path}/lib/src';
    final configFile = File('${tempDir.path}/config.json');

    await configFile.writeAsString('''
{
  "name": "Order",
  "methods": ["get"],
  "data": true,
  "id_field": "orderId",
  "id_field_type": "int"
}
''');

    final result = await Process.run('dart', [
      'run',
      'bin/zfa.dart',
      'generate',
      'Order',
      '--from-json',
      configFile.path,
      '--output',
      outputDir,
      '--force',
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, equals(0), reason: result.stderr.toString());
    expect(
      File('$outputDir/domain/repositories/order_repository.dart').existsSync(),
      isTrue,
    );
  });
}
