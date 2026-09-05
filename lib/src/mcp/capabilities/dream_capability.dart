/// The `dream_draft_spec` MCP v2 capability (spec
/// 1010-zfa-dream-one-command-app, FR-001/FR-010): the LLM integration
/// seam the `zfa dream` command orchestrates.
///
/// The capability composes one prompt — the feature description plus the
/// plan-schema constraint (the zuraffa-1.0 grammar: Template Version pin,
/// Functional Requirements, Acceptance Scenarios, Key Entities, External
/// Dependencies & Contracts, Layer Contracts, and the dream-only
/// AdaptiveViewSlots and Skin Contract sections) plus, on retries, the
/// ingest refusal feedback — and asks the ONLY existing completion
/// abstraction, [LlmClient]. The dream command is a thin orchestrator,
/// NOT a new LLM client: this file adds no HTTP, no provider, no
/// endpoint. When no client is configured (or the completion is empty or
/// unparseable), the capability falls back to the deterministic
/// [DreamSpecDrafter] — a template instantiation that emits a
/// schema-valid spec — and labels the result `drafter=deterministic` so
/// the summary line, the receipts, and the PR body all say which drafter
/// produced the spec (never a silent pass).
///
/// The LLM response contract: two labeled fenced blocks —
/// ```dream-spec ... ``` and ```dream-plan ... ``` — so the spec and the
/// plan travel in one completion and stay separable.
library;

import 'package:zuraffa/src/agent/runtime/llm_client.dart';

/// One draft result: the spec markdown, the plan markdown, and the
/// drafter that produced them (`llm` or `deterministic`).
class DreamDraft {
  const DreamDraft({
    required this.specMarkdown,
    required this.planMarkdown,
    required this.drafter,
  });

  final String specMarkdown;
  final String planMarkdown;
  final String drafter;
}

/// The plan-schema constraint every dream draft must satisfy — the
/// sections `zfa tdd plan`'s parser chain validates (Template Version,
/// FR/AC grammar, Key Entities, External Dependencies & Contracts, Layer
/// Contracts) plus the two dream-only sections that drive the skin cycle
/// (AdaptiveViewSlots, Skin Contract). This text IS the constraint the
/// issue's deliverable 1(a) names; it is shared by the LLM prompt and
/// the deterministic drafter so the two paths cannot drift.
const String kDreamSpecSchemaConstraint = '''
Sections (exact headings, in order):
1. `**Template Version**: `zuraffa-1.0`` — the treaty pin (missing/unknown
   versions are refused before any parsing).
2. `# Spec: <feature>` — the spec title.
3. `## Functional Requirements` — `- **FR-NNN**: <statement>` bullets.
4. `## Acceptance Scenarios` — numbered
   `N. **Given** ... **When** ... **Then** ...` scenarios; a scenario may
   carry `**Type**: widget` on the following line to declare the widget
   (skin) lane.
5. `## Key Entities` — a `| Entity | Fields | Purpose |` table;
   `Fields` cells are backticked `name: Type` pairs. Entity names are
   PascalCase and MUST NOT collide with the zuraffa framework export
   surface (e.g. `Credentials`) or repeat within the table.
6. `## External Dependencies & Contracts` — a
   `| Dependency | Type | Contract | Mock Priority |` table; the Contract
   cell is a backticked `method(args) -> Return` signature and MUST NOT
   be empty. Only declare dependencies the statements reference.
7. `## Layer Contracts` — `**Layer**:` blocks of
   ``- `Interface`: `method(args) -> Return` `` rows; every method
   signature carries ` -> ` (a signature without an arrow is refused).
   An interface MUST appear under exactly one layer.
8. `## AdaptiveViewSlots` — a `| Slot | Breakpoint | Content |` table
   declaring the adaptive view slots the skin cycle fills.
9. `## Skin Contract` — a `| Token | Value | Source |` table declaring
   the theme tokens/constraints the skin cycle must honor.
''';

