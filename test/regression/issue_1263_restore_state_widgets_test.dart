// Regression guard for BUG-1263 (restore state widgets on core):
// https://github.com/arrrrny/zuraffa/issues/1263
//
// zuraffa_flutter (fix #14, 83fea58) is the Flutter binding layer for the v6
// state widgets and re-exports their single source of truth from core deep
// paths:
//
//     export 'package:zuraffa/src/state/widgets/controlled_widget.dart';
//     export 'package:zuraffa/src/state/widgets/signal_builder.dart';
//     export 'package:zuraffa/src/state/widgets/fragment_builder.dart';
//
// Core master (10e62deb, BUG-1173) deleted those files, so every project
// path-depending on both repos at HEAD fails to compile with
// "Error when reading ... No such file or directory" (reproduced 1:1 in the
// issue). Issue #1263 restores the ownership model of fix #14: the deep-path
// sources live in core, while the engine-purity guarantee (BUG-1173) applies
// to the PUBLIC barrel only — the widget libraries stay out of
// lib/zuraffa.dart.
//
// This guard pins that contract from both halves:
//   1. Compile half — the static imports below ARE the zuraffa_flutter
//      contract. While the files are missing, this suite fails with exactly
//      the consumer-facing "No such file or directory" error.
//   2. Runtime half — the three contract files must exist on disk, the
//      declared types must be importable and constructible, and the core
//      barrel must not export any of them.
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

import 'package:zuraffa/src/state/widgets/controlled_widget.dart';
import 'package:zuraffa/src/state/widgets/fragment_builder.dart';
import 'package:zuraffa/src/state/widgets/signal_builder.dart';
import 'package:zuraffa/src/state/widgets/widget_host.dart';

/// The deep-path libraries zuraffa_flutter re-exports (the contract surface
/// that 10e62deb deleted).
const _contractLibraries = <String>[
  'lib/src/state/widgets/controlled_widget.dart',
  'lib/src/state/widgets/signal_builder.dart',
  'lib/src/state/widgets/fragment_builder.dart',
];

/// Internal host machinery the contract libraries are written against
/// (ViewContext / ViewFragment / WidgetHost). Not part of the zuraffa_flutter
/// re-export surface — and deliberately not barrel-exported — but deleting it
/// breaks the contract libraries' compilation, so it is guarded too.
const _supportLibrary = 'lib/src/state/widgets/widget_host.dart';

/// Use case that must never execute: [SignalSlice] is lazy and
/// [FragmentBuilder] only subscribes on attach, which this test never does.
class _NeverCalledUseCase<T> extends ZuraffaUseCase<dynamic, T> {
  const _NeverCalledUseCase();

  @override
  SignalResult<T> call(dynamic params, {ZuraffaContext? context}) =>
      throw UnimplementedError('not called in this test');
}

/// Concrete probe: subclasses compile with typed controller access and the
/// lifecycle hooks' default (no-op) implementations.
class _ProbeView extends ControlledWidget<int> {
  const _ProbeView() : super(controller: 42);
}

void main() {
  group('BUG-1263: core deep paths behind the zuraffa_flutter re-export', () {
    test('the three contract libraries exist at their deep paths', () {
      for (final path in _contractLibraries) {
        expect(
          File(path).existsSync(),
          isTrue,
          reason:
              '$path is re-exported by zuraffa_flutter (fix #14). Deleting it '
              'makes every project that path-depends on both repos at HEAD '
              'fail to compile (BUG-1263).',
        );
      }
    });

    test('the internal host machinery stays importable for the contract', () {
      expect(
        File(_supportLibrary).existsSync(),
        isTrue,
        reason:
            '$_supportLibrary declares ViewContext / ViewFragment / WidgetHost; '
            'the contract libraries import it directly (it is intentionally '
            'NOT exported from the barrel — BUG-1173 purity stands).',
      );
    });

    test('contract types resolve and construct through the deep paths', () {
      // ControlledWidget: typed controller access without casts, default
      // lifecycle hooks callable.
      const view = _ProbeView();
      expect(view.controller, 42);
      expect(view.controller, isA<int>());
      // Default lifecycle hooks are no-ops — callable without any wiring.
      view
        ..onInit()
        ..onDispose();

      // SignalBuilder: constructs from a pure Signal and is a ViewFragment.
      final signal = Signal<bool>(false);
      addTearDown(signal.dispose);
      final signalBuilder = SignalBuilder<bool>(
        signal: signal,
        builder: (context, value) => null,
      );
      expect(signalBuilder, isA<ViewFragment>());

      // FragmentBuilder: constructs from a lazy SignalSlice (never executed
      // here) and is a ViewFragment.
      final fragmentBuilder = FragmentBuilder<int>(
        slice: SignalSlice<int>(
          useCase: const _NeverCalledUseCase<int>(),
          params: null,
        ),
        builder: (context, data) => null,
      );
      expect(fragmentBuilder, isA<ViewFragment>());
    });

    test('BUG-1173 purity stands: the barrel must not export any of them', () {
      final barrel = File('lib/zuraffa.dart');
      expect(
        barrel.existsSync(),
        isTrue,
        reason: 'lib/zuraffa.dart is the package barrel.',
      );
      final unit = parseString(
        content: barrel.readAsStringSync(),
        throwIfDiagnostics: false,
      );
      final widgetExports = unit.unit.directives
          .whereType<ExportDirective>()
          .where(
            (d) => d.uri.stringValue?.contains('src/state/widgets') ?? false,
          )
          .toList();
      expect(
        widgetExports,
        isEmpty,
        reason:
            'Restoring the deep paths (BUG-1263) must NOT re-add widget '
            'exports to lib/zuraffa.dart: the engine purity guarantee from '
            'fix #1173 applies to the public export surface. Deep-path '
            'imports are zuraffa_flutter\'s contract, not the engine API.',
      );
    });
  });
}
