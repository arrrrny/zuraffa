/// Kernel-cache housekeeping shared by the TDD driving commands
/// (`tdd refactor` and `tdd run`) — spec 1333 FR-2; issue #1507; spec 1520
/// FR-5/FR-7.
///
/// Lives in the plugin's `services/` layer (not on either command) because
/// the sweep is a shared contract between the two commands, not a
/// refactor-specific helper (issue #1507 review finding F4).
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'scratch_tmpdir.dart';

/// The janitor's age floor (spec 1520 FR-5): a `dart_test.kernel.*` entry
/// younger than this is NEVER swept, even when its mtime predates the
/// command start — an entry written minutes ago may belong to a concurrent
/// runner (or one that just crashed and is about to be re-read); only
/// genuinely old garbage is reclaimed.
const Duration defaultKernelAgeGuard = Duration(hours: 1);

/// Clear the dart test incremental kernel cache (spec 1333 FR-2; issue
/// #1507; spec 1520): the project's `.dart_tool/test/` directory and stale
/// shared temp `dart_test.kernel.*` entries — BOTH files and directories.
/// The leaked entries are per-invocation DIRECTORIES full of dill files,
/// so the pre-#1507 `entity is File` match never fired (dead code) and a
/// long TDD loop leaked 51 GB in ~80 minutes; directory entries are
/// deleted recursively. Top-level `zfa-*` scratch directories (spec 1520
/// FR-1) are swept here too, so a scratch orphaned by a killed run is
/// reclaimed instead of accumulating forever.
///
/// The temp sweep covers the ambient temp root (TMPDIR/TEMP/TMP, else
/// `Directory.systemTemp`) AND the configured scratch root
/// (`ZFA_TMPDIR` / `.zfa.json` `tdd.tmpDir`, spec 1520 FR-7) when one is
/// set — deduped, both under the same guard stack. With spec 1520's
/// per-run scratch the ambient root only holds HISTORICAL leaks (live runs
/// write inside their own scratch, deleted at run end), so the sweep is
/// the mop for pre-1520 garbage, not the isolation mechanism.
///
/// Four guards keep live runners safe:
///
/// 1. Issue #1507 commandStartedAt guard — entries created or updated
///    after [commandStartedAt] may belong to a concurrent runner and are
///    left untouched.
/// 2. Spec 1520 age floor — entries younger than [ageGuard]
///    (default [defaultKernelAgeGuard], ~1 hour) are left untouched even
///    when their mtime predates the command start: an entry written
///    minutes ago by a now-crashed agent may still be referenced.
/// 3. Liveness guard — a kernel entry whose path appears in ANY live
///    process's argv (the dart test runner's own frontend-server child
///    holds `--output-dill=<tmp>/dart_test.kernel.<rand>/output.dill` for
///    the whole invocation) is skipped; a `zfa-*` scratch dir is skipped
///    when any live kernel dir lives inside it. Without it, sweeping at
///    cycle start inside a process that is itself nested under a live
///    `dart test` (the repo's own in-process test fleet) deletes the outer
///    runner's kernel mid-run and its loader crashes at close with a
///    PathNotFoundException copying the incremental dill back. The probe
///    reads `/proc/<pid>/cmdline` on Linux and `ps -ww -Ao pid=,args=` on
///    macOS; on any other platform it degrades to the mtime guards alone.
/// 4. Project-cycle ownership guard (issue #1507 review finding CR-1) —
///    `.dart_tool/test/` is shared by every cycle in a project, so it is
///    only deleted when no other live TDD cycle owns the project (see
///    [_foreignCycleActive]). The kernel entries above stay protected by
///    the stricter per-entry guards, so they are swept regardless.
///
/// [environment] (default `Platform.environment`) and [now] (default the
/// sweep instant) are injectable so fast-tier tests can drive the guard
/// stack hermetically — no shared-user-TMPDIR state is ever touched.
/// [liveKernelDirs] overrides the liveness probe the same way (default: the
/// real process scan).
///
/// Best-effort overall: a clear failure prints a note and never crashes
/// the command; the caller simply re-runs and the classifier grades the
/// next attempt from its own transcript. When anything was cleared, one
/// reclaim line is printed:
/// `cleared N stale kernel entr(ies), freed X MB`.
Future<void> clearDartTestKernelCache(
  String projectRoot, {
  required DateTime commandStartedAt,
  Map<String, String>? environment,
  DateTime? now,
  Duration ageGuard = defaultKernelAgeGuard,
  Set<String>? liveKernelDirs,
}) async {
  var cleared = 0;
  var freedBytes = 0;
  final liveDirs = liveKernelDirs == null
      ? _liveKernelDirRefs()
      : liveKernelDirs.map(p.canonicalize).toSet();
  // A foreign live cycle owns this project's shared test cache — leave it
  // alone (finding CR-1). Read BEFORE marking ourselves so a live owner's
  // marker is never overwritten.
  final foreignCycle = _foreignCycleActive(projectRoot);
  _markCycleActive(projectRoot);

  try {
    final cacheDir = Directory(p.join(projectRoot, '.dart_tool', 'test'));
    if (await cacheDir.exists()) {
      if (foreignCycle) {
        print(
          '   kernel cache: another live tdd cycle owns this project — '
          'project-local .dart_tool/test/ left untouched',
        );
      } else {
        freedBytes += await _entrySize(cacheDir);
        await cacheDir.delete(recursive: true);
        cleared++;
      }
    }
  } catch (e) {
    print('   kernel cache clear (project .dart_tool/test/) failed: $e');
  }

  // Spec 1520: the temp sweep runs over BOTH the ambient temp root and the
  // configured scratch root, deduped — every root under the full guard
  // stack (liveness, commandStartedAt, age floor). The configured root is
  // resolved ONCE: two calls could read different `.zfa.json` contents
  // (and the `!`-asserted second one could throw on a mid-sweep null).
  final env = environment ?? Platform.environment;
  final effectiveNow = now ?? DateTime.now();
  final ageFloor = effectiveNow.subtract(ageGuard);
  final configured = scratchConfiguredRoot(projectRoot, environment: env);
  final roots = <String>{
    p.canonicalize(scratchEffectiveTempRoot(env)),
    if (configured != null) p.canonicalize(configured),
  };
  for (final rootPath in roots) {
    final swept = await _sweepTempKernelEntries(
      rootPath,
      commandStartedAt: commandStartedAt,
      ageFloor: ageFloor,
      liveKernelDirs: liveDirs,
    );
    cleared += swept.$1;
    freedBytes += swept.$2;
  }
  if (cleared > 0) {
    print(
      '   cleared $cleared stale kernel entr(ies), '
      'freed ${(freedBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
    );
  }
}

