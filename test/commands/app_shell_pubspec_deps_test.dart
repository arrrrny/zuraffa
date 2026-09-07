// Issue #1265 — `zfa app shell` must declare what it emits.
//
// The shell's router builder hard-requires `go_router`
// (`lib/src/routing/app_router.dart` imports package:go_router) but the
// command never looked at the target's pubspec: a stock consumer project
// (fresh `zfa tdd init` + `zfa app shell`) produced a shell that does not
// compile unless the author happened to add go_router.
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

/// A minimal stock consumer project: Flutter app with zuraffa declared but
/// NO go_router — exactly the #1265 scenario (`zfa tdd init` + `zfa app
/// shell`), where the shell's own output cannot compile.
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
    test(
      'auto-adds go_router to the consumer pubspec via flutter pub add',
      () async {
        final dir = await _consumerApp();
        final runner = _RecordingRunner(simulate: true, sandbox: dir);

        await captureOutput(
          () => _runner(dir, runner: runner).run(['shell', '--root', dir.path]),
        );

        expect(runner.invocations, hasLength(1));
        expect(runner.invocations.single, contains('pub add'));
        expect(runner.invocations.single, contains('go_router'));
        // The invoked executable must match the target flavor: the sandbox
        // pubspec declares `flutter`, so `flutter pub add` it is.
        expect(runner.invocations.single, startsWith('flutter pub add'));

        final pubspec = File('${dir.path}/pubspec.yaml').readAsStringSync();
        expect(pubspec, contains('go_router:'));
      },
    );

    test(
      'when the add fails, the make-consistent ⚠️ diagnostic names the gap',
      () async {
        final dir = await _consumerApp();
        final runner = _RecordingRunner(exitCode: 1, sandbox: dir);

        final output = await captureOutput(
          () => _runner(dir, runner: runner).run(['shell', '--root', dir.path]),
        );

        expect(output, contains("pubspec.yaml doesn't declare 1 package(s)"));
        expect(output, contains('go_router'));
        expect(output, contains('--> fix: `flutter pub add go_router`'));
        // Nothing was declared behind the user's back.
        final pubspec = File('${dir.path}/pubspec.yaml').readAsStringSync();
        expect(pubspec, isNot(contains('go_router:')));
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
      expect(output, contains('go_router'));
      final pubspec = File('${dir.path}/pubspec.yaml').readAsStringSync();
      expect(pubspec, isNot(contains('go_router:')));
    });

    test(
      'a project that already declares go_router triggers no pub add',
      () async {
        final dir = await _consumerApp();
        final pubspec = File('${dir.path}/pubspec.yaml');
        await pubspec.writeAsString(
          (await pubspec.readAsString()).replaceFirst(
            '  zuraffa: ^6.0.0',
            '  zuraffa: ^6.0.0\n  go_router: ^14.0.0',
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
