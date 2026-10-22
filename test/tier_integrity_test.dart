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
// emptied the lane for real. The second trap is the fix itself:
// package:test gives a named preset's selector configuration priority
// over the CLI selectors, so `--preset=all --tags ffi` un-scoped the lane
// to the WHOLE tree and was cancelled at its 30-minute ceiling. B8 pins
// the lane's EFFECTIVE selector to every ffi-tagged suite AND requires
// the selection to stay bounded, so neither the empty-lane nor the
// whole-tree class can return.
//
// Behaviors:
//   B1 — every regression-tier test file carries the `regression` tag.
//   B2 — dart_test.yaml defines the regression preset (include_tags
//        regression).

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

// The fast tier's entrypoint (issue #1994): its cap logic is imported
// (not spawned) so the B9 pin asserts the refusal without making this
// fast-lane suite a process spawner under the B5 census.
import '../tools/run_fast_suite.dart';
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

  test('B8: the ffi golden lane selects its ffi-tagged content and stays '
      'scoped (#1678)', () {
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

    // The lane's EFFECTIVE selector. package:test semantics (verified
    // against a probe package): when a preset is named, the PRESET's
    // selector configuration wins and the CLI tag selectors are ignored
    // (`--preset=alpha --tags beta` runs alpha's include_tags). Without a
    // preset, the CLI selectors apply on top of the global config.
    final presetMatch = RegExp(r'--preset=(\S+)').firstMatch(laneRun!);
    final tagsMatch = RegExp(
      r'''--tags\s+(?:"([^"]*)"|'([^']*)'|(\S+))''',
    ).firstMatch(laneRun);
    final preset = presetMatch == null
        ? null
        : presets?[presetMatch.group(1)!] as YamlMap?;
    final include = preset != null
        ? preset['include_tags']
        : (tagsMatch?.group(1) ?? tagsMatch?.group(2) ?? tagsMatch?.group(3)) ??
              doc['include_tags'];
    final exclude = preset?['exclude_tags'] ?? doc['exclude_tags'];

    // Boundedness: an include filter or an explicit path argument keeps
    // the lane scoped. `--preset=all --tags ffi` was neither (the `all`
    // preset has no include_tags and the CLI tags were ignored) — the
    // lane ran the WHOLE tree, slow/benchmark/property tiers included,
    // and was cancelled at its 30-minute ceiling.
    final bounded = include != null || laneRun.contains('test/');
    expect(
      bounded,
      isTrue,
      reason:
          'the ffi lane must scope its selection: a preset without '
          'include_tags (or a bare --exclude-tags) lets the whole tree '
          'in — "$laneRun" (include: $include)',
    );

    for (final entry in ffiTagged.entries) {
      expect(
        _selectorSelects(include, exclude, entry.value),
        isTrue,
        reason:
            '${entry.key} carries `ffi` but the lane selector "$laneRun" '
            '(include: $include, exclude: $exclude) does not select it — '
            'the empty-selection class: `--tags ffi` alone solved against '
            'the default `exclude_tags: slow` selected NOTHING, and the '
            "job stayed green only through an unrelated suite's "
            'markTestSkipped (#1678)',
      );
    }
  });

  test('B9: the fast tier enforces its serial invariant from the CLI side '
      '(#1994)', () {
    // dart_test.yaml pins `concurrency: 1` — and that pin is a CORRECTNESS
    // requirement, not a performance knob: `dart test` runs the suites as
    // isolates of ONE process, so `Directory.current` and `dart:io exitCode`
    // are process-global (the three red master runs of #1632/#1682). A CLI
    // `-j 2` overrides the pin SILENTLY — package:test resolves
    // `concurrency => _concurrency ?? defaultConcurrency`, i.e. the CLI
    // value wins over the config (test_core's Configuration).
    //
    // Issue #1994 is what that silent override costs on a loaded shared
    // host: the fast suite's failures were all load-amplified — spawn
    // ceilings AND cross-suite CWD redirection (`pubspec.yaml not found`
    // mid-setup). So the cap must be enforceable from the invocation, not
    // only from a config a fleet-wide `-j 2` overrules.
    final doc = loadYaml(configFile.readAsStringSync()) as YamlMap;
    expect(
      doc['concurrency'],
      1,
      reason:
          'the fast tier runs SERIAL by design (#1682): a parallel lane '
          'lets one suite chdir siblings into its temp fixture and '
          'clobber their exit-code reads',
    );

    // The sanctioned entrypoint owns the cap. Its logic is a pure
    // function so this pin can assert the refusal WITHOUT spawning a
    // process — a fast-lane suite that spawns a child is a heavyweight
    // suite under the B5 census below.
    expect(
      File(p.join(_repoRoot, 'tools', 'run_fast_suite.dart')).existsSync(),
      isTrue,
      reason:
          'the fast tier needs an entrypoint that owns the serial cap '
          '(issue #1994): `dart test -j 2` overrides dart_test.yaml\'s '
          '`concurrency: 1` silently, so the cap is only real where it is '
          'enforced',
    );

    // A parallel request is REFUSED, with the reason and the issue. The
    // decision function is the one `main` takes, so this asserts the
    // shipped path, not a copy of it.
    final refusal = decideFastSuite(['-j', '2']).refusal;
    expect(
      refusal,
      isNotNull,
      reason: 'a parallel fast-tier run must be refused (#1994)',
    );
    expect(
      refusal,
      contains('concurrency'),
      reason: 'the refusal must name the knob it refuses: $refusal',
    );
    expect(
      refusal,
      contains('#1994'),
      reason:
          'the refusal must point at the issue that made it a cap: '
          '$refusal',
    );

    // Every spelling package:test accepts must be recognized — a refusal
    // that only catches `-j 2` leaves `--concurrency=2` through.
    for (final args in <List<String>>[
      ['-j', '2'],
      ['-j2'],
      ['--concurrency', '2'],
      ['--concurrency=2'],
    ]) {
      expect(
        requestedConcurrencyArg(args),
        '2',
        reason:
            'the cap must read every spelling package:test accepts: '
            '$args',
      );
      expect(
        decideFastSuite(args).refusal,
        isNotNull,
        reason:
            'the cap must refuse every spelling package:test accepts: '
            '$args',
      );
    }
    expect(requestedConcurrencyArg(['test/core']), isNull);
    expect(
      decideFastSuite(['test/core']).refusal,
      isNull,
      reason: 'a request without a concurrency knob must not be refused',
    );

    // The run itself is serial — explicitly, because an implicit default
    // is exactly what the fleet-wide `-j 2` overrides.
    final command = fastSuiteCommand(['test']);
    expect(
      command,
      containsAllInOrder(['--exclude-tags', '-j', '1']),
      reason:
          'the fast-tier run must pin the serial flag AND the CI lane\'s '
          'tag selector: $command',
    );
    expect(
      command[command.indexOf('--exclude-tags') + 1],
      contains('e2e'),
      reason:
          'the fast lane must stay off the `e2e` tier: on a loaded host '
          'those temp-project suites are what pushes the run past a '
          'two-hour window (#1994) — $command',
    );
  });

  test('B10: the loaded-host ceiling covers the fast-tier suites that '
      'drive a REAL analyzer child (#1994)', () {
    // Issue #1994: on a shared host under load ~390 the fast suite's
    // global 2x (60s) ceiling fired on suites that drive a REAL
    // `dart analyze` child — the analyzer's cold start alone eats that
    // budget there, while the same suite passes in isolation. The `ffi`
    // lane already carries 8x for exactly this reason (#1678); the
    // spawn-heavy fast-tier suites had no such ladder.
    final doc = loadYaml(configFile.readAsStringSync()) as YamlMap;
    final tags = doc['tags'] as YamlMap?;
    expect(tags, isNotNull);
    final spawn = tags!['spawn'];
    expect(
      spawn,
      isNotNull,
      reason:
          'dart_test.yaml declares no `spawn` ceiling: every fast-tier '
          'suite that drives a real external child sits under the global '
          '2x (60s) ceiling — the #1994 failure mode',
    );
    final timeout = (spawn as YamlMap)['timeout'];
    expect(timeout, isNotNull);
    final multiplier = double.parse((timeout as String).replaceAll('x', ''));
    expect(
      multiplier * 30,
      greaterThanOrEqualTo(240),
      reason:
          'the `spawn` ceiling must be at least 8x package:test\'s 30s '
          'base (240s) — the `ffi` precedent (#1678); a lower factor '
          're-opens the #1994 false timeout',
    );

    // The census gap that let the flake in: B5 scans the TEST sources
    // for spawns, but a suite that reaches a real child through the LIB
    // (the production certifier with no injected analyzer -> a real
    // `dart analyze` child) is invisible to it. Those suites must carry
    // `spawn`.
    final offenders = <String>[];
    for (final entry in _fastLaneEligibleFiles().entries) {
      final source = File(entry.key).readAsStringSync();
      if (!_realAnalyzerRe.hasMatch(source)) continue;
      if (!entry.value.contains('spawn')) {
        offenders.add(
          '${entry.key} — drives a real `dart analyze` child '
          '(carries: ${entry.value.join(', ')})',
        );
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'fast-tier suites that drive a REAL analyzer child must carry '
          'the `spawn` tag (the 8x loaded-host ceiling) — the B5 census '
          'only sees test-side spawns, so this class slips through it '
          '(#1994):\n${offenders.join('\n')}',
    );
  });

  // Issue #1994 — the fast suite flaked on a LOADED shared host (load
  // average ~390) and did not finish inside a 2-hour bound: the root
  // ceiling was 2x (60s), the CLI's `-j 2` always overrides this file's
  // `concurrency: 1`, and spawn-heavy suites were killed mid-setup —
  // leaving temp projects without a `pubspec.yaml` so the NEXT test in
  // the same file failed on a missing file rather than on its subject.
  // Every one of those files passed in isolation on the same tree.
  //
  //   B13 — the config carries relaxed budgets: root >= 4x, and the
  //         spawn/e2e/ffi weight tags >= 8x (the #1678 precedent).
  //   B12 — every spawn-heavy fast-tier suite carries the `spawn` budget
  //         tag, so it is never left on the bare root ceiling.
  //   B13 — no fast-tier suite declares an explicit per-test `Timeout`
  //         tighter than the root budget: an explicit value overrides
  //         BOTH the tag and the root in package:test, so a 1-minute
  //         literal silently re-introduces the #1994 ceiling.
  test('B11: dart_test.yaml carries loaded-host test budgets (#1994)', () {
    final doc = loadYaml(configFile.readAsStringSync()) as YamlMap;
    expect(
      _timeoutFactor(doc['timeout']),
      greaterThanOrEqualTo(4.0),
      reason:
          'the root ceiling must be at least 4x (120s): 2x (60s) is the '
          'budget #1994 measured flaking on a loaded shared host, where '
          '`dart test -j 2` runs two suites at once because the CLI '
          'concurrency always overrides this file',
    );
    final tags = doc['tags'] as YamlMap?;
    expect(tags, isNotNull);
    for (final tag in const ['spawn', 'e2e', 'ffi']) {
      final entry = tags![tag] as YamlMap?;
      expect(
        entry,
        isNotNull,
        reason:
            '`$tag` must stay declared in dart_test.yaml — a suite using '
            'it would otherwise warn, and its relaxed budget would be '
            'missing',
      );
      expect(
        _timeoutFactor(entry!['timeout']),
        greaterThanOrEqualTo(8.0),
        reason:
            '`$tag` suites spawn external processes; their budget must be '
            'at least 8x (240s) — two sequential 75s child guards plus '
            'slack, the #1678 precedent (#1994)',
      );
    }
  });

  test('B12: every spawn-heavy fast-tier suite carries the spawn budget '
      '(#1994)', () {
    final offenders = <String>[];
    for (final entry in _fastLaneEligibleFiles().entries) {
      final source = File(entry.key).readAsStringSync();
      final scanSource = source.replaceAll(_trivialProbeRe, '');
      if (!_spawnTouchRe.hasMatch(scanSource)) continue;
      if (entry.value.contains('spawn')) continue;
      offenders.add('${entry.key} — carries: ${entry.value.join(', ')}');
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'a fast-tier suite that launches external processes needs the '
          '`spawn` budget tag (8x, 240s); on the bare root ceiling it is '
          'killed mid-setup under load and leaves a half-created temp '
          'project behind for the next test (#1994):\n'
          '${offenders.join('\n')}',
    );
  });

  test('B13: no fast-tier suite declares an explicit timeout below the root '
      'budget (#1994)', () {
    final rootFactor = _timeoutFactor(
      (loadYaml(configFile.readAsStringSync()) as YamlMap)['timeout'],
    );
    final offenders = <String>[];
    for (final entry in _fastLaneEligibleFiles().entries) {
      for (final match in _explicitTimeoutRe.allMatches(
        File(entry.key).readAsStringSync(),
      )) {
        final seconds = _durationSeconds(match.group(1)!);
        if (seconds == null) continue;
        // package:test multiplies the factor by the 30s package default.
        if (seconds >= _packageDefaultTimeoutSeconds * rootFactor) continue;
        offenders.add(
          '${entry.key} — ${seconds}s (root allows '
          '${(_packageDefaultTimeoutSeconds * rootFactor).round()}s)',
        );
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'an explicit per-test `Timeout` overrides BOTH the `spawn`/`e2e` '
          'tag budget and the root ceiling in package:test, so a literal '
          'below the root silently re-creates the #1994 ceiling for that '
          'test — raise it, or route it through '
          '`scaleDuration(...)` from the helpers\' run_'
          'zfa_source.dart:\n'
          '${offenders.join('\n')}',
    );
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

/// Source markers of a suite that reaches a REAL analyzer child THROUGH
/// THE LIB: the production certifier, built WITHOUT an injected analyzer,
/// resolves the production `dart analyze` shell-out
/// (lib/src/plugins/test/test_certifier.dart). The B5 census cannot see
/// this class — it scans the test sources for spawns, and the spawn
/// happens one layer down — which is how a real-analyzer suite stayed in
/// the fast tier under the global 60s ceiling (#1994).
///
/// The marker is split across adjacent string literals so THIS file's own
/// source never contains the assembled text — the B10 census scans every
/// fast-lane-eligible suite, this one included.
final RegExp _realAnalyzerRe = RegExp(
  'TestSelfCertif'
  r'ier\(\s*\)|ProcessScoped'
  r'Analyzer\(',
);

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

/// The package:test default per-test timeout the config's factors multiply.
const int _packageDefaultTimeoutSeconds = 30;

/// An explicit `timeout: Timeout(Duration(...))` literal. Matches only a
/// LITERAL duration: `Timeout(scaleDuration(...))` is a computed budget and
/// deliberately not matched.
final RegExp _explicitTimeoutRe = RegExp(
  r'timeout:\s*(?:const\s+)?Timeout\(\s*Duration\(([^)]*)\)',
);

/// The seconds in a `Duration(...)` argument list (`minutes: 4`), or null
/// when it is not a plain minute/second/millisecond literal.
int? _durationSeconds(String args) {
  int? valueFor(String unit, int scale) {
    final match = RegExp('$unit:\\s*(\\d+)').firstMatch(args);
    return match == null ? null : int.parse(match.group(1)!) * scale;
  }

  final minutes = valueFor('minutes', 60);
  final seconds = valueFor('seconds', 1);
  final millis = valueFor('milliseconds', 0);
  final total = (minutes ?? 0) + (seconds ?? 0);
  if (total > 0) return total;
  if (millis != null) return (millis / 1000).ceil();
  return null;
}

/// The multiplier of a dart_test.yaml timeout value (`4x` -> 4.0). A bare
/// integer is a duration in seconds and is converted against the package
/// default; `false`/absent (`null`) means "no timeout" and is reported as
/// [double.infinity].
double _timeoutFactor(Object? raw) {
  if (raw == null || raw == false) return double.infinity;
  final text = raw.toString().trim();
  final factor = RegExp(r'^(\d+(?:\.\d+)?)x$').firstMatch(text);
  if (factor != null) return double.parse(factor.group(1)!);
  final seconds = int.tryParse(text);
  if (seconds != null) return seconds / _packageDefaultTimeoutSeconds;
  return double.infinity;
}

/// Source markers proving a fast-tier suite TOUCHES an external process
/// (issue #1994) — deliberately broader than [_spawnMarkerRe], which asks a
/// different question.
///
/// [_spawnMarkerRe] feeds B5's heavyweight census: "does this suite build
/// temp projects and run `pub get` / `build_runner`?", the #1632 question
/// about which suites may ride the 30-minute CI lane. B12 asks a narrower
/// one: "does this suite's subject launch a child at all?", because ANY
/// child needs a budget above the bare root ceiling on a loaded host.
///
/// The gap that made #1994 look like a functional regression is the
/// INDIRECT spawn: `test/plugins/test/test_self_certify_test.dart` contains
/// no `Process` call — its subject (the test plugin's self-certifier, built
/// with its default scoped analyzer) shells out to a real `dart analyze`.
/// B5's markers cannot see that, so the suite sat on the 60s ceiling and
/// was killed mid-analysis under load. Hence the production seams that
/// spawn behind a constructor call (the self-certifier without an injected
/// analyzer, the process-backed scoped analyzer) and the CLI entrypoint
/// seam are markers here too.
///
/// Alternatives are split across adjacent string literals so THIS file's
/// own source never contains the assembled marker text (same guard as
/// [_spawnMarkerRe]).
final RegExp _spawnTouchRe = RegExp(
  'Process'
  r'\.run|Process'
  r'\.start|run_'
  r'zfa_source|runZfa'
  r'Source|ZfaEx'
  r'ecutable|TestSelf'
  r'Certifier\(\)|ProcessScoped'
  r'Analyzer',
);
