/// The slang build stage (issue #1141, criterion 3 — `zfa build`
/// succeeds after generation without manual i18n edits).
///
/// Issue #834's design: "the loop must run `dart run slang` as a build
/// step (like `zfa build`) when translation sources change." The TDD
/// loop scaffolds `lib/i18n/*.i18n.json` translation sources (#965);
/// this stage closes the loop: `zfa build` runs the slang codegen
/// BEFORE build_runner so the generated view's
/// `import 'package:<name>/i18n/strings.g.dart'` resolves at build time.
///
/// Decision grammar (zero drift for non-i18n hosts):
///   - no `lib/i18n/*.i18n.json` sources → [SlangStageDecision.skipped],
///     the stage prints NOTHING and invokes nothing;
///   - sources + `build.yaml` wiring `slang_build_runner` →
///     [SlangStageDecision.deferred] (build_runner owns the codegen);
///   - sources → [SlangStageDecision.run] (`dart run slang`);
///     a failure refuses the build with an actionable fix line naming
///     the dependency — never a silent pass.
library;

import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

enum SlangStageDecision {
  /// No translation sources — the stage is invisible (zero drift).
  skipped,

  /// `build.yaml` wires `slang_build_runner` — build_runner owns the
  /// codegen and the stage defers.
  deferred,

  /// The stage runs `dart run slang` itself.
  run,
}

/// The result of one stage run.
class SlangStageResult {
  const SlangStageResult({
    required this.decision,
    required this.success,
    required this.invoked,
    this.exitCode,
    this.preview,
    this.fixLine,
  });

  final SlangStageDecision decision;
  final bool success;
  final bool invoked;
  final int? exitCode;
  final String? preview;
  final String? fixLine;
}

class SlangBuildStage {
  SlangBuildStage({required this.projectRoot, this.dryRun = false});

  /// The host project root (where `lib/i18n` lives).
  final String projectRoot;

  /// Preview only — never invoke the codegen (a dry-run that mutates the
  /// build cache or runs codegen is not dry).
  final bool dryRun;

  /// Whether [projectRoot] carries slang translation sources
  /// (`lib/i18n/*.i18n.json`).
  @visibleForTesting
  static bool hasTranslationSources({required String projectRoot}) {
    final dir = Directory(p.normalize(p.join(projectRoot, 'lib', 'i18n')));
    if (!dir.existsSync()) return false;
    return dir.listSync().whereType<File>().any(
      (f) => f.path.endsWith('.i18n.json'),
    );
  }

  /// Whether [projectRoot]'s `build.yaml` wires the slang builder (the
  /// `slang_build_runner` package owns codegen in that setup).
  @visibleForTesting
  static bool buildYamlWiresSlangBuilder({required String projectRoot}) {
    final file = File(p.normalize(p.join(projectRoot, 'build.yaml')));
    if (!file.existsSync()) return false;
    final content = file.readAsStringSync();
    return content.contains('slang_build_runner') ||
        content.contains('slang:slang');
  }

  /// The stage's decision from the project state alone (pure — no
  /// process, no writes).
  SlangStageDecision decision() {
    if (!hasTranslationSources(projectRoot: projectRoot)) {
      return SlangStageDecision.skipped;
    }
    if (buildYamlWiresSlangBuilder(projectRoot: projectRoot)) {
      return SlangStageDecision.deferred;
    }
    return SlangStageDecision.run;
  }

  /// The one-line stdout preview of the stage's action, or null when
  /// the stage is skipped (a skipped stage prints NOTHING — zero drift
  /// for non-i18n hosts).
  String? previewLine() => switch (decision()) {
    SlangStageDecision.skipped => null,
    SlangStageDecision.deferred =>
      'slang: build.yaml wires slang_build_runner — build_runner owns '
          'the i18n codegen (issue #834)',
    SlangStageDecision.run =>
      'slang: ${_sourceNames().length} translation source(s) '
          '(${_sourceNames().join(', ')}) — running dart run slang '
          '(issues #834/#1141)',
  };

  /// Runs the stage. In dry-run, reports the decision WITHOUT invoking
  /// anything.
  Future<SlangStageResult> run() async {
    final resolved = decision();
    switch (resolved) {
      case SlangStageDecision.skipped:
        return SlangStageResult(
          decision: resolved,
          success: true,
          invoked: false,
        );
      case SlangStageDecision.deferred:
        print(previewLine());
        return SlangStageResult(
          decision: resolved,
          success: true,
          invoked: false,
        );
      case SlangStageDecision.run:
        if (dryRun) {
          print('🌐 ${previewLine()}');
          print('   (dry-run: codegen not invoked)');
          return SlangStageResult(
            decision: resolved,
            success: true,
            invoked: false,
            preview: _sourceNames().join(', '),
          );
        }
        print('🌐 ${previewLine()}');
        final result = await Process.run('dart', [
          'run',
          'slang',
        ], workingDirectory: projectRoot);
        final stdoutText = result.stdout is String
            ? result.stdout as String
            : '';
        final stderrText = result.stderr is String
            ? result.stderr as String
            : '';
        if (stdoutText.trim().isNotEmpty) print(stdoutText.trim());
        if (stderrText.trim().isNotEmpty) print(stderrText.trim());
        final code = result.exitCode;
        if (code == 0) {
          print('   ✅ slang codegen completed');
          return SlangStageResult(
            decision: resolved,
            success: true,
            invoked: true,
            exitCode: code,
          );
        }
        print(
          '❌ slang codegen failed (exit $code) — the i18n sources '
          '(lib/i18n/*.i18n.json) exist but the slang toolchain did not '
          'run.',
        );
        print(
          '   --> fix: add the slang CLI to the host '
          '(`dart pub add dev:slang`) or wire `slang_build_runner` in '
          'build.yaml so build_runner owns the codegen, then re-run '
          '`zfa build`.',
        );
        return SlangStageResult(
          decision: resolved,
          success: false,
          invoked: true,
          exitCode: code,
          fixLine:
              'slang toolchain unresolvable (exit $code) --> fix: '
              'dart pub add dev:slang (or wire slang_build_runner in '
              'build.yaml), then re-run zfa build',
        );
    }
  }

  List<String> _sourceNames() {
    final dir = Directory(_i18nDir);
    if (!dir.existsSync()) return const [];
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.i18n.json'))
        .map((f) => p.posix.join('lib', 'i18n', p.basename(f.path)))
        .toList()
      ..sort();
  }

  String get _i18nDir => p.normalize(p.join(projectRoot, 'lib', 'i18n'));
}
