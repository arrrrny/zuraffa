/// Vocabulary Narrowing — restricts the `ui.render` tool's input schema to a
/// declared subset of the full vocabulary per mission type (spec FR-005, US4).
library;

import 'ui_vocabulary_schema.dart';

/// Per-mission-type vocabulary configurations. Production apps declare these
/// via configuration, not code (spec Assumptions).
///
/// Each config maps a mission type (e.g. `listing`, `chat`, `dashboard`) to a
/// narrowed [UiVocabularySchema]. Nodes / tokens not in the narrowed schema
/// are rejected at render time (FR-005 acceptance 2).
class VocabularyNarrowingConfig {
  /// Mission type → narrowed schema.
  final Map<String, UiVocabularySchema> byMissionType;

  const VocabularyNarrowingConfig(this.byMissionType);

  /// Empty config — every mission uses the base schema.
  static const VocabularyNarrowingConfig empty =
      VocabularyNarrowingConfig(<String, UiVocabularySchema>{});

  /// Resolve the schema for a given mission type, falling back to the base
  /// schema when no narrowing is declared.
  UiVocabularySchema resolve(String? missionType) {
    if (missionType == null) return UiVocabularySchema.base;
    final narrowed = byMissionType[missionType];
    if (narrowed == null) return UiVocabularySchema.base;
    return narrowed;
  }

  /// Whether the given mission type has a narrowed vocabulary.
  bool hasNarrowingFor(String? missionType) {
    if (missionType == null) return false;
    return byMissionType.containsKey(missionType);
  }
}

/// Resolve the active schema for a mission type (FR-005). Returns the narrowed
/// schema if one is declared, otherwise returns the base schema.
///
/// The returned schema carries the `missionType` tag so the mission trace can
/// record which vocabulary a given render was validated against.
UiVocabularySchema vocabularyNarrowing(
  String? missionType,
  UiVocabularySchema baseSchema, {
  VocabularyNarrowingConfig config = VocabularyNarrowingConfig.empty,
}) {
  if (missionType == null) return baseSchema;
  final narrowed = config.byMissionType[missionType];
  if (narrowed == null) return baseSchema;
  return narrowed;
}
