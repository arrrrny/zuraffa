// Issue #1382 — the epic regression exit criterion (`dart test
// test/regression/`) was a FALSE GREEN: dart_test.yaml excludes `slow`
// by default, so the literal invocation loaded ~12 of the tier's files
// and exited 0 while the majority of the tier never executed.
//
// This fast-tier pin closes the coverage hole permanently: EVERY file in
// `test/regression/` must carry the `regression` tag, so
// `dart test --preset=regression` (the honest invocation) covers 100% of
// the tier. A future regression file missing the tag — invisible to both
// the preset and (when slow-tagged) the literal command — fails this pin
// by construction.
//
// Issue #1510 (follow-up, same false-green family): the `e2e` weight tag
// keeps the heavyweight make-command regression suites off CI's fast lane
// without the default-excluded `slow` tag. This pin closes the drift hole
// the tag would otherwise leave open — a future selector or config edit
// must not silently re-admit heavy suites (or silently drop them from the
// heavy lanes):
//
//   B3 — every e2e-tagged file is selected by --preset=all's effective
//        selector (the heavy-lane opt-in stays truthful).
//   B4 — the dart_core fast-lane selector parsed out of ci.yaml excludes
//        every e2e-tagged file.
//
// Issue #1632 (the dart_core fast-lane overflow — the job cancelled at
// its 30-minute ceiling because ~116 heavyweight suites were never
// tagged): two pins close the drift permanently.
//
//   B5 — the fast-lane budget census: every fast-lane-eligible test
//        file (no `slow`/`e2e`/`flutter` tag) that matches a heavyweight
//        criterion — spawns external processes, or is an
//        analyzer/compile self-hosting gate — carries an exclusion tag.
//        Process-spawning/temp-project suites take `e2e` (#1510
//        semantics: honest under direct invocation, off the CI fast
//        lane, selected by --preset=all); in-process slow suites take
//        `slow`.
//   B6 — the tier invariant: every `regression`-tagged file also carries
//        `slow` (the tier's default-lane exclusion is the `slow` tag —
//        a tier-only tag leaks the file into every default `dart test`).
//
// Issue #1678 (the ffi lane's vacuous green): the lane's only content is
// sc_022 (slow+integration+ffi), so `dart test --tags ffi` selected
// NOTHING against the default `exclude_tags: slow` — and the job exited 0
// only because an unrelated MinIO suite's markTestSkipped counted as a
// matched suite (probe: `dart test --tags ffi <minio file>` → "All tests
// skipped", exit 0). Moving that suite into packages/zuraffa_storage
// emptied the lane for real. B8 pins the lane's EFFECTIVE selector to
// every ffi-tagged suite so the empty-selection class cannot return.
//
// Behaviors:
//   B1 — every regression-tier test file carries the `regression` tag.
//   B2 — dart_test.yaml defines the regression preset (include_tags
//        regression).

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'helpers/project_root.dart';

/// Repo root, resolved once via the CWD-independent [findProjectRoot].
late String _repoRoot;

/// `.github/workflows/ci.yaml` under the repo root (never the CWD).
File get _ciWorkflowFile =>
    File(p.join(_repoRoot, '.github', 'workflows', 'ci.yaml'));

