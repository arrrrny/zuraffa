@Tags(['e2e'])
// Issue #1953 — `zfa build` must not clobber a hand-authored Hive registrar.
//
// The #1732 refresh regenerates `lib/src/cache/hive_registrar.dart` with
// `force: true` on every build. A project that hand-authors that file (the
// docs/hand-authored-g-dart-placeholders.md pattern — e.g. zik_zak pins
// `import 'package:zuraffa_flutter/zuraffa_flutter.dart' hide DeviceInfo;`)
// gets the curation wholesale-replaced, the rewritten host re-imports
// `package:zuraffa/zuraffa.dart` un-hided, and the build dies at
// `source_gen:combining_builder` with a broken tree. The refresh must detect
// the hand-authored bytes and refuse (a loud no-op naming the documented
// build.yaml exclude remedy) instead of rewriting.
//
// In-process unit tests for `BuildCommand.refreshHiveRegistrar` and the two
// new classifiers — no subprocess, no build_runner.
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:zuraffa/src/commands/build_command.dart';

void main() {
  group('BuildCommand.refreshHiveRegistrar (#1953 hand-authored refusal)', () {
    late Directory sandbox;
    late BuildCommand command;

    setUp(() async {
      sandbox = await Directory.systemTemp.createTemp('issue_1953_');
      command = BuildCommand();
    });

    tearDown(() async {
      if (sandbox.existsSync()) {
        await sandbox.delete(recursive: true);
      }
    });

    Future<void> write(String rel, String content) async {
      final file = File(p.join(sandbox.path, rel));
      await file.create(recursive: true);
      await file.writeAsString(content);
    }

    String registrarPath() =>
        p.join(sandbox.path, 'lib', 'src', 'cache', 'hive_registrar.dart');

    /// The zik_zak shape: a generated-shaped registrar whose import block is
    /// hand-curated (a `hide` combinator + explanatory comments) because
    /// `package:zuraffa_flutter/zuraffa_flutter.dart` must be imported with
    /// `hide DeviceInfo` to avoid the known ambiguous-import collision.
    Future<void> writeCuratedRegistrarFixture() async {
      await write(
        'lib/src/domain/entities/app_notification/app_notification.dart',
        '''
import 'package:zorphy_annotation/zorphy_annotation.dart';
part 'app_notification.zorphy.dart';

@Zorphy(generateJson: true)
abstract class \$AppNotification {
  String get title;
}
''',
      );
      await write('lib/src/cache/app_notification_cache.dart', '''
import 'package:zuraffa/zuraffa.dart';
import '../domain/entities/app_notification/app_notification.dart';

Future<void> initAppNotificationCache() async {
  await Hive.openBox<AppNotification>('app_notifications');
}
''');
      await write('lib/src/cache/hive_registrar.dart', '''
// Auto-generated Hive registrar
import 'package:zuraffa_flutter/zuraffa_flutter.dart' hide DeviceInfo;
import '../domain/entities/app_notification/app_notification.dart';
part 'hive_registrar.g.dart';

@GenerateAdapters([AdapterSpec<AppNotification>()])
extension HiveRegistrar on HiveInterface {
  void registerAdapters() {
    registerAdapter(AppNotificationAdapter());
  }
}
''');
    }

    Future<List<String>> runRefresh() async {
      final messages = <String>[];
      await runZoned(
        () => command.refreshHiveRegistrar(projectRoot: sandbox.path),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => messages.add(line),
        ),
      );
      return messages;
    }

    test(
      'refuses to rewrite a curated registrar (hide combinator + comments)',
      () async {
        await writeCuratedRegistrarFixture();
        final before = File(registrarPath()).readAsStringSync();

        final messages = await runRefresh();

        expect(
          File(registrarPath()).readAsStringSync(),
          before,
          reason:
              'a hand-authored registrar must survive `zfa build` untouched '
              '(issue #1953)',
        );
        expect(
          messages.join('\n'),
          contains('hive_registrar.dart'),
          reason: 'the refusal must name the file it refused to touch',
        );
        expect(
          messages.join('\n'),
          contains('generate_for'),
          reason:
              'the refusal must point at the documented build.yaml '
              'generate_for.exclude fix (issue #1953 ask 1)',
        );
        expect(
          messages.join('\n'),
          contains('docs/hand-authored-g-dart-placeholders.md'),
        );
      },
    );

    test(
      'refuses when the registrar declares no hive_registrar.g.dart part',
      () async {
        await writeCuratedRegistrarFixture();
        // A literal placeholder: hand-written, no part directive — the
        // docs pattern's "no generator owns that output" case.
        await write('lib/src/cache/hive_registrar.dart', '''
// Hand-authored registrar placeholder.
// Registers adapters through the flutter barrel; no builder owns this file.
import 'package:zuraffa_flutter/zuraffa_flutter.dart' hide DeviceInfo;

extension HiveRegistrar on HiveInterface {
  void registerAdapters() {}
}
''');
        final before = File(registrarPath()).readAsStringSync();

        await runRefresh();

        expect(File(registrarPath()).readAsStringSync(), before);
      },
    );

    test(
      'still refreshes a genuinely generated registrar (#1732 intact)',
      () async {
        await writeCuratedRegistrarFixture();
        // Replace the curated file with the exact bytes the generator emits
        // (the GENERATED marker wrap, no combinators, the part directive),
        // then prove the #1732 refresh still runs.
        await write('lib/src/cache/hive_registrar.dart', '''
// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';
import '../domain/entities/app_notification/app_notification.dart';
part 'hive_registrar.g.dart';

@GenerateAdapters([AdapterSpec<AppNotification>()])
extension HiveRegistrar on HiveInterface {
  void registerAdapters() {
    registerAdapter(AppNotificationAdapter());
  }
}

// END GENERATED
''');

        final refreshed = await command.refreshHiveRegistrar(
          projectRoot: sandbox.path,
        );

        expect(refreshed, isTrue);
        final content = File(registrarPath()).readAsStringSync();
        expect(content, contains("part 'hive_registrar.g.dart';"));
      },
    );
  });

  group('BuildCommand.registrarIsHandAuthored (#1953 detector)', () {
    // The generator wraps every emission in these two markers
    // (SpecLibrary.emitLibrary, wrapWithGeneratedMarkers) and never emits
    // any other comment.
    const header = '// GENERATED - DO NOT EDIT';
    const trailer = '// END GENERATED';

    test('flags comment lines beyond the GENERATED markers', () {
      expect(
        BuildCommand.registrarIsHandAuthored(
          "// curated note\nimport 'a.dart';\npart 'hive_registrar.g.dart';",
        ),
        isTrue,
      );
      // A half-wrapped file (header without the trailer) is a hand edit too.
      expect(
        BuildCommand.registrarIsHandAuthored(
          "$header\nimport 'a.dart';\npart 'hive_registrar.g.dart';",
        ),
        isTrue,
        reason: 'emissions always carry BOTH GENERATED markers',
      );
    });

    test('flags import combinators (hide/show/as)', () {
      expect(
        BuildCommand.registrarIsHandAuthored(
          "import 'package:zuraffa_flutter/zuraffa_flutter.dart' hide DeviceInfo;",
        ),
        isTrue,
      );
      expect(
        BuildCommand.registrarIsHandAuthored("import 'a.dart' show Foo;"),
        isTrue,
      );
      expect(
        BuildCommand.registrarIsHandAuthored("import 'a.dart' as foo;"),
        isTrue,
      );
    });

    test('flags a missing hive_registrar.g.dart part directive', () {
      expect(
        BuildCommand.registrarIsHandAuthored("$header\nimport 'a.dart';"),
        isTrue,
      );
    });

    test('flags export combinators inside an otherwise generated shape', () {
      // An `export … show/hide` combinator is content the generator never
      // emits, so the combinator scan must match `export` too — a curated
      // re-export inside the marker wrap previously fell through as
      // "generated" and the #1732 refresh clobbered it (review fix on
      // PR #1963).
      final withExportShow =
          '''
$header
import 'package:zuraffa/zuraffa.dart';
export 'src/domain/entities/product/product.dart' show Product;
part 'hive_registrar.g.dart';
$trailer
''';
      expect(
        BuildCommand.registrarIsHandAuthored(withExportShow),
        isTrue,
        reason: 'export … show is hand curation the generator never emits',
      );
      expect(
        BuildCommand.registrarIsHandAuthored(
          "$header\nexport 'a.dart' hide Product;\n"
          "part 'hive_registrar.g.dart';\n$trailer",
        ),
        isTrue,
      );
    });

    test('accepts the exact generator emission shape', () {
      final generated =
          '''
$header
import 'package:zuraffa/zuraffa.dart';
import '../domain/entities/product/product.dart';
part 'hive_registrar.g.dart';

@GenerateAdapters([AdapterSpec<Product>()])
extension HiveRegistrar on HiveInterface {
  void registerAdapters() {
    registerAdapter(ProductAdapter());
  }
}

$trailer
''';
      expect(BuildCommand.registrarIsHandAuthored(generated), isFalse);
    });

    test('accepts generator shape plus manual-addition package imports', () {
      // hive_manual_additions.txt entries legitimately land as package:
      // imports (issue #1734) — still no combinators, no extra comments.
      final withManual =
          '''
$header
import 'package:zuraffa/zuraffa.dart';
import 'package:app/models/external.dart';
import '../domain/entities/product/product.dart';
part 'hive_registrar.g.dart';

@GenerateAdapters([AdapterSpec<Product>(), AdapterSpec<External>()])
extension HiveRegistrar on HiveInterface {
  void registerAdapters() {
    registerAdapter(ProductAdapter());
    registerAdapter(ExternalAdapter());
  }
}

$trailer
''';
      expect(BuildCommand.registrarIsHandAuthored(withManual), isFalse);
    });
  });
}
