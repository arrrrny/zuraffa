/// `ReplayPaths` — path re-anchoring for machine-absolute recorded history
/// (spec 0806-zfa-replay, issue #806's Done-when completion).
///
/// A real recorded history embeds the RECORDING machine's filesystem
/// everywhere the writers join a project root: `artifacts.json`'s
/// `test_path` / `subject_path` / `runnable_test_name` carry the canonical
/// `<root>/./<rel>` anchor form, the runner's substituted display commands
/// carry the same form, and the make pipeline's gen steps carry the
/// machine-absolute entrypoint pair `<recorded dart> <recorded zfa.dart>`
/// (`examples/todo_tdd`'s cycle-log is the reference shape). Replayed on any
/// other machine — including a fresh clone at the standard location — those
/// paths never resolve: integrity fails `red-missing-test-artifact`, gen
/// steps cannot spawn, and the sandbox's copied registry points outside the
/// sandbox so `tdd wire` / `tdd func` refuse to run.
///
/// This service re-anchors them:
///  - [detectRecordedRoot] derives the recorded project root from the
///    history's `- test:` anchor markers (all markers MUST agree; zero or
///    conflicting anchors disable re-anchoring entirely — 066 behavior).
///  - [resolveTestPath] resolves a recorded test path for the integrity
///    existence check: a locally-missing anchored path resolves against the
///    local project root; a locally-existing path always wins
///    (same-machine first).
///  - [reAnchorCommand] strips every `<root>/./` occurrence from a command
///    so it executes sandbox-relative (cwd = sandbox) — the recorded root
///    never survives into a spawned process argument.
///  - [reAnchorEntrypoint] re-resolves a gen step's leading entrypoint pair
///    when locally broken: an explicit `--zfa-bin` replaces any zfa
///    entrypoint form; otherwise a missing recorded dart re-resolves to the
///    running dart and a missing zfa script to the running CLI's
///    entrypoint. A fully resolvable recorded pair runs as recorded
///    (determinism); an unresolvable one is left as recorded so the spawn
///    fails honestly as a runner-error.
///
/// Pure functions throughout; [reAnchorEntrypoint] takes an injectable
/// `exists` predicate and platform seams so tests never depend on the host
/// filesystem layout.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

class ReplayPaths {
  const ReplayPaths._();

  /// The canonical recorded-path anchor form: `<root>/./<rel>` — how
  /// `artifacts.json` and the runner's display commands join a project
  /// root to a relative path.
  static final RegExp _anchorPattern = RegExp(r'^(/.*?)\/\./(\S+)$');

  /// The entrypoint pair a make-pipeline gen step records on the recording
  /// machine: `<abs dart> <abs zfa.dart> args…` (only when the first token
  /// is dart-ish AND the second is a zfa entrypoint script).
  static final RegExp _zfaScriptPattern = RegExp(
    r'^(.*[/])?(zfa|zuraffa)\.dart$',
  );

  /// Derive the recorded project root from the history's recorded paths.
  ///
  /// Every `<root>/./<rel>` anchored path contributes its `<root>`; all
  /// contributions MUST agree. Zero anchors, null/relative inputs, or
  /// conflicting roots return null — re-anchoring is then disabled and
  /// replay behaves exactly as spec 066 defined it.
  static String? detectRecordedRoot(Iterable<String?> recordedPaths) {
    String? root;
    for (final path in recordedPaths) {
      if (path == null || path.isEmpty) continue;
      final match = _anchorPattern.firstMatch(path);
      if (match == null) continue;
      final candidate = match.group(1)!;
      if (root == null) {
        root = candidate;
      } else if (root != candidate) {
        return null; // Conflicting anchors — never guess.
      }
    }
    return root;
  }

  /// Resolve a recorded test path for the integrity existence check.
  ///
  /// Resolution order:
  ///   1. A path that exists locally as recorded (absolute or
  ///      project-relative) wins — same-machine replay stays bit-exact.
  ///   2. A locally-missing absolute path anchored at [recordedRoot]
  ///      re-anchors: `<root>/./<rel>` → `<projectRoot>/<rel>`.
  ///   3. Anything else is returned unchanged (the caller reports the
  ///      missing artifact against the recorded path — the fact).
  static String resolveTestPath(
    String testPath, {
    String? recordedRoot,
    required String projectRoot,
  }) {
    if (File(testPath).existsSync()) return testPath;
    if (recordedRoot == null || recordedRoot.isEmpty) return testPath;
    final match = _anchorPattern.firstMatch(testPath);
    if (match == null) return testPath;
    if (match.group(1) != recordedRoot) return testPath;
    // Containment: a `..`-bearing tail would resolve outside the project
    // (and, re-anchored, outside the sandbox). Leave it un-anchored so
    // integrity reports the artifact missing instead of probing
    // somewhere else on disk.
    final rel = p.normalize(match.group(2)!);
    if (rel == '..' || rel.startsWith('../')) return testPath;
    return p.join(projectRoot, rel);
  }

