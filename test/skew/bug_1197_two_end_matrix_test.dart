@Tags(['e2e'])
library;

import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:zuraffa/src/plugins/app_shell/builders/app_shell_builder.dart';
import 'package:zuraffa/src/plugins/view/builders/view_class_builder.dart';
import 'package:zuraffa/src/skew/skew_contract.dart';
import 'package:zuraffa/src/skin/builders/skin_contract_kit_builder.dart';

/// Issue #1197 (part of #908 P0): the two-end skew matrix.
///
/// The supported core range is the generator's own major. Every
/// `package:zuraffa/*` import the generator EMITS must resolve against
/// BOTH ends of that range — the OLDEST supported core (the lowest
/// stable `v<major>.*` tag, materialized via `git archive`) and the
/// NEWEST master (this checkout). A URI that only exists on master (the
/// shape of the `skin.dart` barrel at #1197) must be floor-registered
/// and gated at runtime — never silently emitted, or every generated
/// slice dies once on version skew.
///
/// Before the major's first release no stable tag exists: the old end
/// IS this checkout, and the matrix says so instead of borrowing a
/// core from another major.
void main() {
  final repoRoot = _findRepoRoot();
  final masterCore = InstalledCore(
    root: repoRoot,
    version: _pubspecVersion(repoRoot),
  );
  final oldestTag = _oldestStableTag(repoRoot, generatorMajor);

  Directory? oldCoreDir;
  InstalledCore? oldCore;

  setUpAll(() async {
    if (oldestTag == null) return;
    oldCoreDir = await _materializeTag(oldestTag, repoRoot);
    oldCore = InstalledCore(
      root: oldCoreDir!.path,
      version: _pubspecVersion(oldCoreDir!.path),
    );
  });

  tearDownAll(() async {
    if (oldCoreDir != null) await oldCoreDir!.delete(recursive: true);
  });

  /// The static half of the contract, for one emitted URI: it exists
  /// on master, and it exists on the oldest supported core or carries
  /// a declared floor.
  void expectTwoEndSafe(String uri, String context) {
    expect(
      masterCore.exposes(uri),
      isTrue,
      reason:
          '$context emits package:zuraffa/$uri — file does not exist '
          'on MASTER (generator self-inconsistent)',
    );
    if (oldCore == null || oldCore!.exposes(uri)) return;
    expect(
      coreApiFloors.where((f) => f.uri == uri),
      hasLength(1),
      reason:
          '$context emits package:zuraffa/$uri which the oldest '
          'supported core ($oldestTag) lacks — register it in '
          'coreApiFloors and gate the emission site (#1197)',
    );
  }

  group('the two ends of the matrix', () {
    test('master end exposes the skin barrel', () {
      expect(masterCore.exposes('skin.dart'), isTrue);
    });

    if (oldestTag == null) {
      test('pre-release: no stable v$generatorMajor.* tag yet, so the old end '
          'IS this checkout', () {
        expect(oldCore, isNull);
        expect(
          _pubspecVersion(repoRoot),
          startsWith('$generatorMajor.'),
          reason:
              'the generator must be on the major it derives its '
              'floor from',
        );
      });
    } else {
      test('oldest supported core ($oldestTag) is an in-major core', () {
        // Version strings cannot arbitrate a minor (the reproduced #1197
        // skew: a tag shipped a different pubspec version than its name)
        // — but the major is the contract, and the surface gates below
        // stay availability-based.
        expect(
          compareVersions(oldCore!.version!, supportedCoreFloor),
          greaterThanOrEqualTo(0),
        );
        expect(oldCore!.exposes('skin.dart'), isTrue);
        expect(masterCore.version, isNotNull);
      });
    }
  });

  group('emitted imports resolve on both ends', () {
    test('skin kit emission (zfa skin kit / view --skin / app shell)', () {
      final src = const SkinContractKitBuilder().build(routes: ['home']);
      final uris = _zuraffaImports(src);
      expect(uris, contains('skin.dart'));
      for (final uri in uris) {
        expectTwoEndSafe(uri, 'skin kit');
      }
    });

    test('app router emission with --skin-audit', () {
      final src = const AppShellBuilder().buildAppRouter(skinAudit: true);
      final uris = _zuraffaImports(src);
      expect(uris, contains('skin.dart'));
      for (final uri in uris) {
        expectTwoEndSafe(uri, 'app router');
      }
    });

    test('view emission with --skin', () {
      const builder = ViewClassBuilder();
      final src = builder.build(_viewSpec(withSkinAudit: true));
      final uris = _zuraffaImports(src);
      expect(uris, contains('skin.dart'));
      for (final uri in uris) {
        expectTwoEndSafe(uri, 'view');
      }
    });

    test('bare emissions (no skin) import only two-end-stable APIs', () {
      final sources = [
        const AppShellBuilder().buildAppRouter(skinAudit: false),
        const ViewClassBuilder().build(_viewSpec(withSkinAudit: false)),
      ];
      for (final src in sources) {
        for (final uri in _zuraffaImports(src)) {
          expectTwoEndSafe(uri, 'bare emission');
        }
      }
    });
  });

  group('the whole emission surface (static sweep)', () {
    test(
      'every Directive.import package:zuraffa URI is two-end safe or floored',
      () {
        final uris = _sweepDirectiveImports(repoRoot);
        expect(uris, isNotEmpty);
        for (final entry in uris.entries) {
          expectTwoEndSafe(entry.key, entry.value);
        }
      },
    );

    test('every surface a gate requires exists on master', () {
      // The runtime half's own precondition: `requireSurfaces` is fed
      // URI literals at its emission sites. One that master does not
      // expose would refuse every emission, everywhere.
      final required = _sweepRequiredUris(repoRoot);
      expect(required, containsAll(['skin.dart', 'simulation.dart']));
      for (final uri in required) {
        expect(
          masterCore.exposes(uri),
          isTrue,
          reason:
              'a SkewContract gate requires package:zuraffa/$uri — '
              'file does not exist on MASTER',
        );
      }
    });
  });
}

