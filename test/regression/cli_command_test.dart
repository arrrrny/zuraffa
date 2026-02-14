import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

@Timeout(Duration(minutes: 5))
void main() {
  test(
    'cli generate from flags creates output',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('zfa_cli_');
      addTearDown(() => tempDir.delete(recursive: true));
      final outputDir = '${tempDir.path}/lib/src';
      final cliPath = File('bin/zfa.dart').absolute.path;

      final result = await Process.run('dart', [
        'run',
        cliPath,
        'generate',
        'Product',
        '--methods=get,getList',
        '--data',
        '--output',
        outputDir,
        '--force',
      ], workingDirectory: tempDir.path);

      expect(
        result.exitCode,
        equals(0),
        reason: '${result.stderr}\n${result.stdout}',
      );
      expect(
        File(
          '$outputDir/domain/repositories/product_repository.dart',
        ).existsSync(),
        isTrue,
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'cli generate from json keeps config format',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('zfa_cli_');
      addTearDown(() => tempDir.delete(recursive: true));
      final outputDir = '${tempDir.path}/lib/src';
      final configFile = File('${tempDir.path}/config.json');
      final cliPath = File('bin/zfa.dart').absolute.path;

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
        cliPath,
        'generate',
        'Order',
        '--from-json',
        configFile.path,
        '--output',
        outputDir,
        '--force',
      ], workingDirectory: tempDir.path);

      expect(
        result.exitCode,
        equals(0),
        reason: '${result.stderr}\n${result.stdout}',
      );
      expect(
        File(
          '$outputDir/domain/repositories/order_repository.dart',
        ).existsSync(),
        isTrue,
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'cli plugin list prints available plugins',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('zfa_cli_plugins_');
      addTearDown(() => tempDir.delete(recursive: true));
      final cliPath = File('bin/zfa.dart').absolute.path;

      final result = await Process.run('dart', [
        'run',
        cliPath,
        'plugin',
        'list',
      ], workingDirectory: tempDir.path);

      expect(
        result.exitCode,
        equals(0),
        reason: '${result.stderr}\n${result.stdout}',
      );
      expect(result.stdout.toString(), contains('repository'));
      expect(result.stdout.toString(), contains('usecase'));
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'cli plugin disable and enable updates config',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('zfa_cli_plugins_');
      addTearDown(() => tempDir.delete(recursive: true));
      final configFile = File('${tempDir.path}/.zfa.json');
      await configFile.writeAsString('{}');
      final cliPath = File('bin/zfa.dart').absolute.path;

      final disableResult = await Process.run('dart', [
        'run',
        cliPath,
        'plugin',
        'disable',
        'view',
      ], workingDirectory: tempDir.path);
      expect(
        disableResult.exitCode,
        equals(0),
        reason: '${disableResult.stderr}\n${disableResult.stdout}',
      );

      final disabledConfig =
          jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
      final disabledPlugins =
          (disabledConfig['plugins']?['disabled'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList();
      expect(disabledPlugins.contains('view'), isTrue);

      final enableResult = await Process.run('dart', [
        'run',
        cliPath,
        'plugin',
        'enable',
        'view',
      ], workingDirectory: tempDir.path);
      expect(
        enableResult.exitCode,
        equals(0),
        reason: '${enableResult.stderr}\n${enableResult.stdout}',
      );

      final enabledConfig =
          jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
      final enabledPlugins =
          (enabledConfig['plugins']?['disabled'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList();
      expect(enabledPlugins.contains('view'), isFalse);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'cli generate skips disabled plugins',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('zfa_cli_plugins_');
      addTearDown(() => tempDir.delete(recursive: true));
      final outputDir = '${tempDir.path}/lib/src';
      final configFile = File('${tempDir.path}/.zfa.json');
      final cliPath = File('bin/zfa.dart').absolute.path;

      await configFile.writeAsString('''
{
  "plugins": {
    "disabled": ["view"]
  }
}
''');

      final result = await Process.run('dart', [
        'run',
        cliPath,
        'generate',
        'Product',
        '--methods=get',
        '--vpc',
        '--output',
        outputDir,
        '--force',
      ], workingDirectory: tempDir.path);

      expect(
        result.exitCode,
        equals(0),
        reason: '${result.stderr}\n${result.stdout}',
      );

      expect(
        File(
          '$outputDir/presentation/pages/product/product_controller.dart',
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          '$outputDir/presentation/pages/product/product_presenter.dart',
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          '$outputDir/presentation/pages/product/product_view.dart',
        ).existsSync(),
        isFalse,
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test('cli debug saves artifacts', () async {
    final tempDir = await Directory.systemTemp.createTemp('zfa_cli_debug_');
    addTearDown(() => tempDir.delete(recursive: true));
    final outputDir = '${tempDir.path}/lib/src';
    final cliPath = File('bin/zfa.dart').absolute.path;

    final result = await Process.run('dart', [
      'run',
      cliPath,
      'generate',
      'Product',
      '--methods=get',
      '--output',
      outputDir,
      '--debug',
      '--force',
    ], workingDirectory: tempDir.path);

    expect(
      result.exitCode,
      equals(0),
      reason: '${result.stderr}\n${result.stdout}',
    );

    final debugDir = Directory('${tempDir.path}/.zfa_debug');
    expect(debugDir.existsSync(), isTrue);
    final entries = debugDir.listSync().whereType<Directory>().toList();
    expect(entries.isNotEmpty, isTrue);
  }, timeout: const Timeout(Duration(minutes: 5)));

  test(
    'cli error suggestions include id-field-type hint',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('zfa_cli_error_');
      addTearDown(() => tempDir.delete(recursive: true));
      final outputDir = '${tempDir.path}/lib/src';
      final cliPath = File('bin/zfa.dart').absolute.path;

      final result = await Process.run('dart', [
        'run',
        cliPath,
        'generate',
        'Product',
        '--methods=get',
        '--id-field-type=BadType',
        '--output',
        outputDir,
      ], workingDirectory: tempDir.path);

      expect(result.exitCode, isNot(equals(0)));
      expect(result.stdout.toString(), contains('Suggestions'));
      expect(
        result.stdout.toString(),
        contains('Use --id-field-type=String,int,NoParams'),
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
