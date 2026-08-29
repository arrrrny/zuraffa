import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/commands/make_command.dart';
import 'package:zuraffa/src/plugins/shadcn/capabilities/ui_vocabulary_export_capability.dart';
import 'package:zuraffa/src/plugins/shadcn/shadcn_plugin.dart';

void main() {
  late CliRunner runner;
  late Directory tempDir;

  setUp(() {
    runner = CliRunner(exitOnCompletion: false);
    tempDir = Directory.systemTemp.createTempSync('zfa_ui_cmd_');
    File('${tempDir.path}/pubspec.yaml').writeAsStringSync(
      'name: test_app\n'
      'environment:\n  sdk: ^3.11.0\n'
      'dependencies:\n  flutter:\n    sdk: flutter\n',
    );
    exitCode = 0;
  });

  tearDown(() {
    exitCode = 0;
    tempDir.deleteSync(recursive: true);
  });

  String writePayload(String name, Map<String, dynamic> payload) {
    final file = File('${tempDir.path}/$name');
    file.writeAsStringSync(jsonEncode(payload));
    return file.path;
  }

  Map<String, dynamic> node(
    String type, {
    Map<String, Object?>? props,
    List<Map<String, dynamic>>? children,
    String? styleToken,
  }) => {
    'type': type,
    'props': ?props,
    'children': ?children,
    'styleToken': ?styleToken,
  };

  group('zfa ui schema', () {
    test('writes/prints the schema with --out (FR-001)', () async {
      final out = File('${tempDir.path}/ui-schema.json').path;
      final output = await runner.runCapturing([
        'ui',
        'schema',
        '--project-root=${tempDir.path}',
        '--out=$out',
      ]);
      expect(File(out).existsSync(), true);
      final schema =
          jsonDecode(File(out).readAsStringSync()) as Map<String, dynamic>;
      expect(schema['schemaVersion'], isA<String>());
      expect((schema['components'] as Map).keys, contains('card'));
      expect(output, contains('schema'));
    });

    test('diff-stable across two CLI runs (SC-001)', () async {
      final out1 = File('${tempDir.path}/s1.json').path;
      final out2 = File('${tempDir.path}/s2.json').path;
      await runner.runCapturing([
        'ui',
        'schema',
        '--project-root=${tempDir.path}',
        '--out=$out1',
      ]);
      await runner.runCapturing([
        'ui',
        'schema',
        '--project-root=${tempDir.path}',
        '--out=$out2',
      ]);
      expect(
        File(out2).readAsStringSync(),
        equals(File(out1).readAsStringSync()),
      );
    });

    test('--expect-version mismatch fails (US-5 scenario 3)', () async {
      final output = await runner.runCapturing([
        'ui',
        'schema',
        '--project-root=${tempDir.path}',
        '--expect-version=9.9.9',
      ]);
      expect(output, contains('9.9.9'));
      expect(exitCode, 1);
    });

    test(
      'plugin missing produces an actionable error (FR-008 / Edge Cases)',
      () async {
        final output = await runner.runCapturing([
          'ui',
          'schema',
          '--project-root=${tempDir.path}',
          '--no-plugin',
        ]);
        expect(output.toLowerCase(), contains('shadcn plugin not found'));
        expect(output.toLowerCase(), contains('install'));
        expect(exitCode, 1);
      },
    );
  });

  group('zfa ui validate', () {
    test('valid payload exits 0 with clean report (US-3 scenario 1)', () async {
      final file = writePayload('good.json', {
        'tree': node(
          'card',
          children: [
            node('text', props: {'value': 'Hello'}),
          ],
        ),
      });
      final output = await runner.runCapturing([
        'ui',
        'validate',
        file,
        '--project-root=${tempDir.path}',
      ]);
      expect(output.toLowerCase(), contains('valid'));
      expect(exitCode, 0);
    });

    test(
      'invalid payload exits 1 with diagnostics (US-3 scenarios 2-5)',
      () async {
        final file = writePayload('bad.json', {
          'tree': node(
            'card',
            children: [
              node('ghost_node'),
              node('text', styleToken: 'neon'),
            ],
          ),
        });
        final output = await runner.runCapturing([
          'ui',
          'validate',
          file,
          '--project-root=${tempDir.path}',
        ]);
        expect(output, contains('ghost_node'));
        expect(output, contains('neon'));
        expect(exitCode, 1);
      },
    );

    test('file not found is actionable (FR-008)', () async {
      final output = await runner.runCapturing([
        'ui',
        'validate',
        '${tempDir.path}/missing.json',
        '--project-root=${tempDir.path}',
      ]);
      expect(output.toLowerCase(), contains('not found'));
      expect(exitCode, 1);
    });

    test('invalid JSON reports the file (Edge Cases)', () async {
      final file = File('${tempDir.path}/broken.json')
        ..writeAsStringSync('{nope');
      final output = await runner.runCapturing([
        'ui',
        'validate',
        file.path,
        '--project-root=${tempDir.path}',
      ]);
      expect(output, contains('broken.json'));
      expect(output.toUpperCase(), contains('JSON'));
      expect(exitCode, 1);
    });
  });

  group('zfa ui preview', () {
    test(
      'invalid payload reports errors and does not render (US-4 scenario 3)',
      () async {
        final file = writePayload('bad.json', {'tree': node('ghost_node')});
        final output = await runner.runCapturing([
          'ui',
          'preview',
          file,
          '--project-root=${tempDir.path}',
        ]);
        expect(output, contains('ghost_node'));
        expect(output.toLowerCase(), isNot(contains('rendering')));
        expect(exitCode, 1);
      },
    );

    test('non-macOS fails with platform-not-supported (Edge Cases)', () async {
      final file = writePayload('good.json', {
        'tree': node(
          'card',
          children: [
            node('text', props: {'value': 'Preview me'}),
          ],
        ),
      });
      final output = await runner.runCapturing([
        'ui',
        'preview',
        file,
        '--project-root=${tempDir.path}',
        '--platform=linux',
      ]);
      expect(output.toLowerCase(), contains('macos'));
      expect(output.toLowerCase(), contains('not supported'));
      expect(exitCode, 1);
    });

    test(
      'macOS path generates the harness entrypoint (US-4 scenario 1)',
      () async {
        final file = writePayload('good.json', {
          'tree': node(
            'card',
            children: [
              node('text', props: {'value': 'Preview me'}),
            ],
          ),
        });
        final output = await runner.runCapturing([
          'ui',
          'preview',
          file,
          '--project-root=${tempDir.path}',
          '--platform=macos',
          '--dry-run',
        ]);
        expect(output.toLowerCase(), contains('harness'));
        final harness = File(
          '${tempDir.path}/.zfa/ui/preview/main_preview.dart',
        );
        expect(
          harness.existsSync(),
          true,
          reason: 'preview harness entrypoint must be generated',
        );
        expect(harness.readAsStringSync(), contains('main'));
        expect(harness.readAsStringSync(), contains('payload'));
      },
    );
  });

  group('zfa make <Name> --ui (FR-002)', () {
    test('scaffolds a composite without requiring an entity', () async {
      final make = MakeCommand.forTesting(projectRoot: tempDir.path);
      await make.runForUi('OfferCard');

      expect(
        File(
          '${tempDir.path}/lib/src/ui/nodes/offer_card_node.dart',
        ).existsSync(),
        true,
      );
      expect(
        File(
          '${tempDir.path}/lib/src/ui/renderers/offer_card_renderer.dart',
        ).existsSync(),
        true,
      );
      expect(
        File('${tempDir.path}/.zfa/ui/components/offer_card.json').existsSync(),
        true,
      );
    });
  });

  group('UiVocabularyExportCapability (FR-006)', () {
    test('shadcn plugin exposes the vocabulary export capability', () {
      final plugin = ShadcnPlugin(outputDir: tempDir.path);
      final capability = plugin.capabilities
          .whereType<UiVocabularyExportCapability>()
          .single;
      expect(capability.name, 'ui.schema.export');
      expect(capability.inputSchema, isA<Map<String, dynamic>>());
      expect(capability.outputSchema, isA<Map<String, dynamic>>());
    });

    test('execute returns the exported schema with schemaVersion', () async {
      final plugin = ShadcnPlugin(outputDir: tempDir.path);
      final capability = plugin.capabilities
          .whereType<UiVocabularyExportCapability>()
          .single;
      final result = await capability.execute({'projectRoot': tempDir.path});
      expect(result.success, true);
      final schema = result.data?['schema'] as Map<String, dynamic>;
      expect(schema['schemaVersion'], isA<String>());
      expect((schema['components'] as Map).keys, contains('card'));
    });
  });
}
