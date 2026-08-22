@Tags(['regression', 'slow'])
// Regression test for issue #296.
//
// `zfa entity create` with a field type that resolves to NEITHER an existing
// entity NOR an existing enum used to silently succeed (exit 0), writing an
// entity file whose generated `.zorphy.dart` later failed at `zfa build` time
// with a misleading `json_serializable` error pointing at `InvalidType`.
//
// Root cause: zorphy's `FieldNormalizer` assumed any non-primitive,
// non-enum type was an entity and `$`-prefixed it. `$FeedbackType` was
// undefined, so the analyzer resolved it to `InvalidType`, and the
// `ImportResolver` emitted a bogus entity-style import
// `import '../feedback_type/feedback_type.dart';` for a directory that did
// not exist.
//
// Fix (this PR): zuraffa's `EntityCommand._handleCreate` / `_handleAddField`
// now invoke `EntityTypeValidator.validate` BEFORE writing anything. If any
// field type is unresolvable, the command prints a clear, actionable error
// and exits 1 WITHOUT writing the entity file.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Resolve package root at discovery time, before any test changes CWD.
final _zfaRoot = Directory.current.path;

void main() {
  group('#296 — zfa entity create with unresolvable enum type', () {
    late Directory workspace;
    late String zfaBin;

    Future<ProcessResult> runZfa(List<String> args) {
      return Process.run('dart', [
        zfaBin,
        ...args,
      ], workingDirectory: workspace.path);
    }

    Future<ProcessResult> runZfaInRepo(List<String> args) {
      return Process.run('dart', [zfaBin, ...args], workingDirectory: _zfaRoot);
    }

    setUp(() async {
      zfaBin = p.join(_zfaRoot, 'bin', 'zfa.dart');
      workspace = await Directory.systemTemp.createTemp('issue_296_');
      // The entity command's dependency check scans pubspec.yaml for the
      // strings `zorphy_annotation:` and `build_runner:`. The strings are
      // enough — entity creation itself does not run `dart pub get`.
      await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: issue_296_test_app
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
      'entity create with an unresolvable enum type exits 1 and writes NO file',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final result = await runZfa([
          'entity',
          'create',
          '-n',
          'Feedback',
          '--field',
          'id:String?',
          '--field',
          'message:String',
          '--field',
          'type:FeedbackType', // enum does NOT exist yet
          '--field',
          'imageUrl:String?',
          '--field',
          'createdAt:DateTime?',
        ]);

        // MUST exit non-zero — the silent exit 0 was the original bug.
        expect(
          result.exitCode,
          equals(1),
          reason: 'Unresolvable field type must abort with exit 1',
        );

        final output = result.stdout.toString() + result.stderr.toString();

        // The error must name the unresolvable type and the field.
        expect(output, contains('FeedbackType'));
        expect(output, contains('type'));
        expect(output, contains('Unknown type'));

        // The error must be actionable — point the user at `zfa entity enum`.
        expect(output, contains('zfa entity enum -n FeedbackType'));

        // CRITICAL: no entity file may have been written. The silent
        // `$`-prefixed `InvalidType` emission happened because the file was
        // written despite the unresolvable type.
        final entityFile = File(
          p.join(
            workspace.path,
            'lib',
            'src',
            'domain',
            'entities',
            'feedback',
            'feedback.dart',
          ),
        );
        expect(
          entityFile.existsSync(),
          isFalse,
          reason: 'No entity file may be written when validation fails',
        );
      },
    );

    test(
      'entity create succeeds AFTER the enum is created — clean type, no bogus import',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        // Step 1: create the enum first.
        final enumResult = await runZfa([
          'entity',
          'enum',
          '-n',
          'FeedbackType',
          '--value',
          'error,suggestion,thanks',
        ]);
        expect(
          enumResult.exitCode,
          equals(0),
          reason: 'Enum creation must succeed',
        );

        final enumFile = File(
          p.join(
            workspace.path,
            'lib',
            'src',
            'domain',
            'entities',
            'enums',
            'feedback_type.dart',
          ),
        );
        expect(enumFile.existsSync(), isTrue);

        // Step 2: NOW create the entity that references the enum.
        final result = await runZfa([
          'entity',
          'create',
          '-n',
          'Feedback',
          '--field',
          'id:String?',
          '--field',
          'message:String',
          '--field',
          'type:FeedbackType',
          '--field',
          'imageUrl:String?',
          '--field',
          'createdAt:DateTime?',
        ]);

        expect(
          result.exitCode,
          equals(0),
          reason: 'Entity creation must succeed once the enum exists',
        );

        final entityFile = File(
          p.join(
            workspace.path,
            'lib',
            'src',
            'domain',
            'entities',
            'feedback',
            'feedback.dart',
          ),
        );
        expect(entityFile.existsSync(), isTrue);
        final content = await entityFile.readAsString();

        // The field type must be the clean `FeedbackType`, NOT the
        // `$`-prefixed `$FeedbackType` that produced `InvalidType`.
        expect(content, contains('FeedbackType get type;'));
        expect(
          content,
          isNot(contains(r'$FeedbackType')),
          reason: 'The dollar prefix caused InvalidType — must not appear',
        );

        // The enum barrel import is expected; the BOGUS entity-style import
        // `import '../feedback_type/feedback_type.dart';` must NOT appear
        // (the `feedback_type/` directory does not exist — only the enum
        // file under `enums/` does).
        expect(content, contains("import '../enums/index.dart';"));
        expect(
          content,
          isNot(contains("import '../feedback_type/feedback_type.dart';")),
          reason:
              'The bogus entity-style import for a non-existent '
              'entity directory was the second symptom of #296',
        );
      },
    );

    test(
      'entity add-field with an unresolvable type exits 1 and writes NO change',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        // First, create a valid entity (all primitive fields) so `add-field`
        // has a target to operate on.
        final createResult = await runZfa([
          'entity',
          'create',
          '-n',
          'Note',
          '--field',
          'id:String?',
          '--field',
          'body:String',
        ]);
        expect(createResult.exitCode, equals(0));

        final entityFile = File(
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
        expect(entityFile.existsSync(), isTrue);
        final originalContent = await entityFile.readAsString();

        // Now try to add a field whose type does not exist anywhere.
        final addResult = await runZfa([
          'entity',
          'add-field',
          '-n',
          'Note',
          '--field',
          'category:NoteCategory', // unresolvable
        ]);

        expect(
          addResult.exitCode,
          equals(1),
          reason: 'add-field must also validate field types',
        );

        final output =
            addResult.stdout.toString() + addResult.stderr.toString();
        expect(output, contains('NoteCategory'));
        expect(output, contains('Unknown type'));

        // The entity file must be unchanged.
        final afterContent = await entityFile.readAsString();
        expect(
          afterContent,
          equals(originalContent),
          reason: 'No file modifications when validation fails',
        );
      },
    );

    test(
      'entity create with a self-referential type is allowed',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        // A node that references itself (e.g. a tree) is a valid pattern.
        // The validator must NOT reject the entity being created for
        // referencing itself.
        final result = await runZfa([
          'entity',
          'create',
          '-n',
          'TreeNode',
          '--field',
          'id:String?',
          '--field',
          'label:String',
          '--field',
          'parent:TreeNode?',
          '--field',
          'children:List<TreeNode>',
        ]);

        expect(
          result.exitCode,
          equals(0),
          reason: 'Self-reference must be allowed',
        );

        final entityFile = File(
          p.join(
            workspace.path,
            'lib',
            'src',
            'domain',
            'entities',
            'tree_node',
            'tree_node.dart',
          ),
        );
        expect(entityFile.existsSync(), isTrue);
      },
    );

    // Sanity: the zfa binary itself compiles & runs from the repo root.
    test(
      'zfa binary is runnable (smoke)',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final result = await runZfaInRepo(['--help']);
        expect(result.exitCode, equals(0));
      },
    );
  });
}
