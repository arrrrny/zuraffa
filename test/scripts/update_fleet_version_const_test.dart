// Behavioural guard for the version-constant helpers in
// scripts/update_fleet.sh (issue #2095, review of #2096).
//
// `lib/src/version.dart` is the RUNNING zuraffa version:
// `ZuraffaEngine.registerPackage` feeds it to `PackageCompatibility.check` as
// `appVersion`, so a fleet bump that moves `pubspec.yaml` and not the constant
// ships a false "generated against a newer zuraffa" warning to every consumer
// (7.3.0/7.3.6/7.4.2/7.5.0 all shipped `const version = '7.2.0'`).
//
// The helpers that stamp and check it lived only in a shell script, and the
// PR that added them carried a throwaway harness as its evidence — nothing in
// CI noticed if the call was deleted or the `sed` shape drifted. This suite is
// that evidence, kept:
//
//   stamp -> idempotent -> drift reported -> no-op without the file
//
// plus the two shapes that used to disarm the helpers with no signal at all:
// a double-quoted constant (neither stamped nor reported) and a declaration
// the helpers cannot read (an empty parse read as "no drift", so `check`
// returned 0 and the Dart test still passed because it compares the value).
//
// `update_fleet.sh` needs bash >= 4 (macOS ships 3.2), so the suite extracts
// the helper definitions from the real script and drives them with whatever
// bash is on PATH over a `mkdtemp` fixture — no fleet checkout, no network.

import 'dart:io';

import 'package:test/test.dart';

import '../helpers/project_root.dart';

/// The helpers this suite drives, in the order they appear in the script.
const _helperNames = <String>[
  'version_const_decl',
  'version_const_value',
  'update_version_const',
  'check_version_const',
];

/// Extracts `name() { … }` blocks from [script]; a helper ends at the first
/// line that is exactly `}` in column 0, which is how this file formats them.
String _helpersOf(String script) {
  final lines = script.split('\n');
  final out = <String>[];
  for (final name in _helperNames) {
    final start = lines.indexWhere((l) => l.startsWith('$name() {'));
    expect(
      start,
      isNot(-1),
      reason: 'scripts/update_fleet.sh must define $name()',
    );
    var end = -1;
    for (var i = start + 1; i < lines.length; i++) {
      if (lines[i] == '}') {
        end = i;
        break;
      }
    }
    expect(
      end,
      isNot(-1),
      reason: 'unterminated $name() in scripts/update_fleet.sh',
    );
    out.addAll(lines.sublist(start, end + 1));
  }
  return out.join('\n');
}

/// A harness that sources the extracted helpers and runs one of them.
///
/// `set -uo pipefail` (no `-e`): the contract under test is the exit code a
/// caller reads, and the callers count a failure instead of dying on it.
String _harnessOf(String helpers) =>
    '''
#!/usr/bin/env bash
set -uo pipefail
VERSION="\$1"
ACTION="\$2"
REPO_ROOT="\$3"
GREEN=''; BLUE=''; YELLOW=''; RED=''; NC=''
$helpers
case "\$ACTION" in
  stamp) update_version_const "\$REPO_ROOT" ;;
  check) check_version_const "\$REPO_ROOT" ;;
  *) echo "unknown action: \$ACTION" >&2; exit 2 ;;
esac
''';

class _Run {
  _Run(this.exitCode, this.output);

  final int exitCode;
  final String output;

  @override
  String toString() => 'exit $exitCode\n$output';
}

