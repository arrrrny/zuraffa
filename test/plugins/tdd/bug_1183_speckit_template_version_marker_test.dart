// Bug #1183 — specs authored by speckit-specify always exit 3 on the first
// `zfa tdd plan`: the speckit spec template (`.specify/templates/
// spec-template.md`, the file `create-new-feature.sh` copies verbatim into
// every new `specs/<feature>/spec.md`) ships no `**Template Version**`
// marker, so every new spec is born contract drift (the #919 gate) and the
// first plan dies with exit 3 until `--migrate-spec` patches it. 100%
// deterministic for every new feature — the authoring pipeline and the
// planning pipeline disagree about the spec contract.
//
// Fix contract: the speckit spec template itself ships the treaty pin, so a
// spec authored by speckit-specify already pins a known template version and
// the first `zfa tdd plan` just works. The drift gate itself is UNCHANGED —
// a spec hand-authored without the marker still exits 3 (issue #990 kept
// that contract; this only fixes the authoring side).
//
// Harness: the template is asserted through the REAL gate logic
// (`SpecParser.parseTemplateVersion` — fence stripping included, so a
// marker inside a documentation fence does not count), and the plan runs
// through the real CLI entry point on a temp project (bug 846/919 harness).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/spec_parser.dart';

import '../../helpers/project_root.dart';
import 'helpers/spec_fixture.dart';

/// Same cross-suite safety as bug_919_template_structures_test.dart: read
/// the exit code from the per-isolate dispatch snapshot, never from the
/// process-global `dart:io exitCode` (issue #1096 family).
int takeDispatchedExitCode() => CliRunner.lastDispatchedExitCode;

