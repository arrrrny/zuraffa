@Tags(['regression'])
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// Issue #891 → #1189 → #1206 — the example package's meta override history.
///
/// #891: `example/` depends on BOTH `flutter from sdk` (which pinned `meta`
/// to an exact version — 1.17.0 on Flutter 3.41.x) and `zuraffa from path`
/// (whose analyzer constraint, forced up by `dart_style 3.1.12`, needed
/// `meta ^1.18.3`). The two were irreconcilable *inside* example, so example
/// carried a `meta: ^1.18.3` VERSION override. `--no-example` does not guard
/// the pipeline — `flutter analyze` / `flutter test` recurse into `example/`
/// and resolve there regardless, so the override had to live in the example
/// package itself.
///
/// #1189 (fix shipped in #1206): the conflict is gone from both sides —
/// zuraffa moved `test` into dev_dependencies and widened analyzer to
/// `>=14.0.0 <15.0.0`, and Flutter 3.47.x re-pinned `meta` to `^1.18.3`. The
/// override was dropped ON PURPOSE and the contract flipped:
/// `example/pubspec.yaml` must now carry ZERO `dependency_overrides`. A
/// re-introduced override (version or `path:`) would silently re-couple the
/// committed example to a pin that no longer matches the Flutter SDK under
/// test, and would mask the next solver conflict instead of surfacing it.
///
/// The end-to-end resolution proof is delegated to
/// `tools/flutter_smoke_gate.sh` (the `flutter_consumer_smoke` CI job): it
/// resolves `example/` plus a synthesized core+flutter_test app with zero
/// overrides on every run. This file stays as the cheap file-shape guard so
/// an override cannot creep back in unnoticed between gate runs.
void main() {
  final repoRoot = _findRepoRoot();
  final examplePubspecFile = File('$repoRoot/example/pubspec.yaml');

  test('example/pubspec.yaml exists (the file-shape guard needs it)', () {
    expect(
      examplePubspecFile.existsSync(),
      isTrue,
      reason: 'example/pubspec.yaml must exist — the test guards its shape',
    );
  });

  test('example/pubspec.yaml carries ZERO dependency_overrides '
      '(issue #891 contract flipped by #1206)', () {
    final doc = loadYaml(examplePubspecFile.readAsStringSync()) as Map;
    expect(
      doc['dependency_overrides'],
      isNull,
      reason:
          'example/pubspec.yaml re-introduced a dependency_overrides '
          'section. The #891 override (meta ^1.18.3) was dropped in #1206: '
          'Flutter 3.47.x re-pinned meta and the zuraffa-side #1189 fix '
          '(test in dev_dependencies, analyzer >=14.0.0 <15.0.0) closed '
          'the solver conflict, so the committed example must resolve with '
          'ZERO overrides. This also keeps the root-pubspec prohibition on '
          'path: overrides from sibling checkouts intact — no section '
          'means nothing can override, by version or by path. If a real '
          'conflict returns, fix the constraint (and prove it with '
          'tools/flutter_smoke_gate.sh) instead of silencing it here.',
    );
  });

  test('the zero-overrides resolution proof is delegated to '
      'tools/flutter_smoke_gate.sh', () {
    // This dart_core lane cannot resolve a Flutter app; the proof that the
    // zero-overrides example graph actually closes lives in the
    // flutter_consumer_smoke CI job (#1206). Guard that the delegation
    // target exists and still covers example/ — if the gate moves or is
    // renamed, update this pointer in the same change.
    final gate = File('$repoRoot/tools/flutter_smoke_gate.sh');
    expect(
      gate.existsSync(),
      isTrue,
      reason:
          'tools/flutter_smoke_gate.sh is missing — it is the delegated '
          'proof that example/ resolves with zero dependency_overrides '
          '(#1206). Restore it or update this guard alongside the move.',
    );
    expect(
      gate.readAsStringSync(),
      contains('example'),
      reason:
          'flutter_smoke_gate.sh no longer references example/ — the '
          'zero-overrides resolution proof (#1206 stage 1) is gone. '
          'Restore example/ coverage in the gate.',
    );
  });
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
