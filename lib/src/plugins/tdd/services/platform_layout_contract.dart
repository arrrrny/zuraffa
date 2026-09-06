/// PlatformLayoutContract (spec 1142, issue #1142 — composing #1004 and
/// #1102): the spec contract that lets a feature's Presentation table
/// DECLARE the platform layout slots per feature.
///
/// The production ZikZak login is an `AdaptiveViewState` with separate
/// mobile and macos layout widgets (spec 1004's `adaptive_slots`), while
/// a machine-generated view was a single-layout `Column` — structurally
/// different from the real product. This contract closes the gap at the
/// DECLARATION level: the Presentation layer contract carries an
/// `adaptive_layouts` bullet whose tokens are the slot names:
///
/// ```markdown
/// ## Layer Contracts
///
/// ### Presentation
///
/// - `LoginSection`: `ShadInput` for email, `ShadButton` for Sign In
/// - `adaptive_layouts`: `mobile`, `macos`
/// ```
///
/// Extraction rides the EXISTING [LayerContract] shape (the same
/// producers the i18n key contract rides — `SpecParser.parseLayerContracts`
/// for spec.md and `TestListReader.readLayerContracts` for
/// tdd/test-list.md), so a feature that declares no slots keeps the
/// single-layout skeleton (zero drift) and a feature that declares slots
/// gets the `AdaptiveViewState` skeleton with one layout stub per slot,
/// each traced independently in the coverage ledger.
///
/// The slot vocabulary is the adaptive_layout_scaffold_builder's target
/// set (`mobile`, `tablet`, `desktop`, `macos`) plus the production
/// login's runtime slots (`ios`, `android` — issue #1005's SkinEvent
/// slots). An unknown slot name refuses BY NAME (errors-are-an-API) —
/// never a silent guess.
library;

import 'spec_parser.dart';

/// The declared platform layout slots of a feature (issue #1142).
class PlatformLayoutContract {
  /// The Presentation layer contract bullet names that declare the
  /// slots (case-insensitive match on the interface name; the primary
  /// name mirrors the #1004 contract and the
  /// adaptive_layout_scaffold_builder's `adaptive-layouts` data key).
  static const List<String> declarationNames = [
    'adaptive_layouts',
    'platform_layouts',
    'platform_slots',
  ];

  /// The known platform slots: the scaffold builder's targets plus the
  /// production login's runtime slots (the SkinEvent stream's
  /// `slot=` vocabulary, issue #1005).
  static const List<String> knownSlots = [
    'mobile',
    'tablet',
    'desktop',
    'macos',
    'ios',
    'android',
  ];

  /// The declared slots, in first-declaration order, de-duplicated.
  final List<String> slots;

  const PlatformLayoutContract({required this.slots});

  /// Whether [slot] is a known platform slot.
  static bool isKnownSlot(String slot) => knownSlots.contains(slot.trim());

  /// The Pascal class suffix the generated per-platform layout classes
  /// use (the adaptive_layout_scaffold_builder's `_targetClassSuffix`
  /// mapping, completed for the runtime slots).
  static String classSuffix(String slot) => switch (slot.trim()) {
    'mobile' => 'Mobile',
    'tablet' => 'Tablet',
    'desktop' => 'Desktop',
    'macos' => 'Macos',
    'ios' => 'Ios',
    'android' => 'Android',
    _ => throw PlatformLayoutContractException(
      'unknown platform layout slot "$slot".\n'
      '--> fix: declare one of ${knownSlots.join(", ")} in the '
      '`adaptive_layouts` Presentation bullet.',
    ),
  };

  /// Extract the contract from the feature's layer contracts. Returns
  /// null when no Presentation bullet declares slots (zero drift: the
  /// single-layout skeleton stays). A Presentation bullet whose tokens
  /// name an unknown slot THROWS [PlatformLayoutContractException]
  /// naming the token and the fix — never a silent guess.
  static PlatformLayoutContract? fromContracts(List<LayerContract> contracts) {
    final slots = <String>[];
    for (final contract in contracts) {
      if (!contract.layer.toLowerCase().contains('presentation')) continue;
      if (!declarationNames.contains(
        contract.interfaceName.trim().toLowerCase(),
      )) {
        continue;
      }
      for (final method in contract.methods) {
        final slot = method.trim().toLowerCase();
        if (slot.isEmpty) continue;
        if (!isKnownSlot(slot)) {
          throw PlatformLayoutContractException(
            'unknown platform layout slot "$method" declared in the '
            '`${contract.interfaceName}` Presentation bullet.\n'
            '--> fix: declare one of ${knownSlots.join(", ")} '
            '(the adaptive_layout_scaffold_builder targets + the '
            'production SkinEvent slots).',
          );
        }
        if (!slots.contains(slot)) slots.add(slot);
      }
    }
    if (slots.isEmpty) return null;
    return PlatformLayoutContract(slots: List.unmodifiable(slots));
  }

  @override
  String toString() => 'PlatformLayoutContract(${slots.join(", ")})';
}

/// The parse refusal (errors-are-an-API): names the offending token and
/// the fix. The view command refuses BEFORE any write when this throws.
class PlatformLayoutContractException implements Exception {
  PlatformLayoutContractException(this.message);

  final String message;

  @override
  String toString() => message;
}
