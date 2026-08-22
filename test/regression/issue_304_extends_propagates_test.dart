@Tags(['regression', 'slow'])
// Regression test for issue #304.
//
// `zfa entity create -n Sub --extends Base` used to emit
//   `abstract class $Sub implements Base { ... }`
// (bare name, no `$` prefix) in the source abstract class. The analyzer
// cannot resolve `Base` at source-analysis time because `Base` is the
// GENERATED CONCRETE class name (emitted by zorphy into the .zorphy.dart
// file later). The implements clause was silently dropped from
// `classElement.allSupertypes`, and the generated concrete class lost
// the relationship to `Base` — breaking `isA<Base>()` checks and
// union-type dispatch.
//
// The fix has two parts (both in the zorphy package):
//
//   1. **zfa CLI** (`entity_template_generator.dart`): the `--extends`
//      flag now emits `implements $Base` (with `$` prefix) instead of
//      `implements Base` (bare name). The analyzer resolves `$Base`
//      (the source abstract class) directly.
//
//   2. **zorphy codegen** (`interface_collector.dart`): a recovery
//      path parses the source text of the class declaration, finds
//      unresolved `implements` clauses, resolves each name against
//      `allAnnotatedClasses` (trying `$Name` and `$$Name` variants),
//      and adds the recovered interface to `metadata.interfaces` with
//      the source class name (including the `$` prefix).
//
// This test verifies part 1: the zfa CLI emits the correct `$`-prefixed
// source format. Part 2 (the codegen recovery) is tested in the zorphy
// package itself (see zorphy/test/generation/issue_304_extends_test.dart).
//
// See: https://github.com/arrrrny/zuraffa/issues/304
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Resolve package root at discovery time, before any test changes CWD.
final _zfaRoot = Directory.current.path;

