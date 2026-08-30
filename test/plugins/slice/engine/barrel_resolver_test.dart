/// Tests for BarrelResolver (U13, U14, U15, U16).
///
/// Behaviors traced to specs/043-slice-plugin/tdd/test-list.md:
///   U13: A barrel import with a `show` clause includes only the files
///        exporting the shown symbols
///   U14: A barrel import without `show` includes only the files exporting
///        types the importer actually references
///   U15: A DI barrel re-exporting 100+ registrations yields only the
///        registration files the slice's `getIt` types need
///   U16: A non-barrel file passes through unmodified
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/engine/barrel_resolver.dart';

void main() {
  late Directory tmpDir;
  late BarrelResolver resolver;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('slice_barrel_');
    resolver = BarrelResolver();
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  Future<File> writeDart(String relPath, String content) async {
    final file = File('${tmpDir.path}/$relPath');
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    return file;
  }

  group('BarrelResolver selective expansion (FR-005)', () {
    test(
      'U13: a show clause includes only the files exporting shown symbols',
      () async {
        final barrel = await writeDart('widgets/index.dart', '''
library;
export 'primary_button.dart';
export 'secondary_button.dart';
export 'app_card.dart';
''');
        await writeDart(
          'widgets/primary_button.dart',
          'class PrimaryButton {}\n',
        );
        await writeDart(
          'widgets/secondary_button.dart',
          'class SecondaryButton {}\n',
        );
        await writeDart('widgets/app_card.dart', 'class AppCard {}\n');

        final expanded = await resolver.expandImport(
          importedPath: barrel.path,
          importerSource: 'class View { Widget build() => PrimaryButton(); }',
          shownSymbols: const ['PrimaryButton'],
        );

        expect(expanded, hasLength(1));
        expect(expanded.single.targetPath, contains('primary_button.dart'));
      },
    );

    test('U14: without show, only referenced exported types come in', () async {
      final barrel = await writeDart('widgets/index.dart', '''
library;
export 'primary_button.dart';
export 'secondary_button.dart';
export 'app_card.dart';
export 'loading_indicator.dart';
''');
      await writeDart(
        'widgets/primary_button.dart',
        'class PrimaryButton {}\n',
      );
      await writeDart(
        'widgets/secondary_button.dart',
        'class SecondaryButton {}\n',
      );
      await writeDart('widgets/app_card.dart', 'class AppCard {}\n');
      await writeDart(
        'widgets/loading_indicator.dart',
        'class LoadingIndicator {}\n',
      );

      final expanded = await resolver.expandImport(
        importedPath: barrel.path,
        importerSource: '''
class ProfileView {
  Widget build() => Column(children: [
        AppCard(child: PrimaryButton(label: 'go')),
      ]);
}
''',
        shownSymbols: const [],
      );

      expect(expanded, hasLength(2));
      final names = expanded.map((e) => e.targetPath.split('/').last).toList();
      expect(names, containsAll(['primary_button.dart', 'app_card.dart']));
      expect(names, isNot(contains('secondary_button.dart')));
      expect(names, isNot(contains('loading_indicator.dart')));
    });

    test(
      'U15: a DI barrel with 100+ registrations yields only needed files',
      () async {
        final buffer = StringBuffer('library;\n');
        for (var i = 0; i < 120; i++) {
          buffer.writeln(
            "export 'usecases/use_case_$i\\_di.dart';".replaceAll('\\\\', ''),
          );
          await writeDart(
            'di/usecases/use_case_${i}_di.dart',
            'void registerUseCase$i() {}\n',
          );
        }
        // The two the slice needs, hidden in the middle of the pack.
        buffer.writeln("export 'usecases/get_product_usecase_di.dart';");
        await writeDart(
          'di/usecases/get_product_usecase_di.dart',
          'void registerGetProductUseCase() {}\n',
        );
        buffer.writeln("export 'usecases/fetch_settings_usecase_di.dart';");
        await writeDart(
          'di/usecases/fetch_settings_usecase_di.dart',
          'void registerFetchSettingsUseCase() {}\n',
        );
        final barrel = await writeDart('di/index.dart', buffer.toString());

        final expanded = await resolver.expandImport(
          importedPath: barrel.path,
          importerSource: 'void setup() {}',
          shownSymbols: const [
            'registerGetProductUseCase',
            'registerFetchSettingsUseCase',
          ],
        );

        expect(expanded, hasLength(2));
        final names = expanded.map((e) => e.targetPath.split('/').last).toSet();
        expect(
          names,
          equals({
            'get_product_usecase_di.dart',
            'fetch_settings_usecase_di.dart',
          }),
        );
      },
    );

    test('U16: a non-barrel file passes through unmodified', () async {
      final plain = await writeDart(
        'widgets/primary_button.dart',
        'class PrimaryButton {}\n',
      );

      final expanded = await resolver.expandImport(
        importedPath: plain.path,
        importerSource: 'class View {}',
        shownSymbols: const [],
      );

      expect(expanded, hasLength(1));
      expect(expanded.single.targetPath, equals(plain.path));
    });

    test(
      'U17: a barrel export show clause is preserved in the emitted directive text (A1)',
      () async {
        final barrel = await writeDart('widgets/index.dart', '''
library;
export 'primary_button.dart' show PrimaryButton;
export 'secondary_button.dart';
''');
        await writeDart(
          'widgets/primary_button.dart',
          'class PrimaryButton {}\n',
        );
        await writeDart(
          'widgets/secondary_button.dart',
          'class SecondaryButton {}\n',
        );

        final expanded = await resolver.expandImport(
          importedPath: barrel.path,
          importerSource: 'class View { Widget build() => PrimaryButton(); }',
          shownSymbols: const ['PrimaryButton'],
        );

        final primary = expanded.firstWhere(
          (e) => e.directiveText.contains('primary_button.dart'),
        );
        expect(primary.directiveText, contains('show PrimaryButton'));
        expect(primary.show, contains('PrimaryButton'));
      },
    );

    test(
      'U18: a barrel export hide clause is preserved in the emitted directive text (A2)',
      () async {
        final barrel = await writeDart('widgets/index.dart', '''
library;
export 'primary_button.dart' hide GhostButton;
''');
        await writeDart(
          'widgets/primary_button.dart',
          'class PrimaryButton {}\nclass GhostButton {}\n',
        );

        final expanded = await resolver.expandImport(
          importedPath: barrel.path,
          importerSource: 'class View { Widget build() => PrimaryButton(); }',
          shownSymbols: const [],
        );

        final primary = expanded.firstWhere(
          (e) => e.directiveText.contains('primary_button.dart'),
        );
        expect(primary.directiveText, contains('hide GhostButton'));
        expect(primary.hide, contains('GhostButton'));
      },
    );

    test(
      'U19: export-level show hides symbols that are not shown (A4)',
      () async {
        final barrel = await writeDart('widgets/index.dart', '''
library;
export 'a.dart' show Foo;
export 'b.dart' show Bar;
''');
        await writeDart('widgets/a.dart', 'class Foo {}\nclass Qux {}\n');
        await writeDart('widgets/b.dart', 'class Bar {}\nclass Qux {}\n');

        final expanded = await resolver.expandImport(
          importedPath: barrel.path,
          importerSource: 'class View { Widget build() => Qux(); }',
          shownSymbols: const [],
        );

        // Qux is hidden by both show clauses, so neither target is included.
        expect(expanded, isEmpty);
      },
    );

    test(
      'U20: colliding hidden symbols are disambiguated by show (no duplicate export) (A3)',
      () async {
        final barrel = await writeDart('widgets/index.dart', '''
library;
export 'app_card.dart' show AppCard;
export 'overlay_card.dart' show OverlayCard;
''');
        await writeDart(
          'widgets/app_card.dart',
          'class AppCard {}\nclass BaseCard {}\n',
        );
        await writeDart(
          'widgets/overlay_card.dart',
          'class OverlayCard {}\nclass BaseCard {}\n',
        );

        final expanded = await resolver.expandImport(
          importedPath: barrel.path,
          importerSource:
              'class View { Widget build() => Column(children: [AppCard(), OverlayCard()]); }',
          shownSymbols: const [],
        );

        final directives = expanded.map((e) => e.directiveText).toList();
        expect(directives, contains("export 'app_card.dart' show AppCard;"));
        expect(
          directives,
          contains("export 'overlay_card.dart' show OverlayCard;"),
        );

        final hiddenCollision = await resolver.expandImport(
          importedPath: barrel.path,
          importerSource: 'class View { Widget build() => BaseCard(); }',
          shownSymbols: const ['BaseCard'],
        );
        // BaseCard is declared in both targets but hidden by both show clauses.
        expect(hiddenCollision, isEmpty);
      },
    );
  });
}
