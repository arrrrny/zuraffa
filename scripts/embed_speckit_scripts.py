#!/usr/bin/env python3
"""Generates lib/src/commands/speckit_scaffolding.dart with the four speckit
helper scripts embedded byte-identically (issue #1417).

Re-run this script whenever .specify/scripts/bash/{common,setup-plan,
check-prerequisites,setup-tasks}.sh evolve in the framework repo, then run
the drift-guard test (U-1417-b9) to confirm.
"""
import pathlib

REPO = pathlib.Path("/home/z/my-project/zuraffa")
SCRIPTS = ["common.sh", "setup-plan.sh", "check-prerequisites.sh", "setup-tasks.sh"]

names = {
    "common.sh": "kSpeckitCommonSh",
    "setup-plan.sh": "kSpeckitSetupPlanSh",
    "check-prerequisites.sh": "kSpeckitCheckPrerequisitesSh",
    "setup-tasks.sh": "kSpeckitSetupTasksSh",
}

header = '''/// `SpeckitScaffoldingWriter` — emits the current speckit helper scripts
/// into an existing repo (issue #1417).
///
/// Bug #1417: affected repos gitignore `.specify/*` (only
/// `constitution.md` force-added), so `.specify/scripts/bash/*` lived only
/// on the original machine and every speckit-* skill died at Step 1 with
/// `bash .specify/scripts/bash/setup-plan.sh: No such file or directory
/// (exit 127)` on a fresh clone. No zfa verb could regenerate the
/// scaffolding into an existing repo: `zfa setup` creates a new app,
/// `zfa initialize` only wires pubspec deps, and `zfa generate-commands`
/// regenerates command .md files, not bash helpers.
///
/// The fix: `zfa initialize --speckit` emits the four Step-1 helper scripts
/// (the exact set the speckit-plan/-tasks/-implement skills source) from the
/// embedded constants below — the same treaty as `kZuraffaSpecTemplate`
/// (`lib/src/cli/writers/tdd/spec_template_writer.dart`): content versioned
/// with the CLI package so the skills and the scripts they invoke cannot
/// drift, no repo checkout required. Constitution I (CLI-built only):
/// nothing is hand-scaffolded; the framework owns the emission.
///
/// The embedded constants MUST stay byte-identical to the framework repo's
/// canonical `.specify/scripts/bash/` copies — the drift-guard test
/// (U-1417-b9 in `test/commands/initialize_speckit_test.dart`) fails the
/// suite on divergence and points at the re-embed tool
/// (`scripts/embed_speckit_scripts.py`).
library;

import 'dart:io';

import 'package:path/path.dart' as p;

'''

