// EPIC 3 / issue #1134, lane 4 — the skin builder's silent
// grid/table→list fall-through is REMOVED (the "lying generator"):
// an unknown layout (grid, table, anything not implemented) refuses
// BY NAME — not implemented, not in the ui vocabulary — and writes
// NO file. `list` and `form` keep their templates (exit criterion 3).
library;

import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/skin/builders/skin_builder.dart';

/// Captures stdout prints (the skin_command_test.dart convention).
Future<String> captureOutput(Future<void> Function() body) async {
  final output = <String>[];
  await runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        output.add(line);
      },
    ),
  );
  return output.join('\n');
}

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('skin_layout_refusal_');
    // Flutter flavor marker — the skin builder skips pure-Dart targets.
    await File('${tempDir.path}/pubspec.yaml').writeAsString('''
name: skin_layout_fixture
environment:
  sdk: ^3.11.0
dependencies:
  flutter:
    sdk: flutter
  zuraffa_flutter: ^6.1.0
''');
    outputDir = tempDir.path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  SkinBuilder buildPlugin() => SkinBuilder(
    outputDir: outputDir,
    options: const GeneratorOptions(dryRun: false, force: true),
  );

  GeneratorConfig config(String name) => GeneratorConfig(
    name: name,
    outputDir: outputDir,
  );

  test('layout grid refuses BY NAME and writes NO file (not '
      'implemented, not in the vocabulary)', () async {
    final out = await captureOutput(() async {
      final files = await buildPlugin().generate(
        config('Deal'),
        {'layout': 'grid'},
      );
      expect(files, isEmpty,
          reason: 'a refused layout generates nothing');
    });

    expect(out, contains('grid'));
    expect(out, contains('not implemented'));
    expect(out, contains('--> fix:'));
    expect(out, contains('zfa ui schema'));
    expect(
      Directory(
        '$outputDir/presentation/widgets/deal',
      ).existsSync(),
      isFalse,
      reason: 'no silent fall-through: the grid layout never renders a '
          'list template',
    );
  });

  test('layout table refuses BY NAME and writes NO file', () async {
    final files = await buildPlugin().generate(
      config('Deal'),
      {'layout': 'table'},
    );
    expect(files, isEmpty);
  });

  test('an unknown layout refuses BY NAME (never a silent list)', () async {
    final files = await buildPlugin().generate(
      config('Deal'),
      {'layout': 'kanban-board'},
    );
    expect(files, isEmpty);
  });

  test('list and form keep their templates (the implemented set)',
      () async {
    final listFiles = await buildPlugin().generate(
      config('Deal'),
      {'layout': 'list'},
    );
    expect(listFiles, isNotEmpty);
    expect(
      listFiles.first.path,
      contains('deal_list_widget.dart'),
    );

    final formFiles = await buildPlugin().generate(
      config('Profile'),
      {'layout': 'form'},
    );
    expect(formFiles, isNotEmpty);
    expect(
      formFiles.first.path,
      contains('profile_form_widget.dart'),
    );
  });
}
