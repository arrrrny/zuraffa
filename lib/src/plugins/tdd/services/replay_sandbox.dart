/// `ReplaySandbox` — the clean temp project replay re-executes recorded
/// steps inside (spec 066-zfa-replay, FR-006/FR-007).
///
/// Seeded from the real project by copying the contracts the recorded
/// commands read: `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`,
/// `.zfa.json`, `build.yaml` and `dart_test.yaml` (spec 0806 FR-005 — the
/// contracts recorded `zfa build` / `dart test` commands read), the `lib/`
/// and `test/` trees, the feature's `specs/<feature>/` directory, `.specify/`
/// (memory/config), and `.dart_tool/package_config.json` (its relative
/// `rootUri`s resolve inside the copied tree, giving the sandbox working
/// package resolution without a pub get).
///
/// When a [recordedRoot] is detected (spec 0806 FR-005), the copied
/// feature registry (`specs/<feature>/tdd/*.json` — `artifacts.json`,
/// `run-state.json`, `run-baseline.json`, the #787 run-state family) is
/// re-anchored: every `<recordedRoot>/./` occurrence rewrites to
/// `<sandbox>/./` so spawned `zfa tdd wire` / `gen` / `func` steps resolve
/// their registry records inside the sandbox instead of refusing with
/// "points outside the project root".
///
/// `.git`, `build/` and the dart test kernel caches are never copied.
/// Absent sources are skipped silently. Replay never writes the real
/// project; the sandbox is deleted in the caller's `finally` unless
/// `--keep-sandbox` preserved it.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

class ReplaySandbox {
  final String path;

  const ReplaySandbox._(this.path);

  static Future<ReplaySandbox> create({
    required String projectRoot,
    required String feature,
    String? recordedRoot,
  }) async {
    final dir = await Directory.systemTemp.createTemp('zfa_replay_');
    final sandbox = ReplaySandbox._(dir.path);
    final root = projectRoot;

    Future<void> copyFile(String relative) async {
      final source = File(p.join(root, relative));
      if (!await source.exists()) return;
      final target = File(p.join(sandbox.path, relative));
      await target.parent.create(recursive: true);
      await source.copy(target.path);
    }

    Future<void> copyTree(String relative) async {
      final source = Directory(p.join(root, relative));
      if (!await source.exists()) return;
      await for (final entity in source.list(recursive: true)) {
        final relativePath = p.relative(entity.path, from: source.path);
        final segments = p.split(relativePath);
        // Never copy VCS/build/kernel-cache content, wherever it appears.
        if (segments.contains('.git') ||
            segments.contains('build') ||
            segments.contains('.dart_tool')) {
          continue;
        }
        final target = p.join(sandbox.path, relative, relativePath);
        if (entity is File) {
          await File(target).parent.create(recursive: true);
          await entity.copy(target);
        } else if (entity is Directory) {
          await Directory(target).create(recursive: true);
        }
      }
    }

    for (final file in const [
      'pubspec.yaml',
      'pubspec.lock',
      'analysis_options.yaml',
      '.zfa.json',
      // Spec 0806 FR-005: the contracts the recorded `zfa build` and
      // `dart test` commands read from the project root (cwd = sandbox).
      'build.yaml',
      'dart_test.yaml',
    ]) {
      await copyFile(file);
    }
    await copyFile(p.join('.dart_tool', 'package_config.json'));
    await copyTree('lib');
    await copyTree('test');
    await copyTree(p.join('specs', feature));
    await copyTree('.specify');
    if (recordedRoot != null && recordedRoot.isNotEmpty) {
      await _reAnchorRegistry(
        sandboxPath: sandbox.path,
        feature: feature,
        recordedRoot: recordedRoot,
      );
    }
    return sandbox;
  }

  /// Rewrite every `<recordedRoot>/./` occurrence inside the copied
  /// feature registry (`specs/<feature>/tdd/*.json`) into
  /// `<sandbox>/./` — plain text replacement over the JSON documents (the
  /// `/` separator is never JSON-escaped, and only anchored paths match).
  /// Registries without the anchor prefix copy verbatim.
  static Future<void> _reAnchorRegistry({
    required String sandboxPath,
    required String feature,
    required String recordedRoot,
  }) async {
    final tddDir = Directory(p.join(sandboxPath, 'specs', feature, 'tdd'));
    if (!await tddDir.exists()) return;
    final anchor = '$recordedRoot/./';
    final replacement = '$sandboxPath/./';
    await for (final entity in tddDir.list()) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.json')) continue;
      final raw = await entity.readAsString();
      if (!raw.contains(anchor)) continue;
      await entity.writeAsString(raw.replaceAll(anchor, replacement));
    }
  }

  Future<void> delete() async {
    final dir = Directory(path);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
