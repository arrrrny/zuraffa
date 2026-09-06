// Bug 1198 (part of #908 P0) — the loop is the template's referee:
// templates that fail the loop BLOCK publish.
//
// Pins the publish-gate wiring:
//   - `tools/template_publish_gate.sh` exists, is executable, is
//     syntactically valid, and drives the self-hosting suite;
//   - CI (`.github/workflows/ci.yaml`) runs it as a job;
//   - the release workflow (`.github/workflows/release.yml`) runs it
//     BEFORE the publish/build steps.
//
// If a template fails its TDD loop (structural + compile + behavioral +
// diff guard, upstream + downstream), the gate exits non-zero and nothing
// publishes. This file is what makes that claim testable instead of
// aspirational.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../helpers/template_self_hosting.dart';

void main() {
  late String gatePath;
  late String ciPath;
  late String releasePath;

  setUpAll(() async {
    final repoRoot = await findProjectRoot();
    gatePath = p.join(repoRoot, 'tools', 'template_publish_gate.sh');
    ciPath = p.join(repoRoot, '.github', 'workflows', 'ci.yaml');
    releasePath = p.join(repoRoot, '.github', 'workflows', 'release.yml');
  });

  group('publish gate script', () {
    test('exists and is executable', () {
      final gate = File(gatePath);
      expect(gate.existsSync(), isTrue, reason: '$gatePath must exist');
      final mode = gate.statSync().mode;
      // Exec bits = 0o111 (user/group/other execute) = decimal 73; Dart
      // has no octal literal syntax.
      final executable = mode & 73 != 0;
      expect(
        executable,
        isTrue,
        reason:
            '$gatePath must be executable (chmod +x) so the release '
            'workflow can invoke it directly',
      );
    });

    test(
      'is syntactically valid bash and drives the self-hosting suite',
      () async {
        final syntax = await Process.run('bash', ['-n', gatePath]);
        expect(
          syntax.exitCode,
          0,
          reason:
              'gate script must be valid bash:\n'
              '${syntax.stdout}\n${syntax.stderr}',
        );

        final content = File(gatePath).readAsStringSync();
        // The gate must run BOTH lanes of the self-hosting suite.
        expect(
          content,
          contains('test/templates/self_hosting'),
          reason: 'gate must run the template self-hosting suite',
        );
        expect(
          content,
          contains('--exclude-tags flutter'),
          reason:
              'gate must run the pure-Dart lane with the flutter-tagged '
              'tests excluded',
        );
        expect(
          content,
          contains('--tags flutter'),
          reason: 'gate must run the flutter lane (downstream-compile gate)',
        );
        // The loop decides: any failure must propagate a non-zero exit.
        expect(
          content,
          contains('set -euo pipefail'),
          reason: 'gate must fail the publish on any loop failure',
        );
      },
    );
  });

  group('workflow wiring', () {
    test('CI runs the gate on pull requests and pushes', () {
      final ci = File(ciPath);
      expect(ci.existsSync(), isTrue);
      final content = ci.readAsStringSync();
      expect(content, contains('template_publish_gate'));
      expect(content, contains('tools/template_publish_gate.sh'));
    });

    test('release runs the gate BEFORE the publish/build steps', () {
      final release = File(releasePath);
      expect(release.existsSync(), isTrue);
      final content = release.readAsStringSync();

      final gateIndex = content.indexOf('tools/template_publish_gate.sh');
      final buildIndex = content.indexOf('Build CLI');
      expect(
        gateIndex,
        greaterThan(0),
        reason: 'release workflow must invoke the publish gate',
      );
      expect(
        buildIndex,
        greaterThan(gateIndex),
        reason:
            'the gate must run BEFORE the binaries are built/published '
            '— a template that fails the loop must block the release',
      );
    });
  });
}