Future<void> main() async {
  // The dart_core lane runs SERIAL by design (#1682): Directory.current
  // and dart:io exitCode are process-global, so a parallel lane in which
  // one suite chdirs silently redirects every concurrent suite's
  // relative-path I/O and exit-code reads into its window. The CLI-driving
  // suites here still move the process CWD through their own `-C` windows,
  // and other lanes (chunked/sharded runners, an IDE run) may add
  // parallelism back. Every structural path these pins read is therefore
  // resolved ONCE against the repo root through findProjectRoot() (the same
  // immunity the self-hosting gates rely on), never against the process CWD.
  _repoRoot = await findProjectRoot();
  final tierDir = Directory(p.join(_repoRoot, 'test', 'regression'));
  final configFile = File(p.join(_repoRoot, 'dart_test.yaml'));
  final testDir = Directory(p.join(_repoRoot, 'test'));

  final tierFiles = tierDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('_test.dart'))
      .toList();

  test('the regression tier exists and is non-trivial', () {
    expect(
      tierFiles.length,
      greaterThanOrEqualTo(60),
      reason:
          'the epic regression corpus is ~64 files — a sudden drop '
          'means the tier was renamed or excluded en masse',
    );
  });

  test('B1: every regression-tier file carries the regression tag', () async {
    expect(tierFiles, isNotEmpty);
    final untagged = <String>[];
    for (final file in tierFiles) {
      final source = await file.readAsString();
      final hasTag = RegExp('@Tags\\([^)]*regression').hasMatch(source);
      if (!hasTag) untagged.add(file.path);
    }
    expect(
      untagged,
      isEmpty,
      reason:
          'files without the regression tag are invisible to '
          '`dart test --preset=regression` — the #1382 false-green '
          'class: $untagged',
    );
  });

  test('B2: dart_test.yaml defines the regression preset', () {
    final doc = loadYaml(configFile.readAsStringSync()) as YamlMap;
    final presets = doc['presets'] as YamlMap?;
    expect(presets, isNotNull);
    expect((presets!['regression'] as YamlMap?)?['include_tags'], 'regression');
  });

  test('B3: every e2e-tagged file is selected by --preset=all', () {
    final e2eFiles = _e2eTaggedFiles();
    expect(
      e2eFiles,
      isNotEmpty,
      reason:
          'the e2e weight tag (#1510) must stay in use — with no tagged '
          'file the fast-lane guard in ci.yaml is unpinned',
    );
    final doc = loadYaml(configFile.readAsStringSync()) as YamlMap;
    expect(
      (doc['tags'] as YamlMap?)?.containsKey('e2e'),
      isTrue,
      reason:
          'e2e must stay declared in dart_test.yaml tags so no '
          'invocation warns about an unknown tag',
    );
    final all = (doc['presets'] as YamlMap?)?['all'] as YamlMap?;
    expect(all, isNotNull);
    final include = all!['include_tags'] ?? doc['include_tags'];
    final exclude = all['exclude_tags'] ?? doc['exclude_tags'];
    for (final entry in e2eFiles.entries) {
      expect(
        _selectorSelects(include, exclude, entry.value),
        isTrue,
        reason:
            '${entry.key} carries `e2e` but --preset=all no longer '
            'selects it (include: $include, exclude: $exclude)',
      );
    }
  });

  test('B4: the dart_core fast lane excludes every e2e-tagged file', () {
    final e2eFiles = _e2eTaggedFiles();
    expect(e2eFiles, isNotEmpty);
    final ci = loadYaml(_ciWorkflowFile.readAsStringSync()) as YamlMap;
    final steps =
        ((ci['jobs'] as YamlMap)['dart_core'] as YamlMap)['steps'] as YamlList;
    String? fastLaneExclude;
    for (final step in steps) {
      final run = (step as YamlMap)['run'];
      if (run is! String || !run.contains('dart test')) continue;
      final flag = RegExp(
        r'''--exclude-tags\s+(?:"([^"]*)"|'([^']*)'|(\S+))''',
      ).firstMatch(run);
      if (flag != null) {
        fastLaneExclude = flag.group(1) ?? flag.group(2) ?? flag.group(3);
      }
    }
    expect(
      fastLaneExclude,
      isNotNull,
      reason:
          'dart_core must keep an explicit --exclude-tags selector; '
          '#1510 relies on it, not on the default-excluded slow tag',
    );
    for (final entry in e2eFiles.entries) {
      expect(
        _selectorMatches(fastLaneExclude!, entry.value),
        isTrue,
        reason:
            '${entry.key} carries `e2e` but dart_core\'s selector '
            '"$fastLaneExclude" does not exclude it — the fast lane would '
            're-admit a heavyweight suite',
      );
    }
  });

  test('B5: the fast-lane budget census — no untagged heavyweight suite '
      'rides the dart_core lane (#1632)', () {
    final offenders = <String>[];
    for (final entry in _fastLaneEligibleFiles().entries) {
      final file = entry.key;
      final source = File(file).readAsStringSync();
      // Trivial fixture probes (short-lived `chmod` / `git` / `dart`
      // children) are not the heavyweight #1510 temp-project semantics —
      // discount them so fast in-process contract suites stay on the lane.
      final scanSource = source.replaceAll(_trivialProbeRe, '');
      final spawns = _spawnMarkerRe.hasMatch(scanSource);
      final compileGate =
          _compileGateRe.hasMatch(file) || file.contains('self_hosting');
      if (spawns || compileGate) {
        offenders.add(
          '$file — ${spawns ? 'spawns external processes' : 'compile/self-hosting gate'} '
          '(carries: ${entry.value.join(', ')})',
        );
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'fast-lane-eligible files that spawn external processes or run '
          'analyzer/compile self-hosting gates must carry `e2e` '
          '(process-spawning/temp-project suites, the #1510 semantics) or '
          '`slow` (in-process slow suites) — the untagged drift is what '
          'cancelled dart_core at its 30-minute ceiling (#1632):\n'
          '${offenders.join('\n')}',
    );
  });

  test('B6: every regression-tagged file is kept off the CI fast lane '
      'by `slow` or `e2e` (#1632)', () {
    final leaks = <String>[];
    for (final entity in testDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('_test.dart')) continue;
      final tags = _suiteTags(entity.path);
      if (tags.contains('regression') &&
          !tags.contains('slow') &&
          !tags.contains('e2e')) {
        leaks.add(entity.path);
      }
    }
    expect(
      leaks,
      isEmpty,
      reason:
          'a regression tag alone leaves the file eligible for the '
          'dart_core CI lane — the tier rides the default-lane '
          '`slow` exclusion (the corpus convention) or the #1510 '
          '`e2e` weight tag:\n'
          '${leaks.join('\n')}',
    );
  });

  test('B7: the dart_core lane stays SERIAL and keeps the '
      '--exclude-tags selector (#1632, #1682)', () {
    final ci = loadYaml(_ciWorkflowFile.readAsStringSync()) as YamlMap;
    final steps =
        ((ci['jobs'] as YamlMap)['dart_core'] as YamlMap)['steps'] as YamlList;
    String? testRun;
    for (final step in steps) {
      final run = (step as YamlMap)['run'];
      if (run is String && run.contains('dart test test')) testRun = run;
    }
    expect(testRun, isNotNull, reason: 'the dart_core test step vanished');
    expect(
      testRun,
      isNot(contains('--concurrency')),
      reason:
          'the pure-Dart unit lane must stay serial: Directory.current and '
          'exitCode are process-global and the lane runs suites as isolates '
          'of one VM, so any parallelism lets one suite chdir siblings into '
          'its temp fixture and clobber their exit-code reads — the three '
          'consecutive red master runs (7f89fbc4, 0a3b38e2, 1ab1a426). '
          'Sharding (tools/run_tests_chunked.sh) is the lever if the lane '
          'regrows, not concurrency (#1682)',
    );
    expect(
      testRun,
      contains('--exclude-tags'),
      reason: 'the fast-lane tag selector is the B4-pinned contract',
    );
  });

  test('B8: the ffi golden lane selects its ffi-tagged content (#1678)', () {
    final ffiTagged = <String, Set<String>>{};
    for (final entity in testDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('_test.dart')) continue;
      final tags = _suiteTags(entity.path);
      if (tags.contains('ffi')) ffiTagged[entity.path] = tags;
    }
    expect(
      ffiTagged,
      isNotEmpty,
      reason:
          'the ffi_golden_lane job needs tagged content: an empty lane '
          'can stay green only by dodging the zero-match exit 79',
    );

    final doc = loadYaml(configFile.readAsStringSync()) as YamlMap;
    final presets = doc['presets'] as YamlMap?;
    final ci = loadYaml(_ciWorkflowFile.readAsStringSync()) as YamlMap;
    final job = (ci['jobs'] as YamlMap)['ffi_golden_lane'] as YamlMap?;
    expect(job, isNotNull, reason: 'the ffi_golden_lane job vanished');
    String? laneRun;
    for (final step in job!['steps'] as YamlList) {
      final run = (step as YamlMap)['run'];
      if (run is String && run.contains('dart test')) laneRun = run;
    }
    expect(laneRun, isNotNull, reason: 'the ffi lane test step vanished');

    // The lane's EFFECTIVE selector: --tags / --preset on the command,
    // resolved against the preset it names (a preset's exclude_tags
    // replaces the global one — `--preset=all` sets it to false).
    final presetMatch = RegExp(r'--preset=(\S+)').firstMatch(laneRun!);
    final tagsMatch = RegExp(
      r'''--tags\s+(?:"([^"]*)"|'([^']*)'|(\S+))''',
    ).firstMatch(laneRun);
    final preset = presetMatch == null
        ? null
        : presets?[presetMatch.group(1)!] as YamlMap?;
    final include =
        (tagsMatch?.group(1) ?? tagsMatch?.group(2) ?? tagsMatch?.group(3)) ??
        preset?['include_tags'] ??
        doc['include_tags'];
    final exclude = preset?['exclude_tags'] ?? doc['exclude_tags'];

    for (final entry in ffiTagged.entries) {
      expect(
        _selectorSelects(include, exclude, entry.value),
        isTrue,
        reason:
            '${entry.key} carries `ffi` but the lane selector "$laneRun" '
            '(include: $include, exclude: $exclude) does not select it — '
            'a vacuous lane: `--tags ffi` alone solved against the '
            'default `exclude_tags: slow` selected NOTHING, and the job '
            "stayed green only through an unrelated suite's "
            'markTestSkipped (#1678)',
      );
    }
  });
}

