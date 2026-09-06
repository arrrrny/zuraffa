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
/// Every `package:zuraffa/*` import the generator EMITS must resolve
/// against BOTH ends of the supported core range — the OLDEST
/// supported core (git tag `v6.1.0`, materialized here via
/// `git archive`) and the NEWEST master (this checkout). A URI that
/// only exists on master (the `skin.dart` barrel) must be a
/// floor-registered surface gated at runtime — never silently
/// emitted, or every generated slice dies once on version skew.
void main() {
  final repoRoot = _findRepoRoot();
  final masterCore = InstalledCore(
    root: repoRoot,
    version: _pubspecVersion(repoRoot),
  );

  late Directory oldCoreDir;
  late InstalledCore oldCore;

  setUpAll(() async {
    oldCoreDir = await _materializeTag('v6.1.0', repoRoot);
    oldCore = InstalledCore(
      root: oldCoreDir.path,
      version: _pubspecVersion(oldCoreDir.path),
    );
  });

  tearDownAll(() async {
    if (oldCoreDir.existsSync()) await oldCoreDir.delete(recursive: true);
  });

  group('the two ends of the matrix', () {
    test('master end exposes the skin barrel', () {
      expect(masterCore.exposes('skin.dart'), isTrue);
    });

    test('oldest supported core (v6.1.0 tag) does NOT expose it', () {
      // The reproduced #1197 skew: published 6.1.0 predates the
      // runtime skin-contract kit (spec 1102). Version strings alone
      // cannot arbitrate — the tag shipped pubspec 6.0.1 — so the
      // contract gates on AVAILABILITY and stamps floors advisorially.
      expect(oldCore.exposes('skin.dart'), isFalse);
      expect(oldCore.version, '6.0.1');
      expect(masterCore.version, isNotNull);
    });
  });

  group('emitted imports resolve on both ends', () {
    test('skin kit emission (zfa skin kit / view --skin / app shell)', () {
      final src = const SkinContractKitBuilder().build(routes: ['home']);
      final uris = _zuraffaImports(src);
      expect(uris, contains('skin.dart'));

      // Master end: the emission is self-consistent with master.
      for (final uri in uris) {
        expect(
          masterCore.exposes(uri),
          isTrue,
          reason: 'skin kit emits package:zuraffa/$uri — missing on MASTER',
        );
      }
      // Old end: skin.dart is floor-registered, and the runtime gate
      // refuses emission when the resolved core lacks it (the gate
      // itself is proven in bug_1197_skew_contract_test.dart). The
      // static contract here: no URI may be missing from the old end
      // WITHOUT a declared floor.
      for (final uri in uris) {
        if (!oldCore.exposes(uri)) {
          expect(
            coreApiFloors.where((f) => f.uri == uri),
            hasLength(1),
            reason:
                'package:zuraffa/$uri (skin kit) does not exist in the '
                'oldest supported core (v6.1.0) and is NOT '
                'floor-registered — every generated slice would break '
                'on the published core (issue #1197). Register it in '
                'coreApiFloors and gate the emission site.',
          );
        }
      }
    });

    test('app router emission with --skin-audit', () {
      final src = const AppShellBuilder().buildAppRouter(skinAudit: true);
      final uris = _zuraffaImports(src);
      expect(uris, contains('skin.dart'));
      for (final uri in uris) {
        expect(
          masterCore.exposes(uri),
          isTrue,
          reason: '$uri missing on MASTER',
        );
        if (!oldCore.exposes(uri)) {
          expect(
            coreApiFloors.where((f) => f.uri == uri),
            hasLength(1),
            reason: '$uri missing on oldest core without a floor',
          );
        }
      }
    });

    test('view emission with --skin', () {
      const builder = ViewClassBuilder();
      final src = builder.build(_viewSpec(withSkinAudit: true));
      final uris = _zuraffaImports(src);
      expect(uris, contains('skin.dart'));
      for (final uri in uris) {
        expect(
          masterCore.exposes(uri),
          isTrue,
          reason: '$uri missing on MASTER',
        );
        if (!oldCore.exposes(uri)) {
          expect(
            coreApiFloors.where((f) => f.uri == uri),
            hasLength(1),
            reason: '$uri missing on oldest core without a floor',
          );
        }
      }
    });

    test('bare emissions (no skin) import only two-end-stable APIs', () {
      final sources = [
        const AppShellBuilder().buildAppRouter(skinAudit: false),
        const ViewClassBuilder().build(_viewSpec(withSkinAudit: false)),
      ];
      for (final src in sources) {
        for (final uri in _zuraffaImports(src)) {
          expect(
            oldCore.exposes(uri),
            isTrue,
            reason:
                'bare emission uses package:zuraffa/$uri — missing on '
                'the oldest supported core',
          );
          expect(masterCore.exposes(uri), isTrue);
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
          final uri = entry.key;
          expect(
            masterCore.exposes(uri),
            isTrue,
            reason:
                '${entry.value} emits package:zuraffa/$uri — file does '
                'not exist on MASTER (generator self-inconsistent)',
          );
          if (!oldCore.exposes(uri)) {
            expect(
              coreApiFloors.where((f) => f.uri == uri),
              hasLength(1),
              reason:
                  '${entry.value} emits package:zuraffa/$uri which the '
                  'oldest supported core lacks — register it in '
                  'coreApiFloors and gate its emission site (#1197)',
            );
          }
        }
      },
    );
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
  final libDir = Directory(p.join(repoRoot, 'lib'));
  for (final file in libDir.listSync(recursive: true, followLinks: false)) {
    if (file is! File || !file.path.endsWith('.dart')) continue;
    final src = file.readAsStringSync();
    for (final m in directive.allMatches(src)) {
      found[m.group(1)!] = p.relative(file.path, from: repoRoot);
    }
    // Raw triple-quoted emission templates (the skin kit) are covered
    // by the builder-output scans above — this sweep stays on the
    // code_builder Directive API to avoid false positives from the
    // generator's own self-imports.
  }
  return found;
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
