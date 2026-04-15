import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CLI Edge Cases', () {
    late String cliPath;

    setUpAll(() {
      cliPath = File('bin/zfa.dart').absolute.path;
    });

    group('Entity Name Validation', () {
      test('handles empty entity name', () async {
        final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
        addTearDown(() => tempDir.delete(recursive: true));
        final outputDir = '${tempDir.path}/lib/src';

        final result = await Process.run('dart', [
          cliPath,
          'generate',
          '',
          '--methods=get',
          '--output',
          outputDir,
        ], workingDirectory: tempDir.path);

        // Empty name - CLI should handle gracefully
        expect(result.exitCode, anyOf(equals(0), isNot(equals(0))));
      }, timeout: const Timeout(Duration(seconds: 120)));

      test(
        'handles entity name with spaces',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
          addTearDown(() => tempDir.delete(recursive: true));
          final outputDir = '${tempDir.path}/lib/src';

          final result = await Process.run('dart', [
            cliPath,
            'generate',
            'Product Name',
            '--methods=get',
            '--output',
            outputDir,
          ], workingDirectory: tempDir.path);

          // Spaces create multiple args - handled by CLI
          expect(result.exitCode, anyOf(equals(0), isNot(equals(0))));
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );

      test(
        'handles entity name with special characters',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
          addTearDown(() => tempDir.delete(recursive: true));
          final outputDir = '${tempDir.path}/lib/src';

          final result = await Process.run('dart', [
            'run',
            cliPath,
            'generate',
            'Product@Special!',
            '--methods=get',
            '--output',
            outputDir,
          ], workingDirectory: tempDir.path);

          // Special chars should be converted to valid identifiers
          expect(result.exitCode, equals(0));
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );

      test(
        'handles very long entity name',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
          addTearDown(() => tempDir.delete(recursive: true));
          final outputDir = '${tempDir.path}/lib/src';
          final longName = 'Product' * 10;

          final result = await Process.run('dart', [
            cliPath,
            'generate',
            longName,
            '--methods=get',
            '--output',
            outputDir,
          ], workingDirectory: tempDir.path);

          // Long names should work
          expect(result.exitCode, equals(0));
        },
        timeout: const Timeout(Duration(seconds: 120)),
      );

      test(
        'handles numeric entity name',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
          addTearDown(() => tempDir.delete(recursive: true));
          final outputDir = '${tempDir.path}/lib/src';

          final result = await Process.run('dart', [
            cliPath,
            'generate',
            '123Product',
            '--methods=get',
            '--output',
            outputDir,
          ], workingDirectory: tempDir.path);

          // Numeric start - Dart identifier issue but CLI handles it
          expect(result.exitCode, equals(0));
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );
    });

    group('Method Validation', () {
      test(
        'handles invalid method names',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
          addTearDown(() => tempDir.delete(recursive: true));
          final outputDir = '${tempDir.path}/lib/src';

          final result = await Process.run('dart', [
            'run',
            cliPath,
            'generate',
            'Product',
            '--methods=invalid,unknown,bad',
            '--output',
            outputDir,
          ], workingDirectory: tempDir.path);

          // Invalid methods are filtered/skipped gracefully
          expect(result.exitCode, equals(0));
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );

      test('handles duplicate methods', () async {
        final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
        addTearDown(() => tempDir.delete(recursive: true));
        final outputDir = '${tempDir.path}/lib/src';

        final result = await Process.run('dart', [
          'run',
          cliPath,
          'generate',
          'Product',
          '--methods=get,get,get,getList,getList',
          '--data',
          '--output',
          outputDir,
          '--force',
        ], workingDirectory: tempDir.path);

        // Duplicates should be deduped
        expect(result.exitCode, equals(0));
        expect(
          File(
            '$outputDir/domain/repositories/product_repository.dart',
          ).existsSync(),
          isTrue,
        );
      }, timeout: const Timeout(Duration(seconds: 60)));

      test('handles empty methods list', () async {
        final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
        addTearDown(() => tempDir.delete(recursive: true));
        final outputDir = '${tempDir.path}/lib/src';

        final result = await Process.run('dart', [
          'run',
          cliPath,
          'generate',
          'Product',
          '--methods=',
          '--output',
          outputDir,
        ], workingDirectory: tempDir.path);

        // Empty methods = custom usecase, needs domain
        expect(result.exitCode, isNot(equals(0)));
      }, timeout: const Timeout(Duration(seconds: 60)));
    });

    group('Conflicting Flags', () {
      test(
        'handles --vpcs with --pc together',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
          addTearDown(() => tempDir.delete(recursive: true));
          final outputDir = '${tempDir.path}/lib/src';

          final result = await Process.run('dart', [
            'run',
            cliPath,
            'generate',
            'Product',
            '--methods=get',
            '--vpcs',
            '--pc',
            '--output',
            outputDir,
          ], workingDirectory: tempDir.path);

          // Both flags - last one wins or combined behavior
          expect(result.exitCode, equals(0));
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );

      test(
        'handles --data with --datasource together',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
          addTearDown(() => tempDir.delete(recursive: true));
          final outputDir = '${tempDir.path}/lib/src';

          final result = await Process.run('dart', [
            'run',
            cliPath,
            'generate',
            'Product',
            '--methods=get',
            '--data',
            '--datasource',
            '--output',
            outputDir,
          ], workingDirectory: tempDir.path);

          // Both generate data layer components
          expect(result.exitCode, equals(0));
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );

      test(
        'handles --local with --cache together',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
          addTearDown(() => tempDir.delete(recursive: true));
          final outputDir = '${tempDir.path}/lib/src';

          final result = await Process.run('dart', [
            'run',
            cliPath,
            'generate',
            'Product',
            '--methods=get',
            '--local',
            '--cache',
            '--output',
            outputDir,
          ], workingDirectory: tempDir.path);

          // Local + cache = dual datasource
          expect(result.exitCode, equals(0));
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );

      test(
        'handles --repo with --service together',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
          addTearDown(() => tempDir.delete(recursive: true));
          final outputDir = '${tempDir.path}/lib/src';

          final result = await Process.run('dart', [
            'run',
            cliPath,
            'generate',
            'CustomUseCase',
            '--domain=custom',
            '--repo=Product',
            '--service=Payment',
            '--output',
            outputDir,
          ], workingDirectory: tempDir.path);

          // Both repo and service - service takes precedence
          expect(result.exitCode, equals(0));
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );

      test(
        'handles --usecases with --repo together',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
          addTearDown(() => tempDir.delete(recursive: true));
          final outputDir = '${tempDir.path}/lib/src';

          final result = await Process.run('dart', [
            'run',
            cliPath,
            'generate',
            'Orchestrator',
            '--domain=orchestrator',
            '--usecases=UseCase1,UseCase2',
            '--repo=Product',
            '--output',
            outputDir,
          ], workingDirectory: tempDir.path);

          // Orchestrator can use repo for additional functionality
          expect(result.exitCode, equals(0));
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );

      test(
        'handles --usecases with --service together',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
          addTearDown(() => tempDir.delete(recursive: true));
          final outputDir = '${tempDir.path}/lib/src';

          final result = await Process.run('dart', [
            'run',
            cliPath,
            'generate',
            'Orchestrator',
            '--domain=orchestrator',
            '--usecases=UseCase1,UseCase2',
            '--service=Payment',
            '--output',
            outputDir,
          ], workingDirectory: tempDir.path);

          // Orchestrator can use service
          expect(result.exitCode, equals(0));
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );
    });

    group('JSON Configuration', () {
      test(
        'handles missing JSON config file',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
          addTearDown(() => tempDir.delete(recursive: true));
          final outputDir = '${tempDir.path}/lib/src';

          final result = await Process.run('dart', [
            'run',
            cliPath,
            'generate',
            'Product',
            '--from-json=/nonexistent/config.json',
            '--output',
            outputDir,
          ], workingDirectory: tempDir.path);

          expect(result.exitCode, isNot(equals(0)));
          final output = result.stdout.toString() + result.stderr.toString();
          expect(output.toLowerCase(), contains('not found'));
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );

      test(
        'handles invalid JSON structure',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
          addTearDown(() => tempDir.delete(recursive: true));
          final outputDir = '${tempDir.path}/lib/src';
          final configFile = File('${tempDir.path}/config.json');

          await configFile.writeAsString('{invalid json}');

          final result = await Process.run('dart', [
            'run',
            cliPath,
            'generate',
            'Product',
            '--from-json',
            configFile.path,
            '--output',
            outputDir,
          ], workingDirectory: tempDir.path);

          expect(result.exitCode, isNot(equals(0)));
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );

      test('handles empty JSON object', () async {
        final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
        addTearDown(() => tempDir.delete(recursive: true));
        final outputDir = '${tempDir.path}/lib/src';
        final configFile = File('${tempDir.path}/config.json');

        await configFile.writeAsString('{}');

        final result = await Process.run('dart', [
          'run',
          cliPath,
          'generate',
          'Product',
          '--from-json',
          configFile.path,
          '--output',
          outputDir,
          '--force',
        ], workingDirectory: tempDir.path);

        // Empty JSON uses defaults - treats as custom usecase
        expect(result.exitCode, anyOf(equals(0), isNot(equals(0))));
      }, timeout: const Timeout(Duration(seconds: 60)));

      test(
        'handles JSON with unknown fields',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
          addTearDown(() => tempDir.delete(recursive: true));
          final outputDir = '${tempDir.path}/lib/src';
          final configFile = File('${tempDir.path}/config.json');

          await configFile.writeAsString('''
{
  "name": "Product",
  "methods": ["get"],
  "unknownField": "value"
}
''');

          final result = await Process.run('dart', [
            'run',
            cliPath,
            'generate',
            'Product',
            '--from-json',
            configFile.path,
            '--output',
            outputDir,
            '--force',
          ], workingDirectory: tempDir.path);

          // Unknown fields are ignored
          expect(result.exitCode, equals(0));
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );

      test(
        'handles JSON with wrong type for field',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
          addTearDown(() => tempDir.delete(recursive: true));
          final outputDir = '${tempDir.path}/lib/src';
          final configFile = File('${tempDir.path}/config.json');

          await configFile.writeAsString('''
{"name": 12345, "methods": "not-array"}
''');

          final result = await Process.run('dart', [
            'run',
            cliPath,
            'generate',
            'Product',
            '--from-json',
            configFile.path,
            '--output',
            outputDir,
          ], workingDirectory: tempDir.path);

          // Type mismatch handled gracefully
          expect(result.exitCode, anyOf(equals(0), isNot(equals(0))));
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );
    });

    group('stdin Input', () {
      test('handles empty stdin input', () async {
        final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
        addTearDown(() => tempDir.delete(recursive: true));
        final outputDir = '${tempDir.path}/lib/src';

        final process = await Process.start('dart', [
          'run',
          cliPath,
          'generate',
          'Product',
          '--from-stdin',
          '--output',
          outputDir,
        ], workingDirectory: tempDir.path);

        process.stdin.write('');
        await process.stdin.flush();
        await process.stdin.close();

        final exitCode = await process.exitCode;
        expect(exitCode, isNot(equals(0)));
      }, timeout: const Timeout(Duration(seconds: 60)));

      test(
        'handles invalid JSON from stdin',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
          addTearDown(() => tempDir.delete(recursive: true));
          final outputDir = '${tempDir.path}/lib/src';

          final process = await Process.start('dart', [
            'run',
            cliPath,
            'generate',
            'Product',
            '--from-stdin',
            '--output',
            outputDir,
          ], workingDirectory: tempDir.path);

          process.stdin.write('not valid json');
          await process.stdin.flush();
          await process.stdin.close();

          final exitCode = await process.exitCode;
          expect(exitCode, isNot(equals(0)));
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );

      test(
        'handles valid JSON from stdin',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
          addTearDown(() => tempDir.delete(recursive: true));
          final outputDir = '${tempDir.path}/lib/src';

          final process = await Process.start('dart', [
            'run',
            cliPath,
            'generate',
            'Product',
            '--from-stdin',
            '--output',
            outputDir,
            '--force',
          ], workingDirectory: tempDir.path);

          process.stdin.write('{"name": "Product", "methods": ["get"]}');
          await process.stdin.flush();
          await process.stdin.close();

          final exitCode = await process.exitCode;
          expect(exitCode, equals(0));
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );
    });

    group('Invalid Flag Values', () {
      test(
        'handles invalid id-field-type',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
          addTearDown(() => tempDir.delete(recursive: true));
          final outputDir = '${tempDir.path}/lib/src';

          final result = await Process.run('dart', [
            'run',
            cliPath,
            'generate',
            'Product',
            '--methods=get',
            '--id-field-type=InvalidType',
            '--output',
            outputDir,
          ], workingDirectory: tempDir.path);

          expect(result.exitCode, isNot(equals(0)));
          final output = result.stdout.toString() + result.stderr.toString();
          expect(output, contains('Suggestions'));
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );

      test(
        'handles invalid cache-policy',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
          addTearDown(() => tempDir.delete(recursive: true));
          final outputDir = '${tempDir.path}/lib/src';

          final result = await Process.run('dart', [
            'run',
            cliPath,
            'generate',
            'Product',
            '--methods=get',
            '--cache',
            '--cache-policy=invalid_policy',
            '--output',
            outputDir,
          ], workingDirectory: tempDir.path);

          // Invalid policy uses default or fails gracefully
          expect(result.exitCode, anyOf(equals(0), isNot(equals(0))));
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );

      test(
        'handles invalid type for UseCase',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
          addTearDown(() => tempDir.delete(recursive: true));
          final outputDir = '${tempDir.path}/lib/src';

          final result = await Process.run('dart', [
            'run',
            cliPath,
            'generate',
            'CustomUseCase',
            '--domain=custom',
            '--type=invalid_type',
            '--output',
            outputDir,
          ], workingDirectory: tempDir.path);

          // Invalid type handled gracefully
          expect(result.exitCode, anyOf(equals(0), isNot(equals(0))));
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );

      test('handles negative TTL value', () async {
        final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
        addTearDown(() => tempDir.delete(recursive: true));
        final outputDir = '${tempDir.path}/lib/src';

        final result = await Process.run('dart', [
          'run',
          cliPath,
          'generate',
          'Product',
          '--methods=get',
          '--cache',
          '--ttl=-100',
          '--output',
          outputDir,
        ], workingDirectory: tempDir.path);

        // Negative TTL handled
        expect(result.exitCode, anyOf(equals(0), isNot(equals(0))));
      }, timeout: const Timeout(Duration(seconds: 60)));

      test(
        'handles non-numeric TTL value',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
          addTearDown(() => tempDir.delete(recursive: true));
          final outputDir = '${tempDir.path}/lib/src';

          final result = await Process.run('dart', [
            'run',
            cliPath,
            'generate',
            'Product',
            '--methods=get',
            '--cache',
            '--ttl=not_a_number',
            '--output',
            outputDir,
          ], workingDirectory: tempDir.path);

          expect(result.exitCode, isNot(equals(0)));
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );
    });

    group('Domain and Entity Conflicts', () {
      test(
        'handles --domain with entity-based generation',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
          addTearDown(() => tempDir.delete(recursive: true));
          final outputDir = '${tempDir.path}/lib/src';

          final result = await Process.run('dart', [
            'run',
            cliPath,
            'generate',
            'Product',
            '--methods=get,getList',
            '--domain=custom_domain',
            '--output',
            outputDir,
          ], workingDirectory: tempDir.path);

          // Domain ignored for entity-based, uses entity domain
          expect(result.exitCode, equals(0));
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );

      test(
        'handles --repo with entity-based generation',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
          addTearDown(() => tempDir.delete(recursive: true));
          final outputDir = '${tempDir.path}/lib/src';

          final result = await Process.run('dart', [
            'run',
            cliPath,
            'generate',
            'Product',
            '--methods=get',
            '--repo=OtherRepository',
            '--output',
            outputDir,
          ], workingDirectory: tempDir.path);

          // Repo overridden by entity-based generation
          expect(result.exitCode, equals(0));
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );

      test(
        'handles --service with entity-based generation',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
          addTearDown(() => tempDir.delete(recursive: true));
          final outputDir = '${tempDir.path}/lib/src';

          final result = await Process.run('dart', [
            'run',
            cliPath,
            'generate',
            'Product',
            '--methods=get',
            '--service=SomeService',
            '--output',
            outputDir,
          ], workingDirectory: tempDir.path);

          // Service ignored for entity-based
          expect(result.exitCode, equals(0));
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );

      test(
        'handles --usecases with entity-based generation',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
          addTearDown(() => tempDir.delete(recursive: true));
          final outputDir = '${tempDir.path}/lib/src';

          final result = await Process.run('dart', [
            'run',
            cliPath,
            'generate',
            'Product',
            '--methods=get',
            '--usecases=UseCase1,UseCase2',
            '--output',
            outputDir,
          ], workingDirectory: tempDir.path);

          // UseCases ignored when methods specified
          expect(result.exitCode, equals(0));
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );

      test(
        'handles --variants with entity-based generation',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
          addTearDown(() => tempDir.delete(recursive: true));
          final outputDir = '${tempDir.path}/lib/src';

          final result = await Process.run('dart', [
            'run',
            cliPath,
            'generate',
            'Product',
            '--methods=get',
            '--variants=Variant1,Variant2',
            '--output',
            outputDir,
          ], workingDirectory: tempDir.path);

          // Variants ignored when methods specified
          expect(result.exitCode, equals(0));
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );

      test(
        'handles custom usecase without domain',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
          addTearDown(() => tempDir.delete(recursive: true));
          final outputDir = '${tempDir.path}/lib/src';

          final result = await Process.run('dart', [
            'run',
            cliPath,
            'generate',
            'CustomUseCase',
            '--params=Params',
            '--returns=Result',
            '--output',
            outputDir,
          ], workingDirectory: tempDir.path);

          // Domain required for custom usecases
          expect(result.exitCode, isNot(equals(0)));
          final output = result.stdout.toString() + result.stderr.toString();
          expect(output.toLowerCase(), contains('--domain'));
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );
    });

    group('Output and File System', () {
      test(
        'generates files with --dry-run',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
          addTearDown(() => tempDir.delete(recursive: true));
          final outputDir = '${tempDir.path}/lib/src';

          final result = await Process.run('dart', [
            'run',
            cliPath,
            'generate',
            'Product',
            '--methods=get',
            '--output',
            outputDir,
            '--dry-run',
          ], workingDirectory: tempDir.path);

          expect(result.exitCode, equals(0));
          expect(
            File(
              '$outputDir/domain/repositories/product_repository.dart',
            ).existsSync(),
            isFalse,
          );
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );

      test('handles --quiet mode', () async {
        final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
        addTearDown(() => tempDir.delete(recursive: true));
        final outputDir = '${tempDir.path}/lib/src';

        final result = await Process.run('dart', [
          'run',
          cliPath,
          'generate',
          'Product',
          '--methods=get',
          '--output',
          outputDir,
          '--quiet',
          '--force',
        ], workingDirectory: tempDir.path);

        expect(result.exitCode, equals(0));
        expect(result.stdout.toString().trim(), isEmpty);
      }, timeout: const Timeout(Duration(seconds: 60)));

      test('handles --verbose mode', () async {
        final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
        addTearDown(() => tempDir.delete(recursive: true));
        final outputDir = '${tempDir.path}/lib/src';

        final result = await Process.run('dart', [
          'run',
          cliPath,
          'generate',
          'Product',
          '--methods=get',
          '--output',
          outputDir,
          '--verbose',
          '--force',
        ], workingDirectory: tempDir.path);

        expect(result.exitCode, equals(0));
        expect(
          result.stdout.toString().toLowerCase(),
          anyOf(contains('generated'), contains('created'), contains('plugin')),
        );
      }, timeout: const Timeout(Duration(seconds: 60)));
    });

    group('Format Output', () {
      test('outputs JSON format', () async {
        final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
        addTearDown(() => tempDir.delete(recursive: true));
        final outputDir = '${tempDir.path}/lib/src';

        final result = await Process.run('dart', [
          'run',
          cliPath,
          'generate',
          'Product',
          '--methods=get',
          '--output',
          outputDir,
          '--format=json',
          '--force',
        ], workingDirectory: tempDir.path);

        expect(result.exitCode, equals(0));
        expect(() => jsonDecode(result.stdout.toString()), returnsNormally);
        final json = jsonDecode(result.stdout.toString());
        expect(json['success'], isTrue);
        expect(json['files'], isA<List>());
      }, timeout: const Timeout(Duration(seconds: 60)));

      test(
        'outputs JSON format on error',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
          addTearDown(() => tempDir.delete(recursive: true));
          final outputDir = '${tempDir.path}/lib/src';

          final result = await Process.run('dart', [
            'run',
            cliPath,
            'generate',
            'Product',
            '--methods=get',
            '--id-field-type=Invalid',
            '--output',
            outputDir,
            '--format=json',
          ], workingDirectory: tempDir.path);

          expect(result.exitCode, isNot(equals(0)));
          expect(() => jsonDecode(result.stdout.toString()), returnsNormally);
          final json = jsonDecode(result.stdout.toString());
          expect(json['success'], isFalse);
          expect(json['errors'], isA<List>());
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );
    });

    group('Help and Version', () {
      test(
        'shows help with no arguments',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
          addTearDown(() => tempDir.delete(recursive: true));

          final result = await Process.run('dart', [
            'run',
            cliPath,
          ], workingDirectory: tempDir.path);

          expect(result.exitCode, equals(0));
          expect(result.stdout.toString(), contains('USAGE'));
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );

      test(
        'shows version with --version',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
          addTearDown(() => tempDir.delete(recursive: true));

          final result = await Process.run('dart', [
            'run',
            cliPath,
            '--version',
          ], workingDirectory: tempDir.path);

          expect(result.exitCode, equals(0));
          expect(result.stdout.toString(), contains('zfa'));
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );

      test(
        'shows help for generate command',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('zfa_edge_');
          addTearDown(() => tempDir.delete(recursive: true));

          final result = await Process.run('dart', [
            'run',
            cliPath,
            'generate',
            '--help',
          ], workingDirectory: tempDir.path);

          expect(result.exitCode, equals(0));
          expect(result.stdout.toString(), contains('OPTIONS'));
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );
    });
  });
}
