/// Shared zfa entrypoint resolution for the TDD commands that spawn the CLI
/// as a sub-process (bug #689).
///
/// `zfa tdd make` resolved its pipeline entrypoint through [PipelineRunner];
/// `zfa tdd refactor` instead hardcoded `dart run bin/zfa.dart build`, but
/// `zfa setup` never creates a project-local `bin/zfa.dart` — it installs the
/// system-level `zfa` (typically `~/.local/bin/zfa`). The refactor build pass
/// therefore failed on every freshly bootstrapped project (exit 255).
///
/// This library extracts the PipelineRunner resolution so every TDD command
/// resolves the SAME way, in the SAME order (spec 047 FR-004 / U11, U12):
///
///   1. An explicit override (`--zfa-bin`) when it points at a real file.
///   2. `Platform.script` when this CLI is running from source — a `file://`
///      URL ending in `/bin/zfa.dart` or `/bin/zuraffa.dart` (invoke via the
///      running dart binary).
///   3. `zfa` on PATH — the system-installed CLI that `zfa setup` provides.
///   4. Fallback: `Platform.resolvedExecutable` + `Platform.script` (handles
///      compiled-snapshot / global-activate / test-kernel contexts).
///
/// An unresolvable entrypoint throws [PipelineResolutionError] (misfire-stop
/// before any step executes, U12).
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// Resolution-stage failure: the zfa entrypoint could not be resolved or is
/// missing on disk. Carries the feature context if known.
class PipelineResolutionError implements Exception {
  PipelineResolutionError(this.message, {this.feature});

  final String message;
  final String? feature;

  @override
  String toString() => message;
}

/// A resolved zfa entrypoint: how to spawn the CLI as a sub-process.
class ResolvedZfaEntrypoint {
  const ResolvedZfaEntrypoint({
    required this.executable,
    this.arguments = const [],
    required this.displayCommand,
  });

  /// The executable to spawn (a dart binary or the zfa executable itself).
  final String executable;

  /// Arguments before the sub-command (e.g. the script path when the CLI
  /// runs from source via `dart <bin/zfa.dart>`).
  final List<String> arguments;

  /// Human/machine-readable command line as recorded in evidence.
  final String displayCommand;

  /// The full command line for [subCommand] (e.g. `build`), with arguments
  /// joined in spawn order.
  String commandFor(String subCommand) {
    final tokens = [executable, ...arguments, subCommand];
    return tokens.map(quoteToken).join(' ');
  }
}

/// Quote a token for a command line that an executor re-tokenizes on
/// whitespace (the executor strips a symmetric wrapping quote pair, not
/// data). Tokens without whitespace pass through untouched.
String quoteToken(String token) {
  if (!RegExp(r'\s').hasMatch(token)) return token;
  return "'$token'";
}

/// Resolve the zfa entrypoint (FR-004 / U11, U12).
///
/// [commandLabel] names the calling command in error messages (e.g.
/// `zfa tdd make`, `zfa tdd refactor`).
///
/// Resolution order:
///   1. [zfaBinOverride] (the `--zfa-bin` flag) when set and the target is
///      an executable file.
///   2. `Platform.script` when this CLI is running from source — a `file://`
///      URL whose path ends in `/bin/zfa.dart` or `/bin/zuraffa.dart`. The
///      entrypoint is `dart <that path>`.
///   3. `zfa` on PATH — verified via a direct lookup of the executable in
///      `PATH` (the system CLI `zfa setup` installs).
///   4. Fallback: `Platform.resolvedExecutable` + `Platform.script` when the
///      script is a `file://` URL with another basename (compiled snapshot /
///      global activate / jit snapshot / test kernel).
///
/// Throws [PipelineResolutionError] when nothing resolves (misfire-stop).
Future<ResolvedZfaEntrypoint> resolveZfaEntrypoint({
  String? zfaBinOverride,
  String? feature,
  String commandLabel = 'zfa tdd make',
}) async {
  // 1. Explicit override.
  if (zfaBinOverride != null && zfaBinOverride.isNotEmpty) {
    final f = File(zfaBinOverride);
    if (!await f.exists()) {
      throw PipelineResolutionError(
        '$commandLabel: --zfa-bin "$zfaBinOverride" does not exist on disk. '
        'Provide a path to a real zfa entrypoint.',
        feature: feature,
      );
    }
    return ResolvedZfaEntrypoint(
      executable: zfaBinOverride,
      displayCommand: zfaBinOverride,
    );
  }

  // 2. Running CLI from source (Platform.script).
  final script = Platform.script;
  if (script.scheme == 'file') {
    final scriptPath = script.toFilePath();
    final base = p.basename(scriptPath);
    // bin/zfa.dart or bin/zuraffa.dart — invoke via the dart binary.
    if (base == 'zfa.dart' || base == 'zuraffa.dart') {
      return ResolvedZfaEntrypoint(
        executable: Platform.resolvedExecutable,
        arguments: [scriptPath],
        displayCommand: '${Platform.resolvedExecutable} $scriptPath',
      );
    }
    // Non-standard basename: fall through to PATH lookup (tier 3), then to
    // the compiled-snapshot fallback (tier 4) if PATH also fails.
  }

  // 3. Resolve the concrete `zfa` executable from PATH without a shell.
  final pathEntrypoint = findExecutableOnPath('zfa');
  if (pathEntrypoint != null) {
    return ResolvedZfaEntrypoint(
      executable: pathEntrypoint,
      displayCommand: pathEntrypoint,
    );
  }

  // 4. Final fallback: Platform.resolvedExecutable + Platform.script.
  //    Catches compiled-snapshot and global-activate scenarios where
  //    Platform.script basename is not zfa.dart/zuraffa.dart.
  if (script.scheme == 'file') {
    final scriptPath = script.toFilePath();
    return ResolvedZfaEntrypoint(
      executable: Platform.resolvedExecutable,
      arguments: [scriptPath],
      displayCommand: '${Platform.resolvedExecutable} $scriptPath',
    );
  }

  throw PipelineResolutionError(
    '$commandLabel: cannot resolve the zfa entrypoint. The command needs '
    'to invoke the zfa CLI as a sub-process, but neither --zfa-bin, '
    'Platform.script (running from source), nor `zfa` on PATH resolved. '
    'Run from inside a checkout of zuraffa, or pass --zfa-bin <path>.',
    feature: feature,
  );
}

/// Find the concrete [name] executable on PATH, or null. Direct filesystem
/// lookup (no shell), checking the executable bit on non-Windows.
String? findExecutableOnPath(String name) {
  final path = Platform.environment['PATH'];
  if (path == null || path.isEmpty) return null;
  final extensions = Platform.isWindows
      ? (Platform.environment['PATHEXT'] ?? '.EXE;.BAT;.CMD')
            .split(';')
            .where((extension) => extension.isNotEmpty)
      : const [''];
  for (final directory in path.split(Platform.isWindows ? ';' : ':')) {
    if (directory.isEmpty) continue;
    for (final extension in extensions) {
      final candidate = File(p.join(directory, '$name$extension'));
      if (!candidate.existsSync()) continue;
      if (Platform.isWindows || (candidate.statSync().mode & 0x49) != 0) {
        return candidate.path;
      }
    }
  }
  return null;
}