/// Sweep ONE temp root's top-level kernel entries under the full guard
/// stack: `dart_test.kernel.*` files and directories (#1507's leaks) AND
/// `zfa-*` scratch directories orphaned by a run that died without its
/// `finally` (spec 1520 FR-5 — the sweep must not seal a leak class it
/// used to mop up, or #1507's unbounded growth returns through the
/// scratch). Returns `(cleared, freedBytes)` — best-effort: a root that
/// does not exist sweeps to zero, an entry pinned by a concurrent runner
/// (or deleted mid-walk) is skipped.
Future<(int, int)> _sweepTempKernelEntries(
  String rootPath, {
  required DateTime commandStartedAt,
  required DateTime ageFloor,
  required Set<String> liveKernelDirs,
}) async {
  var cleared = 0;
  var freedBytes = 0;
  try {
    final root = Directory(rootPath);
    if (!await root.exists()) return (cleared, freedBytes);
    await for (final entity in root.list()) {
      final base = p.basename(entity.path);
      final isKernel = base.startsWith('dart_test.kernel.');
      // A scratch dir left behind by a run that never reached its
      // `finally` is sealed from the #1507 sweep by its `zfa-` prefix —
      // matched explicitly so crash debris is still reclaimed.
      final isScratch =
          !isKernel &&
          entity is Directory &&
          base.startsWith(defaultScratchPrefix);
      if (!isKernel && !isScratch) continue;
      // Issue #1507: the leaked entries are DIRECTORIES too — match
      // both shapes and delete directories recursively.
      try {
        final canonical = p.canonicalize(entity.path);
        // A live dart test runner's frontend-server child references its
        // kernel in argv for the whole invocation. For a `zfa-*` scratch
        // that reference is `<scratch>/dart_test.kernel.<rand>/...`, so
        // liveness for a scratch means "any live kernel dir lives
        // inside it" — deleting it would crash that runner's loader at
        // close.
        final live = isScratch
            ? liveKernelDirs.any((kernel) => p.isWithin(canonical, kernel))
            : liveKernelDirs.contains(canonical);
        if (live) {
          continue;
        }
        // Note: `lastModified()` is an instance method on File only —
        // the pre-#1507 code reached it through type promotion and
        // could never stat a directory. FileStat.modified works for
        // both shapes.
        final modifiedAt = (await entity.stat()).modified;
        if (!modifiedAt.isBefore(commandStartedAt)) {
          // An entry created or updated during this command may be
          // pinned by a concurrent runner — skipped; the next suite
          // run re-derives it. (The #1507 guard — spec 1520 leaves it
          // authoritative over the age floor: B12.)
          continue;
        }
        if (!modifiedAt.isBefore(ageFloor)) {
          // Spec 1520 age floor (FR-5): the entry predates the command
          // start but is YOUNGER than the age guard — it may belong to
          // a concurrent runner that started before this one, or to a
          // crashed run whose kernel is about to be re-read. Never
          // garbage; left untouched. (B10.)
          continue;
        }
        freedBytes += await _entrySize(entity);
        await (entity is Directory
            ? entity.delete(recursive: true)
            : entity.delete());
        cleared++;
      } catch (_) {
        // A kernel entry pinned by a concurrent runner is skipped —
        // the next suite run re-derives it.
      }
    }
  } catch (e) {
    print('   kernel cache clear ($rootPath) failed: $e');
  }
  return (cleared, freedBytes);
}