/// The `--skin` view emission fixture (same shape the #1102 unit tests
/// pin — ViewClassSpec with the auditor wrap requested).
ViewClassSpec _viewSpec({required bool withSkinAudit}) => ViewClassSpec(
  viewName: 'ProductView',
  controllerName: 'ProductController',
  presenterName: 'ProductPresenter',
  entityName: 'Product',
  repoFields: const [],
  routeFields: const [],
  repoPresenterArgs: const [],
  initialMethodCall: Block((b) => b),
  imports: const ['package:flutter/material.dart'],
  withState: false,
  withSkinAudit: withSkinAudit,
);

/// Every `package:zuraffa/<uri>` import in [src], normalized to
/// lib-relative paths ('skin.dart', 'zuraffa.dart', 'mock.dart', ...).
Set<String> _zuraffaImports(String src) {
  final matches = RegExp(
    r"import\s+'package:zuraffa/([a-zA-Z0-9_/.-]+\.dart)'",
  ).allMatches(src);
  return matches.map((m) => m.group(1)!).toSet();
}

/// Static sweep over the generator source: every code_builder
/// `Directive.import('package:zuraffa/...')` emission site.
/// Returns URI → emitting file (repo-relative).
Map<String, String> _sweepDirectiveImports(String repoRoot) {
  final found = <String, String>{};
  final directive = RegExp(
    r"""Directive\.import\(\s*'package:zuraffa/([a-zA-Z0-9_/.-]+\.dart)'""",
  );
  for (final entry in _libSources(repoRoot).entries) {
    for (final m in directive.allMatches(entry.value)) {
      found[m.group(1)!] = entry.key;
    }
    // Raw triple-quoted emission templates (the skin kit) are covered
    // by the builder-output scans above — this sweep stays on the
    // code_builder Directive API to avoid false positives from the
    // generator's own self-imports.
  }
  return found;
}

/// Every URI literal handed to a `requiredUris: [...]` gate.
Set<String> _sweepRequiredUris(String repoRoot) {
  final found = <String>{};
  final list = RegExp(r'requiredUris:\s*(?:const\s*)?\[([^\]]*)\]');
  for (final src in _libSources(repoRoot).values) {
    for (final m in list.allMatches(src)) {
      for (final uri in RegExp(r"'([^']+)'").allMatches(m.group(1)!)) {
        found.add(uri.group(1)!);
      }
    }
  }
  return found;
}

/// lib-relative path → source, for every hand-written Dart file under
/// lib/ (generated parts excluded).
Map<String, String> _libSources(String repoRoot) {
  final sources = <String, String>{};
  final libDir = Directory(p.join(repoRoot, 'lib'));
  for (final file in libDir.listSync(recursive: true, followLinks: false)) {
    if (file is! File || !file.path.endsWith('.dart')) continue;
    final relative = p.relative(file.path, from: repoRoot);
    if (relative.startsWith('lib${p.separator}_br_')) continue;
    sources[relative] = file.readAsStringSync();
  }
  return sources;
}

/// The lowest stable `v<major>.*` tag (pre-release tags excluded: a
/// caret constraint never resolves them), or null before the major's
/// first release.
String? _oldestStableTag(String repoRoot, int major) {
  final result = Process.runSync('git', [
    'tag',
    '--list',
    'v$major.*',
  ], workingDirectory: repoRoot);
  final tags =
      (result.stdout as String)
          .split('\n')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty && !t.contains('-'))
          .toList()
        ..sort((a, b) => compareVersions(a.substring(1), b.substring(1)));
  return tags.isEmpty ? null : tags.first;
}

/// Materializes [tag]'s `lib/` + `pubspec.yaml` into a temp dir via
/// `git archive` — no checkout, no worktree, CI-safe.
Future<Directory> _materializeTag(String tag, String repoRoot) async {
  final dest = await Directory.systemTemp.createTemp('zfa1197_tag_${tag}_');
  final result = await Process.run('bash', [
    '-c',
    'git archive $tag lib pubspec.yaml | tar -x -C "${dest.path}"',
  ], workingDirectory: repoRoot);
  if (result.exitCode != 0) {
    await dest.delete(recursive: true);
    throw StateError('git archive $tag failed: ${result.stderr}');
  }
  return dest;
}

String _findRepoRoot() {
  var dir = Directory.current.path;
  while (true) {
    final pubspec = File(p.join(dir, 'pubspec.yaml'));
    if (pubspec.existsSync() &&
        pubspec.readAsStringSync().startsWith('name: zuraffa')) {
      return dir;
    }
    final parent = p.dirname(dir);
    if (parent == dir) {
      throw StateError(
        'zuraffa repo root not found from ${Directory.current.path}',
      );
    }
    dir = parent;
  }
}

String? _pubspecVersion(String dir) {
  final file = File(p.join(dir, 'pubspec.yaml'));
  if (!file.existsSync()) return null;
  final match = RegExp(
    r'^version:\s*(.+)$',
    multiLine: true,
  ).firstMatch(file.readAsStringSync());
  return match?.group(1)?.trim();
}
