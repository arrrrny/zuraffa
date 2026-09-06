/// SDD-TDD suite for issue #1190 — `zfa doctor` grows a generated-imports ↔
/// pubspec check that offers `dart pub add` one-liners (and heals them under
/// `--fix`), and `zfa make` prints the same one-liner on completion.
///
/// Doctor pins follow the U1-U3 pattern of `doctor_checks_test.dart`
/// (recording process runner, hermetic sandbox).
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/commands/doctor_checks.dart';

/// Records spawned fix commands instead of running them (hermetic tests).
class _RecordingRunner {
  final List<String> invocations = [];
  _RecordingRunner();

  Future<ProcessResult> call(String executable, List<String> args) async {
    invocations.add('$executable ${args.join(' ')}');
    return ProcessResult(0, 0, '', '');
  }
}

Future<Directory> _sandbox() async {
  final dir = await Directory.systemTemp.createTemp('zfa-doctor-1190-');
  addTearDown(() async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });
  return dir;
}

const _pubspecWithZuraffa = '''
name: sandbox
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  zuraffa: ^6.0.0
''';

DoctorCheckResult _pick(List<DoctorCheckResult> results, String id) =>
    results.singleWhere((r) => r.id == id);

void main() {
  group('generated-imports check (issue #1190)', () {
    test(
      'U-1190-D1: undeclared generated imports fail with pub add fix',
      () async {
        final dir = await _sandbox();
        await File(
          '${dir.path}/pubspec.yaml',
        ).writeAsString(_pubspecWithZuraffa);
        final libFile = File('${dir.path}/lib/src/data/repositories/p.dart');
        await libFile.parent.create(recursive: true);
        await libFile.writeAsString('''
import 'package:zuraffa/zuraffa.dart';
import 'package:get_it/get_it.dart';

class P {}
''');

        final results = await DoctorChecksRunner(
          projectDir: dir.path,
        ).runAll(fix: false);

        final check = _pick(results, 'generated-imports');
        expect(check.status, DoctorCheckStatus.fail);
        expect(check.detail, contains('get_it'));
        expect(check.suggestedFix, 'dart pub add get_it');
      },
    );

    test('U-1190-D2: all imported packages declared passes', () async {
      final dir = await _sandbox();
      await File('${dir.path}/pubspec.yaml').writeAsString(_pubspecWithZuraffa);
      final libFile = File('${dir.path}/lib/src/data/repositories/p.dart');
      await libFile.parent.create(recursive: true);
      await libFile.writeAsString(
        "import 'package:zuraffa/zuraffa.dart';\nclass P {}\n",
      );

      final results = await DoctorChecksRunner(
        projectDir: dir.path,
      ).runAll(fix: false);

      expect(
        _pick(results, 'generated-imports').status,
        DoctorCheckStatus.pass,
      );
    });

    test(
      'U-1190-D3: no dart sources under lib/ or test/ passes cleanly',
      () async {
        final dir = await _sandbox();
        await File(
          '${dir.path}/pubspec.yaml',
        ).writeAsString(_pubspecWithZuraffa);

        final results = await DoctorChecksRunner(
          projectDir: dir.path,
        ).runAll(fix: false);

        // Same convention as the artifacts check ("no entities directory"
        // is a pass): nothing to diff is not a failure.
        final check = _pick(results, 'generated-imports');
        expect(check.status, DoctorCheckStatus.pass);
        expect(check.detail, contains('no package imports'));
      },
    );

    test(
      'U-1190-D4: fix runs the exact one-liner via the process runner',
      () async {
        final dir = await _sandbox();
        await File(
          '${dir.path}/pubspec.yaml',
        ).writeAsString(_pubspecWithZuraffa);
        final libFile = File('${dir.path}/lib/src/domain/entities/e.dart');
        await libFile.parent.create(recursive: true);
        await libFile.writeAsString(
          "import 'package:get_it/get_it.dart';\nclass E {}\n",
        );
        final runner = _RecordingRunner();

        final results = await DoctorChecksRunner(
          projectDir: dir.path,
          processRunner: runner.call,
        ).runAll(fix: true);

        final check = _pick(results, 'generated-imports');
        expect(check.status, DoctorCheckStatus.fixed);
        expect(runner.invocations, contains('dart pub add get_it'));
      },
    );

    test('U-1190-D5: flutter project suggests flutter pub add', () async {
      final dir = await _sandbox();
      await File('${dir.path}/pubspec.yaml').writeAsString('''
name: sandbox
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
  zuraffa: ^6.0.0
''');
      final libFile = File('${dir.path}/lib/src/presentation/v.dart');
      await libFile.parent.create(recursive: true);
      await libFile.writeAsString(
        "import 'package:get_it/get_it.dart';\nclass V {}\n",
      );

      final results = await DoctorChecksRunner(
        projectDir: dir.path,
      ).runAll(fix: false);

      final check = _pick(results, 'generated-imports');
      expect(check.status, DoctorCheckStatus.fail);
      expect(check.suggestedFix, 'flutter pub add get_it');
    });
  });
}