/// Best-effort byte total of a kernel cache entry (a file, or a directory
/// tree of dill files). An entry that vanishes mid-walk only undercounts
/// the reported size — the delete still runs.
Future<int> _entrySize(FileSystemEntity entity) async {
  if (entity is File) {
    try {
      return await entity.length();
    } catch (_) {
      // The file vanished between listing and stat — undercount, delete
      // still runs.
      return 0;
    }
  }
  if (entity is! Directory) return 0;
  var total = 0;
  try {
    await for (final child in entity.list(
      recursive: true,
      followLinks: false,
    )) {
      if (child is File) {
        try {
          total += await child.length();
        } catch (_) {
          // The child vanished between listing and stat — the size is
          // undercounted, the delete below still runs.
        }
      }
    }
  } catch (_) {
    // An unreadable subtree reports the bytes counted so far.
  }
  return total;
}

/// Matches the absolute kernel-dir path inside an argv element, with or
/// without a flag prefix: the path starts at a `/` that is not part of a
/// `flag=` value boundary (`/tmp/dart_test.kernel.<rand>`).
final RegExp _kernelDirInArgv = RegExp(r'/[^=\s]*dart_test\.kernel\.[^/\s]*');

/// The set of canonicalized `dart_test.kernel.*` directory paths currently
/// referenced by ANY live process's argv.
///
/// The dart test runner's frontend-server child holds
/// `--output-dill=<tmp>/dart_test.kernel.<rand>/output.dill` for the whole
/// invocation, so a referenced directory is a LIVE runner's kernel — never
/// stale garbage — and must survive the sweep. When the sweep runs inside
/// a process nested under a live `dart test` (the repo's own in-process
/// test fleet), this is what keeps the outer runner's loader from crashing
/// at close; in production it additionally protects a concurrent runner's
/// in-flight kernel beyond what the mtime guard can see.
///
/// Linux reads `/proc/<pid>/cmdline`; macOS shells out to
/// `ps -ww -Ao pid=,args=`. Windows has no portable probe and returns an
/// empty set (the commandStartedAt guard still applies). Any scan error
/// degrades to the empty set — best-effort, never fatal.
Set<String> _liveKernelDirRefs() {
  try {
    if (Platform.isLinux) return _liveKernelDirRefsFromProc();
    if (Platform.isMacOS) return _liveKernelDirRefsFromPs();
    return <String>{};
  } catch (_) {
    return <String>{};
  }
}

/// Linux: every `/proc/<pid>/cmdline` (NUL-separated argv) scanned for a
/// `dart_test.kernel.*` path. An empty set on any error.
Set<String> _liveKernelDirRefsFromProc() {
  final live = <String>{};
  for (final entry in Directory('/proc').listSync()) {
    final pid = int.tryParse(p.basename(entry.path));
    if (pid == null) continue;
    try {
      final bytes = File(p.join(entry.path, 'cmdline')).readAsBytesSync();
      // argv is NUL-separated; one element per argument. The element may
      // be a bare path (`/tmp/dart_test.kernel.X/output.dill`) or carry
      // a flag prefix (`--output-dill=/tmp/dart_test.kernel.X/...`) —
      // match the absolute kernel-dir path inside either shape.
      for (final arg in String.fromCharCodes(bytes).split('\x00')) {
        for (final match in _kernelDirInArgv.allMatches(arg)) {
          live.add(p.canonicalize(match.group(0)!));
        }
      }
    } on FileSystemException {
      // A process that exited (or is not ours to read) mid-scan — skip.
    }
  }
  return live;
}

