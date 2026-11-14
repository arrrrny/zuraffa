// Issue #2076 — the state migration emits SIGNAL-BACKED view state.
//
// `zfa migrate state` used to emit a `ChangeNotifier` with one private
// backing field + getter + `notifyListeners()` setter per field, so a
// multi-field transition cost one notification per field. The v6 template
// emits the same field surface (getters and setters keep their names, so a
// generated file stays a drop-in) over a single `Signal` snapshot: N setters
// inside one `batch(...)` notify once, carrying the final values. The signals
// are owned by a `SignalScope` the generated state opens and disposes, which
// is what closes the dispose-leak class the manual `notifyListeners`
// discipline allowed.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/migration/fixers/state_fixer.dart';
import 'package:zuraffa/src/migration/migration_models.dart';

/// A v5 mixed state with three transient UI fields (error, isLoading,
/// isRefreshing) and one domain field (cart) — the minimum that needs a
/// migration at all (the detector/fixer both require both halves).
const _mixedStateSource = '''
class CartState {
  final AppFailure? error;
  final bool isLoading;
  final bool isRefreshing;
  final Cart? cart;

  const CartState({
    this.error,
    this.isLoading = false,
    this.isRefreshing = false,
    this.cart,
  });
}
''';

void main() {
  late Directory projectDir;
  late Directory stateDir;
  late File stateFile;

  setUp(() async {
    projectDir = await Directory.systemTemp.createTemp('zfa_state_signal_');
    stateDir = Directory(
      p.join(projectDir.path, 'lib', 'presentation', 'pages', 'cart'),
    );
    await stateDir.create(recursive: true);
    stateFile = File(p.join(stateDir.path, 'cart_state.dart'));
    await stateFile.writeAsString(_mixedStateSource);
  });

  tearDown(() async {
    if (await projectDir.exists()) {
      await projectDir.delete(recursive: true);
    }
  });

  Future<MigrationResult> runMigration({bool dryRun = false}) async {
    final migrator = StateMigrator();
    return migrator.migrate(
      findings: [
        MigrationFinding(
          message: 'Mixed state',
          filePath: 'lib/presentation/pages/cart/cart_state.dart',
          line: 1,
          ruleId: 'v5_mixed_state',
          severity: MigrationSeverity.warning,
        ),
      ],
      projectDir: projectDir.path,
      dryRun: dryRun,
    );
  }

  Future<String> viewStateSource() =>
      File(p.join(stateDir.path, 'cart_view_state.dart')).readAsString();

  test('emits a signal-backed view state, not a ChangeNotifier', () async {
    await runMigration();

    final source = await viewStateSource();
    expect(source, contains('class CartViewState extends ViewState'));
    expect(
      source,
      isNot(contains('ChangeNotifier')),
      reason: 'the v6 template must not reintroduce the ChangeNotifier shape',
    );
    expect(
      source,
      isNot(contains('notifyListeners')),
      reason: 'per-field notifyListeners() is what #2076 replaces',
    );
    // Signal comes from zuraffa core, so the generated state file is pure
    // Dart and needs no Flutter import.
    expect(source, contains("import 'package:zuraffa/zuraffa.dart';"));
    expect(
      source,
      isNot(contains("import 'package:flutter/material.dart';")),
      reason: 'a signal-backed state file must not depend on Flutter',
    );
  });

  test(
    'keeps the v5 field surface as getters and setters (drop-in read)',
    () async {
      await runMigration();

      final source = await viewStateSource();
      for (final field in ['error', 'isLoading', 'isRefreshing']) {
        expect(
          source,
          contains('get $field'),
          reason: '$field must stay readable under its v5 name',
        );
        expect(
          source,
          contains('set $field'),
          reason: '$field must stay writable under its v5 name',
        );
      }
      // The getter/setter types are the v5 ones, so a presenter that reads
      // `view.isLoading` as a bool still compiles.
      expect(source, contains('bool get isLoading'));
      expect(source, contains('set isLoading(bool value)'));
      expect(source, contains('AppFailure? get error'));
      expect(source, contains('bool get isRefreshing'));
    },
  );

  test('one signal snapshot: N setters notify once under batch', () async {
    await runMigration();

    final source = await viewStateSource();
    expect(
      source,
      contains('Signal<CartViewData>'),
      reason: 'the transient fields live in ONE signal snapshot',
    );
    // Every setter writes the snapshot signal — that single write target is
    // what lets batch() coalesce a multi-field transition.
    final setterCount = source
        .split('\n')
        .where((line) => line.startsWith('  set '))
        .length;
    expect(setterCount, equals(3));
    expect(
      source.split('_state.value = CartViewData(').length - 1,
      equals(setterCount),
      reason: 'every setter must write the shared snapshot signal',
    );
    expect(
      source,
      contains('  set error(AppFailure? value) {'),
      reason: 'the setter keeps its v5 parameter type',
    );
    expect(
      source,
      isNot(contains('notifyListeners')),
      reason: 'the per-field notify is replaced by the signal write',
    );
  });

  test(
    'signal construction is owned by a SignalScope the state disposes',
    () async {
      await runMigration();

      final source = await viewStateSource();
      expect(source, contains('SignalScope'));
      expect(
        source,
        contains('_scope.run('),
        reason: 'the snapshot signal must be constructed inside the scope',
      );
      expect(
        source,
        contains('void dispose()'),
        reason: 'the state must release what its scope owns',
      );
      expect(source, contains('_scope.dispose()'));
      expect(
        source,
        contains('super.dispose()'),
        reason: 'ViewState.dispose() releases the registered signals too',
      );
      // ViewState.dispose() only releases signals registered through
      // registerSignal, which is what `isActive` reads.
      expect(source, contains('registerSignal(_state)'));
    },
  );

  test('the domain state bridges through SignalResult.fromFuture', () async {
    await runMigration();

    final source = await File(
      p.join(stateDir.path, 'cart_domain_state.dart'),
    ).readAsString();
    expect(source, contains('class CartDomainState extends DomainState'));
    expect(
      source,
      contains('SignalResult.fromFuture'),
      reason:
          '#2076 item 3: the domain state emits the loading/success/'
          'failure bridge instead of mirrored error/loading booleans',
    );
    // The slice route is still shown: a v6 use case already returns a
    // SignalResult, so `bind` is the no-bridge path.
    expect(source, contains('bind<Cart>'));
  });

  test(
    're-running the migration does not stack a second set of fields',
    () async {
      final first = await runMigration();
      expect(first.filesCreated, equals(2));

      final viewAfterFirst = await viewStateSource();
      final originalAfterFirst = await stateFile.readAsString();

      final second = await runMigration();

      expect(
        second.filesCreated,
        equals(0),
        reason: 'an already migrated file must not be re-emitted',
      );
      expect(second.actions, isEmpty);
      expect(await viewStateSource(), equals(viewAfterFirst));
      expect(
        await stateFile.readAsString(),
        equals(originalAfterFirst),
        reason: 'the migration note must not be prepended twice',
      );
      expect(
        originalAfterFirst
                .split('NOTE: This file has been migrated to v6')
                .length -
            1,
        equals(1),
      );
    },
  );
}
