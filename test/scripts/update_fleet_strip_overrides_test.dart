// Behavioural guard for the sibling-override strip pass in
// scripts/update_fleet.sh (issue #2097).
//
// `collect_siblings()` hands `fleet_pubspec_tool.py` `--sibling <dep>=<rel>`
// entries, which write
//
//   dependency_overrides:
//     zuraffa:
//       path: ../../zuraffa
//
// into every member pubspec — and into each member's `example/` /
// `examples/*/` manifest, because dart >= 3.6 resolves an example as its own
// root. Those paths exist only on a machine with the sibling checkout, so the
// member's first `flutter pub get` dies with `could not find package zuraffa
// at "../zuraffa"` and the red base blocks every later PR.
//
// The strip step the script's comment promised never existed; this suite
// pins it:
//
//   strip -> keeps xml -> keeps in-repo path deps -> keeps the example's own
//   parent path -> idempotent -> check mode reports a survivor
//
// It drives the REAL production shape, not a private copy of it: the harness
// below runs `find_fleet_pubspecs` (the apply loop's own write set) and hands
// each manifest FILE plus the member repo root to `strip_outside_overrides`,
// which is exactly what the apply loop does. An earlier version of this suite
// re-implemented the discovery walk and only ever called the helper with a
// file, so it could not see that production handed it a DIRECTORY and exited
// 0 without stripping anything (the blocker the #2098 review caught).
//
// `update_fleet.sh` needs bash >= 4 for its associative arrays, so the suite
// extracts the helper definitions from the real script and drives them with
// whatever bash is on PATH over a `mkdtemp` fixture — no fleet checkout, no
// network. The helpers and fixture pattern mirror
// test/scripts/update_fleet_version_const_test.dart (issue #2095).

@Tags(['e2e', 'spawn'])
library;

import 'dart:io';

import 'package:test/test.dart';

import '../helpers/project_root.dart';

