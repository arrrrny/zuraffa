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
// Behaviors:
//   B1 — every regression-tier test file carries the `regression` tag.
//   B2 — dart_test.yaml defines the regression preset (include_tags
//        regression).

import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  final tierDir = Directory('test/regression');
  final configFile = File('dart_test.yaml');

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
    final ci =
        loadYaml(File('.github/workflows/ci.yaml').readAsStringSync())
            as YamlMap;
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
      // The census must not flag itself: this file's own source embeds
      // the spawn-marker pattern text it scans for.
      if (file == 'test/tier_integrity_test.dart') continue;
      final source = File(file).readAsStringSync();
      final spawns = _spawnMarkerRe.hasMatch(source);
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
    for (final entity in Directory('test').listSync(recursive: true)) {
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
}

/// Every `_test.dart` file under `test/` whose suite-level `@Tags`
/// annotation contains `e2e`, mapped to its full tag set. Scanned once.
Map<String, Set<String>> _e2eTaggedFiles() =>
    _cachedE2eFiles ??= _scanE2eTaggedFiles();

Map<String, Set<String>>? _cachedE2eFiles;

/// The suite-level `@Tags` annotation's tag set of [path] (empty when the
/// file declares none).
final RegExp _tagsAnnotationRe = RegExp(r'@Tags\(\[([^\]]*)\]\)');

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
/// helpers (`run_zfa_source.dart` and friends) or direct `Process` use.
final RegExp _spawnMarkerRe = RegExp(
  r'Process\.run|Process\.start|run_zfa_source|runZfaSource|'
  r'zfaExecutable|dartTest\(|runZfa\(',
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
  for (final entity in Directory('test').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('_test.dart')) continue;
    final tags = _suiteTags(entity.path);
    if (tags.intersection({'slow', 'e2e', 'flutter'}).isNotEmpty) continue;
    eligible[entity.path] = tags;
  }
  return eligible;
}

Map<String, Set<String>> _scanE2eTaggedFiles() {
  final tagged = <String, Set<String>>{};
  for (final entity in Directory('test').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('_test.dart')) continue;
    final annotation = RegExp(
      r'@Tags\(\[([^\]]*)\]\)',
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