/// Composes the draft prompt for one dream attempt.
String composeDreamPrompt({
  required String feature,
  required String description,
  String? feedback,
}) {
  final buffer = StringBuffer()
    ..writeln(
      'Draft the zuraffa spec and implementation plan for feature '
      '"$feature".',
    )
    ..writeln()
    ..writeln('Feature description (plain English): $description')
    ..writeln();
  if (feedback != null && feedback.trim().isNotEmpty) {
    buffer
      ..writeln(
        'The previous draft was REFUSED by `zfa tdd ingest`. Fix '
        'every problem named below and re-draft the WHOLE spec/plan '
        'pair:',
      )
      ..writeln()
      ..writeln(feedback.trim())
      ..writeln();
  }
  buffer
    ..writeln('The spec MUST satisfy this schema constraint exactly:')
    ..writeln()
    ..writeln(kDreamSpecSchemaConstraint.trimRight())
    ..writeln()
    ..writeln(
      'Respond with exactly two labeled fenced blocks and nothing '
      'else:',
    )
    ..writeln('```dream-spec')
    ..writeln('<the complete spec.md markdown>')
    ..writeln('```')
    ..writeln('```dream-plan')
    ..writeln('<the complete plan.md markdown>')
    ..writeln('```');
  return buffer.toString();
}

/// Parses an LLM completion into a [DreamDraft]. Returns null when the
/// completion does not carry both labeled blocks (the caller falls back
/// to the deterministic drafter — labeled, never a silent pass).
DreamDraft? parseDreamCompletion(String completion) {
  final spec = _labeledBlock(completion, 'dream-spec');
  final plan = _labeledBlock(completion, 'dream-plan');
  if (spec == null || plan == null) return null;
  if (spec.trim().isEmpty || plan.trim().isEmpty) return null;
  return DreamDraft(
    specMarkdown: spec.trim(),
    planMarkdown: plan.trim(),
    drafter: 'llm',
  );
}

String? _labeledBlock(String text, String label) {
  final m = RegExp('```$label\\s*\\n(.*?)```', dotAll: true).firstMatch(text);
  return m?.group(1);
}

/// The `dream_draft_spec` v2 tool body.
class DreamCapability {
  const DreamCapability();

  /// Drafts the spec/plan pair for [description].
  ///
  /// [llmClient] is the existing completion abstraction (injected by the
  /// caller — the MCP host wires a real client; the CLI path leaves it
  /// null and the deterministic drafter runs, labeled honestly).
  /// [feedback] carries the ingest refusal text on retries (FR-003).
  Future<DreamDraft> draftSpec({
    required String feature,
    required String description,
    String? feedback,
    LlmClient? llmClient,
  }) async {
    final prompt = composeDreamPrompt(
      feature: feature,
      description: description,
      feedback: feedback,
    );
    if (llmClient != null) {
      String completion = '';
      try {
        completion = await llmClient.complete(prompt);
      } catch (_) {
        // A failing client degrades to the deterministic drafter below —
        // the FallbackLLMClient contract (fail-through, never crash).
      }
      final parsed = completion.isEmpty
          ? null
          : parseDreamCompletion(completion);
      if (parsed != null) return parsed;
    }
    return DreamSpecDrafter().draft(
      feature: feature,
      description: description,
      feedback: feedback,
    );
  }
}

/// The deterministic fallback drafter: a template instantiation that
/// emits a schema-valid spec + plan from the description. This is NOT an
/// LLM and NOT a client — it is the labeled degraded mode that keeps
/// `zfa dream` one command end-to-end when no LLM is configured, the
/// same honesty as `FallbackLLMClient` returning '' (FR-001).
///
/// Deterministic rules (shared with DreamRunner's feature-slug
/// derivation via [DreamNouns], so the feature name and the entity name
/// can never disagree):
/// - entity name = PascalCase of the first two significant nouns,
///   singularized (`favorite deals` → `FavoriteDeal`);
/// - fields = `id: String`, `title: String`;
/// - the acceptance scenario carries `**Type**: widget` when the
///   description carries page/screen intent, so the skin cycle runs;
/// - one Domain repository interface with a `list()` signature;
/// - AdaptiveViewSlots + Skin Contract tables (the dream-only sections);
/// - feedback repair: the ingest `--> fix: rename the entity` suggestion
///   is applied verbatim — a colliding name becomes `<Name>Entity`
///   (FR-003).
class DreamSpecDrafter {
  const DreamSpecDrafter();

