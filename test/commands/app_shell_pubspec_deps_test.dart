// Issue #1265 — `zfa app shell` must declare what it emits.
//
// The shell's router builder emits `GoRouter` usage, but since issue
// #1284 the generated `app_router.dart` imports the ZURAFFA_FLUTTER
// barrel (`package:zuraffa_flutter/zuraffa_flutter.dart`, which
// re-exports go_router) instead of `package:go_router` directly. The
// #1265 contract is unchanged — the shell declares the imports it
// emits — and the scenario pinned here is a stock consumer project
// whose pubspec lacks the barrel package the shell's output needs.
//
// Contract pinned here (the make-generator #1190 machinery, unified):
//   1. non-dry-run: the shell computes the import ↔ pubspec gap over the
//      files it emits and AUTO-ADDS the hosted missing packages via one
//      `<flutter|dart> pub add …` invocation (hermetic: injectable runner).
//   2. auto-add impossible → the SAME `⚠️ pubspec.yaml doesn't declare …
//      --> fix:` diagnostic `zfa make` prints.
//   3. dry-run: no pubspec mutation, but the gap is surfaced so the author
//      sees it before generation.
library;

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/app_shell_command.dart';

/// Records spawned `pub add` commands instead of running them (hermetic).
/// [simulate] performs the effect a real `pub add` would have on the
/// sandbox (package inserted under `dependencies:`) so the end state can
/// be pinned without a network.
class _RecordingRunner {
  final List<String> invocations = [];
  final int exitCode;
  final bool simulate;
  final Directory? sandbox;

  _RecordingRunner({this.exitCode = 0, this.simulate = false, this.sandbox});

  Future<ProcessResult> call(
    String executable,
    List<String> args,
    String workingDirectory,
  ) async {
    invocations.add('$executable ${args.join(' ')}');
    if (simulate && args.length >= 3 && args[0] == 'pub' && args[1] == 'add') {
      final pubspec = File('${sandbox!.path}/pubspec.yaml');
      final content = pubspec.readAsStringSync();
      final buf = StringBuffer();
      for (final pkg in args.skip(2)) {
        buf.writeln('  $pkg: ^1.0.0');
      }
      pubspec.writeAsStringSync(
        content.replaceFirst('dependencies:\n', 'dependencies:\n$buf'),
      );
    }
    return ProcessResult(exitCode, exitCode, '', '');
  }
}

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

Future<Directory> _sandbox() async {
  final dir = await Directory.systemTemp.createTemp('zfa-1265-shell-');
  addTearDown(() async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });
  return dir;
}

/// A minimal stock consumer project: Flutter app with `zuraffa` declared
/// but NO `zuraffa_flutter` — exactly the #1265 scenario (`zfa tdd init` +
/// `zfa app shell`), where the shell's own output (app_router.dart imports
/// the zuraffa_flutter barrel for GoRouter, issue #1284) cannot compile.
Future<Directory> _consumerApp() async {
  final dir = await _sandbox();
  await File('${dir.path}/pubspec.yaml').writeAsString('''
name: sandbox_app
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
  zuraffa: ^6.0.0
''');
  final di = File('${dir.path}/lib/src/di/index.dart');
  await di.parent.create(recursive: true);
  await di.writeAsString('''
export 'registrars.dart';

void setupDependencies(GetIt getIt) {}
''');
  final routing = File('${dir.path}/lib/src/routing/index.dart');
  await routing.parent.create(recursive: true);
  await routing.writeAsString('''
export 'app_router.dart';

dynamic getAllRoutes() => [];
''');
  return dir;
}

CommandRunner<void> _runner(Directory dir, {_RecordingRunner? runner}) {
  return CommandRunner<void>('zfa', 'test')
    ..addCommand(AppShellCommand(processRunner: runner?.call));
}

void main() {
  group('app shell declares emitted imports (issue #1265)', () {
    test('auto-adds zuraffa_flutter (the emitted barrel) to the consumer '
        'pubspec via flutter pub add', () async {
      final dir = await _consumerApp();
      final runner = _RecordingRunner(simulate: true, sandbox: dir);

      final output = await captureOutput(
        () => _runner(dir, runner: runner).run(['shell', '--root', dir.path]),
      );

      expect(runner.invocations, hasLength(1));
      expect(runner.invocations.single, contains('pub add'));
      expect(
        runner.invocations.single,
        contains('zuraffa_flutter'),
        reason:
            'issue #1284: the shell emits package:zuraffa_flutter (the '
            'go_router re-export barrel) — never package:go_router '
            'directly — so the auto-added gap is zuraffa_flutter',
      );
      expect(runner.invocations.single, isNot(contains('go_router')));
      // The invoked executable must match the target flavor: the sandbox
      // pubspec declares `flutter`, so `flutter pub add` it is.
      expect(runner.invocations.single, startsWith('flutter pub add'));

      final pubspec = File('${dir.path}/pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('zuraffa_flutter:'));
      expect(output, isNot(contains('package:go_router')));
    });

    test(
      'when the add fails, the make-consistent ⚠️ diagnostic names the gap',
      () async {
        final dir = await _consumerApp();
        final runner = _RecordingRunner(exitCode: 1, sandbox: dir);

        final output = await captureOutput(
          () => _runner(dir, runner: runner).run(['shell', '--root', dir.path]),
        );

        expect(output, contains("pubspec.yaml doesn't declare 1 package(s)"));
        expect(output, contains('zuraffa_flutter'));
        expect(output, contains('--> fix: `flutter pub add zuraffa_flutter`'));
        // Nothing was declared behind the user's back.
        final pubspec = File('${dir.path}/pubspec.yaml').readAsStringSync();
        expect(pubspec, isNot(contains('zuraffa_flutter:')));
      },
    );

    test('dry-run mutates nothing but surfaces the gap', () async {
      final dir = await _consumerApp();
      final runner = _RecordingRunner(simulate: true, sandbox: dir);

      final output = await captureOutput(
        () => _runner(
          dir,
          runner: runner,
        ).run(['shell', '--dry-run', '--root', dir.path]),
      );

      expect(runner.invocations, isEmpty);
      expect(output, contains('zuraffa_flutter'));
      final pubspec = File('${dir.path}/pubspec.yaml').readAsStringSync();
      expect(pubspec, isNot(contains('zuraffa_flutter:')));
    });

    test(
      'a project that already declares zuraffa_flutter triggers no pub add',
      () async {
        final dir = await _consumerApp();
        final pubspec = File('${dir.path}/pubspec.yaml');
        await pubspec.writeAsString(
          (await pubspec.readAsString()).replaceFirst(
            '  zuraffa: ^6.0.0',
            '  zuraffa: ^6.0.0\n  zuraffa_flutter: ^6.0.0',
          ),
        );
        final runner = _RecordingRunner(simulate: true, sandbox: dir);

        await captureOutput(
          () => _runner(dir, runner: runner).run(['shell', '--root', dir.path]),
        );

        expect(runner.invocations, isEmpty);
      },
    );
  });
}
