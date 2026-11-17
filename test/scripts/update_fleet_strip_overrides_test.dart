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
// into every member pubspec. Those paths exist only on a machine with the
// sibling checkout, so the member's first `flutter pub get` dies with
// `could not find package zuraffa at "../zuraffa"` and the red base blocks
// every later PR (arrrrny/zuraffa_intents#28 and its whole repair history).
//
// The strip step the script's comment promised never existed; this suite
// pins it:
//
//   strip -> keeps xml -> keeps in-repo path deps -> idempotent ->
//   no dependency_overrides section -> no-op
//
// `update_fleet.sh` needs bash >= 4, so the suite extracts the helper
// definition from the real script and drives it with whatever bash is on
// PATH over a `mkdtemp` fixture — no fleet checkout, no network. The
// helpers and fixture pattern mirror
// test/scripts/update_fleet_version_const_test.dart (issue #2095).

@Tags(['e2e', 'spawn'])
library;

import 'dart:io';

import 'package:test/test.dart';

import '../helpers/project_root.dart';

const _helperNames = <String>['strip_outside_overrides'];

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

/// A harness that sources the extracted helpers and runs the strip over
/// every pubspec passed on argv (a repo root and/or a bare pubspec path).
String _harnessOf(String helpers) =>
    '''
#!/usr/bin/env bash
set -uo pipefail
GREEN=''; BLUE=''; YELLOW=''; RED=''; NC=''
$helpers
target="\$1"
if [ -d "\$target" ]; then
  while IFS= read -r rel; do
    file="\$target/\$rel"
    [ -f "\$file" ] || continue
    strip_outside_overrides "\$file" || echo "strip failed: \$file" >&2
  done < <(find_pkg_pubspecs "\$target")
else
  strip_outside_overrides "\$target" || echo "strip failed: \$target" >&2
fi
''';

/// The discovery walk the apply loop uses (root pubspec, packages/*, root-
/// level platform dirs) — the same walk whose output `collect_siblings`
/// feeds, so the fixture walks exactly what the fleet bump walks.
const _findPkgPubspecs = '''
find_pkg_pubspecs() {
  local root="\$1" f
  [ -f "\$root/pubspec.yaml" ] && echo "pubspec.yaml"
  for f in "\$root"/packages/*/pubspec.yaml; do
    [ -f "\$f" ] && echo "\${f#"\$root"/}"
  done
  for f in "\$root"/*/pubspec.yaml; do
    [ -f "\$f" ] || continue
    case "\$f" in
      "\$root"/packages/*|"\$root"/example/*|"\$root"/examples/*) continue ;;
    esac
    echo "\${f#"\$root"/}"
  done
  return 0
}
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
    harness = _harnessOf(
      '${_helpersOf(script.readAsStringSync())}\n$_findPkgPubspecs',
    );
    work = await Directory.systemTemp.createTemp('zf-strip-overrides-');
  });

  tearDownAll(() {
    if (work.existsSync()) work.deleteSync(recursive: true);
  });

  /// A throwaway fleet repo with a root pubspec carrying [overrides].
  Directory repo({String overrides = ''}) {
    final root = Directory('${work.path}/repo-${repoCount++}');
    root.createSync();
    File('${root.path}/pubspec.yaml').writeAsStringSync(
      'name: zuraffa_test\n'
      'version: 9.9.9\n'
      'environment:\n'
      '  sdk: ^3.13.0\n'
      '$overrides',
    );
    return root;
  }

  Future<_Run> run(Directory repoRoot) async {
    final script = File('${work.path}/harness.sh')..writeAsStringSync(harness);
    final result = await Process.run('bash', [script.path, repoRoot.path]);
    return _Run(result.exitCode, '${result.stdout}${result.stderr}');
  }

  File pubspecOf(Directory repoRoot) => File('${repoRoot.path}/pubspec.yaml');

  test(
    'strips an out-of-repo path override and keeps the xml policy',
    () async {
      final repoRoot = repo(
        overrides:
            'dependency_overrides:\n'
            '  zuraffa:\n'
            '    path: ../../zuraffa\n'
            '  xml: 7.1.0\n'
            '  zuraffa_ui:\n'
            '    path: ../zuraffa_ui\n',
      );

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
            'the whole sibling block must go, not just its path line: '
            '$text',
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
    final repoRoot = repo(
      overrides:
          'dependency_overrides:\n'
          '  zuraffa_local:\n'
          '    path: ./local/zuraffa_local\n',
    );
    Directory(
      '${repoRoot.path}/local/zuraffa_local',
    ).createSync(recursive: true);
    File(
      '${repoRoot.path}/local/zuraffa_local/pubspec.yaml',
    ).writeAsStringSync('name: zuraffa_local\n');

    final result = await run(repoRoot);

    expect(result.exitCode, 0, reason: result.toString());
    final text = pubspecOf(repoRoot).readAsStringSync();
    expect(
      text,
      contains('path: ./local/zuraffa_local'),
      reason:
          'an in-repo path override is a dev surface, not a sibling: '
          '$text',
    );
  });

  test('is idempotent — a second pass changes nothing', () async {
    final repoRoot = repo(
      overrides:
          'dependency_overrides:\n'
          '  zuraffa:\n'
          '    path: ../../zuraffa\n'
          '  xml: 7.1.0\n',
    );

    expect((await run(repoRoot)).exitCode, 0);
    final once = pubspecOf(repoRoot).readAsStringSync();
    expect((await run(repoRoot)).exitCode, 0);

    expect(pubspecOf(repoRoot).readAsStringSync(), once);
  });

  test('leaves a pubspec without dependency_overrides untouched', () async {
    final repoRoot = repo();

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

  test(
    'the apply loop strips every touched member before the commit block',
    () async {
      // The commit block must never see a member that still carries an
      // out-of-repo path override — pin the ORDER, because that is the
      // invariant: a strip below the commit (or missing) is the bug.
      final root = await findProjectRoot();
      final script = File('$root/scripts/update_fleet.sh').readAsStringSync();

      final strip = script.indexOf('strip_outside_overrides "\$repo_root"');
      expect(
        strip,
        isNot(-1),
        reason: 'the apply loop must strip out-of-repo overrides per repo',
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
