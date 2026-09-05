// Command-level tests for `zfa corpus catalog` — epic #1017 CORPUS-WALK,
// child issue "Catalog ZikZak specs; classify CORE/SKIN".
//
// The catalog is the walk's input contract: it resolves the target's
// features (the corpus manifest, or `--source` directly), classifies each
// spec CORE (engine seam) or SKIN (presentation seam), and writes the
// committed catalog at `corpus/catalogs/<target>.json` — committed, so
// the classification is reviewable and preserved across regenerations
// (manual edits stick unless `--reclassify`).
//
// Fast tier: pure file I/O through the in-process CliRunner — no
// subprocesses, no network.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/corpus_walk_fixture.dart';

void main() {
  late CorpusWalkFixture fx;

  Future<String> catalog(List<String> extra) {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing([
      'corpus',
      'catalog',
      '--project',
      fx.root.path,
      ...extra,
    ]);
  }

  setUp(() async {
    fx = await CorpusWalkFixture.create();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  group('A1 — registration and arg surface', () {
    test('the corpus family lists catalog alongside import', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(['corpus']);
      expect(out, contains('catalog'));
      expect(out, contains('import'));
    });

    test(
      'catalog exposes --target, --source, --reclassify, --project',
      () async {
        final out = await catalog(['--help']);
        expect(out, contains('--target'));
        expect(out, contains('--source'));
        expect(out, contains('--reclassify'));
        expect(out, contains('--project'));
      },
    );

    test('catalog without --target is a usage error', () async {
      final out = await catalog([]);
      expect(out, contains('target'));
      expect(exitCode, 2);
    });
  });

  group('A2 — CORE/SKIN classification', () {
    test('an engine spec classifies CORE, a presentation spec SKIN', () async {
      await fx.writeManifest([
        (name: 'auth-engine', ready: true, reason: ''),
        (name: 'login-screen', ready: true, reason: ''),
      ]);
      await fx.writeSpec('auth-engine', CorpusWalkFixture.coreSpec('auth'));
      await fx.writeSpec('login-screen', CorpusWalkFixture.skinSpec('login'));

      final out = await catalog(['--target', CorpusWalkFixture.target]);
      expect(out, contains('[corpus] auth-engine -> CORE'));
      expect(out, contains('[corpus] login-screen -> SKIN'));
      expect(exitCode, 0, reason: out);
    });

    test('the machine summary line counts core/skin and reports ok', () async {
      await fx.writeManifest([
        (name: 'auth-engine', ready: true, reason: ''),
        (name: 'login-screen', ready: true, reason: ''),
        (name: 'profile-view', ready: true, reason: ''),
      ]);
      await fx.writeSpec('auth-engine', CorpusWalkFixture.coreSpec('auth'));
      await fx.writeSpec('login-screen', CorpusWalkFixture.skinSpec('login'));
      await fx.writeSpec('profile-view', CorpusWalkFixture.skinSpec('profile'));

      final out = await catalog(['--target', CorpusWalkFixture.target]);
      final lastLine = out.trim().split('\n').last;
      expect(
        lastLine,
        startsWith(
          'corpus catalog: target=zik_zak source=manifest features=3 '
          'core=1 skin=2 result=ok',
        ),
        reason: out,
      );
    });

    test('a neutral spec falls back to CORE (engine-first default)', () async {
      await fx.writeManifest([
        (name: 'neutral-thing', ready: true, reason: ''),
      ]);
      await fx.writeSpec(
        'neutral-thing',
        CorpusWalkFixture.neutralSpec('neutral-thing'),
      );
      final out = await catalog(['--target', CorpusWalkFixture.target]);
      expect(out, contains('[corpus] neutral-thing -> CORE'));
    });
  });

  group('A3 — the committed catalog file', () {
    test('writes corpus/catalogs/<target>.json with name, classification, '
        'sha256, readiness', () async {
      await fx.writeManifest([
        (name: 'auth-engine', ready: true, reason: ''),
        (name: 'login-screen', ready: true, reason: ''),
      ]);
      await fx.writeSpec('auth-engine', CorpusWalkFixture.coreSpec('auth'));
      await fx.writeSpec('login-screen', CorpusWalkFixture.skinSpec('login'));

      await catalog(['--target', CorpusWalkFixture.target]);

      final json = fx.readJsonMap(fx.catalogPath);
      expect(json['target'], CorpusWalkFixture.target);
      final features = json['features'] as List;
      expect(features.length, 2);
      final auth =
          features.firstWhere((f) => (f as Map)['name'] == 'auth-engine')
              as Map;
      expect(auth['classification'], 'CORE');
      expect(auth['ready'], isTrue);
      expect(
        auth['spec_sha256'],
        matches(RegExp(r'^[0-9a-f]{64}$')),
        reason: 'the catalog records the spec content hash',
      );
      final login =
          features.firstWhere((f) => (f as Map)['name'] == 'login-screen')
              as Map;
      expect(login['classification'], 'SKIN');
    });

    test('not-ready features are cataloged with their reason', () async {
      await fx.writeManifest([
        (name: 'gap-feature', ready: false, reason: 'no acceptance scenarios'),
      ]);
      await fx.writeSpec('gap-feature', CorpusWalkFixture.coreSpec('gap'));

      final out = await catalog(['--target', CorpusWalkFixture.target]);
      expect(out, contains('not-ready'));
      expect(out, contains('no acceptance scenarios'));
      final json = fx.readJsonMap(fx.catalogPath);
      final feature = (json['features'] as List).first as Map;
      expect(feature['ready'], isFalse);
      expect(feature['reason'], 'no acceptance scenarios');
    });

    test(
      'regeneration is deterministic (byte-identical except timestamps)',
      () async {
        await fx.writeManifest([
          (name: 'auth-engine', ready: true, reason: ''),
        ]);
        await fx.writeSpec('auth-engine', CorpusWalkFixture.coreSpec('auth'));
        await catalog(['--target', CorpusWalkFixture.target]);
        final first = fx.readJsonMap(fx.catalogPath);

        await catalog(['--target', CorpusWalkFixture.target]);
        final second = fx.readJsonMap(fx.catalogPath);

        first.remove('generated_at');
        second.remove('generated_at');
        expect(second, equals(first));
      },
    );
  });

  group('A4 — source resolution', () {
    test('no manifest and no --source stops with import guidance '
        '(exit 2)', () async {
      final out = await catalog(['--target', CorpusWalkFixture.target]);
      expect(out, contains('corpus catalog'));
      expect(out, contains('import'));
      expect(exitCode, 2);
    });

    test(
      '--source walks the source corpus directly (no manifest needed)',
      () async {
        final source = Directory.systemTemp.createTempSync('walk_source_');
        addTearDown(() => source.deleteSync(recursive: true));
        for (final name in ['auth-engine', 'login-screen']) {
          Directory(p.join(source.path, name)).createSync(recursive: true);
        }
        File(
          p.join(source.path, 'auth-engine', 'spec.md'),
        ).writeAsStringSync(CorpusWalkFixture.coreSpec('auth'));
        File(
          p.join(source.path, 'login-screen', 'spec.md'),
        ).writeAsStringSync(CorpusWalkFixture.skinSpec('login'));

        final out = await catalog([
          '--target',
          CorpusWalkFixture.target,
          '--source',
          source.path,
        ]);
        expect(out, contains('[corpus] auth-engine -> CORE'));
        expect(out, contains('[corpus] login-screen -> SKIN'));
        expect(exitCode, 0, reason: out);
        final json = fx.readJsonMap(fx.catalogPath);
        expect(json['source'], 'source');
      },
    );
  });

  group('A5 — manual classifications are preserved', () {
    test(
      'regeneration keeps a committed CORE->SKIN edit (same spec hash)',
      () async {
        await fx.writeManifest([
          (name: 'auth-engine', ready: true, reason: ''),
        ]);
        await fx.writeSpec('auth-engine', CorpusWalkFixture.coreSpec('auth'));
        await catalog(['--target', CorpusWalkFixture.target]);

        // The maintainer's manual override in the committed catalog.
        final file = File(fx.catalogPath);
        final edited = file.readAsStringSync().replaceAll(
          '"classification": "CORE"',
          '"classification": "SKIN"',
        );
        file.writeAsStringSync(edited);

        final out = await catalog(['--target', CorpusWalkFixture.target]);
        expect(out, contains('[corpus] auth-engine -> SKIN'));
        expect(
          out,
          contains('preserved'),
          reason: 'the edit is named preserved',
        );

        // --reclassify discards the edit and recomputes.
        final out2 = await catalog([
          '--target',
          CorpusWalkFixture.target,
          '--reclassify',
        ]);
        expect(out2, contains('[corpus] auth-engine -> CORE'));
      },
    );
  });

  group('A6 — corrupt state stops honestly', () {
    test('a manifest feature whose specs/<f>/spec.md is missing stops '
        'with recovery guidance (exit 2)', () async {
      await fx.writeManifest([
        (name: 'ghost-feature', ready: true, reason: ''),
      ]);
      // No specs/ghost-feature/spec.md written.
      final out = await catalog(['--target', CorpusWalkFixture.target]);
      expect(out, contains('ghost-feature'));
      expect(out, contains('--> fix'));
      expect(exitCode, 2);
    });
  });
}
