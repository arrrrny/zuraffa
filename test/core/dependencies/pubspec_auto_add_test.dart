// Issue #1265 — `PubspecAutoAdd`: the shared auto-add engine behind every
// generator that emits third-party imports.
//
// `zfa make` (issue #1190) detected undeclared generated imports but only
// warned; `zfa app shell` did nothing at all (#1265). Both now route their
// gap through this core: ONE `<flutter|dart> pub add <pkgs>` invocation via
// the injectable process runner (the #1190 doctor `--fix` convention, so
// tests stay hermetic), falling back to the unified
// `⚠️ doesn't declare … --> fix:` diagnostic when the add is impossible.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/dependencies/pubspec_auto_add.dart';

/// Records spawned fix commands instead of running them (hermetic tests).
/// When [simulate] is true, the recording runner also performs the effect a
/// real `pub add` would have on the sandbox (dependency inserted into
/// pubspec.yaml) so callers can pin the end state without a network.
class _RecordingRunner {
  final List<String> invocations = [];
  final List<String> workingDirectories = [];
  final bool simulate;
  final int exitCode;

  _RecordingRunner({this.simulate = false, this.exitCode = 0});

  Future<ProcessResult> call(
    String executable,
    List<String> args,
    String workingDirectory,
  ) async {
    invocations.add('$executable ${args.join(' ')}');
    workingDirectories.add(workingDirectory);
    if (simulate && args.first == 'pub') {
      final packages = args.skip(2).toList(); // ['pub', 'add', ...pkgs]
      final pubspec = File('$workingDirectory/pubspec.yaml');
      var content = pubspec.readAsStringSync();
      if (!content.contains('dependencies:')) {
        content = '${content}dependencies:\n';
      }
      final buf = StringBuffer();
      for (final pkg in packages) {
        buf.writeln('  $pkg: ^1.0.0');
      }
      content = content.replaceFirst('dependencies:\n', 'dependencies:\n$buf');
      pubspec.writeAsStringSync(content);
    }
    return ProcessResult(exitCode, exitCode, '', '');
  }
}

