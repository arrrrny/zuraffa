// Regression test for issue #308.
//
// `zfa entity create` and `zfa entity add-field` rejected forward references
// — field types that resolve to an entity which does NOT yet exist on disk
// but will be created later in the same batch. Real-world GraphQL schemas
// (Vendure, etc.) have genuine mutual-reference cycles:
//
//   Order ↔ Customer           (Customer.orders: List<Order>,
//                               Order.customer: Customer?)
//   Facet ↔ FacetValue
//   Fulfillment ↔ FulfillmentLine
//
// The strict on-disk validator (added by #296 / PR #297) aborted with
// `Unknown type "X" for field "y"` whenever the referenced entity directory
// did not yet exist, so a cyclic batch could not be generated in any order.
//
// Fix (PR #299 → actually PR #309, merged into development as 7f21e31):
// `entity create` and `entity add-field` accept a `--allow-forward-refs`
// flag that opts out of on-disk type validation for the duration of that
// single command. `ImportResolver` already emits correct `$`-prefixed
// entity imports for forward references (e.g. `import '../order/order.dart';`
// even when `order/order.dart` does not exist yet), so the build resolves
// once every entity in the batch has been generated.
//
// This test locks in the fix end-to-end by spawning the `zfa` CLI binary
// against a temp workspace. It covers:
//
//   1. Without --allow-forward-refs: a forward reference is rejected (the
//      #296 guard still fires — `--allow-forward-refs` is OPT-IN, never
//      the default).
//   2. With --allow-forward-refs: the same forward reference is accepted,
//      the entity file is written, and the forward import is emitted.
//   3. Cyclic batch (the actual issue scenario): Customer(List<Order>) is
//      created first, then Order(Customer?) — both succeed, the two files
//      reference each other via the correct `$`-prefixed imports.
//   4. `add-field` without --allow-forward-refs: forward reference rejected.
//   5. `add-field` with --allow-forward-refs: forward reference accepted,
//      the new field is written with the correct `$`-prefixed type.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Resolve package root at discovery time, before any test changes CWD.
final _zfaRoot = Directory.current.path;

