// Regression guard for BUG-1173 (engine purity / Flutter widget collision):
// https://github.com/arrrrny/zuraffa/issues/1173
//
// Spec 014 (pure-dart-core-split) made `zuraffa_flutter` the canonical owner
// of the v6 state widgets (`ControlledWidget`, `SignalBuilder`,
// `FragmentBuilder`) and moved `lib/src/state/widgets/` out of this core
// package. The v6 view-fragment work later re-introduced same-named copies in
// the core barrel. Any Flutter package that depends on BOTH packages (e.g.
// `zuraffa_flutter` resolved against `zuraffa` master) fails `dart analyze`
// with `ambiguous_export` on all three names.
//
// Constitution (spec 014): the engine repo is pure Dart — zero Flutter SDK
// dependencies — and the Flutter widget implementations live solely in
// `zuraffa_flutter`. Whichever package owns a name, the other must not
// re-export a same-named different class.
//
// This guard is syntactic (no analysis context needed) so it stays in the
// FAST default tier and runs on every CI job:
//   1. `lib/src/state/widgets/` must not exist (ownership: zuraffa_flutter).
//   2. The core barrel must not export anything from that directory.
//   3. No file in `lib/` may DECLARE a colliding class/enum/mixin/typedef
//      name owned by `zuraffa_flutter` (even under a different path).
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:test/test.dart';

/// Top-level names that `zuraffa_flutter` defines AND exports from
/// `lib/src/state/widgets/` (BUG-1173 collision surface).
const _collidingNames = <String>{
  'ControlledWidget',
  'SignalBuilder',
  'FragmentBuilder',
};

void main() {
  test(
    'BUG-1173: core must not own or export zuraffa_flutter state widgets',
    () {
      // 1. The moved widget directory must not exist in the pure-Dart core.
      //    Ownership of the Flutter state widgets is solely zuraffa_flutter's
      //    (spec 014, "Files moved to zuraffa_flutter").
      final widgetDir = Directory('lib/src/state/widgets');
      expect(
        widgetDir.existsSync(),
        isFalse,
        reason:
            'lib/src/state/widgets/ was moved to zuraffa_flutter (spec 014). '
            'Re-introducing it in core collides downstream with '
            'ambiguous_export (BUG-1173). Core keeps only the pure '
            'state/signal machinery.',
      );

      // 2. The barrel must not re-export the colliding widget libraries.
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
      for (final export in widgetExports) {
        fail(
          'lib/zuraffa.dart re-exports "${export.uri.stringValue}" — a '
          'zuraffa_flutter-owned state widget library (BUG-1173).',
        );
      }

      // 3. Defense in depth: no core lib/ file may DECLARE a colliding name,
      //    even if a future refactor moves the declaration outside
      //    lib/src/state/widgets/.
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final unit = parseString(
          content: entity.readAsStringSync(),
          path: entity.path,
          throwIfDiagnostics: false,
        ).unit;
        for (final declaration in unit.declarations) {
          final name = switch (declaration) {
            ClassDeclaration() => declaration.namePart.typeName.lexeme,
            EnumDeclaration() => declaration.namePart.typeName.lexeme,
            MixinDeclaration() => declaration.name.lexeme,
            TypeAlias() => declaration.name.lexeme,
            _ => null,
          };
          if (_collidingNames.contains(name)) {
            offenders.add('${entity.path}: $name');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'ControlledWidget / SignalBuilder / FragmentBuilder are owned by '
            'zuraffa_flutter (BUG-1173); the pure-Dart core must not declare '
            'same-named classes. Found declarations at:',
      );
    },
  );
}