void main() {
  group('PubspecAutoAdd.add (issue #1265)', () {
    test('runs exactly one pub add with every hosted package', () async {
      final runner = _RecordingRunner();
      final result = await PubspecAutoAdd.add(
        projectRoot: Directory.systemTemp.path,
        packages: ['go_router', 'zuraffa'],
        isFlutter: true,
        runner: runner.call,
      );

      expect(runner.invocations, hasLength(1));
      expect(runner.invocations.single, 'flutter pub add go_router zuraffa');
      expect(result.added, ['go_router', 'zuraffa']);
      expect(result.failed, isEmpty);
      expect(result.commandLine, 'flutter pub add go_router zuraffa');
    });

    test('pure-Dart targets use `dart pub add`', () async {
      final runner = _RecordingRunner();
      await PubspecAutoAdd.add(
        projectRoot: Directory.systemTemp.path,
        packages: ['get_it'],
        isFlutter: false,
        runner: runner.call,
      );

      expect(runner.invocations.single, 'dart pub add get_it');
    });

    test('no packages → no-op without spawning a process', () async {
      final runner = _RecordingRunner();
      final result = await PubspecAutoAdd.add(
        projectRoot: Directory.systemTemp.path,
        packages: const [],
        isFlutter: true,
        runner: runner.call,
      );

      expect(runner.invocations, isEmpty);
      expect(result.isNoOp, isTrue);
      expect(result.commandLine, isNull);
    });

    test('non-zero exit (offline, resolution conflict) → failed', () async {
      final runner = _RecordingRunner(exitCode: 1);
      final result = await PubspecAutoAdd.add(
        projectRoot: Directory.systemTemp.path,
        packages: ['go_router'],
        isFlutter: true,
        runner: runner.call,
      );

      expect(result.added, isEmpty);
      expect(result.failed, ['go_router']);
    });

    test(
      'missing executable (ProcessException) → failed, not a crash',
      () async {
        Future<ProcessResult> boom(
          String exe,
          List<String> args,
          String workingDirectory,
        ) async {
          throw ProcessException(exe, args, 'flutter: command not found');
        }

        final result = await PubspecAutoAdd.add(
          projectRoot: Directory.systemTemp.path,
          packages: ['go_router'],
          isFlutter: true,
          runner: boom,
        );

        expect(result.added, isEmpty);
        expect(result.failed, ['go_router']);
      },
    );

    test('the real pub add effect lands in pubspec.yaml (simulated)', () async {
      final dir = await Directory.systemTemp.createTemp('zfa-1265-core-');
      addTearDown(() async {
        try {
          await dir.delete(recursive: true);
        } catch (_) {}
      });
      await File('${dir.path}/pubspec.yaml').writeAsString('''
name: sandbox_app
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
''');
      final runner = _RecordingRunner(simulate: true);
      final result = await PubspecAutoAdd.add(
        projectRoot: dir.path,
        packages: ['go_router'],
        isFlutter: true,
        runner: runner.call,
      );

      expect(result.added, ['go_router']);
      final pubspec = File('${dir.path}/pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('go_router:'));
    });

    test('runs pub add in projectRoot, not the caller directory', () async {
      final caller = await Directory.systemTemp.createTemp('zfa-1265-caller-');
      final target = await Directory.systemTemp.createTemp('zfa-1265-target-');
      final previousDirectory = Directory.current.path;
      addTearDown(() async {
        Directory.current = previousDirectory;
        for (final directory in [caller, target]) {
          try {
            await directory.delete(recursive: true);
          } catch (_) {}
        }
      });
      const pubspec = '''
name: sandbox_app
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
''';
      final callerPubspec = File('${caller.path}/pubspec.yaml');
      final targetPubspec = File('${target.path}/pubspec.yaml');
      await callerPubspec.writeAsString(pubspec);
      await targetPubspec.writeAsString(pubspec);
      Directory.current = caller.path;
      final runner = _RecordingRunner(simulate: true);

      final result = await PubspecAutoAdd.add(
        projectRoot: target.path,
        packages: ['go_router'],
        isFlutter: false,
        runner: runner.call,
      );

      expect(result.added, ['go_router']);
      expect(runner.workingDirectories, [target.path]);
      expect(await targetPubspec.readAsString(), contains('go_router:'));
      expect(await callerPubspec.readAsString(), isNot(contains('go_router:')));
    });
  });

  group('PubspecGapReporter — the unified diagnostic (issue #1265)', () {
    test('success output carries the auto-added packages', () {
      final lines = PubspecGapReporter.successLines(
        added: ['go_router', 'zuraffa'],
        commandLine: 'flutter pub add go_router zuraffa',
      );

      final text = lines.join('\n');
      expect(text, contains('Auto-added'));
      expect(text, contains('go_router'));
      expect(text, contains('zuraffa'));
    });

    test(
      'failure output is the make-consistent ⚠️ diagnostic with the fix line',
      () {
        final lines = PubspecGapReporter.gapWarningLines(
          missing: ['go_router'],
          pubAddOneLiner: 'flutter pub add go_router',
        );

        final text = lines.join('\n');
        expect(text, contains("pubspec.yaml doesn't declare 1 package(s)"));
        expect(text, contains('go_router'));
        expect(text, contains("--> fix: `flutter pub add go_router`"));
        expect(text, contains('zfa doctor'));
      },
    );

    test('SDK-provided packages get the sdk note, never a pub add line', () {
      final lines = PubspecGapReporter.gapWarningLines(
        missing: ['flutter'],
        pubAddOneLiner: null,
        sdkMissingPackages: ['flutter'],
      );

      final text = lines.join('\n');
      expect(text, contains('sdk: flutter'));
      expect(text, isNot(contains('--> fix:')));
    });
  });
}