/// Every `_test.dart` file under `test/` whose suite-level `@Tags`
/// annotation contains `e2e`, mapped to its full tag set. Scanned once.
Map<String, Set<String>> _e2eTaggedFiles() =>
    _cachedE2eFiles ??= _scanE2eTaggedFiles();

Map<String, Set<String>>? _cachedE2eFiles;

/// The suite-level `@Tags` annotation's tag set of [path] (empty when the
/// file declares none). Line-anchored (`multiLine` + `^`): a doc comment
/// or string literal showing a literal `@Tags([...])` example must not
/// shadow the real annotation.
final RegExp _tagsAnnotationRe = RegExp(
  r'^@Tags\(\[([^\]]*)\]\)',
  multiLine: true,
);

Set<String> _suiteTags(String path) {
  final annotation = _tagsAnnotationRe.firstMatch(
    File(path).readAsStringSync(),
  );
  if (annotation == null) return const {};
  return RegExp(
    "'([^']*)'",
  ).allMatches(annotation.group(1)!).map((match) => match.group(1)!).toSet();
}

/// Source markers proving a suite drives EXTERNAL processes: the spawn
/// helpers (the run-zfa-source style drivers under `test/helpers/`) or
/// direct `Process` use. Each alternative is split across adjacent string
/// literals so THIS file's own source never contains the assembled marker
/// text — the B5 census scans every fast-lane-eligible suite, this one
/// included, and needs no self-exclusion carve-out.
final RegExp _spawnMarkerRe = RegExp(
  'Process'
  r'\.run|Process'
  r'\.start|run_'
  r'zfa_source|runZfa'
  r'Source|zfaEx'
  r'ecutable|dart'
  r'Test\(|runZfa'
  r'\(',
);

