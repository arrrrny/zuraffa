// Regression guard for BUG-1173 (engine purity / Flutter widget collision):
// https://github.com/arrrrny/zuraffa/issues/1173
//
// REVISED by BUG-1263 (https://github.com/arrrrny/zuraffa/issues/1263):
// fix #1173 originally deleted `lib/src/state/widgets/` outright on the
// belief that zuraffa_flutter solely owned the widget names. That broke
// zuraffa_flutter's fix #14 (83fea58), which re-exports the widgets from
// these exact core deep paths — the two siblings at HEAD became mutually
// uncompilable. Issue #1263 restored the ownership model of fix #14: the
// single source of truth for `ControlledWidget`, `SignalBuilder` and
// `FragmentBuilder` lives in core at `lib/src/state/widgets/`, and
// zuraffa_flutter re-exports those deep paths.
//
// The engine-purity guarantee that STANDS from fix #1173 is about the PUBLIC
// export surface, not about file existence:
//   1. The core barrel must not export anything from `lib/src/state/widgets/`
//      (no `ambiguous_export` at the barrel for consumers of both packages).
//   2. The widget names may be declared ONLY at the canonical deep paths.
//      A declaration anywhere else in `lib/` is a divergent copy that would
//      collide with the re-exported originals downstream.
//
// This guard is syntactic (no analysis context needed) so it stays in the
// FAST default tier and runs on every CI job.
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:test/test.dart';

/// Top-level names the v6 state widgets own (the BUG-1173 collision surface,
/// re-exported by zuraffa_flutter from the core deep paths since fix #14).
const _widgetNames = <String>{
  'ControlledWidget',
  'SignalBuilder',
  'FragmentBuilder',
};

/// The canonical home of the widget declarations (BUG-1263 ownership model).
const _canonicalWidgetDir = 'lib/src/state/widgets';

void main() {
  test(
    'BUG-1173: widget names stay out of the barrel and off any divergent path',
    () {
      // 1. The barrel must not re-export the widget libraries — the purity
      //    guarantee that survives from fix #1173 (BUG-1263 keeps it).
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
            (d) =>
                d.uri.stringValue?.contains('$_canonicalWidgetDir/') ?? false,
          )
          .toList();
      for (final export in widgetExports) {
        fail(
          'lib/zuraffa.dart re-exports "${export.uri.stringValue}" — a state '
          'widget library. The deep paths exist solely for zuraffa_flutter\'s '
          're-export contract (BUG-1263); exporting them publicly recreates '
          'the BUG-1173 ambiguous_export collision.',
        );
      }

      // 2. Defense in depth: the widget names may be declared ONLY at the
      //    canonical deep paths. Any declaration elsewhere in lib/ is a
      //    divergent copy that would collide downstream (BUG-1173).
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.startsWith('$_canonicalWidgetDir/')) continue;
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
          if (_widgetNames.contains(name)) {
            offenders.add('${entity.path}: $name');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'ControlledWidget / SignalBuilder / FragmentBuilder are declared '
            'only at $_canonicalWidgetDir/ (the single source of truth '
            'zuraffa_flutter re-exports). A same-named declaration anywhere '
            'else in lib/ would diverge from it. Found declarations at:',
      );
    },
  );
}