void main() {
  group('#304 — zfa entity create --extends propagates implements clause', () {
    late Directory workspace;
    late String zfaBin;

    Future<ProcessResult> runZfa(List<String> args) {
      return Process.run('dart', [
        zfaBin,
        ...args,
      ], workingDirectory: workspace.path);
    }

    setUp(() async {
      zfaBin = p.join(_zfaRoot, 'bin', 'zfa.dart');
      workspace = await Directory.systemTemp.createTemp('issue_304_');
      // The entity command's dependency check scans pubspec.yaml for the
      // strings `zorphy_annotation:` and `build_runner:`. The strings are
      // enough — entity creation itself does not run `dart pub get`.
      await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: issue_304_test_app
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
      'entity create --extends emits `implements \$Base` (with \$ prefix) '
      'so the analyzer can resolve it',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        // Step 1: create the base entity.
        final baseResult = await runZfa([
          'entity',
          'create',
          '-n',
          'AuthenticationResult',
          '--field',
          'errorCode:String',
          '--field',
          'message:String',
        ]);
        expect(
          baseResult.exitCode,
          equals(0),
          reason: 'Base entity creation must succeed',
        );

        // Step 2: create the subclass with --extends.
        final subResult = await runZfa([
          'entity',
          'create',
          '-n',
          'NativeAuthenticationResult',
          '--extends',
          'AuthenticationResult',
          '--field',
          'errorCode:String',
          '--field',
          'message:String',
        ]);
        expect(
          subResult.exitCode,
          equals(0),
          reason: 'Subclass creation with --extends must succeed',
        );

        // Step 3: inspect the generated source file.
        final subFile = File(
          p.join(
            workspace.path,
            'lib',
            'src',
            'domain',
            'entities',
            'native_authentication_result',
            'native_authentication_result.dart',
          ),
        );
        expect(subFile.existsSync(), isTrue);
        final content = await subFile.readAsString();

        // The source abstract class MUST declare
        //   `implements $AuthenticationResult`
        // (with the `$` prefix). Without the `$` prefix, the analyzer
        // cannot resolve `AuthenticationResult` at source-analysis time
        // (it's the GENERATED CONCRETE class name, which doesn't exist
        // until zorphy emits it into the .zorphy.dart file). The
        // implements clause would be silently dropped, and the generated
        // concrete class would lose the relationship to
        // AuthenticationResult — breaking `isA<AuthenticationResult>()`.
        expect(
          content,
          contains(r'implements $AuthenticationResult'),
          reason:
              'The source abstract class must declare '
              '`implements \$AuthenticationResult` (with the \$ prefix) so '
              'the analyzer can resolve the implements target at '
              'source-analysis time. The bare name `AuthenticationResult` '
              'refers to the GENERATED CONCRETE class, which does not '
              'exist yet — the analyzer would silently drop the implements '
              'clause, causing the generated concrete class to lose the '
              'relationship to AuthenticationResult.',
        );

        // The source MUST NOT use the bare name (which was the bug).
        expect(
          content,
          isNot(contains('implements AuthenticationResult {')),
          reason:
              'The bare name `implements AuthenticationResult` (without \$) '
              'was the bug — the analyzer cannot resolve it. The fix '
              'normalizes the extends interface to use the \$-prefixed '
              'source abstract class name.',
        );

        // The source MUST NOT use `$$` (sealed class prefix) for a
        // regular entity.
        expect(
          content,
          isNot(contains(r'implements $$AuthenticationResult')),
          reason:
              'A regular entity (created without --sealed) should use '
              '`\$AuthenticationResult` (single \$), not '
              '`\$\$AuthenticationResult` (sealed).',
        );
      },
    );

    test(
      'entity create --extends with a \$-prefixed name preserves the name as-is',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        // Create the base entity first.
        await runZfa([
          'entity',
          'create',
          '-n',
          'BaseEntity',
          '--field',
          'id:String',
        ]);

        // Create the subclass with --extends $BaseEntity (already $-prefixed).
        final result = await runZfa([
          'entity',
          'create',
          '-n',
          'SubEntity',
          '--extends',
          r'$BaseEntity',
          '--field',
          'id:String',
        ]);
        expect(result.exitCode, equals(0));

        final subFile = File(
          p.join(
            workspace.path,
            'lib',
            'src',
            'domain',
            'entities',
            'sub_entity',
            'sub_entity.dart',
          ),
        );
        expect(subFile.existsSync(), isTrue);
        final content = await subFile.readAsString();

        // The \$-prefixed name should be preserved as-is (no double \$\$).
        expect(
          content,
          contains(r'implements $BaseEntity'),
          reason:
              'A \$-prefixed extends interface should be preserved as-is. '
              'The normalization helper only adds \$ if the name does not '
              'already start with \$.',
        );
        expect(
          content,
          isNot(contains(r'implements $$BaseEntity')),
          reason: 'No double \$\$ prefix should be added.',
        );
      },
    );

    test(
      'entity create --extends with a \$\$-prefixed sealed name preserves it as-is',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        // Create the base sealed entity first.
        await runZfa([
          'entity',
          'create',
          '-n',
          'SealedBase',
          '--sealed',
          '--field',
          'id:String',
        ]);

        // Create the subclass with --extends $$SealedBase (sealed prefix).
        final result = await runZfa([
          'entity',
          'create',
          '-n',
          'SealedSub',
          '--extends',
          r'$$SealedBase',
          '--field',
          'id:String',
        ]);
        expect(result.exitCode, equals(0));

        final subFile = File(
          p.join(
            workspace.path,
            'lib',
            'src',
            'domain',
            'entities',
            'sealed_sub',
            'sealed_sub.dart',
          ),
        );
        expect(subFile.existsSync(), isTrue);
        final content = await subFile.readAsString();

        // The \$\$-prefixed name should be preserved as-is.
        expect(
          content,
          contains(r'implements $$SealedBase'),
          reason:
              'A \$\$-prefixed (sealed) extends interface should be '
              'preserved as-is. The normalization helper only adds \$ if '
              'the name does not already start with \$.',
        );
      },
    );

    test(
      'entity create without --extends does not add an implements clause',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final result = await runZfa([
          'entity',
          'create',
          '-n',
          'Standalone',
          '--field',
          'id:String',
        ]);
        expect(result.exitCode, equals(0));

        final file = File(
          p.join(
            workspace.path,
            'lib',
            'src',
            'domain',
            'entities',
            'standalone',
            'standalone.dart',
          ),
        );
        expect(file.existsSync(), isTrue);
        final content = await file.readAsString();

        // No implements clause should be present.
        expect(
          content,
          isNot(contains('implements')),
          reason:
              'An entity created without --extends should not have an '
              'implements clause.',
        );
      },
    );
  });
}
