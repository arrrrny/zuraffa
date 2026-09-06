/// Stale-installed-binary detection for the `zfa` CLI (issue #1184).
///
/// The trap: `~/.local/bin/zfa` is a compiled snapshot (see
/// `scripts/rebuild.sh`). After fixing generator source in a zuraffa
/// checkout, every shell `zfa …` invocation kept reproducing the OLD bug
/// because the snapshot predated the fix — and nothing told the operator
/// (the #1159 bug-whole run lost ~an hour to exactly this false repro).
///
/// Mechanism:
/// - `scripts/rebuild.sh` records the source commit next to the installed
///   binary (`<install-dir>/zfa.build_commit`) at build time.
/// - At startup (shell path only, see `CliRunner`) and in `zfa doctor`,
///   the CLI reads that marker, resolves the enclosing zuraffa worktree
///   (nearest pubspec.yaml with `name: zuraffa`), compares its HEAD, and
///   surfaces ONE warning line when the two differ.
///
/// Silence rules — never warn when any input is unknowable:
/// - running from source / under the Dart VM (`dart run bin/zfa.dart`,
///   `dart test`): there is no installed binary to staleness-check;
/// - no build-commit marker (pre-#1184 install): staleness is unprovable;
/// - the working directory is not inside a zuraffa worktree;
/// - the worktree has no resolvable git HEAD (not a repo, or no commits).
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// Marker file name written by `scripts/rebuild.sh` next to the installed
/// `zfa` binary; contains the git commit the binary was built from.
const String zfaBuildCommitMarker = 'zfa.build_commit';

/// Signature for the process spawner used to resolve the worktree HEAD.
/// Injectable so tests stay hermetic.
typedef ZfaStalenessProcessRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> args,
      String? workingDirectory,
    );

/// Why a staleness probe returned no result — used by `zfa doctor` to
/// emit honest skip messages without duplicating probe logic.
enum StalenessSkipReason { sourceRun, noMarker, noCheckout, noHead }

/// The verdict of one staleness probe. [warning] is non-null iff the
/// installed binary's build commit differs from the enclosing zuraffa
/// worktree's HEAD.
class StalenessReport {
  const StalenessReport({
    required this.binaryDir,
    required this.buildCommit,
    required this.checkoutRoot,
    required this.checkoutHead,
  });

  /// Directory holding the running (installed) binary.
  final String binaryDir;

  /// Commit recorded at build time by `scripts/rebuild.sh`.
  final String buildCommit;

  /// Nearest enclosing worktree whose pubspec declares `name: zuraffa`.
  final String checkoutRoot;

  /// `git rev-parse HEAD` of that worktree, when resolvable.
  final String checkoutHead;

  bool get isStale =>
      buildCommit.isNotEmpty &&
      checkoutHead.isNotEmpty &&
      buildCommit != checkoutHead;

  /// The ONE-line operator warning, or null when not stale. Text per the
  /// issue #1184 remediation — the fix is always the same: rebuild.
  String? get warning {
    if (!isStale) return null;
    return '⚠️ installed zfa (${BinaryStaleness.shortCommit(buildCommit)}) is '
        'older than this checkout (${BinaryStaleness.shortCommit(checkoutHead)}) '
        '— run scripts/rebuild.sh';
  }
}

class BinaryStaleness {
  BinaryStaleness({String? binaryDir, ZfaStalenessProcessRunner? processRunner})
    : _explicitBinaryDir = binaryDir,
      _processRunner = processRunner ?? _defaultProcessRunner;

  static Future<ProcessResult> _defaultProcessRunner(
    String executable,
    List<String> args,
    String? workingDirectory,
  ) => Process.run(executable, args, workingDirectory: workingDirectory);

  /// Test seam: when set, simulates "the process IS an installed binary
  /// living in this directory" instead of deriving from the VM.
  final String? _explicitBinaryDir;
  final ZfaStalenessProcessRunner _processRunner;

  /// Executables that mean "we are NOT running a compiled installed zfa":
  /// source runs (`dart run bin/zfa.dart`), `dart test`, and pub-global
  /// snapshots all resolve to the Dart VM, which never carries the
  /// build-commit marker next to it.
  static const _vmExecutables = {
    'dart',
    'dart.exe',
    'dartaotruntime',
    'dartaotruntime.exe',
    'flutter_tester',
  };

  /// Directory of the installed binary, or null when running from source.
  String? get binaryDir {
    if (_explicitBinaryDir != null) return _explicitBinaryDir;
    final exe = Platform.resolvedExecutable;
    final base = p.basename(exe).toLowerCase();
    if (_vmExecutables.contains(base) || base.startsWith('dart')) return null;
    return p.dirname(exe);
  }

