// Tests for the `zfa package analyze` command (issue #477).
//
// `zfa package analyze` is the diagnostic layer that closes the #477
// misfire: an agent that lands in a non-Zuraffa Dart/Flutter package
// (e.g. a Flutter plugin like zikzak_inappwebview) can run this command
// to get an honest verdict + concrete next-step commands instead of
// silently misfiring.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/commands/package_command.dart';

void main() {
  late Directory sandbox;
  late CliRunner runner;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('zfa_pkg_analyze_');
    runner = CliRunner(exitOnCompletion: false);
  });

  tearDown(() async {
    try {
      if (sandbox.existsSync()) {
        await sandbox.delete(recursive: true);
      }
    } catch (_) {}
  });

  /// Write a pubspec at the sandbox root with the given [name] and [body]
  /// (body is appended under the `name:` line).
  File writePubspec({required String name, String? body}) {
    final f = File(p.join(sandbox.path, 'pubspec.yaml'));
    final buf = StringBuffer()
      ..writeln('name: $name')
      ..writeln('version: 0.1.0')
      ..writeln('environment:')
      ..writeln('  sdk: ">=3.0.0 <4.0.0"');
    if (body != null) buf.writeln(body);
    f.writeAsStringSync(buf.toString());
    return f;
  }

  group('PackageAnalysis.reportFor', () {
    test('no pubspec.yaml -> non-Dart flavor + noPubspec verdict', () {
      final report = PackageAnalysis.reportFor(sandbox.path);
      expect(report.hasPubspec, isFalse);
      expect(report.flavor, PackageFlavor.nonDart);
      expect(report.verdict, PackageVerdict.noPubspec);
      expect(report.packageName, '<unknown>');
    });

    test('broken YAML pubspec -> brokenPubspec verdict', () {
      File(p.join(sandbox.path, 'pubspec.yaml'))
          .writeAsStringSync('name: broken\n  bad: : : indentation');
      final report = PackageAnalysis.reportFor(sandbox.path);
      expect(report.hasPubspec, isTrue);
      expect(report.flavor, PackageFlavor.brokenPubspec);
      expect(report.verdict, PackageVerdict.brokenPubspec);
    });

    test('pure-Dart package with no zuraffa deps -> pureDart + notZuraffa', () {
      writePubspec(name: 'my_pure_dart');
      final report = PackageAnalysis.reportFor(sandbox.path);
      expect(report.flavor, PackageFlavor.pureDart);
      expect(report.hasZuraffa, isFalse);
      expect(report.hasZorphyAnnotation, isFalse);
      expect(report.hasZuraffaLayout, isFalse);
      expect(report.verdict, PackageVerdict.notZuraffa);
      expect(report.packageName, 'my_pure_dart');
      expect(report.packageVersion, '0.1.0');
    });

    test('Flutter app (flutter: section, no plugin) -> flutterApp', () {
      writePubspec(
        name: 'my_flutter_app',
        body: '''
flutter:
  uses-material-design: true
''',
      );
      final report = PackageAnalysis.reportFor(sandbox.path);
      expect(report.flavor, PackageFlavor.flutterApp);
      expect(report.verdict, PackageVerdict.notZuraffa);
    });

    test('Flutter plugin (flutter.plugin section) -> flutterPlugin', () {
      // This is the zikzak_inappwebview shape from #477.
      writePubspec(
        name: 'zikzak_inappwebview',
        body: '''
flutter:
  plugin:
    platforms:
      android:
        package: com.example.zikzak
        pluginClass: ZikzakInappwebviewPlugin
      ios:
        pluginClass: ZikzakInappwebviewPlugin
''',
      );
      final report = PackageAnalysis.reportFor(sandbox.path);
      expect(report.flavor, PackageFlavor.flutterPlugin);
      expect(report.verdict, PackageVerdict.notZuraffa);
      // The next-steps for a Flutter plugin must mention that zfa cannot
      // rewrite the plugin, and must offer to create a new Zuraffa app
      // via `zfa setup`.
      final steps = report.nextSteps.join('\n');
      expect(steps, contains('cannot rewrite'));
      expect(steps, contains('zfa setup'));
    });

    test('partially Zuraffa: zorphy_annotation present but no layout', () {
      writePubspec(
        name: 'partial',
        body: '''
dependencies:
  zorphy_annotation: ^2.2.0
''',
      );
      final report = PackageAnalysis.reportFor(sandbox.path);
      expect(report.hasZorphyAnnotation, isTrue);
      expect(report.hasZuraffa, isFalse);
      expect(report.hasZuraffaLayout, isFalse);
      expect(report.verdict, PackageVerdict.partiallyZuraffa);
    });

    test('Zuraffa-ready: deps wired + layout present', () async {
      writePubspec(
        name: 'ready_app',
        body: '''
dependencies:
  zuraffa: ^6.0.0
  zorphy_annotation: ^2.2.0
''',
      );
      // Create the canonical layout.
      await Directory(
        p.join(sandbox.path, 'lib', 'src', 'domain', 'entities'),
      ).create(recursive: true);
      final report = PackageAnalysis.reportFor(sandbox.path);
      expect(report.hasZuraffa, isTrue);
      expect(report.hasZorphyAnnotation, isTrue);
      expect(report.hasZuraffaLayout, isTrue);
      expect(report.verdict, PackageVerdict.zuraffaReady);
    });

    test('zuraffa in dev_dependencies still counts', () {
      writePubspec(
        name: 'dev_dep_app',
        body: '''
dev_dependencies:
  zuraffa: ^6.0.0
''',
      );
      final report = PackageAnalysis.reportFor(sandbox.path);
      expect(report.hasZuraffa, isTrue);
    });

    test('zuraffa in dependency_overrides still counts', () {
      writePubspec(
        name: 'override_app',
        body: '''
dependency_overrides:
  zuraffa:
    path: ../../zuraffa
''',
      );
      final report = PackageAnalysis.reportFor(sandbox.path);
      expect(report.hasZuraffa, isTrue);
    });

    test('.zfa.json detection', () {
      writePubspec(name: 'with_config');
      File(p.join(sandbox.path, '.zfa.json'))
          .writeAsStringSync('{"version":1}');
      final report = PackageAnalysis.reportFor(sandbox.path);
      expect(report.hasZfaConfig, isTrue);
    });

    test('JSON output is valid JSON and round-trips', () {
      writePubspec(name: 'json_test');
      final report = PackageAnalysis.reportFor(sandbox.path);
      final json = report.toJson();
      // Must be parseable by dart:convert.
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded['package'], 'json_test');
      expect(decoded['flavor'], 'pureDart');
      expect(decoded['verdict'], 'notZuraffa');
      expect(decoded['hasPubspec'], isTrue);
      expect(decoded['nextSteps'], isA<List>());
    });

    test('JSON output with verbose includes pubspecDependencies', () {
      writePubspec(
        name: 'verbose_test',
        body: '''
dependencies:
  zuraffa: ^6.0.0
  http: ^1.0.0
''',
      );
      final report = PackageAnalysis.reportFor(sandbox.path);
      final json = report.toJson(verbose: true);
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded['pubspecDependencies'], isA<List>());
      expect(decoded['pubspecDependencies'], containsAll(<String>['zuraffa', 'http']));
    });
  });

  group('PackageCommand CLI wiring', () {
    test('zfa package (no subcommand) prints usage', () async {
      final output = await runner.runCapturing(['package']);
      expect(output.toLowerCase(), contains('usage'));
      expect(output, contains('analyze'));
    });

    test('zfa package analyze --help prints usage', () async {
      final output = await runner.runCapturing(['package', 'analyze', '--help']);
      expect(output.toLowerCase(), contains('usage'));
      expect(output, contains('--root'));
      expect(output, contains('--json'));
    });

    test('zfa help mentions package command', () async {
      final output = await runner.runCapturing(['help']);
      expect(output, contains('package'));
    });
  });

  group('PackageCommand.run via runCapturing', () {
    test('human-readable output on a non-Zuraffa sandbox', () async {
      writePubspec(name: 'cli_test_app');
      final output =
          await runner.runCapturing(['package', 'analyze', '--root', sandbox.path]);
      expect(output, contains('Zuraffa Package Analysis'));
      expect(output, contains('cli_test_app'));
      expect(output, contains('Verdict:'));
      expect(output, contains('Next steps:'));
    });

    test('--json emits valid JSON for programmatic consumers', () async {
      writePubspec(name: 'cli_json_app');
      final output = await runner.runCapturing(
          ['package', 'analyze', '--root', sandbox.path, '--json']);
      // Strip any leading non-JSON log lines (CliRunner may print a header).
      final jsonStart = output.indexOf('{');
      expect(jsonStart, greaterThanOrEqualTo(0),
          reason: 'expected at least one { in output: $output');
      final jsonText = output.substring(jsonStart);
      final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
      expect(decoded['package'], 'cli_json_app');
      expect(decoded['verdict'], 'notZuraffa');
    });

    test('Flutter plugin sandbox yields notZuraffa + cannot-rewrite next step',
        () async {
      writePubspec(
        name: 'zikzak_inappwebview',
        body: '''
flutter:
  plugin:
    platforms:
      android:
        package: com.example.zikzak
        pluginClass: ZikzakInappwebviewPlugin
''',
      );
      final output = await runner.runCapturing(
          ['package', 'analyze', '--root', sandbox.path]);
      expect(output, contains('Flutter plugin'));
      expect(output, contains('cannot rewrite'));
      expect(output, contains('zfa setup'));
    });
  });
}