void main() {
  late Directory work;
  late String harness;
  var repoCount = 0;

  setUpAll(() async {
    final root = await findProjectRoot();
    final script = File('$root/scripts/update_fleet.sh');
    expect(
      script.existsSync(),
      isTrue,
      reason: 'scripts/update_fleet.sh must exist at the repo root ($root)',
    );
    harness = _harnessOf(_helpersOf(script.readAsStringSync()));
    work = await Directory.systemTemp.createTemp('zf-version-const-');
  });

  tearDownAll(() {
    if (work.existsSync()) work.deleteSync(recursive: true);
  });

  /// A throwaway fleet repo. [versionConst] `null` means no constant at all.
  Directory repo({String? versionConst}) {
    final root = Directory('${work.path}/repo-${repoCount++}');
    root.createSync();
    if (versionConst != null) {
      final file = File('${root.path}/lib/src/version.dart');
      file.createSync(recursive: true);
      file.writeAsStringSync(versionConst);
    }
    return root;
  }

  Future<_Run> run(String action, Directory repoRoot) async {
    final script = File('${work.path}/harness-$action.sh')
      ..writeAsStringSync(harness);
    final result = await Process.run('bash', [
      script.path,
      '9.9.9',
      action,
      repoRoot.path,
    ]);
    return _Run(result.exitCode, '${result.stdout}${result.stderr}');
  }

  File constOf(Directory repoRoot) =>
      File('${repoRoot.path}/lib/src/version.dart');

  test('stamps a single-quoted constant and leaves no temp file', () async {
    final repoRoot = repo(versionConst: "const version = '7.2.0';\n");

    final result = await run('stamp', repoRoot);

    expect(result.exitCode, 0, reason: result.toString());
    expect(constOf(repoRoot).readAsStringSync(), "const version = '9.9.9';\n");
    expect(
      File('${constOf(repoRoot).path}.tmp').existsSync(),
      isFalse,
      reason: 'a stamp must not leave ${constOf(repoRoot).path}.tmp behind',
    );
  });

  test('is idempotent — a second stamp changes nothing', () async {
    final repoRoot = repo(versionConst: "const version = '7.2.0';\n");

    expect((await run('stamp', repoRoot)).exitCode, 0);
    final once = constOf(repoRoot).readAsStringSync();
    expect((await run('stamp', repoRoot)).exitCode, 0);

    expect(constOf(repoRoot).readAsStringSync(), once);
  });

  test('preserves a trailing comment on the constant', () async {
    final repoRoot = repo(versionConst: "const version = '7.2.0'; // pinned\n");

    final result = await run('stamp', repoRoot);

    expect(result.exitCode, 0, reason: result.toString());
    expect(
      constOf(repoRoot).readAsStringSync(),
      "const version = '9.9.9'; // pinned\n",
    );
  });

  test(
    'reports drift in check mode, and is clean when the value matches',
    () async {
      final drifted = repo(versionConst: "const version = '7.2.0';\n");
      final bad = await run('check', drifted);
      expect(bad.exitCode, 1, reason: bad.toString());
      expect(
        bad.output,
        contains('version drift'),
        reason: 'the drift line is what a fleet bump reads: ${bad.output}',
      );

      final aligned = repo(versionConst: "const version = '9.9.9';\n");
      final ok = await run('check', aligned);
      expect(ok.exitCode, 0, reason: ok.toString());
    },
  );

  test('no-ops for a repo with no lib/src/version.dart', () async {
    final repoRoot = repo();

    expect((await run('stamp', repoRoot)).exitCode, 0);
    expect(
      constOf(repoRoot).existsSync(),
      isFalse,
      reason: 'a repo without the file must not gain one',
    );

    expect((await run('check', repoRoot)).exitCode, 0);
  });

  test(
    'stamps and checks a double-quoted constant instead of ignoring it',
    () async {
      // The disarm case: both helpers used to key on `^const version = '`
      // only, so this file was neither stamped nor reported and #2095 could
      // return with no signal anywhere.
      final repoRoot = repo(versionConst: 'const version = "7.2.0";\n');

      final before = await run('check', repoRoot);
      expect(before.exitCode, 1, reason: before.toString());
      expect(before.output, contains('7.2.0'), reason: before.output);

      final stamped = await run('stamp', repoRoot);
      expect(stamped.exitCode, 0, reason: stamped.toString());
      expect(
        constOf(repoRoot).readAsStringSync(),
        "const version = '9.9.9';\n",
      );

      expect((await run('check', repoRoot)).exitCode, 0);
    },
  );

  test(
    'reports a declaration it cannot read instead of silently passing',
    () async {
      // An unparseable declaration used to make `check` return 0 — the worst
      // outcome: the drift is invisible and the Dart value test still passes.
      final repoRoot = repo(versionConst: "const String version = '7.2.0';\n");

      final checked = await run('check', repoRoot);
      expect(checked.exitCode, 1, reason: checked.toString());
      expect(
        checked.output,
        contains('cannot read'),
        reason: 'the reason matters: ${checked.output}',
      );

      // Apply mode cannot guess the shape either: it says so and leaves the
      // file alone rather than aborting the whole fleet bump.
      final stamped = await run('stamp', repoRoot);
      expect(stamped.exitCode, 0, reason: stamped.toString());
      expect(stamped.output, contains('cannot read'), reason: stamped.output);
      expect(
        constOf(repoRoot).readAsStringSync(),
        "const String version = '7.2.0';\n",
      );
    },
  );

  test(
    'a failed write is reported, not fatal, and leaves no temp file',
    () async {
      // Deterministic for any uid: the temp path exists as a DIRECTORY, so the
      // redirect fails with ENOTDIR/EISDIR rather than on file permissions.
      final repoRoot = repo(versionConst: "const version = '7.2.0';\n");
      Directory('${constOf(repoRoot).path}.tmp').createSync();

      final result = await run('stamp', repoRoot);

      expect(
        result.exitCode,
        1,
        reason: 'the caller counts a failure; it must not read as success',
      );
      expect(result.output, contains('could not write'), reason: result.output);
      expect(
        constOf(repoRoot).readAsStringSync(),
        "const version = '7.2.0';\n",
        reason: 'a failed stamp must not half-apply',
      );
    },
  );

  test(
    'the apply loop stamps only behind the manifest-failure guard',
    () async {
      // The stamp is called once per repo, after its pubspecs were bumped. If
      // a pubspec update failed, stamping anyway ships a core that declares the
      // new version beside a manifest that still declares the old one — and the
      // commit block would land it (review of #2096). Pin the ORDER, because
      // that is the invariant: a stamp above the guard is the bug.
      final root = await findProjectRoot();
      final script = File('$root/scripts/update_fleet.sh').readAsStringSync();

      final guardMatch = RegExp(
        r'if\s+\[\s+"?\$repo_failed"?\s*==\s*"?1"?\s*\]',
      ).firstMatch(script);
      expect(
        guardMatch,
        isNotNull,
        reason: 'the apply loop must skip a repo whose manifest update failed',
      );

      final stamp = script.indexOf(r'update_version_const "$repo_root"');
      expect(
        stamp,
        isNot(-1),
        reason: 'scripts/update_fleet.sh must stamp the constant',
      );
      expect(
        guardMatch!.end,
        lessThan(stamp),
        reason:
            'the repo_failed guard must run BEFORE update_version_const, or a '
            'failed manifest still gets a stamped constant',
      );
      expect(
        script,
        contains('repo_failed=1'),
        reason: 'a failed pubspec update must set repo_failed',
      );
    },
  );
}
