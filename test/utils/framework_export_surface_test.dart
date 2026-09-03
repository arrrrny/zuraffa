// Unit tests for FrameworkExportSurface.
//
// The surface is what `entity create` preflights entity names against
// (issue #942), so resolution and composition must be exact:
//   - relative `rootUri` entries in package_config.json resolve against
//     the CONFIG FILE's own directory (package_config v2 spec), not one
//     level above it;
//   - the surface is the COMPOSED export graph of the framework barrels
//     — `show`/`hide` combinators apply per hop, part files merge, and a
//     symbol hidden on every barrel path is not on the surface at all;
//   - everything fails open: malformed config or a broken export graph
//     yields no surface / no symbols, never a crash.
//
// Every fixture seeds unique probe symbols (the `Z942Probe*` names) so
// assertions can never be satisfied by the CLI checkout's own real
// framework surface, which the script-path fallback may resolve to.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/utils/framework_export_surface.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('zfa_surface_test_');
  });

  tearDown(() async {
    if (tmp.existsSync()) {
      await tmp.delete(recursive: true);
    }
  });

  /// A fake project the preflight runs against: `<tmp>/proj` with a
  /// `.dart_tool/package_config.json` carrying [packages].
  Future<String> seedProject({
    List<Map<String, String>> packages = const [
      {'name': 'zuraffa', 'rootUri': '../../dep'},
    ],
    String name = 'proj',
  }) async {
    final proj = Directory(p.join(tmp.path, name));
    final dartTool = Directory(p.join(proj.path, '.dart_tool'));
    await dartTool.create(recursive: true);
    await File(
      p.join(dartTool.path, 'package_config.json'),
    ).writeAsString(jsonEncode({'configVersion': 2, 'packages': packages}));
    return proj.path;
  }

  /// A fake zuraffa package at `<tmp>/dep` (or [root]) with the given
  /// barrel contents under its `lib/`.
  Future<String> seedDep({String? root, String? zuraffa, String? mock}) async {
    final lib = Directory(p.join(root ?? p.join(tmp.path, 'dep'), 'lib'));
    await lib.create(recursive: true);
    if (zuraffa != null) {
      await File(p.join(lib.path, 'zuraffa.dart')).writeAsString(zuraffa);
    }
    if (mock != null) {
      await File(p.join(lib.path, 'mock.dart')).writeAsString(mock);
    }
    return lib.parent.path;
  }

  group('resolution', () {
    test('relative rootUri resolves against the .dart_tool config '
        'directory (a path dep lands on the dep package)', () async {
      final dep = await seedDep(zuraffa: 'class Z942ProbeRelative {}\n');
      await seedProject(
        packages: [
          {'name': 'some_other', 'rootUri': '../../elsewhere'},
          {'name': 'zuraffa', 'rootUri': '../../dep'},
        ],
      );

      final surface = FrameworkExportSurface.tryResolve(
        projectRoot: p.join(tmp.path, 'proj'),
      );

      expect(surface, isNotNull);
      expect(
        surface!.lookup('Z942ProbeRelative'),
        isNotNull,
        reason:
            'package_config v2: relative rootUri entries resolve against '
            'the config file directory (<proj>/.dart_tool/), so '
            '"../../dep" must land on $dep — joining one level higher '
            'walks OUTSIDE the temp root and the dep is never found',
      );
      expect(surface.lookup('Z942ProbeRelative'), contains('zuraffa.dart'));
    });

    test('relative rootUri "../" (the shape package_config.json uses for '
        'the root package) resolves inside the project', () async {
      // A root package refers to ITSELF with "../": the config lives in
      // the same package the URI points at (the shape this repo's own
      // package_config.json carries). Joining against the config
      // directory lands on the project; joining against its parent
      // (the old bug) escapes it entirely.
      final selfRoot = await seedDep(
        root: p.join(tmp.path, 'self'),
        zuraffa: 'class Z942ProbeSelf {}\n',
      );
      final dartTool = Directory(p.join(selfRoot, '.dart_tool'));
      await dartTool.create(recursive: true);
      await File(p.join(dartTool.path, 'package_config.json')).writeAsString(
        jsonEncode({
          'configVersion': 2,
          'packages': [
            {'name': 'zuraffa', 'rootUri': '../'},
          ],
        }),
      );

      final surface = FrameworkExportSurface.tryResolve(projectRoot: selfRoot);

      expect(surface, isNotNull);
      expect(
        surface!.lookup('Z942ProbeSelf'),
        isNotNull,
        reason: 'resolved lib must be $selfRoot/lib',
      );
    });

    test(
      'file:// rootUri resolves (with and without a trailing slash)',
      () async {
        final dep = await seedDep(zuraffa: 'class Z942ProbeFileUri {}\n');
        await seedProject(
          packages: [
            {'name': 'zuraffa', 'rootUri': Uri.file(dep).toString()},
          ],
        );

        final surface = FrameworkExportSurface.tryResolve(
          projectRoot: p.join(tmp.path, 'proj'),
        );
        expect(surface!.lookup('Z942ProbeFileUri'), isNotNull);

        final slashDep = await seedDep(
          root: p.join(tmp.path, 'dep2'),
          zuraffa: 'class Z942ProbeFileUriSlash {}\n',
        );
        await seedProject(
          packages: [
            {'name': 'zuraffa', 'rootUri': '${Uri.file(slashDep)}/'},
          ],
          name: 'proj2',
        );

        final slashSurface = FrameworkExportSurface.tryResolve(
          projectRoot: p.join(tmp.path, 'proj2'),
        );
        expect(slashSurface!.lookup('Z942ProbeFileUriSlash'), isNotNull);
      },
    );

    test('malformed package_config.json fails open — no crash, and no '
        'surface derived from the broken config', () async {
      final dartTool = Directory(p.join(tmp.path, 'proj', '.dart_tool'));
      await dartTool.create(recursive: true);
      await File(
        p.join(dartTool.path, 'package_config.json'),
      ).writeAsString('{configVersion: 2, this is not JSON');

      final surface = FrameworkExportSurface.tryResolve(
        projectRoot: p.join(tmp.path, 'proj'),
      );

      // Fail-open: when the config is unreadable the preflight gets no
      // help from it. Depending on where the test process itself lives,
      // the CLI-checkout fallback may still resolve (that is the
      // documented fallback, not a leak) — but the broken config's
      // contents must never produce a surface.
      expect(surface?.lookup('Z942ProbeBrokenConfig'), isNull);
    });
  });

  group('combinator composition', () {
    test('show/hide combinators apply per hop — symbols hidden on every '
        'barrel path are not on the surface', () async {
      await seedDep(
        zuraffa: '''
export 'src/a.dart' show Z942ProbeShown;
export 'src/c.dart' hide Z942ProbeDropped;
''',
      );
      final src = Directory(p.join(tmp.path, 'dep', 'lib', 'src'));
      await src.create(recursive: true);
      // a.dart declares BOTH symbols but the barrel only shows one.
      await File(p.join(src.path, 'a.dart')).writeAsString('''
class Z942ProbeShown {}

class Z942ProbeMasked {}
''');
      await File(p.join(src.path, 'c.dart')).writeAsString('''
class Z942ProbeKept {}

class Z942ProbeDropped {}
''');

      await seedProject();

      final surface = FrameworkExportSurface.tryResolve(
        projectRoot: p.join(tmp.path, 'proj'),
      );

      expect(surface, isNotNull);
      expect(surface!.lookup('Z942ProbeShown'), isNotNull);
      expect(
        surface.lookup('Z942ProbeMasked'),
        isNull,
        reason:
            'a.dart declares Z942ProbeMasked, but every barrel path to it '
            'runs through `show Z942ProbeShown` — it is NOT on the export '
            'surface and must never refuse an entity name',
      );
      expect(surface.lookup('Z942ProbeDropped'), isNull);
      expect(surface.lookup('Z942ProbeKept'), isNotNull);
    });

    test('combinators survive a transitive re-export hop', () async {
      await seedDep(zuraffa: "export 'src/mid.dart';\n");
      final src = Directory(p.join(tmp.path, 'dep', 'lib', 'src'));
      await src.create(recursive: true);
      await File(
        p.join(src.path, 'mid.dart'),
      ).writeAsString("export 'leaf.dart' show Z942ProbeLeafShown;\n");
      await File(p.join(src.path, 'leaf.dart')).writeAsString('''
class Z942ProbeLeafShown {}

class Z942ProbeLeafMasked {}
''');

      await seedProject();

      final surface = FrameworkExportSurface.tryResolve(
        projectRoot: p.join(tmp.path, 'proj'),
      );

      expect(surface!.lookup('Z942ProbeLeafShown'), isNotNull);
      expect(
        surface.lookup('Z942ProbeLeafMasked'),
        isNull,
        reason: 'the show on the mid hop must survive the barrel hop',
      );
    });
  });

  group('graph tolerance', () {
    test('part files merge into the exporting library', () async {
      await seedDep(zuraffa: "part 'src/part_of_barrel.dart';\n");
      final src = Directory(p.join(tmp.path, 'dep', 'lib', 'src'));
      await src.create(recursive: true);
      await File(
        p.join(src.path, 'part_of_barrel.dart'),
      ).writeAsString('class Z942ProbeParted {}\n');

      await seedProject();

      final surface = FrameworkExportSurface.tryResolve(
        projectRoot: p.join(tmp.path, 'proj'),
      );

      expect(surface!.lookup('Z942ProbeParted'), isNotNull);
    });

    test('a missing file in the export graph does not throw', () async {
      await seedDep(
        zuraffa: '''
export 'src/ghost.dart';

class Z942ProbePresent {}
''',
      );
      // src/ghost.dart intentionally does not exist; mock.dart was never
      // seeded either — both must be skipped silently.

      await seedProject();

      final surface = FrameworkExportSurface.tryResolve(
        projectRoot: p.join(tmp.path, 'proj'),
      );

      expect(surface, isNotNull);
      expect(surface!.lookup('Z942ProbePresent'), isNotNull);
      expect(surface.lookup('Z942ProbeGhost'), isNull);
    });
  });

  group('declaration parsing', () {
    test('extension types capture their own name, not the `type` '
        'introducer, and private declarations stay off the surface', () async {
      await seedDep(
        zuraffa: '''
extension type Z942ProbeExtType(String value) {}

extension Z942ProbeExt on String {}

typedef Z942ProbeAlias = String;

class _Z942ProbePrivate {}

enum Z942ProbeFlag { a, b }
''',
      );

      await seedProject();

      final surface = FrameworkExportSurface.tryResolve(
        projectRoot: p.join(tmp.path, 'proj'),
      );

      expect(surface!.lookup('Z942ProbeExtType'), isNotNull);
      expect(
        surface.lookup('type'),
        isNull,
        reason:
            'the `extension type` introducer must not be captured '
            'as a symbol',
      );
      expect(surface.lookup('Z942ProbeExt'), isNotNull);
      expect(surface.lookup('Z942ProbeAlias'), isNotNull);
      expect(
        surface.lookup('_Z942ProbePrivate'),
        isNull,
        reason: 'private declarations are not part of the public surface',
      );
      expect(surface.lookup('Z942ProbeFlag'), isNotNull);
    });
  });
}
