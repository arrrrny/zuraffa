import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:args/command_runner.dart';
import 'package:zuraffa/src/commands/initialize_command.dart';
import 'package:zuraffa/src/commands/setup_command.dart';
import 'package:zuraffa/src/core/dependencies/dependency_wirer.dart';

void main() {
  group('SetupCommand', () {
    test('has correct name', () {
      final cmd = SetupCommand();
      expect(cmd.name, 'setup');
    });

    test('has correct description', () {
      final cmd = SetupCommand();
      expect(cmd.description, contains('Bootstrap'));
      expect(cmd.description, contains('Flutter'));
      expect(cmd.description, contains('Dart'));
    });

    test('exposes --flutter flag', () {
      final cmd = SetupCommand();
      expect(cmd.argParser.options, contains('flutter'));
    });

    test('exposes --dart flag', () {
      final cmd = SetupCommand();
      expect(cmd.argParser.options, contains('dart'));
    });

    test('exposes --platforms option', () {
      final cmd = SetupCommand();
      expect(cmd.argParser.options, contains('platforms'));
    });

    test('exposes --dry-run flag', () {
      final cmd = SetupCommand();
      expect(cmd.argParser.options, contains('dry-run'));
    });

    test('exposes --force flag', () {
      final cmd = SetupCommand();
      expect(cmd.argParser.options, contains('force'));
    });

    test('exposes --org option', () {
      final cmd = SetupCommand();
      expect(cmd.argParser.options, contains('org'));
    });

    test('takes a positional name argument', () {
      final cmd = SetupCommand();
      // CommandRunner passes positional args via argResults.rest.
      // Verify the command doesn't declare the name as an option (it's positional).
      expect(cmd.argParser.options, isNot(contains('name')));
    });
  });

  group('InitializeCommand flags', () {
    test('accepts --deps-only flag', () {
      final parser = InitializeCommand.buildParser();
      final result = parser.parse(['--deps-only']);
      expect(result['deps-only'], isTrue);
    });

    test('accepts --no-deps flag', () {
      final parser = InitializeCommand.buildParser();
      final result = parser.parse(['--no-deps']);
      expect(result['no-deps'], isTrue);
    });

    test('--deps-only defaults to false', () {
      final parser = InitializeCommand.buildParser();
      final result = parser.parse([]);
      expect(result['deps-only'], isFalse);
    });

    test('--no-deps defaults to false', () {
      final parser = InitializeCommand.buildParser();
      final result = parser.parse([]);
      expect(result['no-deps'], isFalse);
    });

    test('still accepts legacy --entity option', () {
      final parser = InitializeCommand.buildParser();
      final result = parser.parse(['--entity=User']);
      expect(result['entity'], 'User');
    });

    test('still accepts --force flag', () {
      final parser = InitializeCommand.buildParser();
      final result = parser.parse(['--force']);
      expect(result['force'], isTrue);
    });
  });

  group('CLI registration', () {
    test('SetupCommand can be added to a CommandRunner', () {
      final runner = CommandRunner<void>('zfa', 'test')
        ..addCommand(SetupCommand());
      final setupCmd = runner.commands['setup'];
      expect(setupCmd, isNotNull);
      expect(setupCmd!.name, 'setup');
    });

    test('SetupCommand accepts both --flutter and --dart in parser', () {
      final cmd = SetupCommand();
      // Both flags can be parsed independently (the mutual-exclusion check
      // is in run(), not in the parser). Verify both are recognized.
      final result = cmd.argParser.parse(['--flutter', '--dart']);
      expect(result['flutter'], isTrue);
      expect(result['dart'], isTrue);
    });

    test(
      'run() rejects both --flutter and --dart with UsageException',
      () async {
        final runner = CommandRunner<void>('zfa', 'test')
          ..addCommand(SetupCommand());
        await expectLater(
          runner.run(['setup', 'myapp', '--flutter', '--dart']),
          throwsA(isA<UsageException>()),
        );
      },
    );

    // #364: a malformed deep-link scheme must be rejected BEFORE any
    // file is created — writing it raw into AndroidManifest.xml /
    // Info.plist would corrupt the platform build.
    test('run() rejects a malformed --deep-link-scheme with '
        'UsageException before creating anything', () async {
      final runner = CommandRunner<void>('zfa', 'test')
        ..addCommand(SetupCommand());
      await expectLater(
        runner.run(['setup', 'myapp', '--deep-link-scheme', 'go zuzu']),
        throwsA(isA<UsageException>()),
      );
    });

    test(
      'run() rejects a malformed --deep-link-host with UsageException',
      () async {
        final runner = CommandRunner<void>('zfa', 'test')
          ..addCommand(SetupCommand());
        await expectLater(
          runner.run([
            'setup',
            'myapp',
            '--deep-link-scheme',
            'gozuzu',
            '--deep-link-host',
            'go"zuzu.dev',
          ]),
          throwsA(isA<UsageException>()),
        );
      },
    );

    test('run() warns when --deep-link-host is passed without '
        '--deep-link-scheme', () async {
      final runner = CommandRunner<void>('zfa', 'test')
        ..addCommand(SetupCommand());
      final printed = <String>[];
      await runZoned(
        () => runner.run([
          'setup',
          'myapp',
          '--deep-link-host',
          'go.zuzu.dev',
          '--dry-run',
        ]),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => printed.add(line),
        ),
      );
      expect(
        printed.any((l) => l.contains('ignored without --deep-link-scheme')),
        isTrue,
        reason: 'host is silently dropped without a scheme — warn the user',
      );
    });
  });

  group('DependencyWirer', () {
    test('findMissing detects all missing deps in empty pubspec', () {
      const emptyPubspec = 'name: test\nenvironment:\n  sdk: ^3.11.0\n';
      final missing = DependencyWirer.findMissing(
        emptyPubspec,
        isFlutter: true,
      );
      final names = missing.map((s) => s.name).toList();
      expect(names, contains('zuraffa_flutter'));
      expect(names, contains('zorphy_annotation'));
      expect(names, contains('build_runner'));
      expect(names, contains('json_annotation'));
      expect(names, contains('json_serializable'));
      expect(names, contains('flutter_lints'));
      expect(names, contains('analyzer'));
    });

    test('findMissing detects missing deps for dart project', () {
      const emptyPubspec = 'name: test\nenvironment:\n  sdk: ^3.11.0\n';
      final missing = DependencyWirer.findMissing(
        emptyPubspec,
        isFlutter: false,
      );
      final names = missing.map((s) => s.name).toList();
      expect(names, contains('zuraffa'));
      expect(names, isNot(contains('zuraffa_flutter')));
      expect(names, isNot(contains('flutter_lints')));
    });

    test('findMissing returns empty when all deps present', () {
      const fullPubspec = '''
name: test
environment:
  sdk: ^3.11.0
dependencies:
  zuraffa_flutter: any
  zorphy_annotation: any
  json_annotation: ^4.12.0
dev_dependencies:
  build_runner: ^2.15.2
  json_serializable: ^6.13.2
  flutter_lints: ^6.0.0
dependency_overrides:
  analyzer: ^13.1.0
  meta: ^1.19.0
''';
      final missing = DependencyWirer.findMissing(fullPubspec, isFlutter: true);
      expect(missing, isEmpty);
    });

    test('isFlutterProject detects flutter sdk dependency', () {
      const flutterPubspec = '''
name: test
environment:
  sdk: ^3.11.0
dependencies:
  flutter:
    sdk: flutter
''';
      expect(DependencyWirer.isFlutterProject(flutterPubspec), isTrue);
    });

    test('isFlutterProject returns false for pure dart', () {
      const dartPubspec = 'name: test\nenvironment:\n  sdk: ^3.11.0\n';
      expect(DependencyWirer.isFlutterProject(dartPubspec), isFalse);
    });

    test('addOverrideToPubspec adds new section when missing', () {
      const pubspec = 'name: test\nenvironment:\n  sdk: ^3.11.0\n';
      final result = DependencyWirer.addOverrideToPubspec(
        pubspec,
        'analyzer',
        '14.1.0',
      );
      expect(result, contains('dependency_overrides:'));
      expect(result, contains('analyzer: 14.1.0'));
    });

    test('addOverrideToPubspec is idempotent', () {
      const pubspec = '''
name: test
dependency_overrides:
  analyzer: 14.1.0
''';
      final result = DependencyWirer.addOverrideToPubspec(
        pubspec,
        'analyzer',
        '14.1.0',
      );
      expect(result, equals(pubspec));
    });

    test('addOverrideToPubspec appends to existing section', () {
      const pubspec = '''
name: test
dependency_overrides:
  meta: ^1.19.0
''';
      final result = DependencyWirer.addOverrideToPubspec(
        pubspec,
        'analyzer',
        '14.1.0',
      );
      expect(result, contains('analyzer: 14.1.0'));
      expect(result, contains('meta: ^1.19.0'));
    });

    test('standardSet returns different deps for flutter vs dart', () {
      final flutterSpecs = DependencyWirer.standardSet(isFlutter: true);
      final dartSpecs = DependencyWirer.standardSet(isFlutter: false);

      final flutterNames = flutterSpecs.map((s) => s.name).toSet();
      final dartNames = dartSpecs.map((s) => s.name).toSet();

      expect(flutterNames, contains('zuraffa_flutter'));
      expect(flutterNames, isNot(contains('zuraffa')));
      expect(flutterNames, contains('flutter_lints'));

      expect(dartNames, contains('zuraffa'));
      expect(dartNames, isNot(contains('zuraffa_flutter')));
      expect(dartNames, isNot(contains('flutter_lints')));
    });
  });

  group('SetupCommand git init', () {
    test('exposes --no-git flag', () {
      final cmd = SetupCommand();
      expect(cmd.argParser.options, contains('no-git'));
    });

    test('initializeGit creates .git in a fresh directory', () async {
      final dir = await Directory.systemTemp.createTemp('zfa_git_');
      try {
        await SetupCommand().initializeGit(
          projectRoot: dir.path,
          noGit: false,
          dryRun: false,
          verbose: false,
        );
        expect(Directory('${dir.path}/.git').existsSync(), isTrue);
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('initializeGit skips when --no-git is set', () async {
      final dir = await Directory.systemTemp.createTemp('zfa_git_');
      try {
        await SetupCommand().initializeGit(
          projectRoot: dir.path,
          noGit: true,
          dryRun: false,
          verbose: false,
        );
        expect(Directory('${dir.path}/.git').existsSync(), isFalse);
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('initializeGit is idempotent when .git already exists', () async {
      final dir = await Directory.systemTemp.createTemp('zfa_git_');
      try {
        await Directory('${dir.path}/.git').create();
        await SetupCommand().initializeGit(
          projectRoot: dir.path,
          noGit: false,
          dryRun: false,
          verbose: false,
        );
        expect(Directory('${dir.path}/.git').existsSync(), isTrue);
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test(
      'dry-run prints git init intent without touching the filesystem',
      () async {
        final dir = await Directory.systemTemp.createTemp('zfa_git_');
        try {
          final prints = <String>[];
          await runZoned(
            () => SetupCommand().initializeGit(
              projectRoot: dir.path,
              noGit: false,
              dryRun: true,
              verbose: false,
            ),
            zoneSpecification: ZoneSpecification(
              print: (self, parent, zone, message) => prints.add(message),
            ),
          );
          expect(prints.join('\n'), contains('Would run: git init'));
          expect(Directory('${dir.path}/.git').existsSync(), isFalse);
        } finally {
          await dir.delete(recursive: true);
        }
      },
    );
  });

  group('SetupCommand run (dry-run)', () {
    test('prints git init intent during dry-run bootstrap', () async {
      final runner = CommandRunner('zfa', 'test')..addCommand(SetupCommand());
      final prints = <String>[];
      await runZoned(
        () => runner.run(['setup', 'demo_app', '--dry-run', '--flutter']),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, message) => prints.add(message),
        ),
      );
      final out = prints.join('\n');
      expect(out, contains('Would run: git init'));
      expect(out, contains('flutter create'));
    });

    test('default --flutter pins SPM + platforms ios,android', () async {
      final runner = CommandRunner('zfa', 'test')..addCommand(SetupCommand());
      final prints = <String>[];
      await runZoned(
        () => runner.run(['setup', 'demo_app', '--dry-run', '--flutter']),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, message) => prints.add(message),
        ),
      );
      final cmd = prints.firstWhere((l) => l.contains('Would run: flutter'));
      expect(cmd, contains('--platforms ios'));
      expect(cmd, contains('--platforms android'));
      expect(cmd, contains('--swift-package-manager'));
      expect(cmd, isNot(contains('--platforms macos')));
    });

    test('--platforms without ios does NOT add --swift-package-manager',
        () async {
      final runner = CommandRunner('zfa', 'test')..addCommand(SetupCommand());
      final prints = <String>[];
      await runZoned(
        () => runner.run([
          'setup',
          'demo_app',
          '--dry-run',
          '--flutter',
          '--platforms=macos',
        ]),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, message) => prints.add(message),
        ),
      );
      final cmd = prints.firstWhere((l) => l.contains('Would run: flutter'));
      expect(cmd, contains('--platforms macos'));
      expect(cmd, isNot(contains('--swift-package-manager')));
    });

    test('--platforms=ios still enables --swift-package-manager', () async {
      final runner = CommandRunner('zfa', 'test')..addCommand(SetupCommand());
      final prints = <String>[];
      await runZoned(
        () => runner.run([
          'setup',
          'demo_app',
          '--dry-run',
          '--flutter',
          '--platforms=ios',
        ]),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, message) => prints.add(message),
        ),
      );
      final cmd = prints.firstWhere((l) => l.contains('Would run: flutter'));
      expect(cmd, contains('--swift-package-manager'));
    });
  });
}