/// Spawn calls whose child is a short-lived fixture probe — a literal
/// `chmod` / `git` / `dart` first argument — not the heavyweight
/// #1510 temp-project semantics (`pub get` + `build_runner` children)
/// the census exists for. B5 discounts these before the marker scan.
final RegExp _trivialProbeRe = RegExp(
  r"Process\.run(?:Sync)?\(\s*'(?:chmod|git|dart)'",
);

/// Path markers of the analyzer/compile gate family: suites whose
/// assertions compile or resolve generated code in-process.
final RegExp _compileGateRe = RegExp(r'_compile_test\.dart$');

/// Every `_test.dart` file under `test/` that the dart_core fast lane
/// RUNS — its tag set is disjoint from the exclusion vocabulary
/// (`slow` via dart_test.yaml's default, `flutter || e2e` via the CI
/// selector) — mapped to its tag set.
Map<String, Set<String>> _fastLaneEligibleFiles() {
  final eligible = <String, Set<String>>{};
  final testDir = Directory(p.join(_repoRoot, 'test'));
  for (final entity in testDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('_test.dart')) continue;
    final tags = _suiteTags(entity.path);
    if (tags.intersection({'slow', 'e2e', 'flutter'}).isNotEmpty) continue;
    eligible[entity.path] = tags;
  }
  return eligible;
}

Map<String, Set<String>> _scanE2eTaggedFiles() {
  final tagged = <String, Set<String>>{};
  final testDir = Directory(p.join(_repoRoot, 'test'));
  for (final entity in testDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('_test.dart')) continue;
    final annotation = RegExp(
      r'^@Tags\(\[([^\]]*)\]\)',
      multiLine: true,
    ).firstMatch(entity.readAsStringSync());
    if (annotation == null) continue;
    final tags = RegExp(
      "'([^']*)'",
    ).allMatches(annotation.group(1)!).map((match) => match.group(1)!).toSet();
    if (tags.contains('e2e')) tagged[entity.path] = tags;
  }
  return tagged;
}

/// True when [tags] satisfies the boolean tag selector [selector]
/// (a union of `&&`-intersections, e.g. `slow || flutter || e2e`).
bool _selectorMatches(Object selector, Set<String> tags) {
  if (selector is bool) return selector;
  for (final unionTerm in selector.toString().split('||')) {
    final atoms = unionTerm
        .split('&&')
        .map((atom) => atom.trim())
        .where((atom) => atom.isNotEmpty);
    if (atoms.isNotEmpty && atoms.every(tags.contains)) return true;
  }
  return false;
}

/// True when a config include/exclude pair selects a suite carrying [tags].
bool _selectorSelects(Object? include, Object? exclude, Set<String> tags) {
  final included = include == null || _selectorMatches(include, tags);
  final excluded = exclude != null && _selectorMatches(exclude, tags);
  return included && !excluded;
}
