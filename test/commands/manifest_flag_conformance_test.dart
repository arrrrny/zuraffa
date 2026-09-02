import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:args/command_runner.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/slice/slice_command.dart';

import '../plugins/slice/helpers/capture_output.dart';

/// Issue #771 — manifest schema ↔ CLI grammar conformance for REQUIRED
/// properties.
///
/// `zfa manifest` publishes `inputSchema.required` per capability; a
/// manifest-driven client (MCP agent, script) that follows the contract
/// sends every required property as `--<property> <value>`. Commands whose
/// parser rejects the schema-documented flag mis-invoke on the first try —
/// the exact failure the issue reports for `mock json` / `api
/// create-api-bridge` (both fixed on master since; this suite pins the
/// contract and covers the commands that still reject their schema flags).
///
/// Contract under test:
///   FR-1: every required schema property must be accepted as a CLI flag
///         (snake_cased, dashes) — never "Could not find an option".
///   FR-2: the value passed via the flag must reach the capability (the
///         command proceeds past parsing with that name — provable via the
///         deterministic "No slice named X" / "Exporting slice X" /
///         plan output messages).
///   FR-3: the positional form keeps working (regression guard).
///
/// Fast tier: slice assertions run against a bare SliceCommand in an empty
/// project (usage/validation paths only, no generation); the feature
/// assertions use a fixture workspace through CliRunner with --plan
/// (plan-only, no writes).
void main() {
  group('slice — schema-required flags parse and flow (FR-1/FR-2)', () {
    late CommandRunner<void> runner;
    late SliceCommand command;

    setUp(() {
      command = SliceCommand(projectRoot: Directory.systemTemp.path);
      runner = CommandRunner<void>('zfa', 'test')..addCommand(command);
    });

    test('merge accepts --name (schema: required ["name"])', () async {
      final output = await captureOutput(
        () => runner.run(['slice', 'merge', '--name', 'Gold']),
      );
      expect(
        output,
        isNot(contains('Could not find an option named "--name"')),
      );
      // The name flowed into the capability (deterministic not-found
      // message from MergeSliceCapability for a slice that doesn't exist).
      expect(output, contains('No slice named "Gold" found'));
    });

    test('merge via manifest alias merge_slice accepts --name', () async {
      final output = await captureOutput(
        () => runner.run(['slice', 'merge_slice', '--name', 'Gold']),
      );
      expect(
        output,
        isNot(contains('Could not find an option named "--name"')),
      );
      expect(output, contains('No slice named "Gold" found'));
    });

    test('verify accepts --name (schema: required ["name"])', () async {
      final output = await captureOutput(
        () => runner.run(['slice', 'verify', '--name', 'Gold']),
      );
      expect(
        output,
        isNot(contains('Could not find an option named "--name"')),
      );
      expect(output, contains('No slice named "Gold" found'));
    });

    test(
      'export accepts --name (schema: required ["name", "format"])',
      () async {
        final output = await captureOutput(
          () => runner.run([
            'slice',
            'export',
            '--name',
            'Gold',
            '--format',
            'tar.gz',
          ]),
        );
        expect(
          output,
          isNot(contains('Could not find an option named "--name"')),
        );
        expect(output, contains('Exporting slice "Gold"'));
      },
    );

    test(
      'cut accepts --entries (schema: required ["name", "entries"])',
      () async {
        final output = await captureOutput(
          () => runner.run(['slice', 'cut', 'MySlice', '--entries', 'product']),
        );
        expect(
          output,
          isNot(contains('Could not find an option named "--entries"')),
        );
        // The alias satisfies the same guard the canonical --entry does: the
        // command must NOT fail with the missing-entry usage error.
        expect(output, isNot(contains('Missing --entry')));
      },
    );

    test('FR-3 regression: positional merge still works', () async {
      final output = await captureOutput(
        () => runner.run(['slice', 'merge', 'Gold']),
      );
      expect(output, contains('No slice named "Gold" found'));
    });
  });

  group('feature — schema-required --name parses and flows (FR-1/FR-2)', () {
    late Directory workspace;

    setUp(() async {
      workspace = await Directory.systemTemp.createTemp('zfa_manifest771_');
      await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: manifest_conformance_fixture
environment:
  sdk: ^3.11.0
''');
      final entityDir = Directory(
        p.join(workspace.path, 'lib', 'src', 'domain', 'entities', 'product'),
      );
      await entityDir.create(recursive: true);
      await File(p.join(entityDir.path, 'product.dart')).writeAsString('''
class Product {
  final String id;

  const Product({required this.id});
}
''');
    });

    tearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    test('feature route accepts --name (schema: required ["name"])', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final output = await runner.runCapturing([
        '-C',
        workspace.path,
        'feature',
        'route',
        '--name',
        'Product',
        '--plan',
      ]);
      expect(
        output,
        isNot(contains('Could not find an option named "--name"')),
      );
      expect(output, isNot(contains('Missing feature name')));
      // The name flowed into the normalized make plan.
      expect(output, contains('Product'));
    });

    test(
      'FR-3 regression: positional feature route Product still works',
      () async {
        final runner = CliRunner(exitOnCompletion: false);
        final output = await runner.runCapturing([
          '-C',
          workspace.path,
          'feature',
          'route',
          'Product',
          '--plan',
        ]);
        expect(output, isNot(contains('Missing feature name')));
        expect(output, contains('Product'));
      },
    );
  });
}