const _helperNames = <String>[
  'find_pkg_pubspecs',
  'find_example_pubspecs',
  'find_fleet_pubspecs',
  'outside_overrides',
  'strip_outside_overrides',
  'check_outside_overrides',
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

/// A harness that sources the extracted helpers and drives them over a repo
/// root the way the apply loop does: the write-set walk, then a strip or a
/// check per manifest. `mode` is `apply` (default) or `check`.
String _harnessOf(String helpers) =>
    '''
#!/usr/bin/env bash
set -uo pipefail
GREEN=''; BLUE=''; YELLOW=''; RED=''; NC=''
$helpers
target="\$1"
mode="\${2:-apply}"
rc=0
while IFS= read -r rel; do
  manifest="\$target/\$rel"
  if [ "\$mode" = "check" ]; then
    check_outside_overrides "\$manifest" "\$target" || { echo "leftover: \$rel" >&2; rc=1; }
  else
    strip_outside_overrides "\$manifest" "\$target" || echo "strip failed: \$rel" >&2
  fi
done < <(find_fleet_pubspecs "\$target")
exit "\$rc"
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
    work = await Directory.systemTemp.createTemp('zf-strip-overrides-');
  });

  tearDownAll(() {
    if (work.existsSync()) work.deleteSync(recursive: true);
  });

  /// A throwaway fleet repo whose files are [files] (relative path -> body).
  Directory repo(Map<String, String> files) {
    final root = Directory('${work.path}/repo-${repoCount++}');
    root.createSync(recursive: true);
    files.forEach((rel, content) {
      final file = File('${root.path}/$rel');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(content);
    });
    return root;
  }

  /// A member pubspec with [overrides] under a `dependency_overrides:` header.
  String pubspec(String overrides) =>
      'name: zuraffa_test\n'
      'version: 9.9.9\n'
      'environment:\n'
      '  sdk: ^3.13.0\n'
      '$overrides';

  Future<_Run> run(Directory repoRoot, {String mode = 'apply'}) async {
    final script = File('${work.path}/harness.sh')..writeAsStringSync(harness);
    final result = await Process.run('bash', [
      script.path,
      repoRoot.path,
      mode,
    ]);
    return _Run(result.exitCode, '${result.stdout}${result.stderr}');
  }

  File pubspecOf(Directory repoRoot, [String rel = 'pubspec.yaml']) =>
      File('${repoRoot.path}/$rel');

  test(
    'strips an out-of-repo path override and keeps the xml policy',
    () async {
      final repoRoot = repo({
        'pubspec.yaml': pubspec(
          'dependency_overrides:\n'
          '  zuraffa:\n'
          '    path: ../../zuraffa\n'
          '  xml: 7.1.0\n'
          '  zuraffa_ui:\n'
          '    path: ../zuraffa_ui\n',
        ),
      });

      final result = await run(repoRoot);

      expect(result.exitCode, 0, reason: result.toString());
      final text = pubspecOf(repoRoot).readAsStringSync();
      expect(
        text,
        isNot(contains('path: ../../zuraffa')),
        reason: 'the sibling override must be stripped: $text',
      );
      expect(
        text,
        isNot(contains('path: ../zuraffa_ui')),
        reason: 'a second sibling override is stripped too: $text',
      );
      expect(
        text,
        isNot(contains('zuraffa_ui:')),
        reason:
            'the whole sibling block must go, not just its path line: $text',
      );
      expect(
        text,
        contains('xml: 7.1.0'),
        reason: 'the fleet xml policy override must survive: $text',
      );
      expect(
        text,
        contains('dependency_overrides:'),
        reason: 'the section header itself stays while xml remains: $text',
      );
    },
  );

  test('keeps a path override that resolves inside the repo', () async {
    final repoRoot = repo({
      'pubspec.yaml': pubspec(
        'dependency_overrides:\n'
        '  zuraffa_local:\n'
        '    path: ./local/zuraffa_local\n',
      ),
    });

    final result = await run(repoRoot);

    expect(result.exitCode, 0, reason: result.toString());
    final text = pubspecOf(repoRoot).readAsStringSync();
    expect(
      text,
      contains('path: ./local/zuraffa_local'),
      reason: 'an in-repo path override is a dev surface, not a sibling: $text',
    );
  });

  test(
    'judges containment against the member repo root, not the manifest dir',
    () async {
      // `packages/adapter` -> `path: ../core` is a sibling package INSIDE
      // the member repo, and `packages/core` -> `path: ../../zuraffa` is a
      // sibling checkout OUTSIDE it. The manifest-directory boundary got
      // this backwards and stripped the valid one.
      final repoRoot = repo({
        'pubspec.yaml': pubspec(''),
        'packages/adapter/pubspec.yaml': pubspec(
          'dependency_overrides:\n'
          '  core:\n'
          '    path: ../core\n'
          '  zuraffa:\n'
          '    path: ../../../zuraffa\n',
        ),
        'packages/core/pubspec.yaml': pubspec(''),
      });

      final result = await run(repoRoot);

      expect(result.exitCode, 0, reason: result.toString());
      final adapter = pubspecOf(
        repoRoot,
        'packages/adapter/pubspec.yaml',
      ).readAsStringSync();
      expect(
        adapter,
        contains('core:\n    path: ../core'),
        reason: 'an in-repo sibling package must survive: $adapter',
      );
      expect(
        adapter,
        isNot(contains('zuraffa:')),
        reason: 'the out-of-repo checkout must be stripped: $adapter',
      );
      expect(
        pubspecOf(repoRoot, 'packages/core/pubspec.yaml').readAsStringSync(),
        contains('name: zuraffa_test'),
        reason: 'an untouched member is left byte-identical',
      );
    },
  );

  test('strips an example manifest and keeps its own parent path', () async {
    // dart >= 3.6 resolves `example/` as its own root, so the tool writes
    // fleet overrides into it. `path: ..` is the example's parent — inside
    // the repo, kept; `path: ../../zuraffa_http` is a sibling checkout,
    // stripped. These were stripped by nothing at all before.
    final repoRoot = repo({
      'pubspec.yaml': pubspec(''),
      'example/pubspec.yaml': pubspec(
        'dependency_overrides:\n'
        '  zuraffa:\n'
        '    path: ..\n'
        '  zuraffa_http:\n'
        '    path: ../../zuraffa_http\n'
        '  xml: 7.1.0\n',
      ),
      'examples/app/pubspec.yaml': pubspec(
        'dependency_overrides:\n'
        '  zuraffa:\n'
        '    path: ../..\n'
        '  zuraffa_ui:\n'
        '    path: ../../../zuraffa_ui\n',
      ),
    });

    final result = await run(repoRoot);

    expect(result.exitCode, 0, reason: result.toString());
    final example = pubspecOf(
      repoRoot,
      'example/pubspec.yaml',
    ).readAsStringSync();
    expect(
      example,
      contains('zuraffa:\n    path: ..\n'),
      reason: "the example's own parent path must survive: $example",
    );
    expect(
      example,
      isNot(contains('zuraffa_http')),
      reason: 'the sibling checkout must be stripped: $example',
    );
    final nested = pubspecOf(
      repoRoot,
      'examples/app/pubspec.yaml',
    ).readAsStringSync();
    expect(
      nested,
      contains('zuraffa:\n    path: ../..'),
      reason: 'the examples/* parent path must survive: $nested',
    );
    expect(
      nested,
      isNot(contains('zuraffa_ui')),
      reason: 'the sibling checkout must be stripped: $nested',
    );
  });

  test('decodes a quoted path before the containment check', () async {
    final repoRoot = repo({
      'pubspec.yaml': pubspec(
        'dependency_overrides:\n'
        '  zuraffa:\n'
        '    path: "../../zuraffa"\n'
        "  zuraffa_local:\n"
        "    path: './local/zuraffa_local'\n"
        '  xml: 7.1.0\n',
      ),
    });

    final result = await run(repoRoot);

    expect(result.exitCode, 0, reason: result.toString());
    final text = pubspecOf(repoRoot).readAsStringSync();
    expect(
      text,
      isNot(contains('zuraffa:')),
      reason: 'a quoted sibling path is still out of repo: $text',
    );
    expect(
      text,
      contains("path: './local/zuraffa_local'"),
      reason: 'a quoted in-repo path is kept: $text',
    );
    expect(
      text,
      contains('xml: 7.1.0'),
      reason: 'the xml policy line survives: $text',
    );
  });

  test('leaves a nested path: under a git: block alone', () async {
    // A `git:` dependency carries its own `path:` (a subdirectory inside the
    // checked-out repo). It is not the override's target and must not be
    // read as one.
    final repoRoot = repo({
      'pubspec.yaml': pubspec(
        'dependency_overrides:\n'
        '  zuraffa_git:\n'
        '    git:\n'
        '      url: https://github.com/arrrrny/zuraffa.git\n'
        '      path: packages/zuraffa\n'
        '  xml: 7.1.0\n',
      ),
    });

    final result = await run(repoRoot);

    expect(result.exitCode, 0, reason: result.toString());
    expect(
      pubspecOf(repoRoot).readAsStringSync(),
      contains('      path: packages/zuraffa'),
      reason: 'a nested git: path is not an override target',
    );
  });

  test('preserves CRLF line endings', () async {
    final repoRoot = repo({
      'pubspec.yaml':
          'name: zuraffa_test\r\n'
          'version: 9.9.9\r\n'
          'dependency_overrides:\r\n'
          '  zuraffa:\r\n'
          '    path: ../../zuraffa\r\n'
          '  xml: 7.1.0\r\n',
    });

    final result = await run(repoRoot);

    expect(result.exitCode, 0, reason: result.toString());
    final bytes = pubspecOf(repoRoot).readAsBytesSync();
    expect(
      String.fromCharCodes(bytes),
      isNot(contains('zuraffa:')),
      reason: 'the sibling override is stripped',
    );
    expect(
      String.fromCharCodes(bytes),
      'name: zuraffa_test\r\n'
      'version: 9.9.9\r\n'
      'dependency_overrides:\r\n'
      '  xml: 7.1.0\r\n',
      reason: 'the file stays CRLF, not rewritten as LF',
    );
  });

  test('is idempotent — a second pass changes nothing', () async {
    final repoRoot = repo({
      'pubspec.yaml': pubspec(
        'dependency_overrides:\n'
        '  zuraffa:\n'
        '    path: ../../zuraffa\n'
        '  xml: 7.1.0\n',
      ),
    });

    expect((await run(repoRoot)).exitCode, 0);
    final once = pubspecOf(repoRoot).readAsStringSync();
    expect((await run(repoRoot)).exitCode, 0);

    expect(pubspecOf(repoRoot).readAsStringSync(), once);
  });

  test('leaves a pubspec without dependency_overrides untouched', () async {
    final repoRoot = repo({'pubspec.yaml': pubspec('')});

    final result = await run(repoRoot);

    expect(result.exitCode, 0, reason: result.toString());
    expect(
      pubspecOf(repoRoot).readAsStringSync(),
      contains('name: zuraffa_test'),
    );
    expect(
      pubspecOf(repoRoot).readAsStringSync(),
      isNot(contains('dependency_overrides')),
    );
  });

  test('check mode reports a survivor instead of passing in silence', () async {
    // The apply loop verifies its own work before committing, and `--check`
    // uses the same gate — a manifest still carrying a sibling path must be
    // named, not silently accepted.
    final repoRoot = repo({
      'pubspec.yaml': pubspec(
        'dependency_overrides:\n'
        '  zuraffa:\n'
        '    path: ../../zuraffa\n',
      ),
    });

    final dirty = await run(repoRoot, mode: 'check');

    expect(dirty.exitCode, 1, reason: dirty.toString());
    expect(
      dirty.output,
      contains('leftover: pubspec.yaml'),
      reason: 'the survivor is named: ${dirty.output}',
    );
    expect(
      dirty.output,
      contains('resolves outside'),
      reason: 'the finding says why: ${dirty.output}',
    );

    expect((await run(repoRoot)).exitCode, 0);
    final clean = await run(repoRoot, mode: 'check');
    expect(clean.exitCode, 0, reason: clean.toString());
  });

  test(
    'the apply loop strips every touched member before the commit block',
    () async {
      // The commit block must never see a member that still carries an
      // out-of-repo path override — pin the ORDER, because that is the
      // invariant: a strip below the commit (or missing) is the bug.
      final root = await findProjectRoot();
      final script = File('$root/scripts/update_fleet.sh').readAsStringSync();

      expect(
        script,
        isNot(contains('strip_outside_overrides "\$repo_root"')),
        reason:
            'the helper takes a manifest FILE plus the repo root — the old '
            'directory call exited 0 without stripping anything (#2098)',
      );
      final strip = script.indexOf(
        'strip_outside_overrides "\$repo_root/\$rel"',
      );
      expect(
        strip,
        isNot(-1),
        reason: 'the apply loop must strip each manifest it wrote',
      );

      final commit = script.indexOf('git commit -m "chore(fleet)');
      expect(
        commit,
        isNot(-1),
        reason: 'scripts/update_fleet.sh must still commit per repo',
      );
      expect(
        strip,
        lessThan(commit),
        reason:
            'the strip must run BEFORE the per-repo commit, or the commit '
            'lands the sibling overrides the strip was meant to remove',
      );
    },
  );
}