  /// Strip every `<recordedRoot>/./` occurrence from [command], leaving the
  /// project-relative tail. Commands execute with cwd = the sandbox root,
  /// so a stripped path resolves inside the sandbox — the recorded root
  /// never survives into a spawned process argument. A null root leaves
  /// the command unchanged. Only the canonical `/./` marker form is
  /// evidence: a bare recorded-root prefix (no marker) is left alone.
  static String reAnchorCommand(String command, {String? recordedRoot}) {
    if (recordedRoot == null || recordedRoot.isEmpty) return command;
    // Same containment rule as [resolveTestPath]: normalize the tail and
    // keep `..`-bearing ones verbatim — the spawned command then fails
    // honestly inside the sandbox instead of writing outside it.
    final escaped = RegExp.escape(recordedRoot);
    return command.replaceAllMapped(RegExp('$escaped/\\./(\\S+)'), (m) {
      final rel = p.normalize(m.group(1)!);
      return (rel == '..' || rel.startsWith('../')) ? m.group(0)! : rel;
    });
  }

  /// Re-resolve a gen step's entrypoint pair when locally broken.
  ///
  /// [zfaBin], when provided, takes precedence over ANY zfa entrypoint
  /// form: a bare `zfa` prefix (the 066 contract, unchanged) or the
  /// machine-absolute pair (`<dart> <zfa.dart>` — both tokens dropped, the
  /// recorded args kept).
  ///
  /// Without `--zfa-bin`, a pair whose recorded dart binary or zfa script
  /// does not exist locally ([exists]) re-resolves the missing token:
  /// dart → [resolvedDart] (default: the running CLI's
  /// `Platform.resolvedExecutable`), zfa → [runningScript] (the running
  /// CLI's entrypoint; null leaves the recorded script as-is so the spawn
  /// fails honestly). A fully resolvable recorded pair runs as recorded —
  /// determinism preserved for same-machine replay.
  static String reAnchorEntrypoint(
    String command, {
    String? zfaBin,
    String? resolvedDart,
    String? runningScript,
    bool Function(String path)? exists,
  }) {
    final existsLocally = exists ?? (path) => File(path).existsSync();
    final tokens = command.split(RegExp(r'\s+'));
    if (tokens.isEmpty) return command;

    // The 066 contract: a bare `zfa` prefix resolves through --zfa-bin.
    final isBareZfa = tokens.first == 'zfa';
    if (zfaBin != null && zfaBin.isNotEmpty && isBareZfa) {
      return [zfaBin, ...tokens.skip(1)].join(' ');
    }

    // The 0806 pair form: `<dart-ish> <zfa-ish> args…`.
    final isPair =
        tokens.length >= 2 && _isDartToken(tokens[0]) && _isZfaToken(tokens[1]);
    if (!isPair) return command;

    if (zfaBin != null && zfaBin.isNotEmpty) {
      // Precedence: the explicit override replaces the whole pair.
      return [zfaBin, ...tokens.skip(2)].join(' ');
    }

    final recordedDart = tokens[0];
    final recordedZfa = tokens[1];
    var newDart = recordedDart;
    var newZfa = recordedZfa;
    if (!_tokenResolvable(recordedDart, existsLocally)) {
      final replacement = resolvedDart ?? Platform.resolvedExecutable;
      if (replacement.isNotEmpty) newDart = replacement;
    }
    if (!_tokenResolvable(recordedZfa, existsLocally)) {
      // Without a running entrypoint to fall back on, keep the recorded
      // script — the spawn fails as a runner-error, never a silent pass.
      if (runningScript != null && runningScript.isNotEmpty) {
        newZfa = runningScript;
      }
    }
    if (newDart == recordedDart && newZfa == recordedZfa) return command;
    return [newDart, newZfa, ...tokens.skip(2)].join(' ');
  }

  /// A dart-ish first token: the bare `dart` on PATH or an absolute path
  /// whose basename is `dart`.
  static bool _isDartToken(String token) =>
      token == 'dart' || p.basename(token) == 'dart';

  /// A zfa-ish second token: bare `zfa` or a path ending in
  /// `zfa.dart` / `zuraffa.dart`.
  static bool _isZfaToken(String token) =>
      token == 'zfa' || _zfaScriptPattern.hasMatch(token);

  /// A token is runnable as recorded when it is bare (PATH lookup —
  /// replay trusts PATH, exactly like 066's bare-`zfa` contract) or exists
  /// locally as a file.
  static bool _tokenResolvable(
    String token,
    bool Function(String path) existsLocally,
  ) => !token.contains('/') || existsLocally(token);
}
