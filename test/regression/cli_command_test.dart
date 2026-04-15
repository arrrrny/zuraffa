import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late String zfaBin;
  late bool useCompiledBinary;

  setUpAll(() {
    // Prefer the compiled AOT binary for speed (milliseconds vs seconds per invocation)
    final homeDir = Platform.environment['HOME'] ?? '';
    final compiledBin = p.join(homeDir, '.pub-cache', 'bin', 'zfa');
    final compiledExists = File(compiledBin).existsSync();

    if (compiledExists) {
      zfaBin = compiledBin;
      useCompiledBinary = true;
    } else {
      // Fallback: use dart run on the source script
      zfaBin = File('bin/zfa.dart').absolute.path;
      useCompiledBinary = false;
    }
  });

  /// Runs the zfa CLI with the given arguments.
  Future<ProcessResult> runZfa(List<String> args, {String? workingDirectory}) {
    if (useCompiledBinary) {
      return Process.run(zfaBin, args, workingDirectory: workingDirectory);
    } else {
      return Process.run('dart', [
        'run',
        zfaBin,
        ...args,
      ], workingDirectory: workingDirectory);
    }
  }

  test('cli generate from flags creates output', () async {
    final tempDir = await Directory.systemTemp.createTemp('zfa_cli_');
    addTearDown(() => tempDir.delete(recursive: true));
    final outputDir = '${tempDir.path}/lib/src';

    final result = await runZfa([
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

    final result = await runZfa([
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
      File('$outputDir/domain/repositories/order_repository.dart').existsSync(),
      isTrue,
    );
  });

  test('cli plugin list prints available plugins', () async {
    final tempDir = await Directory.systemTemp.createTemp('zfa_cli_plugins_');
    addTearDown(() => tempDir.delete(recursive: true));

    final result = await runZfa([
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
  });

  test('cli plugin disable and enable updates config', () async {
    final tempDir = await Directory.systemTemp.createTemp('zfa_cli_plugins_');
    addTearDown(() => tempDir.delete(recursive: true));
    final configFile = File('${tempDir.path}/.zfa.json');
    await configFile.writeAsString('{}');

    final disableResult = await runZfa([
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

    final enableResult = await runZfa([
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
  });

  test('cli generate skips disabled plugins', () async {
    final tempDir = await Directory.systemTemp.createTemp('zfa_cli_plugins_');
    addTearDown(() => tempDir.delete(recursive: true));
    final outputDir = '${tempDir.path}/lib/src';
    final configFile = File('${tempDir.path}/.zfa.json');

    await configFile.writeAsString('{"plugins": {"disabled": ["view"]}}');

    final result = await runZfa([
      'generate',
      'Product',
      '--methods=get',
      '--vpcs',
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
  });

  test('cli debug saves artifacts', () async {
    final tempDir = await Directory.systemTemp.createTemp('zfa_cli_debug_');
    addTearDown(() => tempDir.delete(recursive: true));
    final outputDir = '${tempDir.path}/lib/src';

    final result = await runZfa([
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
  });

  test('cli error suggestions include id-field-type hint', () async {
    final tempDir = await Directory.systemTemp.createTemp('zfa_cli_error_');
    addTearDown(() => tempDir.delete(recursive: true));
    final outputDir = '${tempDir.path}/lib/src';

    final result = await runZfa([
      'generate',
      'Product',
      '--methods=get',
      '--id-field-type=BadType',
      '--output',
      outputDir,
    ], workingDirectory: tempDir.path);

    expect(result.exitCode, isNot(equals(0)));
    final output = result.stdout.toString() + result.stderr.toString();
    expect(output, contains('Suggestions'));
    expect(output, contains('Use --id-field-type=String,int,NoParams'));
  });
}
