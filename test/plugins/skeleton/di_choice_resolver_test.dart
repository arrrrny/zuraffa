/// Tests for DiChoiceResolver (042: --di auto detection).
///
/// Behaviors traced to specs/042-bone-working-slice/tdd/test-list.md:
///   042-U34 / A7: firebase reference in pubspec.yaml → auto-detected firebase
///   042-U35: firebase reference in zfa.yaml → auto-detected firebase
///   042-U36 / A8: no config → mock with auto-fallback source
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/skeleton/generators/di_choice_resolver.dart';
import 'package:zuraffa/src/plugins/skeleton/models/bone.dart';

void main() {
  late Directory tmpDir;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('di_choice_test_');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  DiChoice resolveInTmp(String requested) => DiChoiceResolver().resolve(
    requested: requested,
    projectRoot: tmpDir.path,
  );

  group('DiChoiceResolver.resolve (042)', () {
    test(
      '042-U34/A7: firebase reference in pubspec.yaml → auto-detected firebase',
      () async {
        await File('${tmpDir.path}/pubspec.yaml').writeAsString('''
name: host_app
dependencies:
  firebase_core: ^3.0.0
''');
        final choice = resolveInTmp('auto');
        expect(choice.backend, equals(BoneBackendKind.firebase));
        expect(choice.source, equals(DiChoiceSource.autoDetected));
      },
    );

    test(
      '042-U35: firebase reference in zfa.yaml → auto-detected firebase',
      () async {
        await File('${tmpDir.path}/zfa.yaml').writeAsString('''
di:
  backend: firebase
''');
        final choice = resolveInTmp('auto');
        expect(choice.backend, equals(BoneBackendKind.firebase));
        expect(choice.source, equals(DiChoiceSource.autoDetected));
      },
    );

    test('042-U36/A8: no config anywhere → mock fallback recorded', () {
      final choice = resolveInTmp('auto');
      expect(choice.backend, equals(BoneBackendKind.mock));
      expect(choice.source, equals(DiChoiceSource.autoFallback));
    });

    test('pubspec without firebase references → mock fallback', () async {
      await File('${tmpDir.path}/pubspec.yaml').writeAsString('''
name: host_app
dependencies:
  http: ^1.0.0
''');
      final choice = resolveInTmp('auto');
      expect(choice.backend, equals(BoneBackendKind.mock));
      expect(choice.source, equals(DiChoiceSource.autoFallback));
    });

    test('explicit mock flag wins even when firebase config present', () async {
      await File(
        '${tmpDir.path}/pubspec.yaml',
      ).writeAsString('dependencies:\n  firebase_core: ^3.0.0\n');
      final choice = resolveInTmp('mock');
      expect(choice.backend, equals(BoneBackendKind.mock));
      expect(choice.source, equals(DiChoiceSource.flag));
    });
  });
}
