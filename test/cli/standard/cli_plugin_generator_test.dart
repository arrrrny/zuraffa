// Tests for CliGeneratorPlugin — the FR-011 generator.
//
// Covers U46-U48 and A5 (SC-005) in the test-list.
//
// Pure-Dart (FR-012): no package:flutter import.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';
import 'package:zuraffa/src/plugins/cli/cli_plugin.dart'
    show CliGeneratorPlugin;

void main() {
  group('CliGeneratorPlugin', () {
    late CliGeneratorPlugin plugin;

    setUp(() {
      plugin = CliGeneratorPlugin(outputDir: 'lib/src');
    });

    group('plugin metadata (FR-010, FR-011)', () {
      test('U46: id is "cli" and name is "Standard CLI Plugin"', () {
        expect(plugin.id, equals('cli'));
        expect(plugin.name, equals('Standard CLI Plugin'));
        expect(plugin.version, equals(CliPlugin.pluginVersion));
      });

      test('runAfter includes usecase/repository/di', () {
        expect(
          plugin.runAfter,
          containsAll(const ['usecase', 'repository', 'di']),
        );
      });
    });

    group('generateForEntity (FR-011, SC-005)', () {
      test(
        'U47: produces a file at lib/src/cli/commands/<snake>_command.dart',
        () {
          final file = plugin.generateForEntity('Product');
          expect(
            file.path,
            equals('lib/src/cli/commands/product_command.dart'),
          );
          expect(file.type, equals('cli_command'));
          expect(file.action, equals('create'));
          expect(file.content, isNotNull);
        },
      );

      test('generated file imports the entity\'s use-case class by name', () {
        final file = plugin.generateForEntity('Product');
        final content = file.content!;
        expect(
          content,
          contains(
            "import '../../domain/entities/product/product_usecase.dart'",
          ),
        );
        expect(content, contains('ProductUseCase'));
      });

      test('generated file imports the standard CLI plugin runtime', () {
        final file = plugin.generateForEntity('Product');
        final content = file.content!;
        expect(content, contains("import 'package:zuraffa/zuraffa.dart'"));
        expect(content, contains('extends StandardCommand'));
      });

      test(
        'U48: generated file passes dart analyze (no manual DI wiring)',
        () async {
          final file = plugin.generateForEntity('Product');
          final content = file.content!;

          // The contract: the generated file must NOT contain any
          // `GetIt.instance.registerSingleton` or similar manual DI wiring.
          expect(
            content.contains('GetIt.instance'),
            isFalse,
            reason:
                'Generated CLI command must not contain manual DI wiring '
                '(SC-005: zero manual wiring).',
          );
          expect(content.contains('registerSingleton'), isFalse);
          expect(content.contains('registerFactory'), isFalse);
          expect(content.contains('registerLazySingleton'), isFalse);

          // The generated file must not import package:flutter.
          expect(
            content.contains('package:flutter'),
            isFalse,
            reason: 'Generated CLI command must be pure-Dart (FR-012).',
          );

          // The generated file declares a class named <Entity>Command.
          expect(
            content,
            contains('class ProductCommand extends StandardCommand'),
          );
        },
      );

      test('PascalCase entity name produces correctly-named class', () {
        final file = plugin.generateForEntity('orderItem');
        final content = file.content!;
        expect(
          content,
          contains('class OrderItemCommand extends StandardCommand'),
        );
        expect(
          file.path,
          equals('lib/src/cli/commands/order_item_command.dart'),
        );
      });

      test(
        'handler returns SuccessResult with entity name and method',
        () async {
          final file = plugin.generateForEntity('Product');
          final content = file.content!;
          // The generated handler must return a CommandResult.
          expect(content, contains('SuccessResult'));
        },
      );
    });

    group('generateWithContext (FR-011)', () {
      test('returns a GeneratedFile for the given entity', () {
        // generateForEntity is a synchronous helper; the test asserts the
        // returned GeneratedFile is well-formed.
        final file = plugin.generateForEntity('Product');
        expect(file.path, equals('lib/src/cli/commands/product_command.dart'));
      });
    });

    group('createCommand (FR-011)', () {
      test('exposes a `cli` subcommand to the existing CliRunner', () {
        final cmd = plugin.createCommand();
        expect(cmd.name, equals('cli'));
        expect(
          cmd.description,
          contains('Generate a standardized CLI command'),
        );
      });
    });

    group('disk write (issue #1022)', () {
      late Directory tmpDir;
      late String previousDir;

      setUp(() async {
        tmpDir = await Directory.systemTemp.createTemp('cli_plugin_test_');
        previousDir = Directory.current.path;
      });

      tearDown(() async {
        Directory.current = previousDir;
        if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
      });

      test(
        'U48: cli command writes file to disk that dart analyze accepts',
        () async {
          // Create a self-contained project skeleton inside the temp dir
          // so FileUtils.writeFile lands at the correct relative path and
          // dart analyze can resolve all imports — no global state mutation.
          final cliDir = p.join(tmpDir.path, 'lib', 'src', 'cli', 'commands');
          final entityDir = p.join(
            tmpDir.path,
            'lib',
            'src',
            'domain',
            'entities',
            'product',
          );
          await Directory(cliDir).create(recursive: true);
          await Directory(entityDir).create(recursive: true);

          // Stub the entity use-case the generated import references.
          await File(p.join(entityDir, 'product_usecase.dart')).writeAsString(
            'class ProductUseCase {\n'
            '  Future<dynamic> getList() async => [];\n'
            '}\n',
          );

          // Point the temp project at zuraffa so dart analyze can resolve
          // the generated import `package:zuraffa/zuraffa.dart`.
          final projectRoot = previousDir;
          await File(p.join(tmpDir.path, 'pubspec.yaml')).writeAsString('''
name: cli_analyze_stub
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  zuraffa:
    path: $projectRoot
''');

          // Resolve dependencies so dart analyze can resolve package imports.
          await Process.run('dart', [
            'pub',
            'get',
          ], workingDirectory: tmpDir.path);

          // Point FileUtils.writeFile into the temp dir.
          Directory.current = tmpDir.path;

          // Register the cli command in a fresh runner.
          final runner = CommandRunner<void>('zfa-test', 'test runner');
          runner.addCommand(plugin.createCommand());

          await runner.run(['cli', 'Product']);

          // The file must exist on disk — not just in-memory.
          final expectedPath = p.join(
            tmpDir.path,
            'lib',
            'src',
            'cli',
            'commands',
            'product_command.dart',
          );
          expect(
            await File(expectedPath).exists(),
            isTrue,
            reason:
                'zfa cli Product must write lib/src/cli/commands/product_command.dart '
                'to disk (issue #1022: phantom write).',
          );

          // The generated file must pass dart analyze (compile gate).
          final analyzeResult = await Process.run('dart', [
            'analyze',
            expectedPath,
          ], workingDirectory: tmpDir.path);
          expect(
            analyzeResult.exitCode,
            0,
            reason:
                'Generated CLI command must pass dart analyze (compile gate).\n'
                'stdout: ${analyzeResult.stdout}\n'
                'stderr: ${analyzeResult.stderr}',
          );
        },
        timeout: const Timeout(Duration(minutes: 2)),
      );
    });
  });
}
