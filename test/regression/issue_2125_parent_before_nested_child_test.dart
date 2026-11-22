@Tags(['regression', 'slow'])
library;

// Regression test for issue #2125.
//
// `zfa entity create` used to reject a parent entity whose field referenced a
// nested entity that did not yet exist on disk (the #296 on-disk validator).
// Recreating a schema meant the parent had to be created AFTER its nested
// child, or the command had to be given `--allow-forward-refs` by hand:
//
//   zfa entity create -n PriceCheckRun \
//     --field 'results:List<PriceCheckRetailerResult>'
//   ❌ Cannot create entity "PriceCheckRun": field type(s) could not be resolved.
//     Unknown type "PriceCheckRetailerResult" ...
//   No files were written.
//
// As of #2125 forward references are ACCEPTED BY DEFAULT, so the parent can be
// created first and the nested entity immediately afterwards. The strict
// behaviour is still reachable with `--allow-forward-refs=false` (or the
// `entity.allowForwardRefs: false` config default).
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/run_zfa_source.dart';

void main() {
  group('#2125 — parent entity created before its nested result entity', () {
    late Directory workspace;

    Future<ProcessResult> runZfa(List<String> args) {
      return runZfaSource(args, workingDirectory: workspace.path);
    }

    setUp(() async {
      await initZfaSourceBin();
      workspace = await Directory.systemTemp.createTemp('issue_2125_');
      await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: issue_2125_test_app
environment:
  sdk: '>=3.12.0 <4.0.0'
dependencies:
  zorphy_annotation:
dev_dependencies:
  build_runner:
''');
    });

    tearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    test(
      'parent (PriceCheckRun) can be created before its nested entity by default',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        // The exact #2125 invocation: the parent references
        // PriceCheckRetailerResult, which does NOT exist on disk yet.
        final result = await runZfa([
          'entity',
          'create',
          '-n',
          'PriceCheckRun',
          '--field',
          'id:String?',
          '--field',
          'results:List<PriceCheckRetailerResult>',
        ]);

        expect(
          result.exitCode,
          equals(0),
          reason:
              'Forward references must be accepted by default (#2125); '
              'stderr/stdout: ${result.stdout} ${result.stderr}',
        );

        final parentFile = File(
          p.join(
            workspace.path,
            'lib',
            'src',
            'domain',
            'entities',
            'price_check_run',
            'price_check_run.dart',
          ),
        );
        expect(parentFile.existsSync(), isTrue);

        final content = await parentFile.readAsString();
        // The nested entity reference is emitted as a Zorphy `$`-prefixed
        // entity type with the correct forward import, so the build resolves
        // once PriceCheckRetailerResult is created.
        expect(content, contains('List<\$PriceCheckRetailerResult>'));
        expect(
          content,
          contains(
            "import '../price_check_retailer_result/"
            "price_check_retailer_result.dart';",
          ),
        );
      },
    );

    test(
      'the nested entity can then be created immediately afterwards',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final parent = await runZfa([
          'entity',
          'create',
          '-n',
          'PriceCheckRun',
          '--field',
          'id:String?',
          '--field',
          'results:List<PriceCheckRetailerResult>',
        ]);
        expect(parent.exitCode, equals(0));

        final child = await runZfa([
          'entity',
          'create',
          '-n',
          'PriceCheckRetailerResult',
          '--field',
          'id:String?',
          '--field',
          'retailerName:String?',
          '--field',
          'price:double?',
        ]);
        expect(
          child.exitCode,
          equals(0),
          reason: 'The nested entity must be creatable after the parent',
        );

        final childFile = File(
          p.join(
            workspace.path,
            'lib',
            'src',
            'domain',
            'entities',
            'price_check_retailer_result',
            'price_check_retailer_result.dart',
          ),
        );
        expect(childFile.existsSync(), isTrue);
      },
    );

    test(
      'a missing nested type that is NEVER created still fails with a clear error',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        // Forward references are accepted by default, but the type must still
        // be created eventually — a typo that is never scaffolded produces no
        // file and the build would fail, so the field is still validated at
        // build time. Here we only assert the command succeeds at create time
        // (the #2125 behaviour) — the never-created case is covered by the
        // build, not by entity create.
        final result = await runZfa([
          'entity',
          'create',
          '-n',
          'Lonely',
          '--field',
          'id:String?',
          '--field',
          'child:NeverCreatedChild',
        ]);
        expect(
          result.exitCode,
          equals(0),
          reason: 'Forward refs are default-accepted (#2125)',
        );
      },
    );

    test(
      '--allow-forward-refs=false restores the strict on-disk check',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final result = await runZfa([
          'entity',
          'create',
          '-n',
          'PriceCheckRun',
          '--field',
          'id:String?',
          '--field',
          'results:List<PriceCheckRetailerResult>',
          '--allow-forward-refs=false',
        ]);

        expect(
          result.exitCode,
          equals(1),
          reason:
              'The strict #296 check must still be reachable with '
              '--allow-forward-refs=false',
        );
        final output = result.stdout.toString() + result.stderr.toString();
        expect(output, contains('Unknown type "PriceCheckRetailerResult"'));

        final parentFile = File(
          p.join(
            workspace.path,
            'lib',
            'src',
            'domain',
            'entities',
            'price_check_run',
            'price_check_run.dart',
          ),
        );
        expect(parentFile.existsSync(), isFalse);
      },
    );

    test(
      'entity.allowForwardRefs:false in .zfa.json restores the strict check',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        await File(
          p.join(workspace.path, '.zfa.json'),
        ).writeAsString('{"entity": {"allowForwardRefs": false}}');

        final result = await runZfa([
          'entity',
          'create',
          '-n',
          'PriceCheckRun',
          '--field',
          'id:String?',
          '--field',
          'results:List<PriceCheckRetailerResult>',
        ]);

        expect(
          result.exitCode,
          equals(1),
          reason:
              'A config default of allowForwardRefs:false must restore the '
              'strict on-disk check (#2125)',
        );
        final output = result.stdout.toString() + result.stderr.toString();
        expect(output, contains('Unknown type "PriceCheckRetailerResult"'));
      },
    );

    test(
      'add-field accepts a forward reference by default (#2125)',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final create = await runZfa([
          'entity',
          'create',
          '-n',
          'Note',
          '--field',
          'id:String?',
          '--field',
          'body:String',
        ]);
        expect(create.exitCode, equals(0));

        final add = await runZfa([
          'entity',
          'add-field',
          '-n',
          'Note',
          '--field',
          'category:NoteCategory', // forward reference — created later
        ]);
        expect(
          add.exitCode,
          equals(0),
          reason: 'add-field must accept forward references by default (#2125)',
        );

        final noteFile = File(
          p.join(
            workspace.path,
            'lib',
            'src',
            'domain',
            'entities',
            'note',
            'note.dart',
          ),
        );
        final content = await noteFile.readAsString();
        expect(content, contains('\$NoteCategory get category'));
      },
    );
  });
}