void main() {
  group('#308 — zfa entity create/add-field with --allow-forward-refs', () {
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
      workspace = await Directory.systemTemp.createTemp('issue_308_');
      // The entity command's dependency check scans pubspec.yaml for the
      // strings `zorphy_annotation:` and `build_runner:`. The strings are
      // enough — entity creation itself does not run `dart pub get`.
      await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: issue_308_test_app
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
      'entity create WITHOUT --allow-forward-refs rejects a forward reference (opt-in)',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        // Customer references Order, which does NOT exist on disk yet.
        // Without --allow-forward-refs, the #296 validator must still
        // fire and abort. This proves the flag is OPT-IN and the default
        // behaviour is unchanged from #296.
        final result = await runZfa([
          'entity',
          'create',
          '-n',
          'Customer',
          '--field',
          'id:String?',
          '--field',
          'orders:List<Order>', // forward reference
        ]);

        expect(
          result.exitCode,
          equals(1),
          reason: 'Forward refs must be rejected by default (#296 guard)',
        );

        final output = result.stdout.toString() + result.stderr.toString();
        expect(output, contains('Unknown type "Order"'));
        expect(output, contains('orders'));
        expect(output, contains('could not be resolved'));

        // No file may be written when validation fails.
        final entityFile = File(
          p.join(
            workspace.path,
            'lib',
            'src',
            'domain',
            'entities',
            'customer',
            'customer.dart',
          ),
        );
        expect(entityFile.existsSync(), isFalse);
      },
    );

    test(
      'entity create WITH --allow-forward-refs accepts a forward reference and writes the file',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final result = await runZfa([
          'entity',
          'create',
          '-n',
          'Customer',
          '--field',
          'id:String?',
          '--field',
          'orders:List<Order>', // forward reference — Order created later
          '--allow-forward-refs',
        ]);

        expect(
          result.exitCode,
          equals(0),
          reason: '--allow-forward-refs must skip the on-disk check',
        );

        final entityFile = File(
          p.join(
            workspace.path,
            'lib',
            'src',
            'domain',
            'entities',
            'customer',
            'customer.dart',
          ),
        );
        expect(entityFile.existsSync(), isTrue);

        final content = await entityFile.readAsString();

        // The field type must be the `$`-prefixed entity type `$Order`
        // (Zorphy entity convention) wrapped in `List<...>`.
        expect(
          content,
          contains('List<\$Order>'),
          reason: 'Forward entity ref must be emitted as `List<\$Order>`',
        );

        // The ImportResolver must emit the forward entity-style import
        // `import '../order/order.dart';` even though order/ does not
        // exist yet — that is the whole point of #308.
        expect(
          content,
          contains("import '../order/order.dart';"),
          reason:
              'ImportResolver must emit the forward import so the build '
              'resolves once Order is created',
        );
      },
    );

    test(
      'cyclic batch: Customer(List<Order>) then Order(Customer?) — both succeed, cross-imports correct',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        // Step 1: create Customer first, referencing Order (which does
        // not exist yet) via --allow-forward-refs.
        final step1 = await runZfa([
          'entity',
          'create',
          '-n',
          'Customer',
          '--field',
          'id:String?',
          '--field',
          'orders:List<Order>',
          '--allow-forward-refs',
        ]);
        expect(step1.exitCode, equals(0));

        // Step 2: now create Order, referencing Customer back. Customer
        // already exists on disk by now, but using --allow-forward-refs
        // again is the natural batch-mode usage and must also succeed.
        final step2 = await runZfa([
          'entity',
          'create',
          '-n',
          'Order',
          '--field',
          'id:String?',
          '--field',
          'customer:Customer?',
          '--allow-forward-refs',
        ]);
        expect(step2.exitCode, equals(0));

        final customerFile = File(
          p.join(
            workspace.path,
            'lib',
            'src',
            'domain',
            'entities',
            'customer',
            'customer.dart',
          ),
        );
        final orderFile = File(
          p.join(
            workspace.path,
            'lib',
            'src',
            'domain',
            'entities',
            'order',
            'order.dart',
          ),
        );
        expect(customerFile.existsSync(), isTrue);
        expect(orderFile.existsSync(), isTrue);

        final customerSrc = await customerFile.readAsString();
        final orderSrc = await orderFile.readAsString();

        // Customer references Order.
        expect(customerSrc, contains('List<\$Order>'));
        expect(customerSrc, contains("import '../order/order.dart';"));

        // Order references Customer back — the cycle is closed.
        expect(orderSrc, contains('\$Customer?'));
        expect(orderSrc, contains("import '../customer/customer.dart';"));
      },
    );

    test(
      'add-field WITHOUT --allow-forward-refs rejects a forward reference',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        // First create a valid entity (all primitives).
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
        expect(noteFile.existsSync(), isTrue);
        final before = await noteFile.readAsString();

        // Now try to add a field whose type does not exist anywhere.
        final add = await runZfa([
          'entity',
          'add-field',
          '-n',
          'Note',
          '--field',
          'category:NoteCategory', // forward reference
        ]);

        expect(
          add.exitCode,
          equals(1),
          reason: 'add-field must also validate field types by default',
        );

        final output = add.stdout.toString() + add.stderr.toString();
        expect(output, contains('Unknown type "NoteCategory"'));
        expect(output, contains('could not be resolved'));

        // File must be unchanged.
        final after = await noteFile.readAsString();
        expect(after, equals(before));
      },
    );

    test(
      'add-field WITH --allow-forward-refs accepts a forward reference and writes the field',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        // Create a valid entity first.
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

        // Add a forward-referencing field with --allow-forward-refs.
        final add = await runZfa([
          'entity',
          'add-field',
          '-n',
          'Note',
          '--field',
          'category:NoteCategory', // forward reference — NoteCategory created later
          '--allow-forward-refs',
        ]);
        expect(
          add.exitCode,
          equals(0),
          reason:
              '--allow-forward-refs must skip the on-disk check for add-field',
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
        expect(noteFile.existsSync(), isTrue);

        final content = await noteFile.readAsString();

        // The new field must be present with the $-prefixed type.
        expect(
          content,
          contains('\$NoteCategory get category'),
          reason: 'Forward entity ref must be emitted as `\$NoteCategory`',
        );
      },
    );

    // Sanity: the zfa binary itself compiles & runs from the repo root.
    test(
      'zfa binary is runnable (smoke)',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final result = await Process.run('dart', [
          zfaBin,
          '--help',
        ], workingDirectory: _zfaRoot);
        expect(result.exitCode, equals(0));
      },
    );
  });
}