writer = '''/// Result of one [SpeckitScaffoldingWriter.emit] run.
class SpeckitEmitResult {
  const SpeckitEmitResult({
    required this.created,
    required this.skipped,
    required this.overwritten,
    required this.gitignoreUpdated,
    this.gitignorePath,
  });

  /// Scripts written for the first time.
  final List<String> created;

  /// Existing scripts left untouched (no --force).
  final List<String> skipped;

  /// Existing scripts overwritten via --force.
  final List<String> overwritten;

  /// Whether the `.gitignore` force-include block was appended.
  final bool gitignoreUpdated;

  final String? gitignorePath;
}

/// Emits the embedded speckit helper scripts into
/// `<projectRoot>/.specify/scripts/bash/`.
class SpeckitScaffoldingWriter {
  const SpeckitScaffoldingWriter();

  /// The scripts emitted for the skills' Step 1, in emission order.
  static const List<String> scriptNames = [
    'common.sh',
    'setup-plan.sh',
    'check-prerequisites.sh',
    'setup-tasks.sh',
  ];

  /// Content for each [scriptNames] entry (byte-identical to the canonical
  /// framework copies — see the drift guard, spec FR-002 / SC-003).
  static Map<String, String> embeddedScripts() => {
        'common.sh': kSpeckitCommonSh,
        'setup-plan.sh': kSpeckitSetupPlanSh,
        'check-prerequisites.sh': kSpeckitCheckPrerequisitesSh,
        'setup-tasks.sh': kSpeckitSetupTasksSh,
      };

  /// Marker comment keys the idempotent `.gitignore` force-include block.
  static const String gitignoreMarker =
      '# zfa initialize --speckit: keep the speckit helper scripts tracked';

  /// Rules that would ignore `.specify/scripts` (the emitted helpers). A
  /// bare `.specify/` or `.specify/*` excludes the directory itself; a
  /// direct rule names it explicitly.
  static const List<String> _excludingRules = [
    '.specify/',
    '.specify/*',
    '.specify/scripts',
    '.specify/scripts/',
    '.specify/scripts/*',
  ];

  Future<SpeckitEmitResult> emit(
    String projectRoot, {
    bool force = false,
    bool dryRun = false,
    void Function(String message)? log,
  }) {
    final say = log ?? (_) {};
    final bashDir = Directory(
      p.join(projectRoot, '.specify', 'scripts', 'bash'),
    );

    final created = <String>[];
    final skipped = <String>[];
    final overwritten = <String>[];
    final scripts = embeddedScripts();

    for (final name in scriptNames) {
      final file = File(p.join(bashDir.path, name));
      final content = scripts[name]!;
      if (file.existsSync()) {
        final existing = file.readAsStringSync();
        if (existing == content) {
          skipped.add(name);
          continue;
        }
        if (!force) {
          skipped.add(name);
          continue;
        }
        if (!dryRun) {
          file.writeAsStringSync(content);
        }
        overwritten.add(name);
        continue;
      }
      if (!dryRun) {
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(content);
      }
      created.add(name);
    }

    var gitignoreUpdated = false;
    String? gitignorePath;
    final gi = File(p.join(projectRoot, '.gitignore'));
    if (gi.existsSync() && _needsForceInclude(gi.readAsStringSync())) {
      gitignorePath = gi.path;
      if (!dryRun) {
        _appendForceInclude(gi);
      }
      gitignoreUpdated = true;
    }

    for (final name in created) {
      say('✓ Emitted .specify/scripts/bash/$name');
    }
    for (final name in overwritten) {
      say('✓ Overwritten .specify/scripts/bash/$name (--force)');
    }
    for (final name in skipped) {
      say('• Skipped .specify/scripts/bash/$name (already present; use --force to overwrite)');
    }
    if (gitignoreUpdated) {
      say('✓ .gitignore: appended force-include block for .specify/scripts');
    }

    return Future.value(
      SpeckitEmitResult(
        created: created,
        skipped: skipped,
        overwritten: overwritten,
        gitignoreUpdated: gitignoreUpdated,
        gitignorePath: gitignorePath,
      ),
    );
  }

  /// True when [content] carries a rule that would ignore the emitted
  /// helpers (checked per line, honoring negations and comments).
  bool _needsForceInclude(String content) {
    var needed = false;
    for (final raw in content.split('\\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      var rule = line;
      var negated = false;
      if (rule.startsWith('!')) {
        negated = true;
        rule = rule.substring(1);
      }
      if (_excludingRules.contains(rule)) {
        needed = !negated;
      }
    }
    return needed;
  }

  /// Appends the force-include block (last match wins in gitignore
  /// semantics). Idempotent: a marker hit is a no-op.
  void _appendForceInclude(File gitignore) {
    final existing = gitignore.readAsStringSync();
    if (existing.contains(gitignoreMarker)) return;
    final sb = StringBuffer(existing);
    if (!existing.endsWith('\\n')) sb.writeln();
    sb
      ..writeln(gitignoreMarker)
      ..writeln('!.specify/scripts')
      ..writeln('!.specify/scripts/**');
    gitignore.writeAsStringSync(sb.toString());
  }
}

'''

consts = []
for name in SCRIPTS:
    content = (REPO / ".specify/scripts/bash" / name).read_text()
    assert "'''" not in content, f"{name} contains triple quotes"
    consts.append(f"/// Byte-identical embed of `.specify/scripts/bash/{name}`\n"
                  f"const String {names[name]} = r'''{content}''';\n")

out = header + writer + "\n".join(consts)
dest = REPO / "lib/src/commands/speckit_scaffolding.dart"
dest.write_text(out)
print(f"wrote {dest} ({len(out)} chars)")

# byte-identity sanity check: strip the constant back out and compare
import re
for name in SCRIPTS:
    m = re.search(r"const String " + names[name] + r" = r'''(.*?)''';", out, re.S)
    embedded = m.group(1)
    original = (REPO / ".specify/scripts/bash" / name).read_text()
    print(f"  {name}: byte-identical={embedded == original}")
