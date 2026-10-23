// Issue #2008 — the Hive registrar generator emits its
// `package:zuraffa/zuraffa.dart` barrel import UNHIDDEN. An app entity
// whose name collides with a zuraffa core export (`DeviceInfo`) then makes
// the generated registrar fail `zfa build`'s analyze gate with
// `ambiguous_import` — the registrar imports the app's
// ../domain/entities/device_info/device_info.dart AND the barrel, and the
// bare `DeviceInfo` in `AdapterSpec<DeviceInfo>()` resolves to both.
//
// Every other generated file already hides the entity's own symbols from
// the barrel (the #942 `EntityUtils.barrelHideNames` mechanism); the
// registrar emission must do the same. Because the generator's output then
// legitimately carries a `hide` clause on the barrel import, the #1953
// hand-authored detector must accept exactly that line while still
// refusing every other combinator shape.
//
// In-process unit tests for `BuildCommand.refreshHiveRegistrar` and
// `BuildCommand.registrarIsHandAuthored` — no subprocess, no build_runner.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:zuraffa/src/commands/build_command.dart';

void main() {
  group('BuildCommand.refreshHiveRegistrar (#2008 barrel hide)', () {
    late Directory sandbox;
    late BuildCommand command;

    setUp(() async {
      sandbox = await Directory.systemTemp.createTemp('issue_2008_');
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

    /// A generated-shaped registrar for an entity whose name collides
    /// with a zuraffa core export (`DeviceInfo` is exported from the real
    /// barrel at `src/device/device.dart`). The sandbox carries a
    /// `pubspec.yaml` and a `.dart_tool/package_config.json` resolving
    /// `zuraffa` to a fixture barrel that exports `DeviceInfo`, so the
    /// refresh's barrel-export resolution (#2008 seeding) verifies the
    /// hide list against a real surface — exactly what a hosted zuraffa
    /// gives an app project.
    Future<void> writeDeviceInfoFixture() async {
      await write('pubspec.yaml', 'name: repro_2008\n');
      await write('.dart_tool/package_config.json', '''
{
  "configVersion": 2,
  "packages": [
    {
      "name": "zuraffa",
      "rootUri": ".fixture_zuraffa",
      "packageUri": "lib/",
      "languageVersion": "3.0"
    }
  ]
}
''');
      await write('.fixture_zuraffa/lib/zuraffa.dart', '''
// Fixture barrel standing in for the hosted zuraffa package: exports the
// core `DeviceInfo` an app entity can collide with (issue #2008). The
// resolver walks EXPORT statements only, so the class lives behind one,
// mirroring the real barrel (`export 'src/device/device.dart';`).
export 'device_info.dart';
''');
      await write('.fixture_zuraffa/lib/device_info.dart', '''
class DeviceInfo {
  String get fixtureModel => '';
}
''');
      await write('lib/src/domain/entities/device_info/device_info.dart', '''
import 'package:zorphy_annotation/zorphy_annotation.dart';
part 'device_info.zorphy.dart';

@Zorphy(generateJson: true)
abstract class \$DeviceInfo {
  String get model;
}
''');
      await write('lib/src/cache/device_info_cache.dart', '''
import 'package:zuraffa/zuraffa.dart';
import '../domain/entities/device_info/device_info.dart';

Future<void> initDeviceInfoCache() async {
  await Hive.openBox<DeviceInfo>('device_infos');
}
''');
      await write('lib/src/cache/hive_registrar.dart', '''
// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';
import '../domain/entities/device_info/device_info.dart';
part 'hive_registrar.g.dart';

@GenerateAdapters([AdapterSpec<DeviceInfo>()])
extension HiveRegistrar on HiveInterface {
  void registerAdapters() {
    registerAdapter(DeviceInfoAdapter());
  }
}
// END GENERATED
''');
    }

    test('hides the adapter entity from the zuraffa barrel import', () async {
      await writeDeviceInfoFixture();

      final refreshed = await command.refreshHiveRegistrar(
        projectRoot: sandbox.path,
      );

      expect(refreshed, isTrue);
      final content = File(registrarPath()).readAsStringSync();
      expect(
        content,
        contains("import 'package:zuraffa/zuraffa.dart' hide DeviceInfo;"),
        reason:
            'the registrar references the bare DeviceInfo name, so the '
            'barrel import must hide it or the generated tree fails the '
            'analyze gate with ambiguous_import (issue #2008)',
      );
      expect(
        content,
        contains("import '../domain/entities/device_info/device_info.dart';"),
        reason: 'the app entity import itself must stay',
      );
      // The generator's own output must not trip the #1953 hand-authored
      // detector — otherwise every second `zfa build` would refuse to
      // refresh the registrar it just wrote.
      expect(
        BuildCommand.registrarIsHandAuthored(content),
        isFalse,
        reason:
            'the generator-emitted hide clause must be accepted as '
            'generated shape (issue #2008)',
      );
    });
  });

  group('BuildCommand.registrarIsHandAuthored (#2008 generator hide)', () {
    // The generator wraps every emission in these two markers
    // (SpecLibrary.emitLibrary) — see the #1953 detector tests.
    const header = '// GENERATED - DO NOT EDIT';
    const trailer = '// END GENERATED';

    test('accepts a hide clause on the zuraffa barrel import', () {
      // Issue #2008: the registrar generator now hides the adapter
      // entities' own symbols from the barrel import it always emits —
      // a `hide` on exactly `package:zuraffa/zuraffa.dart` is generated
      // shape, not curation.
      final generated =
          '''
$header
import 'package:zuraffa/zuraffa.dart' hide DeviceInfo;
import '../domain/entities/device_info/device_info.dart';
part 'hive_registrar.g.dart';

@GenerateAdapters([AdapterSpec<DeviceInfo>()])
extension HiveRegistrar on HiveInterface {
  void registerAdapters() {
    registerAdapter(DeviceInfoAdapter());
  }
}

$trailer
''';
      expect(BuildCommand.registrarIsHandAuthored(generated), isFalse);
    });

    test('still flags combinators the generator never emits', () {
      // A hide on the FLUTTER barrel is the #1953 zik_zak curation — the
      // generator never imports zuraffa_flutter here.
      expect(
        BuildCommand.registrarIsHandAuthored(
          "import 'package:zuraffa_flutter/zuraffa_flutter.dart' hide DeviceInfo;",
        ),
        isTrue,
      );
      expect(
        BuildCommand.registrarIsHandAuthored(
          "import 'package:zuraffa/zuraffa.dart' show DeviceInfo;",
        ),
        isTrue,
      );
      expect(
        BuildCommand.registrarIsHandAuthored(
          "import 'package:zuraffa/zuraffa.dart' as z;",
        ),
        isTrue,
      );
      expect(
        BuildCommand.registrarIsHandAuthored(
          "import '../domain/entities/device_info/device_info.dart' hide DeviceInfo;",
        ),
        isTrue,
      );
    });
  });
}
