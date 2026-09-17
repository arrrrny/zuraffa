/// WidgetVocabularyGate (EPIC 3 / issue #1134, lane 4 — the shadcn
/// vocabulary as a TDD gate): validates widget references — the
/// Presentation layer contract's component tokens — against the
/// `zfa ui schema` vocabulary (the [NodeRegistry] built-ins plus the
/// project's registered composites).
///
/// The epic's named defect: "shadcn grid/table silently falls through
/// to list — lying generator." grid and table are NOT in the
/// vocabulary (the #1149 committed removal: the CLI refuses them, the
/// vocabulary never had them), are NOT implemented, and every
/// generator refuses them BY NAME — never a silent stand-in.
///
/// Token discrimination (a widget reference is a NOUN naming a UI
/// component, not any Presentation token):
/// - a `key:` token (`key: auth.signIn -> 'Sign in'`) is an i18n
///   declaration (issue #965) — not a widget reference;
/// - a method-signature token (`buildMain(a, b) -> String`,
///   `isSubmittable(String, String) -> bool`) is an interface method —
///   the library-dev Presentation contracts (specs 0965/1444/1141)
///   stay untouched;
/// - a slot-declaration bullet (`adaptive_layouts`) never reaches the
///   gate (UiLedgerProjection.componentTokensOf filters it).
///
/// Normalization: the shadcn/zfa/zuraffa family prefixes are stripped
/// and the remainder lowercased (`ShadInput` → `input`,
/// `ZfaButton` → `button`) — the vocabulary names are the canonical
/// set; the prefixed spellings are the skin dialects that alias them.
/// A token whose normalized name is not in the vocabulary is a
/// violation naming the token, its normalized form, and the
/// `zfa ui schema` fix.
///
/// Pure and synchronous: tokens + vocabulary in, violations out.
library;

import '../../skin/vocabulary/ui_node_registry.dart';
import 'i18n_key_contract.dart';

/// One vocabulary violation: the offending token, its normalized
/// form, and the refusal message (with the `--> fix:` line).
class WidgetVocabularyViolation {
  final String token;
  final String normalized;
  final String message;

  const WidgetVocabularyViolation({
    required this.token,
    required this.normalized,
    required this.message,
  });

  @override
  String toString() => message;
}

/// The widget-reference vocabulary gate (issue #1134 lane 4).
abstract final class WidgetVocabularyGate {
  /// The vendor prefixes the skin dialects alias the vocabulary with
  /// (`ShadInput`, `ZfaButton`, `ZuraffaCard`).
  static const List<String> _vendorPrefixes = ['shad', 'zfa', 'zuraffa'];

  /// The `zfa ui schema` built-in vocabulary (the NodeRegistry
  /// built-ins — the authoritative 26-widget set; grid/table are NOT
  /// in it, the #1149 committed removal).
  static List<String> get builtInVocabulary =>
      NodeRegistry.builtInsOnly().allNames;

  /// Whether [token] is a widget reference at all — a noun naming a
  /// UI component. Method signatures (an open paren), `key:` tokens,
  /// and empty tokens are NOT widget references (the discrimination
  /// that keeps the library-dev Presentation contracts untouched).
  static bool isWidgetReferenceToken(String token) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.contains('(')) return false; // a method signature
    if (I18nKeyContract.isKeyToken(trimmed)) return false; // an i18n key
    return true;
  }

  /// Normalize a widget reference to its vocabulary name: strip the
  /// vendor prefix (shad/zfa/zuraffa, case-insensitive) and lowercase
  /// (`ShadInput` → `input`, `ZfaButton` → `button`, `ZuraffaCard` →
  /// `card`). A token with no vendor prefix passes through lowercased.
  static String normalize(String token) {
    var name = token.trim().toLowerCase();
    for (final prefix in _vendorPrefixes) {
      if (name.startsWith(prefix) && name.length > prefix.length) {
        name = name.substring(prefix.length);
        break;
      }
    }
    return name;
  }

  /// Validate [tokens] against the vocabulary ([vocabulary] defaults
  /// to the `zfa ui schema` built-ins). Non-widget-reference tokens
  /// (method signatures, key tokens) are skipped — they are not widget
  /// references. Returns the violations, each naming the token, its
  /// normalized form, and the fix; an empty list means the gate
  /// passes.
  static List<WidgetVocabularyViolation> validate(
    List<String> tokens, {
    List<String>? vocabulary,
  }) {
    final names = vocabulary ?? builtInVocabulary;
    final violations = <WidgetVocabularyViolation>[];
    for (final token in tokens) {
      if (!isWidgetReferenceToken(token)) continue;
      final normalized = normalize(token);
      if (names.contains(normalized)) continue;
      final removed = normalized == 'grid' || normalized == 'table';
      violations.add(
        WidgetVocabularyViolation(
          token: token,
          normalized: normalized,
          message: 'widget reference "$token" '
              '(normalizes to "$normalized") is not in the ui vocabulary '
              '(`zfa ui schema`)${removed ? ' — grid/table are NOT implemented (removed from the layout vocabulary, issue #1149); a generator that rendered them as a list was lying' : ''}.\n'
              '--> fix: declare a `zfa ui schema` vocabulary name '
              '(e.g. ${names.take(6).join(', ')}, …) or register a '
              'project composite under .zfa/ui/components/, then re-run.',
        ),
      );
    }
    return violations;
  }
}