  /// The build commit recorded next to the binary at build time, or null
  /// when absent/unreadable/empty (never warn on unprovable input).
  String? readBuildCommit(String? binDir) {
    if (binDir == null) return null;
    try {
      final file = File(p.join(binDir, zfaBuildCommitMarker));
      if (!file.existsSync()) return null;
      final commit = file.readAsStringSync().trim();
      return commit.isEmpty ? null : commit;
    } on IOException {
      return null;
    }
  }

  /// Nearest enclosing directory whose `pubspec.yaml` declares
  /// `name: zuraffa` — i.e. the zuraffa source worktree the CLI is being
  /// run against — or null when there is none.
  static String? findZuraffaCheckout(String startDir) {
    var dir = Directory(startDir);
    while (true) {
      final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
      if (pubspec.existsSync()) {
        try {
          if (_isZuraffaPubspec(pubspec.readAsStringSync())) return dir.path;
        } on IOException {
          // Unreadable pubspec — keep walking up.
        }
      }
      final parentPath = dir.parent.path;
      if (parentPath == dir.path) return null; // filesystem root
      dir = Directory(parentPath);
    }
  }

  static final RegExp _zuraffaName = RegExp(
    r'^name:\s*zuraffa\s*$',
    multiLine: true,
  );

  static bool _isZuraffaPubspec(String content) =>
      _zuraffaName.hasMatch(content);

  /// `git rev-parse HEAD` in [checkoutDir], or null when unresolvable
  /// (not a worktree, no commits, git missing). All failures are silent:
  /// the warning is advisory and must never break the invocation.
  Future<String?> checkoutHead(String checkoutDir) async {
    try {
      final result = await _processRunner('git', [
        'rev-parse',
        'HEAD',
      ], checkoutDir);
      if (result.exitCode != 0) return null;
      final head = (result.stdout as String? ?? '').trim();
      return head.isEmpty ? null : head;
    } catch (_) {
      return null;
    }
  }

  /// Probe the running process for staleness against [cwd] (the effective
  /// working directory, i.e. the `-C` target when one was supplied).
  /// Returns null whenever any input is unknowable — see the silence rules
  /// in the library doc.
  Future<StalenessReport?> probe({String? cwd}) async {
    final binDir = binaryDir;
    if (binDir == null) return null; // source run — nothing installed
    final buildCommit = readBuildCommit(binDir);
    if (buildCommit == null) return null; // no marker — unprovable
    final checkout = findZuraffaCheckout(cwd ?? Directory.current.path);
    if (checkout == null) return null; // not inside a zuraffa worktree
    final head = await checkoutHead(checkout);
    if (head == null) return null; // no resolvable HEAD
    return StalenessReport(
      binaryDir: binDir,
      buildCommit: buildCommit,
      checkoutRoot: checkout,
      checkoutHead: head,
    );
  }

  /// The warning for [cwd], or null when not provably stale. This is the
  /// seam `CliRunner` calls before dispatching any shell invocation.
  Future<String?> warningFor({String? cwd}) async =>
      (await probe(cwd: cwd))?.warning;

  /// Short form for operator-facing messages (git's terminal convention).
  static String shortCommit(String commit) =>
      commit.length <= 12 ? commit : commit.substring(0, 12);

  /// Like [probe], but also reports WHY the probe returned null.
  /// Used by `zfa doctor` to emit honest skip messages.
  Future<StalenessProbeResult> probeDetailed({String? cwd}) async {
    final binDir = binaryDir;
    if (binDir == null) {
      return const StalenessProbeResult(
        skipReason: StalenessSkipReason.sourceRun,
      );
    }
    final buildCommit = readBuildCommit(binDir);
    if (buildCommit == null) {
      return const StalenessProbeResult(
        skipReason: StalenessSkipReason.noMarker,
      );
    }
    final checkout = BinaryStaleness.findZuraffaCheckout(
      cwd ?? Directory.current.path,
    );
    if (checkout == null) {
      return const StalenessProbeResult(
        skipReason: StalenessSkipReason.noCheckout,
      );
    }
    final head = await checkoutHead(checkout);
    if (head == null) {
      return const StalenessProbeResult(skipReason: StalenessSkipReason.noHead);
    }
    return StalenessProbeResult(
      report: StalenessReport(
        binaryDir: binDir,
        buildCommit: buildCommit,
        checkoutRoot: checkout,
        checkoutHead: head,
      ),
    );
  }
}

/// Result of a detailed staleness probe — carries either a report or a
/// skip reason.
class StalenessProbeResult {
  const StalenessProbeResult({this.report, this.skipReason});

  final StalenessReport? report;
  final StalenessSkipReason? skipReason;

  bool get isSkipped => report == null && skipReason != null;
}
