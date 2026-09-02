import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// Issue #891 — CI red on master: `example/` fails dependency resolution.
///
/// Contract: the example package depends on both `flutter from sdk` and
/// `zuraffa from path`. The Flutter SDK pins `meta` to an exact version
/// (1.17.0 in CI / Flutter 3.41.x), while the root package's analyzer
/// constraint (`analyzer ^14.3.0`, itself forced by `dart_style 3.1.12`
/// which requires `analyzer >=13.1.0`) requires `meta ^1.18.3`. The two are
/// irreconcilable *inside* example unless example declares its own `meta`
/// version override. Downgrading analyzer is not an option: the newest
/// analyzer accepting meta <1.18.0 is 10.0.1, far below dart_style's floor.
///
/// `--no-example` on `flutter packages get` does not guard the pipeline —
/// `flutter analyze` / `flutter test` recurse into `example/` and resolve
/// dependencies there regardless, so the override must live in the example
/// package itself.
void main() {
  final repoRoot = _findRepoRoot();
  final examplePubspecFile = File('$repoRoot/example/pubspec.yaml');

  test('example package declares a meta dependency_override (issue #891)', () {
    expect(
      examplePubspecFile.existsSync(),
      isTrue,
      reason: 'example/pubspec.yaml must exist — the test guards its shape',
    );
    final doc = loadYaml(examplePubspecFile.readAsStringSync()) as Map;
    final overrides = doc['dependency_overrides'];
    expect(
      overrides,
      isA<Map>(),
      reason:
          'example/pubspec.yaml has NO dependency_overrides section. The '
          'Flutter SDK pins meta exactly (1.17.0 on 3.41.x) while the root '
          'analyzer constraint needs meta ^1.18.3, so example/ cannot '
          'resolve without the override and every CI job dies in '
          '`flutter analyze` before running a single check.',
    );
    expect(
      (overrides as Map).containsKey('meta'),
      isTrue,
      reason: 'dependency_overrides must contain a `meta` entry',
    );
  });

  test('the meta override floor covers analyzer ≥13.1.0 (meta ^1.18.3)', () {
    final doc = loadYaml(examplePubspecFile.readAsStringSync()) as Map;
    final metaOverride = (doc['dependency_overrides'] as Map)['meta'];
    final text = metaOverride.toString();
    final floor = _versionFloor(text);
    expect(
      floor,
      isNotNull,
      reason: 'meta override "$text" must be a caret/version constraint',
    );
    // analyzer ≥13.1.0 demands meta ^1.18.3; the override floor must be at
    // least 1.18.0 so the solver never re-introduces the original conflict.
    final parts = floor!.split('.');
    final major = int.parse(parts[0]);
    final minor = int.parse(parts[1]);
    expect(
      major > 1 || (major == 1 && minor >= 18),
      isTrue,
      reason:
          'meta override floor $floor is below 1.18 — analyzer ≥13.1.0 '
          '(forced by dart_style 3.1.12) requires meta ^1.18.3 and the '
          'conflict would return',
    );
  });

  test('the meta override is a VERSION override, not a path: override', () {
    // The root pubspec explicitly forbids reintroducing path: overrides
    // (CI has no sibling checkouts). Guard that the fix stays a version
    // constraint.
    final doc = loadYaml(examplePubspecFile.readAsStringSync()) as Map;
    final metaOverride = (doc['dependency_overrides'] as Map)['meta'];
    final text = metaOverride.toString();
    expect(
      text.contains('path:'),
      isFalse,
      reason: 'meta override must be a version constraint, not a path',
    );
  });

  test(
    'root pubspec analyzer constraint still sits in dart_style-compatible range',
    () {
      // Sanity guard: the override exists BECAUSE the analyzer floor is
      // ≥13.1.0 (dart_style 3.1.12). If someone later drops the analyzer
      // constraint below 13.1.0 (compatible with Flutter's meta pin), the
      // example override becomes unnecessary — flip this guard then.
      final rootDoc =
          loadYaml(File('$repoRoot/pubspec.yaml').readAsStringSync()) as Map;
      final analyzer = (rootDoc['dependencies'] as Map)['analyzer'];
      expect(
        analyzer,
        isNotNull,
        reason: 'root package must keep a direct analyzer dependency',
      );
      final floor = _versionFloor(analyzer.toString());
      expect(floor, isNotNull);
      final parts = floor!.split('.');
      final major = int.parse(parts[0]);
      final minor = int.parse(parts[1]);
      // ≥13.1.0  → meta ^1.18.3 required → override is load-bearing.
      final needsOverride = major > 13 || (major == 13 && minor >= 1);
      expect(
        needsOverride,
        isTrue,
        reason:
            'analyzer floor dropped below 13.1.0 — if the new floor also '
            'accepts Flutter-pinned meta, remove the example meta override '
            'and relax this test',
      );
    },
  );
}

/// Walks up from the executable to locate the repository root (the dir
/// whose pubspec.yaml declares the `zuraffa` package).
String _findRepoRoot() {
  var dir = Directory.current.path;
  for (var i = 0; i < 8; i++) {
    final pubspec = File('$dir/pubspec.yaml');
    if (pubspec.existsSync()) {
      final doc = loadYaml(pubspec.readAsStringSync()) as Map;
      if (doc['name'] == 'zuraffa') return dir;
    }
    final parent = Directory(dir).parent.path;
    if (parent == dir) break;
    dir = parent;
  }
  fail(
    'could not locate the zuraffa repository root from '
    '${Directory.current.path}',
  );
}

/// Extracts the lower-bound version from a constraint string such as
/// `^1.18.3`, `1.18.3`, or `>=1.18.3 <2.0.0`.
String? _versionFloor(String constraint) {
  final caret = RegExp(r'\^(\d+\.\d+\.\d+)').firstMatch(constraint);
  if (caret != null) return caret.group(1);
  final ge = RegExp(r'>=\s*(\d+\.\d+\.\d+)').firstMatch(constraint);
  if (ge != null) return ge.group(1);
  final exact = RegExp(r'^(\d+\.\d+\.\d+)$').firstMatch(constraint.trim());
  return exact?.group(1);
}
