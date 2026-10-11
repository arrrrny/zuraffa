// EPIC 3 / issue #1134, lane 4 — the shadcn/ui vocabulary as a TDD
// gate: `zfa tdd plan` validates widget references (Presentation
// component tokens) against the `zfa ui schema` vocabulary
// (NodeRegistry built-ins + project composites). grid/table are NOT
// in the vocabulary, are NOT implemented, and refuse BY NAME — no
// view generator emits unchecked grid/table layout code (exit
// criterion 3).
//
//  U-1134-g1: normalization — `ShadInput`→`input` ✓, `ZfaButton`→
//             `button` ✓, `ShadGrid`→`grid` ✗ (not in vocabulary),
//             `table` ✗; method-signature tokens, `key:` tokens and
//             slot-declaration bullets are NOT widget references and
//             never refuse (library-dev contracts stay untouched).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/widget_vocabulary_gate.dart';

void main() {
  test('U-1134-g1: normalization strips the shad/zfa/zuraffa prefixes '
      'and matches the vocabulary, case-insensitively', () {
    expect(WidgetVocabularyGate.normalize('ShadInput'), 'input');
    expect(WidgetVocabularyGate.normalize('ZfaButton'), 'button');
    expect(WidgetVocabularyGate.normalize('button'), 'button');
    expect(WidgetVocabularyGate.normalize('INPUT'), 'input');
    expect(WidgetVocabularyGate.normalize('ZuraffaCard'), 'card');
    expect(WidgetVocabularyGate.normalize('ShadGrid'), 'grid');
    expect(WidgetVocabularyGate.normalize('table'), 'table');
  });

  test('U-1134-g1b: widget-reference discrimination — method '
      'signatures, key tokens and slot bullets are not widget '
      'references', () {
    expect(
      WidgetVocabularyGate.isWidgetReferenceToken(
        'buildMain(appName, coreImport, zuraffaApp) -> String',
      ),
      isFalse,
      reason:
          'a method signature is an interface method, not a widget '
          'reference (the library-dev Presentation contracts)',
    );
    expect(
      WidgetVocabularyGate.isWidgetReferenceToken(
        "key: auth.signIn -> 'Sign in'",
      ),
      isFalse,
      reason: 'a key: token is an i18n declaration (issue #965)',
    );
    expect(WidgetVocabularyGate.isWidgetReferenceToken(''), isFalse);
    expect(WidgetVocabularyGate.isWidgetReferenceToken('ShadInput'), isTrue);
    expect(WidgetVocabularyGate.isWidgetReferenceToken('grid'), isTrue);
  });

  test('U-1134-g1c: validate passes in-vocabulary tokens and refuses '
      'out-of-vocabulary ones BY NAME with the vocabulary fix', () {
    final clean = WidgetVocabularyGate.validate(const [
      'ShadInput',
      'ZfaButton',
    ]);
    expect(clean, isEmpty, reason: 'in-vocabulary tokens pass');

    final violations = WidgetVocabularyGate.validate(const [
      'ShadInput',
      'ShadGrid',
      'table',
    ]);
    expect(violations, hasLength(2));
    final grid = violations.firstWhere((v) => v.token == 'ShadGrid');
    expect(grid.normalized, 'grid');
    expect(grid.message, contains('grid'));
    expect(grid.message, contains('--> fix:'));
    expect(grid.message, contains('zfa ui schema'));
    expect(
      grid.message,
      contains(RegExp('not implemented', caseSensitive: false)),
      reason:
          'grid/table are named as not implemented — the removed '
          'vocabulary, never a silent list fall-through',
    );
    final table = violations.firstWhere((v) => v.token == 'table');
    expect(table.message, contains('table'));
    expect(
      table.message,
      contains(RegExp('not implemented', caseSensitive: false)),
    );
  });

  test('U-1134-g1d: the vocabulary the gate consults is the zfa ui '
      'schema set (NodeRegistry built-ins)', () {
    // The 26 built-ins (the `zfa ui schema` export) minus grid/table —
    // the committed removal (#1149): grid/table are NOT in the
    // vocabulary.
    final vocabulary = WidgetVocabularyGate.builtInVocabulary;
    expect(vocabulary, containsAll(['button', 'input', 'card', 'list']));
    expect(vocabulary, isNot(contains('grid')));
    expect(vocabulary, isNot(contains('table')));
  });
}
