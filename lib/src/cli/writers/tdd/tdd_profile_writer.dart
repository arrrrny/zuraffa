/// `TddProfileWriter` — writes `.specify/memory/tdd-profile.md` for a
/// generated Flutter project.
library;

import 'dart:io';

import '../../../plugins/tdd/models/tdd_profile.dart';

class TddProfileWriter {
  const TddProfileWriter({this.profile = TddProfile.flutter});

  final TddProfile profile;

  /// Write the profile to `.specify/memory/tdd-profile.md`.
  ///
  /// Detection is layered:
  ///   1. **Lenient runner-family check** (existing frontmatter is parsed
  ///      for its `runner:` value, case-insensitively): if the existing
  ///      file's runner is in the same family as the one we're writing,
  ///      it's handled by family, not by bytes. This handles the common
  ///      case where a previous `zfa tdd init` (or a CI detector or a
  ///      manual author) wrote an equally-valid Dart runner such as
  ///      `package:test (^1.24.0)` — accepted as a no-op even though its
  ///      body differs from the preset template (issue #680).
  ///   2. **Exact-content match** (Flutter family, or an existing file
  ///      with no parseable runner): if the existing file's body matches
  ///      what we'd render, it's accepted as a no-op.
  ///   3. **`--force` override**: when the existing file is in the same
  ///      family and content differs, [force] lets the caller clobber
  ///      it instead of throwing.
  ///   4. **Hard conflict**: cross-family runner is rejected with
  ///      [StateError] in BOTH directions — a Flutter runner in a
  ///      Dart-targeting init, AND a Dart runner in a Flutter-targeting
  ///      init (silently keeping the wrong-family profile would leave the
  ///      baseline invoking the wrong test runner); [force] does NOT
  ///      bypass this because changing the test runner is a real
  ///      semantic change.
  ///
  /// When [dryRun] is true the file is not touched and the would-be
  /// path is returned.
  Future<String?> write(
    String projectRoot, {
    bool force = false,
    bool dryRun = false,
  }) async {
    final dir = Directory('$projectRoot/.specify/memory');
    final file = File('${dir.path}/tdd-profile.md');
    final content = _render(profile);

    if (dryRun) {
      return file.path;
    }

    if (await file.exists()) {
      final existing = await file.readAsString();

      // Lenient check: extract the runner from the existing frontmatter
      // (case-insensitively — `Flutter_test` and `flutter_test` are the
      // same runner). If the existing file already uses a Dart runner
      // (non-Flutter) and we're targeting Dart, accept it — it may have
      // been written by a different tool (e.g. a previous `zfa tdd init`
      // run, a CI detector, or a manual author) with a different but
      // equally-valid runner value (e.g. "package:test (^1.24.0)" vs the
      // hardcoded 'dart' literal). The only hard conflicts are
      // cross-family: a Flutter runner in a Dart-targeting init, or a
      // Dart runner in a Flutter-targeting init (issue #680).
      final frontmatterRunner = _extractRunner(existing);
      final runnerFamily = _runnerFamily(frontmatterRunner);
      final writingFamily = isFlutterProfile
          ? _RunnerFamily.flutter
          : _RunnerFamily.dart;

      if (frontmatterRunner.isNotEmpty) {
        if (runnerFamily == _RunnerFamily.flutter &&
            writingFamily == _RunnerFamily.dart) {
          throw StateError(
            'tdd-profile.md already exists with a Flutter runner '
            '("$frontmatterRunner") but `zfa tdd init` is targeting a Dart '
            'project. Delete the file first to re-detect.',
          );
        }
        if (runnerFamily == _RunnerFamily.dart &&
            writingFamily == _RunnerFamily.flutter) {
          throw StateError(
            'tdd-profile.md already exists with a Dart runner '
            '("$frontmatterRunner") but `zfa tdd init` is targeting a '
            'Flutter project. Delete the file first to re-detect.',
          );
        }
        // Same family. A Dart profile is accepted as-is regardless of its
        // body: every Dart runner is equally valid and overwriting an
        // enriched profile with the preset template would lose
        // information (issue #680). A Flutter profile falls through to
        // the exact-content check below.
        if (runnerFamily == _RunnerFamily.dart) {
          return null;
        }
      }

      // Same Flutter family (or an unparseable/missing runner — flavor
      // can't be trusted, so the bytes decide) and content differs:
      // exact-content match is required.
      if (existing.trim() == content.trim()) {
        return null;
      }

      // Same Flutter family but content actually differs. --force lets
      // the caller clobber it; otherwise reject with a clear message.
      if (!force) {
        throw StateError(
          'tdd-profile.md already exists at ${file.path} with different '
          'content; refusing to overwrite. Pass --force to overwrite or '
          'delete the file first if you want to regenerate.',
        );
      }
      // force + different content: fall through and overwrite.
    }

    await dir.create(recursive: true);
    await file.writeAsString(content);
    return file.path;
  }

  bool get isFlutterProfile =>
      profile.runner == 'flutter_test' || profile.runner == 'flutter';

  String _extractRunner(String content) {
    // Match `runner: <value>` in the YAML frontmatter block.
    // Handles both single and double-quoted values.
    final match = RegExp(
      r'''^\s*runner:\s*(?:"([^"]+)"|'([^']+)'|([^\s#]+))\s*$''',
      multiLine: true,
    ).firstMatch(content);
    return (match?.group(1) ?? match?.group(2) ?? match?.group(3) ?? '').trim();
  }

  /// Classifies a runner value into its family (Flutter vs Dart),
  /// case-insensitively so `Flutter_test` / `FLUTTER` land in the Flutter
  /// family instead of sneaking through as "valid Dart runners".
  _RunnerFamily _runnerFamily(String runner) {
    final normalized = runner.toLowerCase();
    return normalized == 'flutter_test' || normalized == 'flutter'
        ? _RunnerFamily.flutter
        : _RunnerFamily.dart;
  }

  String _render(TddProfile p) {
    final platform = isFlutterProfile ? 'Flutter' : 'Dart';
    final runnerHint = isFlutterProfile
        ? '`flutter_test`. Invoked as `flutter test`.'
        : '`dart test`. Invoked as `dart test`.';
    final langNote = isFlutterProfile ? '. Flutter 3.41+ on PATH' : '';
    return '''# TDD Profile — $platform (generated by `zfa setup`)

This profile is read by the `tdd` spec-kit extension.

## Stack

- **Language**: Dart (latest stable)$langNote.
- **Test runner**: $runnerHint
- **Static analysis**: `dart analyze`. Configured via `analysis_options.yaml`.
- **Mutation tool**: opt-in via the `mutation_test` dev_dependency.
- **Coverage**: `${p.resolveCoverage()}` then
  `dart run coverage:format_coverage`.

## Commands

- Single test: `${p.resolveSingle(file: '{file}', name: '{name}')}'
- Whole file: `${p.resolveFile('{file}')}'
- Full suite: `${p.resolveSuite()}'
- Coverage: `${p.resolveCoverage()}'

## Keys (machine-readable)

```yaml
runner: ${p.runner}
single: '${p.single}'
file: '${p.file}'
suite: '${p.suite}'
coverage: '${p.coverage}'
```
''';
  }
}

enum _RunnerFamily { flutter, dart }
