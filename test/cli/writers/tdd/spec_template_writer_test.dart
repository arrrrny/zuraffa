// Bug #1480 — zuraffa's spec authoring grammar never reaches a spec-kit
// project: the `.specify/templates/spec-template.md` a consumer project
// receives is the stock spec-kit template (no `## Layer Contracts`, no
// `traces:` grammar), and no zfa verb installs zuraffa's own template.
//
// Fix contract: `zfa tdd init` (the wiring verb) ensures the project's
// spec template carries the zuraffa-1.0 authoring grammar via the new
// `SpecTemplateWriter`:
//   - template absent            -> install the embedded zuraffa-1.0 template
//   - grammarless (stock) present -> replace it with a loud notice (the
//     stock template is exactly the #1480 dead-end carrier)
//   - already pins a KNOWN zuraffa template version -> untouched (the
//     version marker is the customization treaty, #919/#1183)
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/cli/writers/tdd/spec_template_writer.dart';
import 'package:zuraffa/src/plugins/tdd/services/spec_parser.dart';

void main() {
  late Directory tmpDir;

  setUp(() async {
    tmpDir = Directory.systemTemp.createTempSync('bug1480_template_');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  File templateFile(String root) =>
      File(p.join(root, '.specify', 'templates', 'spec-template.md'));

  group('bug #1480 — SpecTemplateWriter propagates the authoring grammar', () {
    test('U3a: template absent -> the zuraffa-1.0 grammar template is '
        'installed and parses as a known template version', () async {
      expect(templateFile(tmpDir.path).existsSync(), isFalse);

      final result = await const SpecTemplateWriter().write(tmpDir.path);

      expect(result, isNotNull, reason: 'a write happened');
      expect(result!.action, SpecTemplateWriteAction.created);
      final installed = templateFile(tmpDir.path);
      expect(installed.existsSync(), isTrue);
      final content = installed.readAsStringSync();
      expect(
        const SpecParser().parseTemplateVersion(content),
        'zuraffa-1.0',
        reason:
            'the installed template must pin a KNOWN template version — '
            'specs authored from it pass the #919 contract gate unchanged '
            '(bug #1183 contract).',
      );
      expect(content, contains('## Layer Contracts'));
      expect(content, contains('traces:'));
    });

    test('U3b: the embedded template carries the FULL authoring grammar the '
        'declared-routing path reads', () async {
      final content = kZuraffaSpecTemplate;
      expect(content, contains('## Layer Contracts'));
      expect(content, contains('traces:'));
      expect(content, contains('**Type**'));
      expect(content, contains('### Key Entities'));
      expect(
        const SpecParser().parseContractRows(content).map((r) => r.name),
        contains('Validator'),
        reason:
            'the template must yield DECLARED contract rows through the '
            'real parser so template-authored specs route declared out of '
            'the box (issue #1480).',
      );
    });

    test('U3c: a grammarless stock spec-kit template is REPLACED (it is the '
        'dead-end carrier) — the notice names what happened', () async {
      final file = templateFile(tmpDir.path);
      file.parent.createSync(recursive: true);
      const stock =
          '# Feature Specification: [FEATURE NAME]\n'
          '\n'
          '## User Scenarios & Testing *(mandatory)*\n'
          '\n'
          '1. **Given** [initial state], **When** [action], **Then** '
          '[outcome]\n'
          '\n'
          '## Requirements *(mandatory)*\n'
          '\n'
          '- **FR-001**: System MUST [specific capability]\n';
      file.writeAsStringSync(stock);

      final result = await const SpecTemplateWriter().write(tmpDir.path);

      expect(result, isNotNull);
      expect(result!.action, SpecTemplateWriteAction.replaced);
      final content = file.readAsStringSync();
      expect(content, isNot(stock));
      expect(
        const SpecParser().parseTemplateVersion(content),
        'zuraffa-1.0',
        reason: 'the replacement carries the grammar + the version pin',
      );
      expect(content, contains('## Layer Contracts'));
      expect(content, contains('traces:'));
    });

    test('U3d: a template already pinning a known zuraffa version is NEVER '
        'touched (byte-identical, no-op)', () async {
      final file = templateFile(tmpDir.path);
      file.parent.createSync(recursive: true);
      const customized =
          '**Template Version**: `zuraffa-1.0`\n'
          '\n'
          '# My team\'s customized spec template\n'
          '\n'
          '## Layer Contracts\n'
          '\n'
          '**Function**:\n'
          '- `Custom`: `doThing(Input) -> Output`\n';
      file.writeAsStringSync(customized);

      final result = await const SpecTemplateWriter().write(tmpDir.path);

      expect(result, isNull, reason: 'no write happened — already current');
      expect(
        file.readAsStringSync(),
        customized,
        reason:
            'the customization treaty: a template that already pins a '
            'known zuraffa version is user content, never clobbered',
      );
    });

    test('A3: `zfa tdd init` end-to-end — after wiring, the project template '
        'carries the grammar (the issue\'s REQUIRED verification)', () async {
      // A minimal Dart project — `zfa tdd init` wires a real project root
      // (the pubspec patcher needs the file; the template writer does not).
      File(p.join(tmpDir.path, 'pubspec.yaml')).writeAsStringSync(
        'name: bug148_fixture\nenvironment:\n  sdk: ^3.11.0\n',
      );
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'init',
        '--project',
        tmpDir.path,
      ]);

      final installed = templateFile(tmpDir.path);
      expect(
        installed.existsSync(),
        isTrue,
        reason:
            '`zfa tdd init` must install the authoring template (issue '
            '#1480: no verb installed it — out was\n$out)',
      );
      final content = installed.readAsStringSync();
      expect(content, contains('## Layer Contracts'));
      expect(content, contains('traces:'));
      expect(const SpecParser().parseTemplateVersion(content), 'zuraffa-1.0');
      // Idempotent re-run: already current, still green.
      final out2 = await runner.runCapturing([
        'tdd',
        'init',
        '--project',
        tmpDir.path,
      ]);
      expect(CliRunner.lastDispatchedExitCode, 0, reason: out2);
    });
  });
}