void main() {
  late Directory tmpDir;
  late String featureDir;
  const featureName = '001-demo';

  setUp(() async {
    tmpDir = Directory.systemTemp.createTempSync('bug1183_template_');
    featureDir = makeFeatureDir(tmpDir.path, featureName);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    exitCode = 0;
  });

  group('bug #1183 — the speckit spec template ships the treaty pin', () {
    test('T1: the template carries a non-fenced **Template Version** marker '
        'that the plan gate parser recognizes', () async {
      final repoRoot = await findProjectRoot();
      final template = await File(
        '$repoRoot/.specify/templates/spec-template.md',
      ).readAsString();

      final version = const SpecParser().parseTemplateVersion(template);
      expect(
        version,
        isNotNull,
        reason:
            'the speckit spec template must ship the `**Template '
            'Version**: `…`` marker OUTSIDE any fenced code block — a '
            'fenced example is documentation, not the pin (the same rule '
            'SpecParser.parseTemplateVersion enforces). Specs authored by '
            'speckit-specify copy this template verbatim; without the pin '
            'every first `zfa tdd plan` exits 3 (bug #1183).',
      );
    });

    test('T2: the template pins a KNOWN template version (the gate accepts '
        'template-authored specs as-is)', () async {
      final repoRoot = await findProjectRoot();
      final template = await File(
        '$repoRoot/.specify/templates/spec-template.md',
      ).readAsString();

      final version = const SpecParser().parseTemplateVersion(template);
      expect(
        SpecParser.knownTemplateVersions,
        contains(version),
        reason:
            'a spec authored from the template must pass the #919 '
            'contract gate unchanged: the pinned version must be one the '
            'parser implements (known: '
            '${SpecParser.knownTemplateVersions.join(', ')}).',
      );
    });

    test('T3: the marker sits in the template frontmatter (header block, '
        'before the first section heading)', () async {
      final repoRoot = await findProjectRoot();
      final template = await File(
        '$repoRoot/.specify/templates/spec-template.md',
      ).readAsString();

      final markerLine = template
          .split('\n')
          .indexWhere(
            (line) => RegExp(
              r'^\s*\*\*template\s+version\*\*:',
              caseSensitive: false,
            ).hasMatch(line),
          );
      expect(markerLine, isNot(-1), reason: 'the marker line is present');
      final firstSection = template
          .split('\n')
          .indexWhere((line) => line.startsWith('## '));
      expect(
        markerLine,
        lessThan(firstSection),
        reason:
            'the pin is authored in the frontmatter position — the same '
            'position `SpecMigrator` inserts it (issue #990) and the same '
            'position green specs carry it — not buried below the fold '
            'where an authoring agent can drop it.',
      );
    });

    test('T4: a spec authored by copying the template VERBATIM (exactly what '
        'create-new-feature.sh does) never fails the marker gate', () async {
      final repoRoot = await findProjectRoot();
      final template = await File(
        '$repoRoot/.specify/templates/spec-template.md',
      ).readAsString();

      // The authoring step, byte-verbatim: resolve_template_content pipes
      // the template straight into specs/<feature>/spec.md.
      await File(p.join(featureDir, 'spec.md')).writeAsString(template);

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'plan',
        featureName,
        '--project',
        tmpDir.path,
      ]);

      expect(
        out,
        isNot(contains('missing `**Template Version**` marker')),
        reason:
            'the first plan must not report marker contract drift for a '
            'template-authored spec (bug #1183): out was\n$out',
      );
      expect(
        takeDispatchedExitCode(),
        isNot(3),
        reason:
            'exit 3 is the contract-drift exit — a template-authored '
            'spec must never earn it on the marker gate; out was\n$out',
      );
    });

    test(
      'T5: first plan just works — a spec authored from the template '
      'plans green (exit 0, test list written) with no migration step',
      () async {
        final repoRoot = await findProjectRoot();
        final template = await File(
          '$repoRoot/.specify/templates/spec-template.md',
        ).readAsString();

        // The authoring agent fills the template's placeholders in place and
        // drops the include-when sections a tiny feature does not declare
        // (Lanes, Skin Contract) — exactly what /speckit-specify does. The
        // property under test: the marker the TEMPLATE ships survives
        // authoring verbatim, so the first plan cannot drift.
        var authored = template
            // fill the header block
            .replaceFirst('[FEATURE NAME]', 'First Plan Just Works')
            .replaceFirst('[###-feature-name]', featureName)
            .replaceFirst('[DATE]', '2026-09-06')
            .replaceFirst('"\$ARGUMENTS"', 'authored from the fixed template')
            // fill User Story 1 and its acceptance scenarios
            .replaceFirst(
              '### User Story 1 - [Brief Title] (Priority: P1)',
              '### User Story 1 - First plan just works (Priority: P1)',
            )
            .replaceFirst(
              '[Describe this user journey in plain language]',
              'A spec authored from the speckit template plans on the first '
                  'try with no migration step.',
            )
            .replaceFirst(
              '[Explain the value and why it has this priority level]',
              'The authoring contract is broken while the first plan exits 3.',
            )
            .replaceFirst(
              '[Describe how this can be tested independently - e.g., "Can be '
                  'fully tested by [specific action] and delivers [specific '
                  'value]"]',
              'Can be fully tested by running zfa tdd plan on a '
                  'template-authored spec and observing exit 0.',
            )
            .replaceFirst(
              '1. **Given** [initial state], **When** [action], '
                  '**Then** [expected outcome]\n'
                  '2. **Given** [initial state], **When** [action], '
                  '**Then** [expected outcome]',
              '1. **Given** a spec authored from the speckit template '
                  '**When** the first `zfa tdd plan` runs **Then** the test list '
                  'is generated without contract drift',
            )
            // fill the requirements and measurable outcome placeholders
            .replaceFirst(
              RegExp(r'- \*\*FR-001\*\*[\s\S]*?- \*\*FR-007\*\*[^\n]*'),
              '- **FR-001**: System MUST accept a spec authored from the '
              'speckit spec template as contract-conformant on the first '
              'plan.\n'
              '            traces: Validator',
            )
            .replaceFirst(
              RegExp(
                r'- \*\*\[Entity 1\]\*\*[\s\S]*?- \*\*\[Entity 2\]\*\*[^\n]*',
              ),
              '- **SpecTemplate**: `path: String`, `version: String` — the '
              'authoring skeleton every new spec is copied from',
            )
            .replaceFirst(
              RegExp(r'- \*\*SC-001\*\*[\s\S]*?- \*\*SC-004\*\*[^\n]*'),
              '- **SC-001**: The first `zfa tdd plan` on a template-authored '
              'spec exits 0 with a test list.',
            );

        // drop the optional include-when sections and leftover scaffolding a
        // tiny feature does not declare (the agent deletes them when they do
        // not apply — the template's own italics say "include when …")
        authored = authored
            .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '')
            .replaceFirst(RegExp(r'### User Story 2[\s\S]*?(?=\n## )'), '')
            .replaceFirst(RegExp(r'## Lanes[\s\S]*?(?=\n## )'), '')
            .replaceFirst(RegExp(r'## Skin Contract[\s\S]*?(?=\n## )'), '')
            .replaceFirst(RegExp(r'## Assumptions[\s\S]*'), '');

        await File(p.join(featureDir, 'spec.md')).writeAsString(authored);

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing([
          'tdd',
          'plan',
          featureName,
          '--project',
          tmpDir.path,
        ]);

        expect(
          takeDispatchedExitCode(),
          0,
          reason:
              'the FIRST plan on a template-authored spec must succeed '
              'with no `--migrate-spec` detour (bug #1183: it deterministically '
              'exited 3 before); out was\n$out',
        );
        final testList = File(p.join(featureDir, 'tdd', 'test-list.md'));
        expect(
          testList.existsSync(),
          isTrue,
          reason: 'the first plan writes the plan artifact (tdd/test-list.md)',
        );
      },
    );
  });
}