  DreamDraft draft({
    required String feature,
    required String description,
    String? feedback,
  }) {
    var entity = _entityName(description);
    entity = _applyRenameFeedback(entity, feedback);

    final isWidget = RegExp(
      r'\b(page|screen|view|dialog|sheet|ui|widget)s?\b',
      caseSensitive: false,
    ).hasMatch(description);

    final title = description.trim();
    final entityLower = entity
        .replaceAllMapped(RegExp('([A-Z])'), (m) => ' ${m.group(1)}')
        .trim()
        .toLowerCase();

    final spec =
        '''
**Template Version**: `zuraffa-1.0`

# Spec: $feature

## Functional Requirements

- **FR-001**: $title (the $entityLower carries the data)

## Acceptance Scenarios

1. **Given** a fresh state **When** the user invokes the feature
   **Then** the system responds${isWidget ? '\n   **Type**: widget' : ''}

## Key Entities

| Entity | Fields | Purpose |
|--------|--------|---------|
| $entity | `id: String`, `title: String` | $title |

## External Dependencies & Contracts

| Dependency | Type | Contract | Mock Priority |
|-----------|------|----------|---------------|
| Hive | storage | `read(key) -> $entity?` | P1 |

## Layer Contracts

**Domain**:

- `${entity}Repository`: `list() -> Future<Result<List<$entity>, AppFailure>>`

## AdaptiveViewSlots

| Slot | Breakpoint | Content |
|------|-----------|---------|
| primary | default | the $entityLower list |

## Skin Contract

| Token | Value | Source |
|-------|-------|--------|
| spacing | default | framework theme |
''';

    final plan =
        '''
# Implementation Plan: $feature

**Branch**: `$feature` | **Spec**: specs/$feature/spec.md

## Summary

$title — drafted by `zfa dream` (deterministic drafter; no LLM client
configured).

## Key Entities

- `$entity` (id, title) with a Domain repository and a widget-lane view
  when the description declares UI intent.

## Engine/Skin cycles

- Engine: `zfa tdd run $feature` to green.
- Skin: `zfa tdd view` over the widget lane; hand-edit seam per the Skin
  Contract.
''';

    return DreamDraft(
      specMarkdown: spec,
      planMarkdown: plan,
      drafter: 'deterministic',
    );
  }
}

/// Significant-noun extraction shared by the drafter (entity name) and
/// the dream runner (feature slug) so the two can never disagree.
class DreamNouns {
  const DreamNouns._();

  static const Set<String> _stopwords = {
    'a',
    'an',
    'the',
    'that',
    'this',
    'these',
    'those',
    's',
    'by',
    'of',
    'for',
    'with',
    'and',
    'or',
    'to',
    'in',
    'on',
    'at',
    'from',
    'into',
    'user',
    'users',
    'page',
    'pages',
    'screen',
    'screens',
    'list',
    'lists',
    'listing',
    'listings',
    'show',
    'shows',
    'shown',
    'display',
    'displays',
    'render',
    'renders',
    'rendered',
    'sort',
    'sorts',
    'sorted',
    'manage',
    'manages',
    'when',
    'then',
    'given',
  };

  /// Lowercased significant tokens of [description], stopwords dropped.
  /// Apostrophes are stripped BEFORE tokenizing (`user's` → `user`, a
  /// stopword) so possessives never leak into entity/feature names.
  static List<String> extract(String description) {
    final tokens = description
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9\s]"), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty && !_stopwords.contains(t))
        .toList();
    return tokens;
  }

  /// The entity name: PascalCase of the first two significant nouns,
  /// singularized (trailing 's' dropped when the token ends with one and
  /// is longer than 3 chars).
  static String entityName(String description) =>
      _pascalCase(extract(description).take(2).map(_singularize).toList());

  /// The feature slug: kebab-case of the first two significant nouns,
  /// singularized.
  static String featureSlug(String description) =>
      extract(description).take(2).map(_singularize).join('-');
}

String _entityName(String description) => DreamNouns.entityName(description);

String _singularize(String word) {
  if (word.length > 3 && word.endsWith('s') && !word.endsWith('ss')) {
    return word.substring(0, word.length - 1);
  }
  return word;
}

String _pascalCase(List<String> words) => words
    .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
    .join();

/// Applies the ingest rename suggestion: a feedback line naming the
/// colliding [entity] with `--> fix: rename the entity, e.g. '<X>'`
/// renames the entity to <X> when <X> is derived from the collision
/// language, else the deterministic `entity + 'Entity'` repair (#942's
/// suggested shape).
String _applyRenameFeedback(String entity, String? feedback) {
  if (feedback == null || !feedback.contains('rename the entity')) {
    return entity;
  }
  if (RegExp(
    'entity name collision[^\\n]*\\b$entity\\b',
    caseSensitive: false,
  ).hasMatch(feedback)) {
    return '${entity}Entity';
  }
  return entity;
}