/// macOS: `ps -ww -Ao pid=,args=` (unlimited width, pid then full argv on
/// one line, e.g. `/bin/sh ./runner.sh --output-dill=/tmp/dart_test...`).
Set<String> _liveKernelDirRefsFromPs() {
  final live = <String>{};
  final result = Process.runSync('ps', ['-ww', '-Ao', 'pid=,args=']);
  if (result.exitCode != 0) return live;
  for (final line in (result.stdout as String).split('\n')) {
    final trimmed = line.trimLeft();
    if (trimmed.isEmpty) continue;
    final space = trimmed.indexOf(' ');
    if (space <= 0) continue;
    // Drop the leading pid; scan the argv tail for a kernel-dir path.
    for (final match in _kernelDirInArgv.allMatches(
      trimmed.substring(space + 1),
    )) {
      live.add(p.canonicalize(match.group(0)!));
    }
  }
  return live;
}

/// The per-project cycle marker: a pid file written at cycle start so a
/// concurrent cycle can tell the project's shared `.dart_tool/test/` is in
/// active use. Keyed by project root and best-effort (an unwritable
/// `.dart_tool/` simply degrades to the pre-#1507 unconditional delete).
String _cycleMarkerPath(String projectRoot) =>
    p.join(projectRoot, '.dart_tool', 'zfa_tdd_cycle.pid');

/// The pid recorded in [projectRoot]'s cycle marker, or null when absent
/// or unreadable.
int? _cycleMarkerOwner(String projectRoot) {
  try {
    final file = File(_cycleMarkerPath(projectRoot));
    if (!file.existsSync()) return null;
    return int.tryParse(file.readAsStringSync().trim());
  } on FileSystemException {
    return null;
  }
}

/// True when a live cycle that is NOT this process or one of its ancestors
/// owns [projectRoot].
///
/// Best-effort and non-blocking: it never waits and never fails — a stale
/// marker (dead pid) or an unreadable one reads as "no owner", so the
/// sweep proceeds. A pid-presence marker (rather than a held file lock) is
/// enough here because `zfa` is a one-shot CLI: the holder's liveness is
/// the hold. False positives can only make the sweep skip the project
/// cache (safe); false negatives fall back to the pre-#1507 behavior.
///
/// Ancestors count as "us": `tdd run` spawns `tdd refactor` step children
/// (`StepRunner` runs `tdd <step> <id>` as a subprocess), and the parent is
/// blocked waiting — it is not actively using the cache, so its marker must
/// not stop the child from clearing its own cache at cycle start.
bool _foreignCycleActive(String projectRoot) {
  final owner = _cycleMarkerOwner(projectRoot);
  return owner != null && _pidAlive(owner) && !_isThisCycle(owner);
}

/// Record this process as the project's active cycle. A live foreign
/// owner's marker is left in place so its protection is never lost while
/// it is still running; an ancestor's marker is adopted (overwritten) so
/// the deepest active cycle owns the project.
void _markCycleActive(String projectRoot) {
  try {
    final owner = _cycleMarkerOwner(projectRoot);
    if (owner != null && _pidAlive(owner) && !_isThisCycle(owner)) return;
    final file = File(_cycleMarkerPath(projectRoot));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('$pid');
  } catch (_) {
    // Best-effort — without a marker the project cache falls back to the
    // pre-#1507 unconditional delete.
  }
}

/// True when [owner] is this process or one of its ancestors.
bool _isThisCycle(int owner) => owner == pid || _isAncestor(owner);

/// Walk this process's ppid chain (bounded) looking for [candidate].
bool _isAncestor(int candidate) {
  var current = pid;
  for (var depth = 0; depth < 64; depth++) {
    final parent = _parentPid(current);
    if (parent == null || parent <= 1) return false;
    if (parent == candidate) return true;
    current = parent;
  }
  return false;
}

/// The parent pid of [pid] — `/proc/<pid>/status` (`PPid:`) on Linux,
/// `ps -o ppid= -p <pid>` on macOS. Null when unknown (Windows, a dead
/// process, or any read error).
int? _parentPid(int pid) {
  try {
    if (Platform.isLinux) {
      final status = File('/proc/$pid/status');
      if (!status.existsSync()) return null;
      for (final line in status.readAsLinesSync()) {
        if (line.startsWith('PPid:')) {
          return int.tryParse(line.substring(5).trim());
        }
      }
      return null;
    }
    if (Platform.isMacOS) {
      final result = Process.runSync('ps', ['-o', 'ppid=', '-p', '$pid']);
      if (result.exitCode != 0) return null;
      return int.tryParse((result.stdout as String).trim());
    }
  } catch (_) {
    // Fall through to null — the guard degrades to pid equality.
  }
  return null;
}

bool _pidAlive(int pid) {
  try {
    return Process.runSync('kill', ['-0', pid.toString()]).exitCode == 0;
  } on Object {
    // Cannot probe (no kill binary, permissions): assume alive so the
    // guard errs on the side of state integrity.
    return true;
  }
}
