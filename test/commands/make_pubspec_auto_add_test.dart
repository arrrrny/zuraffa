// Issue #1265 — `zfa make` must auto-add the packages its generated code
// imports, not just warn.
//
// Before the fix, the #1190 completion post-pass detected the gap
// (`⚠️ pubspec.yaml doesn't declare N package(s) …`) but still left the tree
// in a state that only compiles via a transitive dependency. The assessment
// prescribes: auto-add via the same mechanical `pub add` the doctor `--fix`
// path uses, and keep the ⚠️ + `--> fix:` diagnostic ONLY when the add is
// impossible (offline, resolution conflict, SDK-only gap).
//
// Issue #1530 re-scoped the CORE package: `zuraffa` is ENSURED textually
// (offline-safe, the `zfa tdd init --skin` patcher discipline) BEFORE the
// auto-add runs, so a failed/offline `pub add` can no longer leave the
// generated `package:zuraffa/...` imports undeclared. The #1265 auto-add
// and the ⚠️ diagnostic remain for every OTHER hosted gap package.
//
// Hermetic: the `pub add` process is intercepted by an injectable runner
// (the doctor_checks.dart `ZfaProcessRunner` convention); the fake simulates
// the real pub add effect on the sandbox pubspec so the end state is pinned
// without a network.
library;

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/plugin_loader.dart';
import 'package:zuraffa/src/commands/entity_command.dart';
import 'package:zuraffa/src/commands/make_command.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_registry.dart';

/// Records spawned `pub add` commands; [simulate] applies the effect a real
/// `pub add` would have on the sandbox pubspec.
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
    if (simulate &&
        exitCode == 0 &&
        args.length >= 3 &&
        args[0] == 'pub' &&
        args[1] == 'add') {
      final pubspec = File('${sandbox!.path}/pubspec.yaml');
      final content = pubspec.readAsStringSync();
      final buf = StringBuffer();
      for (final pkg in args.skip(2)) {
        buf.writeln('  $pkg: ^1.0.0');
      }
      pubspec.writeAsStringSync(
        content.contains('dependencies:\n')
            ? content.replaceFirst('dependencies:\n', 'dependencies:\n$buf')
            : '${content}dependencies:\n$buf',
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

void main() {
  late Directory dir;
  late _RecordingRunner runner;
  var prevCwd = Directory.current.path;

  setUpAll(() {
    // The process-global plugin registry is empty outside the real CLI;
    // mirror cli_runner._loadAndRegisterPlugins() once for this isolate.
    final loader = PluginLoader(
      outputDir: 'lib/src',
      dryRun: false,
      force: false,
      verbose: false,
      config: PluginConfig(),
    );
    for (final plugin in loader.buildRegistry().plugins) {
      if (!PluginRegistry.instance.plugins.any((p) => p.id == plugin.id)) {
        PluginRegistry.instance.register(plugin);
      }
    }
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zfa-1265-make-');
    prevCwd = Directory.current.path;
    Directory.current = dir.path;
    await File('${dir.path}/pubspec.yaml').writeAsString('''
name: sandbox_app
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
  zorphy_annotation: ^2.3.0
dev_dependencies:
  build_runner: ^2.4.0
''');
    runner = _RecordingRunner(simulate: true, sandbox: dir);
  });

  tearDown(() async {
    Directory.current = prevCwd;
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  CommandRunner<void> commandRunner() {
    return CommandRunner<void>('zfa', 'test')..addCommand(
      MakeCommand(
        PluginRegistry.instance,
        projectRoot: dir.path,
        processRunner: runner.call,
      ),
    );
  }

  Future<void> seedEntity() async {
    try {
      await EntityCommand().execute([
        'create',
        '-n',
        'car',
      ], exitOnCompletion: false);
    } catch (_) {}
  }

  group('zfa make auto-adds emitted imports (issue #1265)', () {
    test('crud run auto-adds the hosted gap via pub add; zuraffa is ENSURED '
        'textually (#1530)', () async {
      await seedEntity();

      final output = await captureOutput(
        () => commandRunner().run([
          'make',
          'car',
          '--preset=crud',
          '--state',
          '--test',
        ]),
      );

      // One mechanical auto-add covering every OTHER hosted gap package
      // — `zuraffa` is excluded (the #1530 ensure declared it).
      expect(runner.invocations, hasLength(1));
      expect(runner.invocations.single, startsWith('flutter pub add '));
      expect(
        runner.invocations.single.split(' '),
        isNot(contains('zuraffa')),
        reason:
            '#1530: the ensured core package must not be re-`pub add`ed '
            '(a zuraffa_flutter add is fine — it is a different package)',
      );

      // The pubspec declares the core package — via the textual ensure.
      final pubspec = File('${dir.path}/pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('zuraffa: ^6.0.0'));

      // The ensure success surfaces in the completion output…
      expect(output, contains('Ensured zuraffa'));
      // …and the auto-add success for the remaining packages.
      expect(output, contains('Auto-added'));
      // …and the warn-only gap diagnostic is gone (nothing remains).
      expect(output, isNot(contains("pubspec.yaml doesn't declare")));
    }, timeout: const Timeout(Duration(minutes: 3)));

    test(
      'when the add fails, the ⚠️ + fix diagnostic remains for the other '
      'packages — the core zuraffa declaration is STILL ensured (#1530)',
      () async {
        await seedEntity();
        final failing = _RecordingRunner(exitCode: 1, sandbox: dir);

        final output = await captureOutput(() async {
          // Rebind the runner for this run.
          runner = failing;
          final failingRunner = CommandRunner<void>('zfa', 'test')
            ..addCommand(
              MakeCommand(
                PluginRegistry.instance,
                projectRoot: dir.path,
                processRunner: failing.call,
              ),
            );
          await failingRunner.run([
            'make',
            'car',
            '--preset=crud',
            '--state',
            '--test',
          ]);
        });

        expect(runner.invocations, hasLength(1));
        // The failed `pub add` packages keep the consistent diagnostic.
        expect(output, contains("pubspec.yaml doesn't declare"));
        expect(output, contains('--> fix: `flutter pub add'));
        // The CORE package is declared EVEN OFFLINE — the #1530 ensure is
        // a textual patch, not a pub add, and its receipt line names it
        // (not behind the user's back).
        expect(output, contains('Ensured zuraffa'));
        final pubspec = File('${dir.path}/pubspec.yaml').readAsStringSync();
        expect(pubspec, contains('zuraffa: ^6.0.0'));
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'dry-run never spawns pub add and never mutates the pubspec',
      () async {
        await seedEntity();

        await captureOutput(
          () => commandRunner().run([
            'make',
            'car',
            '--preset=crud',
            '--state',
            '--test',
            '--dry-run',
          ]),
        );

        expect(runner.invocations, isEmpty);
        final pubspec = File('${dir.path}/pubspec.yaml').readAsStringSync();
        expect(pubspec, isNot(contains('zuraffa:')));
      },
    );
  });
}
