import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/usecase/usecase_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_osbg_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('generates os_background usecase with service dependency', () async {
    final plugin = UseCasePlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );
    final config = GeneratorConfig(
      name: 'SyncData',
      service: 'Data',
      domain: 'sync',
      paramsType: 'NoParams',
      returnsType: 'void',
      useCaseType: 'os_background',
      outputDir: outputDir,
    );
    final files = await plugin.generate(config);
    expect(files.length, equals(1));
    final content = files.first.content ?? '';

    // Must extend OsBackgroundTaskUseCase
    expect(content.contains('OsBackgroundTaskUseCase<void>'), isTrue);
    expect(content.contains('class SyncDataUseCase'), isTrue);

    // Must have descriptor getter
    expect(
      content.contains('OsBackgroundTaskDescriptor get descriptor'),
      isTrue,
    );
    expect(content.contains('com.zuraffa.sync_data_task'), isTrue);

    // Must have execute method
    expect(content.contains('Future<void> execute'), isTrue);

    // Must have callbackHandler with @pragma('vm:entry-point')
    expect(content.contains("@pragma('vm:entry-point')"), isTrue);
    expect(content.contains('callbackHandler'), isTrue);

    // Must inject service dependency
    expect(content.contains('final DataService _dataService;'), isTrue);
    expect(content.contains('SyncDataUseCase(this._dataService);'), isTrue);
  });

  test('generates os_background usecase with repo dependency', () async {
    final plugin = UseCasePlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );
    final config = GeneratorConfig(
      name: 'PeriodicCleanup',
      repo: 'Cache',
      domain: 'maintenance',
      paramsType: 'NoParams',
      returnsType: 'void',
      useCaseType: 'os_background',
      outputDir: outputDir,
    );
    final files = await plugin.generate(config);
    final content = files.first.content ?? '';

    expect(content.contains('class PeriodicCleanupUseCase'), isTrue);
    expect(content.contains('OsBackgroundTaskUseCase<void>'), isTrue);
    expect(content.contains('final CacheRepository _cacheRepository;'), isTrue);
    expect(
      content.contains('PeriodicCleanupUseCase(this._cacheRepository);'),
      isTrue,
    );
    expect(
      content.contains('await _cacheRepository.periodicCleanup(params);'),
      isTrue,
    );
  });

  test('generates os_background usecase without dependency', () async {
    final plugin = UseCasePlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );
    final config = GeneratorConfig(
      name: 'HeartbeatPing',
      domain: 'health',
      paramsType: 'NoParams',
      returnsType: 'void',
      useCaseType: 'os_background',
      outputDir: outputDir,
    );
    final files = await plugin.generate(config);
    final content = files.first.content ?? '';

    expect(content.contains('class HeartbeatPingUseCase'), isTrue);
    expect(content.contains('OsBackgroundTaskUseCase<void>'), isTrue);
    // No service/repo dependency fields
    expect(content.contains('Repository'), isFalse);
    expect(content.contains('Service'), isFalse);
    // Has TODO placeholder
    expect(
      content.contains('TODO: Implement OS background task logic'),
      isTrue,
    );
  });

  test('generates os_background usecase with typed returns', () async {
    final plugin = UseCasePlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );
    final config = GeneratorConfig(
      name: 'FetchWeather',
      service: 'Weather',
      domain: 'weather',
      paramsType: 'NoParams',
      returnsType: 'WeatherData',
      useCaseType: 'os_background',
      outputDir: outputDir,
    );
    final files = await plugin.generate(config);
    final content = files.first.content ?? '';

    expect(content.contains('OsBackgroundTaskUseCase<WeatherData>'), isTrue);
    expect(content.contains('Future<WeatherData> execute'), isTrue);
  });

  test('plugin routes os_background type to the correct generator', () async {
    final plugin = UseCasePlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );

    // Verify that the osBackgroundGenerator is created
    expect(plugin.osBackgroundGenerator, isNotNull);
  });
}
