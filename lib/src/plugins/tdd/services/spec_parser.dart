/// `SpecParser` — reads a `spec.md` and emits a list of behaviors.
///
/// Bug #846: acceptance ids are document-wide sequential (AC-1, AC-2, …
/// across user stories — the literal scenario number restarts per story
/// and duplicate criterion ids made traceability ambiguous), and a
/// scenario whose header line carries `(manual: <owner>)` is an explicit
/// non-automatable declaration: it is excluded from the automated loop
/// (no behavior row) and shows up in the traceability matrix as manual.
library;

import '../../../models/mock_priority.dart';
import '../models/behavior.dart';
import '../models/lane.dart';
import '../models/routing.dart';

/// One row of the zuraffa-1.0 template's `External Dependencies &
/// Contracts` table (bug #919): the dependency's name, its kind, the
/// declared contract (`name(args) -> return` shapes), and the mock
/// priority the mock-first make path (#909) will honor.
class SpecDependency {
  const SpecDependency({
    required this.dependency,
    required this.type,
    required this.contract,
    required this.mockPriority,
  });

  final String dependency;
  final String type;
  final String contract;
  final String mockPriority;

  @override
  String toString() =>
      'SpecDependency($dependency, $type, $contract, '
      '$mockPriority)';
}

/// One declared layer-contract interface (bug #919): the layer name
/// (`**Domain**:`), the interface name, and its declared method
/// signatures (backticked `name(args) -> result` shapes).
class LayerContract {
  const LayerContract({
    required this.layer,
    required this.interfaceName,
    required this.methods,
  });

  final String layer;
  final String interfaceName;
  final List<String> methods;

  @override
  String toString() => 'LayerContract($layer, $interfaceName, $methods)';
}

/// One declared field of a [SpecEntity], parsed from a backticked
/// `` `name: Type` `` pair in the spec's Key Entities prose.
class EntityField {
  const EntityField({required this.name, required this.type});

  final String name;
  final String type;

  @override
  String toString() => '$name:$type';
}

/// One entity declared by the spec's `Key Entities` section (bug #829):
/// the name is the bullet's bold head (generic suffixes stripped to a
/// valid Dart identifier), the fields are the `name: Type` pairs the
/// spec carries (empty when the prose declares none). Bug #919:
/// `purpose` is the third column of the zuraffa-1.0 template's table
/// form; empty for legacy bullet declarations. Issue #1486: in table
/// cells the pairs no longer require backticks — plain prose pairs
/// (`| Task | id: String, title: String |`) parse too, mixed freely
/// with the backticked form.
class SpecEntity {
  const SpecEntity({
    required this.name,
    this.fields = const [],
    this.purpose = '',
  });

  final String name;
  final List<EntityField> fields;
  final String purpose;

  @override
  String toString() => 'SpecEntity(name: $name, fields: $fields)';
}

/// Issue #1486: a Key Entities fields cell that SHOWS pair evidence —
/// a backticked span or an `identifier:` shape — but still parsed to
/// zero fields. The #1486 failure mode was silence: the cell's pairs
/// were dropped, the entity generated field-less, and the first signal
/// was a vacuous-green deep into the run. The record names the row, the
/// verbatim cell, and the 1-based spec line so plan can refuse the
/// silence before anything generates against the empty entity.
class SpecEntityFieldAnomaly {
  const SpecEntityFieldAnomaly({
    required this.entity,
    required this.cell,
    required this.line,
  });

  final String entity;
  final String cell;
  final int line;

  @override
  String toString() => 'SpecEntityFieldAnomaly($entity, line $line: `$cell`)';
}

/// One FR's declaration-level routing facts (feature 1484): what the
/// FR's block DECLARES, and nothing else — the FR id, the
/// document-wide unit id the FR consumes ([_extractUnit] walks the same
/// numbering), the 1-based spec line of the FR header, whether the
/// block carries the `**Type**: manual` exemption marker (and where),
/// and the contract tokens the block's first `traces:` line binds.
///
/// Issue #1484: every FR unconditionally derived a unit behaviour row,
/// so inherently non-unit FRs (UI appearance, non-functional
/// constraints, whole-app properties) manufactured unit rows that could
/// never pass `make` — permanently blocking `zfa tdd run` with no
/// opt-out. #846 gave acceptance criteria the `(manual:)` hatch; 1484
/// extends the same concept to FRs.
class FrRouting {
  final String frId;
  final String unitId;
  final int specLine;

  /// Whether the FR's block declares the `**Type**: manual` exemption —
  /// the same marker grammar the scenario-side `**Type**` declaration
  /// uses, constrained to the `manual` kind.
  final bool manualMarker;

  /// The 1-based spec line of the marker line, when declared.
  final int? markerLine;

  /// The contract tokens the block's first `traces:` line binds
  /// (signature-shaped tokens dropped, the [traceTokens] filter).
  final List<String> traceTokens;

  /// The FR prose after the id colon, raw (the `**` strip and the
  /// `[persistent]` tag handling stay [_extractUnit]'s business).
  final String rawText;

  const FrRouting({
    required this.frId,
    required this.unitId,
    required this.specLine,
    required this.rawText,
    this.manualMarker = false,
    this.markerLine,
    this.traceTokens = const [],
  });

  /// Whether the block binds a contract trace — a `traces:` line whose
  /// tokens survive the filter. An EMPTY list is the unbound state
  /// #1319 warns about.
  bool get traced => traceTokens.isNotEmpty;

  /// The 1484 routing: an FR declared `**Type**: manual` — or, by
  /// default, an FR with no `traces:` binding — is a manual
  /// declaration, never a unit behaviour row. The explicit declaration
  /// outranks the trace (a marker plus a contradictory binding stays
  /// manual: the author's word wins).
  bool get routesManual => manualMarker || !traced;

  @override
  String toString() =>
      'FrRouting($frId/$unitId, line $specLine, '
      'manual: $manualMarker, traces: $traceTokens)';
}

class SpecParser {
  const SpecParser();

  /// Issue #1196 (parser hardening): normalize the spec text BEFORE
  /// any walk — CRLF (`\r\n`) and lone-CR line endings become `\n`
  /// (line-for-line, so every 1-based spec line number survives), and
  /// a leading BOM is stripped (the UTF-8 decoder usually eats it,
  /// but the parser must not depend on the I/O layer). Without this,
  /// `.`-terminated capture patterns (`(.+)$`) silently drop every
  /// CRLF FR bullet — a silent misroute the 120-format sweep catches.
  static String normalizeSpecText(String specMd) {
    var md = specMd;
    if (md.startsWith('\uFEFF')) md = md.substring(1);
    if (md.contains('\r')) {
      md = md.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    }
    return md;
  }

  /// Issue #1196: decode the common markdown-escaped HTML entities in
  /// a HEADING line before section matching (`&amp;` in `External
  /// Dependencies &amp; Contracts` otherwise hides the section — the
  /// parser skips its declared contracts silently). Content lines stay
  /// verbatim; only heading recognition decodes.
  static String _decodeEntities(String line) => line
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ');

  /// Issue #1196: the scenario block header. Numbering may be flat
  /// (`1.`) or dotted/nested (`1.1.`, `2.3.` — ACs nested under user
  /// stories), and the Given marker may be bold (`**Given**`, the
  /// strict grammar) or plain (`Given` — inline-prose specs). The same
  /// grammar drives the behavior walk, the marker walk, and the
  /// requirement scanner so AC ids stay aligned document-wide.
  static final RegExp _scenarioHeader = RegExp(
    r'^\s*(\d+(?:\.\d+)*)\.?\s*(?:\*\*)?Given(?:\*\*)?',
  );

  /// The UI-intent signature (bug #830): acceptance prose that names a
  /// UI-observable outcome — rendered surfaces, layout regions, navigation
  /// outcomes, the app shell — cannot be expressed by a plain-function
  /// subject, so such scenarios are marked [BehaviorKind.widget] and their
  /// gen pair is a view-builder stub + a `testWidgets` test.
  ///
  /// Bug #936: Then-clauses are passive/past by convention ("an error
  /// message is rendered", "the user is navigated"), so the verb
  /// alternation covers the full conjugation (`render(?:s|ed|ing)?`,
  /// `navigat(?:e|es|ed|ion|ing)`, `display(?:s|ed|ing)?`). Word
  /// boundaries stay anchored; "navigation" already matched before #936.
  ///
  /// Issue #1318: the weak outcome verbs `shows?|shown` moved OUT of the
  /// unconditional alternation — matched with no subject context they
  /// routed SSE event-schema assertions ("the decision_made event shows
  /// outcome: clarify") widget-kind, and the spec-1000 noFlutter guard
  /// hard-refused every all-CORE server spec. They survive in
  /// [_weakAppearanceVerb], gated on a co-occurring [_uiSurfaceNoun]; the
  /// strong #830/#936 grammar below (render/navigate/display + layout
  /// nouns) is unchanged.
  static final RegExp uiAcceptanceIntent = RegExp(
    r'\b(render(?:s|ed|ing)?|sidebar|bottom nav|tab bar|app bar|app shell|'
    r'themes?|widgets?|navigat(?:e|es|ed|ion|ing)|display(?:s|ed|ing)?)\b',
    caseSensitive: false,
  );

  /// Issue #1318: event-noun subject + content verb — "the decision_made
  /// event shows outcome: clarify", "the content_delta events contain the
  /// clarification", "the response includes the schema". The subject is
  /// protocol, not surface: the verb describes the event's PAYLOAD, so
  /// the prose is an event/protocol schema assertion even when a UI
  /// surface noun co-occurs in the payload description ("the event shows
  /// the dialog id in its payload"). Such scenarios route CORE by
  /// default; an explicit `**Type**` marker is the escape hatch. The
  /// optional modifier word before the noun keeps compound subjects
  /// covered (`decision_made event`, `SSE response`, `error message`).
  /// `render/navigate/display` are deliberately NOT content verbs here:
  /// they are the #936 grammar's backbone, and #1318's named scope is the
  /// shows/includes/carries family. `has`/`have` exclude only as MAIN
  /// verbs — the `(?!\s+been)` lookahead keeps perfect-tense passives
  /// ("the message has been rendered", the #936 convention) out of the
  /// exclusion so the strong grammar still sees them.
  static final RegExp _eventNounSubject = RegExp(
    r'\b(?:[\w-]+\s+)?'
    r'(?:events?|messages?|responses?|payloads?|streams?|frames?|'
    r'notifications?)\s+'
    r'(?:shows?|shown|includes?|contains?|carries?|presents?|returns?|'
    r'holds?|h(?:as|ave)(?!\s+been))\b',
    caseSensitive: false,
  );

  /// Issue #1318: the weak appearance verbs — #936's `shows?|shown` plus
  /// `appears?` ("the dialog appears with the title") — matched with NO
  /// subject context are ambiguous: "the decision_made event shows
  /// outcome: clarify" is protocol prose, "the screen shows a spinner" is
  /// UI. They no longer live in the unconditional [uiAcceptanceIntent]
  /// alternation; [isUiAcceptance] routes them widget-kind only when a
  /// [_uiSurfaceNoun] co-occurs.
  static final RegExp _weakAppearanceVerb = RegExp(
    r'\b(shows?|shown|appears?)\b',
    caseSensitive: false,
  );

  /// Issue #1318: the UI surface nouns a weak appearance verb needs in
  /// order to route widget-kind. `dialogs?`/`screens?`/`pages?` join the
  /// #830 layout set here ONLY (not in [uiAcceptanceIntent]) — a noun
  /// alone ("they see the home screen") stays acceptance, while
  /// noun+appearance-verb prose ("the screen shows a spinner", "the
  /// dialog appears with the title", "the page shows the settings form")
  /// is genuine UI intent. For `shows?|shown` widening THIS set never
  /// widens routing beyond pre-#1318 (the bare verb sufficed, so every
  /// verb+noun pair already routed widget). `appears?` is the exception:
  /// it was NOT in the pre-#1318 alternation, so "the dialog appears"
  /// routed acceptance before #1318 — a deliberate widening (see the RED
  /// table in specs/1318-noflutter-false-positive-on-event-prose/tdd/).
  static final RegExp _uiSurfaceNoun = RegExp(
    r'\b(sidebar|bottom nav|tab bar|app bar|app shell|themes?|widgets?|'
    r'dialogs?|screens?|pages?)\b',
    caseSensitive: false,
  );

  /// Separates independently asserted predicates without splitting noun
  /// lists inside one predicate. This keeps an event-content exclusion local
  /// to its clause while allowing a sibling UI assertion to classify.
  static final RegExp _predicateClauseBoundary = RegExp(
    r'(?:[.!?;]\s+|,\s*(?:and|but|while)\s+|'
    r'\s+(?:and|but|while)\s+(?=(?:the|a|an|i|we|they|you)\b))',
    caseSensitive: false,
  );

  /// Whether an acceptance scenario's prose carries UI intent (bug #830).
  ///
  /// Issue #1318 ordering: within each predicate clause, the event-noun
  /// exclusion is checked FIRST — a content verb whose subject is an event
  /// noun is protocol prose, never a rendered surface. A separate clause may
  /// still carry UI intent. The weak appearance verbs
  /// (`shows?|shown|appears?`) survive only with a co-occurring UI surface
  /// noun. Ambiguous prose keeps its sanctioned escape hatch: declare the
  /// scenario with a `**Type**` marker (the declaration outranks the
  /// classifier in both directions).
  static bool isUiAcceptance(String description) {
    for (final clause in description.split(_predicateClauseBoundary)) {
      if (_eventNounSubject.hasMatch(clause)) continue;
      if (uiAcceptanceIntent.hasMatch(clause)) return true;
      if (_weakAppearanceVerb.hasMatch(clause) &&
          _uiSurfaceNoun.hasMatch(clause)) {
        return true;
      }
    }
    return false;
  }

  /// The inline non-automatable declaration on a scenario header line
  /// (bug #846): a manual scenario consumes an AC number but emits no
  /// row, so the id alignment is preserved even when scenarios are
  /// human-executed.
  static final RegExp manualScenarioMarker = RegExp(r'\(manual:\s*[^)]*\)');

  /// A scenario type marker line (feature 071, rung 1): `**Type**: widget`
  /// on its own line inside a scenario block. The kind must name a
  /// [BehaviorKind] value.
  static final RegExp _typeMarkerLine = RegExp(
    r'^\s*\*\*Type\*\*:\s*(\S+)\s*$',
  );

  /// Parse the per-scenario `**Type**` lane markers (feature 071,
  /// contracts/template-declarations.md §1) into declarations keyed by
  /// the document-wide behavior id (`A<n>`), each carrying the 1-based
  /// spec line of its marker.
  ///
  /// Declared structures only: the walk mirrors [_extractAcceptance]'s
  /// block scan (numbered Given headers, document-wide AC numbering,
  /// manual scenarios consume a number but emit nothing) — no prose is
  /// interpreted. Refusals are errors-are-an-API: a duplicate marker or
  /// an unknown kind names the offending spec line and the fix.
  static Map<String, ScenarioDeclaration> parseScenarioTypeMarkers(
    String specMd,
  ) {
    final markers = <String, ScenarioDeclaration>{};
    // Fenced code blocks are documentation, not declarations: a
    // `**Type**` marker inside a ``` example must neither declare a
    // lane nor collide with a real marker (round-2 review fix 5). Each
    // fenced span is blanked to equivalent newlines so the surviving
    // markers' spec lines stay accurate.
    final blanked = normalizeSpecText(specMd).replaceAllMapped(
      _fencedCodeBlock,
      (m) => '\n' * '\n'.allMatches(m.group(0)!).length,
    );
    final lines = blanked.split('\n');
    var inScenario = false;
    // Feature 1484: whether the walk is inside an FR block — an FR
    // header through the next [_endsFrBlock] boundary. Only there does
    // `**Type**: manual` carry the FR-side exemption meaning.
    var inFrBlock = false;
    var scenarioLine = 0;
    var aIdx = 0;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineNo = i + 1;
      if (_scenarioHeader.hasMatch(line)) {
        aIdx += 1;
        inScenario = true;
        inFrBlock = false;
        scenarioLine = lineNo;
        continue;
      }
      if (_frLine(line) != null) {
        // An FR header opens its block (the boundary the FR routing
        // walk uses); the block's continuation lines are FR-owned. The
        // scenario state is untouched — an FR bullet inside an open
        // scenario block reads exactly as it did before.
        inFrBlock = true;
        continue;
      }
      // Any markdown heading that is not a scenario header ends the
      // scenario block: a marker after `## Functional Requirements`
      // belongs to no numbered scenario (round-2 review fix 5).
      if (line.trimLeft().startsWith('#')) {
        inScenario = false;
        inFrBlock = false;
        continue;
      }
      final m = _typeMarkerLine.firstMatch(line);
      if (m == null) continue;
      if (!inScenario) {
        // Feature 1484: `**Type**: manual` outside any numbered
        // scenario block is the FR-side manual exemption — an FR block
        // continuation line the FR routing walk ([parseFrRoutings])
        // owns, never a misplaced scenario marker. The exemption is
        // gated by FR-block ownership: outside an FR block it stays the
        // misplaced-marker refusal. Any OTHER kind outside a scenario
        // block stays the misplaced-marker refusal too (round-2 review
        // fix 5).
        if (inFrBlock && m.group(1)!.toLowerCase() == 'manual') continue;
        throw StateError(
          'spec line $lineNo carries a `**Type**` marker outside any '
          'numbered scenario block.\n'
          '   --> fix: move the marker inside the scenario it declares.',
        );
      }
      final raw = m.group(1)!.toLowerCase();
      final kind = BehaviorKind.values.where((k) => k.name == raw).firstOrNull;
      if (kind == null) {
        throw StateError(
          'spec line $lineNo declares an unknown scenario type '
          '"**Type**: ${m.group(1)}".\n'
          '   --> fix: use one of '
          '${BehaviorKind.values.map((k) => k.name).join(', ')}.',
        );
      }
      final id = 'A$aIdx';
      if (markers.containsKey(id)) {
        throw StateError(
          'duplicate `**Type**` markers for scenario $id (first at line '
          '${markers[id]!.specLine}, duplicate at line $lineNo).\n'
          '   --> fix: keep exactly one `**Type**` marker per scenario.',
        );
      }
      // A manual scenario consumes the AC number but emits no row
      // (bug #846) — so it also declares nothing (no row to route).
      final blockIsManual = manualScenarioMarker.hasMatch(
        lines[scenarioLine - 1],
      );
      if (!blockIsManual) {
        markers[id] = ScenarioDeclaration(
          behaviorId: id,
          declaredType: kind,
          specLine: lineNo,
        );
      }
    }
    return markers;
  }

  /// The heading that opens a Key Entities section (corpus format:
  /// `### Key Entities`; any heading level 1-6 is accepted, matched
  /// case-insensitively). Issue #1196: a trailing qualifier (`### Key
  /// Entities — commerce`) is tolerated, and HTML entities are decoded
  /// before the match (see [_matchesSectionHeading]).
  static final RegExp _keyEntitiesHeading = RegExp(
    r'^#{1,6}\s+key\s+entities\b[^#]*$',
    caseSensitive: false,
  );

  /// A Key Entities bullet: `- **Name**: prose ...` (the name may carry
  /// a generic suffix such as `ToggleParams<I, F>`).
  static final RegExp _entityBullet = RegExp(
    r'^\s*[-*]\s+\*\*(.+?)\*\*\s*:\s*(.*)$',
  );

  /// A backticked `` `name: Type` `` field pair in the bullet prose.
  static final RegExp _fieldPair = RegExp(
    r'`([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([^`]+)`',
  );

  /// Issue #1486: the `name: Type` pair shape a fields cell carries,
  /// backticked or not. Applied to (a) the raw content of each backtick
  /// span and (b) each top-level comma-separated fragment of the
  /// unbackticked text, it is exactly the old backticked grammar for
  /// backticked spans (name must open the span, type runs to the
  /// closing backtick) and the new plain-prose grammar for the rest.
  static final RegExp _fieldPairShape = RegExp(
    r'^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.+)$',
  );

  /// Issue #1486: positive evidence that a fields cell TRIES to declare
  /// pairs — any backtick span, or any `identifier:` shape. Evidence
  /// plus zero parsed fields is a spec-authoring bug the plan names
  /// (see [SpecEntityFieldAnomaly]), never a silent empty list.
  static final RegExp _fieldCellEvidence = RegExp(
    r'`|[A-Za-z_][A-Za-z0-9_]*\s*:',
  );

  /// Issue #1486: the `final` member shape of an entity Dart file —
  /// what phase-0's reuse path compares the plan's declared fields
  /// against (`final String id;`, `final Map<String, int> counters;`,
  /// `late final String x;`). Assignment-initialised locals (`final x
  /// = 3;`) are excluded by the `=`, constructor params don't carry
  /// `final`. Best-effort by design: it feeds a reuse warning only.
  static final RegExp _dartFinalMember = RegExp(
    r'\bfinal\s+([^;=]+?)\s+([A-Za-z_][A-Za-z0-9_]*)\s*;',
  );

  static final RegExp _dartIdentifier = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

  /// A Key Entities table header (bug #919): the zuraffa-1.0 template
  /// declares entities as a 3-column table `| Entity | Fields | Purpose |`.
  static final RegExp _entityTableHeader = RegExp(
    r'^\s*\|\s*entity\s*\|\s*fields\s*\|\s*purpose\s*\|\s*$',
    caseSensitive: false,
  );

  /// Issue #1381: the pre-#919 2-column Key Entities header
  /// (`| Entity | Fields |`) — bug #919 kept pre-919 artifacts readable
  /// everywhere else, so the parser accepts this header too instead of
  /// silently extracting zero entities (which made the run-engine cert
  /// gate pass trivially).
  static final RegExp _entityTableHeader2Col = RegExp(
    r'^\s*\|\s*entity\s*\|\s*fields\s*\|\s*$',
    caseSensitive: false,
  );

  /// A Key Entities table row: `| Name | `f: T`, `g: U` | purpose |`.
  static final RegExp _entityTableRow = RegExp(
    r'^\s*\|\s*([^|]+?)\s*\|\s*([^|]*?)\s*\|\s*([^|]*?)\s*\|\s*$',
  );

  /// A 2-column Key Entities table row: `| Name | `f: T`, `g: U` |`
  /// (issue #1381 — no Purpose column).
  static final RegExp _entityTableRow2Col = RegExp(
    r'^\s*\|\s*([^|]+?)\s*\|\s*([^|]*?)\s*\|\s*$',
  );

  /// A Key Entities table separator row (`| -- | -- | -- |`).
  static final RegExp _tableSeparator = RegExp(r'^\s*\|[\s\-|:]*\|\s*$');

  /// The zuraffa spec template's treaty pin (bug #919): the header marker
  /// `**Template Version**: `x`` that declares which template grammar the
  /// spec was authored against.
  static final RegExp _templateVersionMarker = RegExp(
    r'^\s*\*\*template\s+version\*\*:\s*`?([^`\n]+?)`?\s*$',
    caseSensitive: false,
  );

  /// Fenced code blocks (```` ``` ```` … ```` ``` ````). The template
  /// version marker inside a fenced block is documentation, not a treaty
  /// pin (a spec's "How to write a spec" example would otherwise pin the
  /// spec to the example's version).
  static final RegExp _fencedCodeBlock = RegExp(
    r'^[ \t]*```[^\r\n]*(?:\r?\n|$)[\s\S]*?^[ \t]*```[ \t]*\r?$',
    multiLine: true,
  );

  /// Template versions whose grammar this parser implements (bug #919).
  /// A spec declaring anything else — or nothing — is contract drift:
  /// plan exits 3 before parsing, so an unpinned spec can never drive a
  /// silently-wrong plan.
  static const Set<String> knownTemplateVersions = {latestTemplateVersion};

  /// The latest template version whose grammar this parser implements.
  /// The `--migrate-spec` migration path (issue #990) pins a migrated
  /// spec to this version; the gate contract itself (knownTemplateVersions,
  /// the drift exit) is unchanged.
  static const String latestTemplateVersion = 'zuraffa-1.0';

  /// External dependency names the template ecosystem knows (bug #919):
  /// a requirement statement may reference one of these only when the
  /// spec declares it in the External Dependencies & Contracts table —
  /// an undeclared reference is a spec contract violation (exit 2).
  static const Set<String> knownExternalDependencies = {
    'Hive',
    'SharedPreferences',
    'Firebase',
    'Supabase',
    'SQLite',
    'Drift',
  };

  /// The declared template version, or null when the spec carries no
  /// `**Template Version**` marker.
  ///
  /// Fenced code blocks (``` … ```) are stripped before matching, so a
  /// marker that appears inside a "How to write a spec" example is
  /// treated as documentation and not as the spec's treaty pin.
  String? parseTemplateVersion(String specMd) {
    final stripped = normalizeSpecText(specMd).replaceAll(_fencedCodeBlock, '');
    for (final line in stripped.split('\n')) {
      final m = _templateVersionMarker.firstMatch(line.trim());
      if (m != null) return m.group(1)!.trim();
    }
    return null;
  }

  /// Issue #1196: section-heading match that first decodes HTML
  /// entities and then applies the canonical heading pattern (which
  /// tolerates a trailing qualifier). `## External Dependencies &amp;
  /// Contracts` and `## Layer Contracts — epic-level` are the section
  /// the parser owes its contracts to — silently skipping either is a
  /// silent misroute.
  static bool _matchesSectionHeading(String trimmedLine, RegExp heading) =>
      heading.hasMatch(_decodeEntities(trimmedLine));

  /// The heading that opens the External Dependencies & Contracts section
  /// (bug #919): `## External Dependencies & Contracts` (any level,
  /// `&` or `and`, case-insensitive). Issue #1196: trailing qualifier
  /// tolerated; entities decoded ([_matchesSectionHeading]).
  static final RegExp _dependenciesHeading = RegExp(
    r'^#{1,6}\s+external\s+dependencies\s+(?:&|and)\s+contracts\b[^#]*$',
    caseSensitive: false,
  );

  /// The heading that opens the Layer Contracts section (bug #919):
  /// `## Layer Contracts` (any level, case-insensitive). Issue #1196:
  /// a per-epic qualifier (`## Layer Contracts — epic-level`) is the
  /// same section — contracts declared per-epic route exactly like
  /// per-feature ones.
  static final RegExp _layerContractsHeading = RegExp(
    r'^#{1,6}\s+layer\s+contracts\b[^#]*$',
    caseSensitive: false,
  );

  /// A bold layer name inside the Layer Contracts section: `**Domain**:`.
  static final RegExp _layerName = RegExp(r'^\s*\*\*(.+?)\*\*\s*:\s*$');

  /// A layer-contract declaration bullet:
  /// `` - `Repo`: `save(x) -> R`, `get() -> R?` ``.
  static final RegExp _layerContractBullet = RegExp(
    r'^\s*[-*]\s+`([^`]+)`\s*:\s*(.+)$',
  );

  /// Split a markdown pipe row into its cells (no escape handling —
  /// cells in these template sections never carry literal pipes).
  static List<String> _splitCells(String line) {
    return line
        .split('|')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();
  }

  /// Split a pipe row while preserving empty cells' column positions.
  static List<String> _splitPositionalCells(String line) {
    final raw = line.split('|').map((c) => c.trim()).toList();
    return raw.length > 2 ? raw.sublist(1, raw.length - 1) : raw;
  }

  /// Extract the declared external dependencies (bug #919): each row of
  /// the `| Dependency | Type | Contract | Mock Priority |` table.
  /// Header and separator rows are skipped; rows with fewer than four
  /// cells are ignored rather than fatal.
  List<SpecDependency> parseDependencies(String specMd) {
    final dependencies = <SpecDependency>[];
    var inSection = false;
    for (final line in normalizeSpecText(specMd).split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('#')) {
        inSection = _matchesSectionHeading(trimmed, _dependenciesHeading);
        continue;
      }
      if (!inSection || !trimmed.startsWith('|')) continue;
      final cells = _splitCells(trimmed);
      if (cells.length < 4) continue;
      if (cells[0].toLowerCase() == 'dependency') continue; // header
      if (RegExp(r'^-+$').hasMatch(cells[0])) continue; // separator
      dependencies.add(
        SpecDependency(
          dependency: cells[0],
          type: cells[1],
          contract: cells[2],
          mockPriority: cells[3],
        ),
      );
    }
    return dependencies;
  }

  /// Extract the declared layer contracts (bug #919): the bold layer
  /// names and their backticked interface declarations, preserving the
  /// declared method signatures verbatim.
  List<LayerContract> parseLayerContracts(String specMd) {
    final contracts = <LayerContract>[];
    var inSection = false;
    var layer = '';
    for (final line in normalizeSpecText(specMd).split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('#')) {
        inSection = _matchesSectionHeading(trimmed, _layerContractsHeading);
        if (!inSection) layer = '';
        continue;
      }
      if (!inSection || trimmed.isEmpty) continue;
      final layerM = _layerName.firstMatch(trimmed);
      if (layerM != null) {
        layer = layerM.group(1)!.trim();
        continue;
      }
      final bullet = _layerContractBullet.firstMatch(trimmed);
      if (bullet == null || layer.isEmpty) continue;
      contracts.add(
        LayerContract(
          layer: layer,
          interfaceName: bullet.group(1)!.trim(),
          methods: RegExp(r'`([^`]+)`')
              .allMatches(bullet.group(2)!)
              .map((m) => m.group(1)!.trim())
              .toList(),
        ),
      );
    }
    return contracts;
  }

  /// The heading that opens the Lanes section (issue #1000): `## Lanes`
  /// (any level, case-insensitive). Issue #1196: trailing qualifier
  /// tolerated; entities decoded ([_matchesSectionHeading]).
  static final RegExp _lanesHeading = RegExp(
    r'^#{1,6}\s+lanes\b[^#]*$',
    caseSensitive: false,
  );

  /// A lane declaration line: `- lane: CORE` (the yaml block's list
  /// item; the dash is optional so a bare `lane: CORE` also parses).
  static final RegExp _laneLine = RegExp(
    r'^\s*(?:-\s*)?lane:\s*(.+?)\s*$',
    caseSensitive: false,
  );

  /// A behaviors line: `behaviors: [A1, A2, U1-U6]` (bracketed list or
  /// bare comma list).
  static final RegExp _laneBehaviorsLine = RegExp(
    r'^\s*behaviors:\s*(.+?)\s*$',
    caseSensitive: false,
  );

  /// A flutter-allowed line: `flutter_allowed: false`.
  static final RegExp _laneFlutterAllowedLine = RegExp(
    r'^\s*flutter_allowed:\s*(.+?)\s*$',
    caseSensitive: false,
  );

  /// An adaptive-slots line: `adaptive_slots: [mobile, ios, android, macos]`.
  static final RegExp _laneAdaptiveSlotsLine = RegExp(
    r'^\s*adaptive_slots:\s*(.+?)\s*$',
    caseSensitive: false,
  );

  /// A golden-gate line (bug #1261): `golden: true` (every behavior the
  /// lane declares is golden-gated) or `golden: [W1, W3]` (the subset).
  /// `golden: false` marks nothing.
  static final RegExp _laneGoldenLine = RegExp(
    r'^\s*golden:\s*(.+?)\s*$',
    caseSensitive: false,
  );

  /// Strip the optional brackets of a yaml list value
  /// (`[a, b]` -> `a, b`); a bare comma list passes through.
  static String _stripBrackets(String value) {
    var v = value.trim();
    if (v.startsWith('[')) v = v.substring(1);
    if (v.endsWith(']')) v = v.substring(0, v.length - 1);
    return v.trim();
  }

  /// Split a yaml list value into trimmed tokens, dropping empties.
  static List<String> _listTokens(String value) => _stripBrackets(
    value,
  ).split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

  /// Expand a behavior-list token (issue #1000): `U1-U6` ranges expand
  /// to `U1 .. U6` (same alphabetic prefix, ascending integers); a
  /// parenthetical annotation is stripped into [annotations]
  /// (`A3 (acceptance: navigates to deal_list)` -> id `A3`, annotation
  /// `acceptance: navigates to deal_list`); anything else is the id
  /// verbatim.
  static (List<String>, Map<String, String>) _expandBehaviorTokens(
    List<String> tokens,
  ) {
    final ids = <String>[];
    final annotations = <String, String>{};
    for (final token in tokens) {
      var t = token.trim();
      final annotation = RegExp(r'\(([^)]*)\)\s*$').firstMatch(t);
      if (annotation != null) {
        final note = annotation.group(1)!.trim();
        t = t.substring(0, annotation.start).trim();
        if (note.isNotEmpty && t.isNotEmpty) annotations[t] = note;
      }
      if (t.isEmpty) continue;
      final range = RegExp(
        r'^([A-Za-z]+)(\d+)\s*-\s*[A-Za-z]*(\d+)$',
      ).firstMatch(t);
      if (range != null) {
        final prefix = range.group(1)!;
        final start = int.parse(range.group(2)!);
        final end = int.parse(range.group(3)!);
        if (end >= start && end - start < 1000) {
          for (var n = start; n <= end; n++) {
            ids.add('$prefix$n');
          }
          continue;
        }
      }
      ids.add(t);
    }
    return (ids, annotations);
  }

  /// Extract the declared lanes (issue #1000): the spec's `## Lanes`
  /// section, authored as a yaml block (fenced or bare):
  ///
  /// ```yaml
  /// Lanes:
  ///   - lane: CORE
  ///     behaviors: [A1, A2, U1-U6]
  ///     flutter_allowed: false
  ///   - lane: SKIN
  ///     behaviors: [W1-W4]
  ///     flutter_allowed: true
  ///     adaptive_slots: [mobile, ios, android, macos]
  ///   - lane: BOTH
  ///     behaviors: [A3 (acceptance: navigates to deal_list)]
  ///     flutter_allowed: conditionally
  /// ```
  ///
  /// Lenient by design (a spec without the section yields an empty list
  /// — every pre-1000 spec): fence-marker lines are skipped so the block
  /// parses fenced or bare, a `Lanes:` header line is skipped, and a
  /// `lane:` line opens a new declaration whose `behaviors:` /
  /// `flutter_allowed:` / `adaptive_slots:` continuation lines fill it.
  /// Unknown lane names parse verbatim — plan refuses them (the grammar
  /// is CORE/SKIN/BOTH).
  List<LaneDeclaration> parseLanes(String specMd) {
    final lanes = <LaneDeclaration>[];
    var inSection = false;
    String? currentLane;
    var behaviorIds = <String>[];
    var annotations = <String, String>{};
    var flutterAllowed = '';
    var adaptiveSlots = <String>[];
    // Bug #1261: the lane's golden declaration, held unresolved until
    // flush — `golden: true` must see the lane's FULL behaviors list
    // regardless of the key's order in the yaml row.
    var goldenAll = false;
    var goldenTokens = <String>[];

    void flush() {
      if (currentLane == null) return;
      lanes.add(
        LaneDeclaration(
          lane: currentLane!,
          behaviorIds: behaviorIds,
          flutterAllowed: flutterAllowed,
          adaptiveSlots: adaptiveSlots,
          goldenIds: goldenAll ? List<String>.of(behaviorIds) : goldenTokens,
          annotations: annotations,
        ),
      );
      currentLane = null;
      behaviorIds = <String>[];
      annotations = <String, String>{};
      flutterAllowed = '';
      adaptiveSlots = <String>[];
      goldenAll = false;
      goldenTokens = <String>[];
    }

    for (final line in normalizeSpecText(specMd).split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('#')) {
        final wasInSection = inSection;
        inSection = _matchesSectionHeading(trimmed, _lanesHeading);
        if (wasInSection && !inSection) flush();
        continue;
      }
      if (!inSection) continue;
      // Fence markers (```yaml … ```): the block parses fenced or bare.
      if (trimmed.startsWith('```')) continue;
      // The `Lanes:` yaml header line — the declarations follow.
      if (RegExp(r'^lanes:\s*$', caseSensitive: false).hasMatch(trimmed)) {
        continue;
      }
      final laneM = _laneLine.firstMatch(trimmed);
      if (laneM != null) {
        flush();
        currentLane = laneM.group(1)!.trim();
        continue;
      }
      if (currentLane == null) continue;
      final behaviorsM = _laneBehaviorsLine.firstMatch(trimmed);
      if (behaviorsM != null) {
        final (ids, notes) = _expandBehaviorTokens(
          _listTokens(behaviorsM.group(1)!),
        );
        behaviorIds = ids;
        annotations = notes;
        continue;
      }
      final flutterM = _laneFlutterAllowedLine.firstMatch(trimmed);
      if (flutterM != null) {
        flutterAllowed = _stripBrackets(flutterM.group(1)!);
        continue;
      }
      final slotsM = _laneAdaptiveSlotsLine.firstMatch(trimmed);
      if (slotsM != null) {
        adaptiveSlots = _listTokens(slotsM.group(1)!);
        continue;
      }
      final goldenM = _laneGoldenLine.firstMatch(trimmed);
      if (goldenM != null) {
        final value = goldenM.group(1)!.trim().toLowerCase();
        if (value == 'true') {
          // Resolved at flush: every behavior the lane declares is
          // golden-gated, whatever order the yaml row wrote the keys.
          goldenAll = true;
          goldenTokens = <String>[];
        } else if (value == 'false' || value.isEmpty) {
          goldenAll = false;
          goldenTokens = <String>[];
        } else {
          goldenAll = false;
          goldenTokens = _listTokens(goldenM.group(1)!);
        }
        continue;
      }
    }
    flush();
    return lanes;
  }

  /// Extract the declared contract rows (feature 071): every row an
  /// author can trace a behavior to, with its routing kind and
  /// (function rows) eagerly-parsed signatures.
  ///
  /// Sources: the Layer Contracts section (bold layer label → row kind:
  /// Presentation/Domain/Data/Function; other layers carry no routing
  /// kind and are skipped), the Key Entities table (entity rows), and
  /// the External Dependencies table (`storage:`/`channel:` type
  /// tokens; other dependency types carry no routing kind). Rows are
  /// line-addressable (1-based spec line). A malformed FUNCTION
  /// signature (missing the `-> Return`) refuses naming the row and the
  /// offending text — errors-are-an-API.
  List<ContractRowDecl> parseContractRows(String specMd) {
    const functionKinds = ['presentation', 'domain', 'data', 'function'];
    final rows = <ContractRowDecl>[];
    final lines = normalizeSpecText(specMd).split('\n');
    String? layer; // active Layer Contracts layer label
    String? section; // active declared section kind
    for (var i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trim();
      final lineNo = i + 1;
      if (trimmed.startsWith('#')) {
        layer = null;
        section = null;
        if (_matchesSectionHeading(trimmed, _layerContractsHeading)) {
          section = 'layer-contracts';
        } else if (_matchesSectionHeading(trimmed, _keyEntitiesHeading)) {
          section = 'key-entities';
        } else if (_matchesSectionHeading(trimmed, _dependenciesHeading)) {
          section = 'dependencies';
        }
        continue;
      }
      if (trimmed.isEmpty) continue;
      if (section == 'layer-contracts') {
        final layerM = _layerName.firstMatch(trimmed);
        if (layerM != null) {
          layer = layerM.group(1)!.trim();
          continue;
        }
        final bullet = _layerContractBullet.firstMatch(trimmed);
        if (bullet == null || layer == null) continue;
        final name = bullet.group(1)!.trim();
        final label = layer.toLowerCase();
        final kind = functionKinds.contains(label)
            ? ContractRowKind.values.firstWhere((k) => k.name == label)
            : null;
        if (kind == null) continue; // no routing kind — not a routing row
        final methods = RegExp(
          r'`([^`]+)`',
        ).allMatches(bullet.group(2)!).map((m) => m.group(1)!.trim()).toList();
        final signatures = <Signature>[];
        for (final method in methods) {
          try {
            signatures.add(Signature.parse(method));
          } on FormatException {
            // A malformed signature refuses on FUNCTION rows (their
            // return type drives subject generation); other layers
            // preserve methods verbatim for their existing consumers.
            if (kind == ContractRowKind.function) {
              throw StateError(
                'contract row "$name" declares a malformed signature '
                '"$method" — declared signatures must be '
                '`name(Params) -> Return` (spec line $lineNo).\n'
                '   --> fix: add the `-> Return` part.',
              );
            }
          }
        }
        rows.add(
          ContractRowDecl(
            name: name,
            kind: kind,
            signatures: signatures,
            specLine: lineNo,
          ),
        );
        continue;
      }
      if (section == 'key-entities') {
        // Bug #919: the zuraffa-1.0 template declares entities as a
        // 3-column TABLE (`| Entity | Fields | Purpose |`) — parse the
        // table rows (header/separator skipped), like parseDependencies.
        if (!trimmed.startsWith('|')) continue;
        final cells = _splitCells(trimmed);
        if (cells.isEmpty) continue;
        if (cells[0].toLowerCase() == 'entity') continue; // header
        if (RegExp(r'^-+$').hasMatch(cells[0])) continue; // separator
        rows.add(
          ContractRowDecl(
            name: cells[0],
            kind: ContractRowKind.entity,
            specLine: lineNo,
          ),
        );
        continue;
      }
      if (section == 'dependencies') {
        if (!trimmed.startsWith('|')) continue;
        final cells = _splitCells(trimmed);
        if (cells.length < 2) continue;
        if (cells[0].toLowerCase() == 'dependency') continue;
        if (RegExp(r'^-+$').hasMatch(cells[0])) continue;
        final type = cells[1].toLowerCase();
        final kind = type.startsWith('storage')
            ? ContractRowKind.storage
            : (type.startsWith('channel') || type.startsWith('platform'))
            ? ContractRowKind.channel
            : ContractRowKind.service; // issue #960: every declared
        // dependency row is a first-class declaration — an undeclared
        // kind is the row's own business, never a reason to skip it.
        // Issue #960: the contract cell (methods) and the mock
        // priority cell travel with the row so the mock surface is
        // generated from the declaration and the loop orders mocks by
        // declared priority.
        final signatures = (cells.length > 2 ? cells[2] : '')
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        final priority = cells.length > 3 ? cells[3] : '';
        rows.add(
          ContractRowDecl(
            name: cells[0],
            kind: kind,
            rawSignatures: signatures,
            priority: MockPriority.tryParse(priority) ?? MockPriority.none,
            specLine: lineNo,
          ),
        );
        continue;
      }
    }
    return rows;
  }

  /// Issue #1485: the heading that scopes signature-list bullets in a
  /// contract document — `## Operations`, `### TaskStore Methods`,
  /// `## REST API` (any level, case-insensitive, the word matched on
  /// word boundaries anywhere in the heading).
  static final RegExp _contractOperationsHeading = RegExp(
    r'^#{1,6}\s+.*\b(?:operations|methods|api)\b.*$',
    caseSensitive: false,
  );

  /// Issue #1485: a bullet whose ENTIRE value is one backticked span
  /// (`` - `count() -> int` ``) — a pure signature declaration.
  static final RegExp _pureSignatureBullet = RegExp(
    r'^\s*[-*+]\s+`([^`]+)`\s*$',
  );

  /// Issue #1485: a bullet whose FIRST backticked span may carry trailing
  /// prose (`` - `count() -> int` — the number of tasks ``). Honored only
  /// inside an [_contractOperationsHeading] scope.
  static final RegExp _proseSignatureBullet = RegExp(
    r'^\s*[-*+]\s+`([^`]+)`(.*)$',
  );

  /// Issue #1485: an operations/method table header's key column —
  /// `| Operation | … |` or `| Method | … |`.
  static final RegExp _operationsHeaderCell = RegExp(
    r'^(?:operation|method)$',
    caseSensitive: false,
  );

  /// Issue #1485: the signature column header cell (`| Signature | … |`,
  /// also as `Method Signature`).
  static bool _isSignatureHeaderCell(String cell) {
    final c = cell.toLowerCase().trim();
    return c == 'signature' || c == 'method signature';
  }

  /// Parse ONE contract document (`specs/<feature>/contracts/<name>.md`,
  /// issue #1485) into declared rows: every operation/method table data
  /// row and every declared signature becomes a
  /// [ContractRowDecl] of kind [ContractRowKind.function] — an
  /// operations contract declares callable operations, so a traced
  /// behavior routes the unit lane and the signature ladder resolves
  /// its subject shape (#1259 semantics).
  ///
  /// Grammar (deliberately narrow — a contract document carries prose,
  /// CLI tables and examples alongside its declarations):
  ///
  /// - Pipe table whose header row's FIRST cell is `Operation` or
  ///   `Method`: one row per data row, named by the first cell. An
  ///   optional `Signature` column binds parsed
  ///   `name(Params) -> Return` signatures to the row.
  /// - Pipe table whose header row's first cell is `Signature`: the
  ///   first cell of each data row IS the signature; the row is named
  ///   by the parsed signature's method.
  /// - Interface bullets (the Layer Contracts grammar): `` - `Name`:
  ///   `sig`, `sig` `` — one row with every parsed signature.
  /// - Pure signature bullets: `` - `sig` `` — one row named by the
  ///   parsed signature's method. Inside an Operations/Methods/API
  ///   section a signature bullet may carry trailing prose.
  ///
  /// Fenced code blocks are documentation, not declarations (the same
  /// stance every spec.md walk applies) — blanked before the walk with
  /// line numbers preserved. Only markdown is parsed: signature cells
  /// holding plain prose are dropped; a cell SHAPED like a signature
  /// but failing to parse (`` `(int) ->` ``) is carried in
  /// [ContractRowDecl.rawSignatures] so the resolver's
  /// malformed-declaration refusal names it when the row is consulted.
  /// `specLine` is the 1-based line within the contract file.
  List<ContractRowDecl> parseContractFileRows(String contractMd) {
    final rows = <ContractRowDecl>[];
    final blanked = normalizeSpecText(contractMd).replaceAllMapped(
      _fencedCodeBlock,
      (m) => '\n' * '\n'.allMatches(m.group(0)!).length,
    );
    final lines = blanked.split('\n');
    var inOperationsScope = false;
    // The active table's shape while walking its data rows (null when
    // no declared-shape table is open): the signature column index, or
    // -1 for a signature-FIRST table, and a flag for the name source.
    int? tableSigColumn;
    var tableSignatureFirst = false;
    for (var i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trim();
      final lineNo = i + 1;
      if (trimmed.startsWith('#')) {
        inOperationsScope = _contractOperationsHeading.hasMatch(
          _decodeEntities(trimmed),
        );
        tableSigColumn = null;
        tableSignatureFirst = false;
        continue;
      }
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('|')) {
        final cells = _splitCells(trimmed);
        if (cells.isEmpty) continue;
        if (tableSigColumn == null && !tableSignatureFirst) {
          // Header detection: the NEXT line must be the separator row.
          final next = i + 1 < lines.length ? lines[i + 1].trim() : '';
          if (!_tableSeparator.hasMatch(next)) continue;
          final first = cells.first.toLowerCase();
          if (_operationsHeaderCell.hasMatch(first)) {
            tableSignatureFirst = false;
            tableSigColumn = cells.indexWhere(_isSignatureHeaderCell);
          } else if (_isSignatureHeaderCell(first)) {
            tableSignatureFirst = true;
            tableSigColumn = -1;
          }
          continue;
        }
        // A data row of the open table. A second table header may follow
        // immediately without a blank line; treat it as a new table rather
        // than as a declaration whose name is the header text.
        final next = i + 1 < lines.length ? lines[i + 1].trim() : '';
        final first = cells.first.toLowerCase();
        final startsTable =
            (_operationsHeaderCell.hasMatch(first) ||
                _isSignatureHeaderCell(first)) &&
            _tableSeparator.hasMatch(next);
        if (startsTable) {
          tableSigColumn = null;
          tableSignatureFirst = false;
          if (_operationsHeaderCell.hasMatch(first)) {
            tableSignatureFirst = false;
            tableSigColumn = cells.indexWhere(_isSignatureHeaderCell);
          } else {
            tableSignatureFirst = true;
            tableSigColumn = -1;
          }
          continue;
        }
        if (RegExp(r'^:?-+:?$').hasMatch(cells.first)) continue; // separator
        if (tableSignatureFirst) {
          final signature = _firstParseableSignature(cells.first);
          if (signature != null) {
            rows.add(
              ContractRowDecl(
                name: signature.name,
                kind: ContractRowKind.function,
                signatures: [signature],
                specLine: lineNo,
              ),
            );
          }
          continue;
        }
        final signatures = <Signature>[];
        final rawSignatures = <String>[];
        final positional = _splitPositionalCells(trimmed);
        if (tableSigColumn != null &&
            tableSigColumn >= 0 &&
            positional.length > tableSigColumn) {
          _collectSignatures(
            positional[tableSigColumn],
            signatures,
            rawSignatures,
          );
        }
        rows.add(
          ContractRowDecl(
            name: positional.isNotEmpty && positional.first.isNotEmpty
                ? positional.first
                : cells.first,
            kind: ContractRowKind.function,
            signatures: signatures,
            rawSignatures: rawSignatures,
            specLine: lineNo,
          ),
        );
        continue;
      }
      // A non-table line closes any open table.
      tableSigColumn = null;
      tableSignatureFirst = false;
      // Interface bullets (the Layer Contracts grammar) declare anywhere
      // in the document.
      final interface = _layerContractBullet.firstMatch(trimmed);
      if (interface != null) {
        final signatures = <Signature>[];
        final rawSignatures = <String>[];
        for (final m in RegExp(r'`([^`]+)`').allMatches(interface.group(2)!)) {
          _collectSignatures(m.group(1)!, signatures, rawSignatures);
        }
        rows.add(
          ContractRowDecl(
            name: interface.group(1)!.trim(),
            kind: ContractRowKind.function,
            signatures: signatures,
            rawSignatures: rawSignatures,
            specLine: lineNo,
          ),
        );
        continue;
      }
      // A pure signature bullet declares anywhere in the document.
      final pure = _pureSignatureBullet.firstMatch(trimmed);
      if (pure != null) {
        final text = pure.group(1)!.trim();
        final signature = _firstParseableSignature(text);
        if (signature != null) {
          rows.add(
            ContractRowDecl(
              name: signature.name,
              kind: ContractRowKind.function,
              signatures: [signature],
              specLine: lineNo,
            ),
          );
        } else if (text.contains('(') && text.contains('->')) {
          // Signature-shaped but unparseable: carry raw so the resolver's
          // malformed-declaration refusal names it when consulted.
          final name = RegExp(
            r'^[A-Za-z_][A-Za-z0-9_]*',
          ).firstMatch(text)?.group(0);
          rows.add(
            ContractRowDecl(
              name: name ?? text,
              kind: ContractRowKind.function,
              rawSignatures: [text],
              specLine: lineNo,
            ),
          );
        }
        continue;
      }
      // Inside an Operations/Methods/API section, a signature bullet
      // may carry trailing prose (`` - `count() -> int` — the count ``).
      if (inOperationsScope) {
        final prose = _proseSignatureBullet.firstMatch(trimmed);
        if (prose != null) {
          final signature = _firstParseableSignature(prose.group(1)!.trim());
          if (signature != null) {
            rows.add(
              ContractRowDecl(
                name: signature.name,
                kind: ContractRowKind.function,
                signatures: [signature],
                specLine: lineNo,
              ),
            );
          }
        }
      }
    }
    return rows;
  }

  /// The first signature in [text] that parses as
  /// `name(Params) -> Return` (backticked spans first, then bare text);
  /// null when nothing parses. Used where the row NAME comes from the
  /// signature itself, so an unparseable cell declares no row at all.
  static Signature? _firstParseableSignature(String text) {
    final spans = RegExp(r'`([^`]+)`').allMatches(text).map((m) => m.group(1)!);
    final candidates = [...spans, if (!text.contains('`')) text];
    for (final span in candidates) {
      try {
        return Signature.parse(span.trim());
      } on FormatException {
        // Try the next span.
      }
    }
    return null;
  }

  /// Fill [signatures] and [rawSignatures] from ONE declared-signature
  /// cell (issue #1485): backticked spans (or bare comma-separated
  /// spans) that parse become [Signature]s; a span shaped like a
  /// signature but failing to parse is carried raw so the resolver's
  /// malformed-declaration refusal names it when consulted; plain prose
  /// is dropped.
  static void _collectSignatures(
    String cell,
    List<Signature> signatures,
    List<String> rawSignatures,
  ) {
    final matches = RegExp(r'`([^`]+)`').allMatches(cell).toList();
    final spans = matches.isNotEmpty
        ? matches.map((m) => m.group(1)!)
        : _splitTopLevelCommas(cell);
    for (final span in spans) {
      final s = span.trim();
      if (s.isEmpty) continue;
      try {
        signatures.add(Signature.parse(s));
      } on FormatException {
        if (s.contains('(') && s.contains('->')) rawSignatures.add(s);
      }
    }
  }

  /// Split a bare signature cell without splitting commas inside a
  /// parameter list (`save(Task, int) -> void` remains one span).
  static Iterable<String> _splitTopLevelCommas(String cell) {
    final out = <String>[];
    final buf = StringBuffer();
    var depth = 0;
    for (final ch in cell.split('')) {
      if (ch == '(') depth++;
      if (ch == ')') depth--;
      if (ch == ',' && depth == 0) {
        out.add(buf.toString());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    out.add(buf.toString());
    return out.where((s) => s.trim().isNotEmpty);
  }

  /// Issue #1485: the declared-row map EVERY command-side consumer
  /// builds — spec.md sections first (`parseContractRows`), then the
  /// feature's contract documents (`contracts/*.md`, enumerated by the
  /// caller — `DeclaredRouting.contractFiles`). A contract-file row that
  /// collides with a spec.md row name WINS (it is more structured and
  /// was produced by the planning workflow); every contract row is
  /// additionally registered under its `<file-stem>.<row>` alias so a
  /// `traces: <ContractFile>.<Row>` token resolves — the resolver's API
  /// is unchanged, this only widens the source feeding it. [perFile]
  /// reports how many rows each contract file declared (keyed by the
  /// file name as given).
  static ({Map<String, ContractRowDecl> rows, Map<String, int> perFile})
  declaredContractRows(
    String specMd, {
    List<({String file, String md})> contractFiles = const [],
  }) {
    final rows = <String, ContractRowDecl>{
      for (final r in const SpecParser().parseContractRows(specMd)) r.name: r,
    };
    final perFile = <String, int>{};
    for (final source in contractFiles) {
      final fileRows = const SpecParser().parseContractFileRows(source.md);
      perFile[source.file] = fileRows.length;
      final stem = source.file.endsWith('.md')
          ? source.file.substring(0, source.file.length - '.md'.length)
          : source.file;
      for (final row in fileRows) {
        rows[row.name] = row; // bare name — the contract-file version wins
        rows['$stem.${row.name}'] = row; // the file-qualified alias
      }
    }
    return (rows: rows, perFile: perFile);
  }

  /// Extract the entities the spec declares under `Key Entities` (bug
  /// #829 remediation 1: plan must surface them so the loop can create
  /// and wire them). Bug #919: the zuraffa-1.0 template declares
  /// entities as a 3-column table — rows are parsed alongside the legacy
  /// bullets, and a section may mix both forms. Issue #1486: table
  /// fields cells accept unbackticked `name: Type` pairs (mixed freely
  /// with the backticked form); bullet prose keeps the strict
  /// backticked-only grammar so ordinary prose colons cannot invent
  /// fields. When [anomalies] is provided it receives one
  /// [SpecEntityFieldAnomaly] per table cell that showed pair evidence
  /// but still parsed to zero fields — the caller decides how loudly to
  /// refuse the silence.
  List<SpecEntity> parseKeyEntities(
    String specMd, {
    List<SpecEntityFieldAnomaly>? anomalies,
  }) {
    final entities = <SpecEntity>[];
    var inSection = false;
    var tableMode = false;
    var tableColumns = 0;
    var lineNo = 0;
    for (final line in normalizeSpecText(specMd).split('\n')) {
      lineNo++;
      final trimmed = line.trim();
      if (trimmed.startsWith('#')) {
        inSection = _matchesSectionHeading(trimmed, _keyEntitiesHeading);
        tableMode = false;
        tableColumns = 0;
        continue;
      }
      if (!inSection) continue;
      if (trimmed.isEmpty) continue;
      if (_entityTableHeader.hasMatch(trimmed)) {
        tableMode = true;
        tableColumns = 3;
        continue;
      }
      if (_entityTableHeader2Col.hasMatch(trimmed)) {
        tableMode = true;
        tableColumns = 2;
        continue;
      }
      if (_tableSeparator.hasMatch(trimmed)) continue;
      if (tableMode) {
        final rowRegex = tableColumns == 2
            ? _entityTableRow2Col
            : _entityTableRow;
        final m = rowRegex.firstMatch(trimmed);
        if (m == null) {
          // End of the table — fall through to bullet handling so a
          // mixed section still extracts its bullet-declared entities.
          tableMode = false;
        } else {
          var name = m.group(1)!.trim();
          final genericStart = name.indexOf('<');
          if (genericStart > 0) {
            name = name.substring(0, genericStart).trim();
          }
          if (!_dartIdentifier.hasMatch(name)) continue;
          // Issue #1486: table cells carry the pair covenant — accept
          // backticked, plain, and mixed pairs; report evidence-without-
          // fields instead of losing it silently.
          final cell = m.group(2) ?? '';
          final fields = _parseFieldCell(cell);
          if (fields.isEmpty &&
              anomalies != null &&
              _fieldCellEvidence.hasMatch(cell)) {
            anomalies.add(
              SpecEntityFieldAnomaly(entity: name, cell: cell, line: lineNo),
            );
          }
          entities.add(
            SpecEntity(
              name: name,
              fields: fields,
              purpose: tableColumns == 3 ? (m.group(3) ?? '').trim() : '',
            ),
          );
          continue;
        }
      }
      final m = _entityBullet.firstMatch(trimmed);
      if (m == null) {
        if (trimmed.startsWith('|')) continue;
        inSection = false;
        continue;
      }
      var name = m.group(1)!.trim();
      final genericStart = name.indexOf('<');
      if (genericStart > 0) name = name.substring(0, genericStart).trim();
      if (!_dartIdentifier.hasMatch(name)) continue;
      final prose = m.group(2) ?? '';
      // Bullet prose stays backticked-only (issue #1486): the bullet's
      // free prose may carry ordinary colons (`Note: this file is
      // generated`), so only the explicit `` `name: Type` `` covenant
      // may mint fields here. Table cells are the pair-dedicated
      // grammar — see [_parseFieldCell].
      final fields = _fieldPair
          .allMatches(prose)
          .map((f) => EntityField(name: f.group(1)!, type: f.group(2)!.trim()))
          .toList();
      entities.add(SpecEntity(name: name, fields: fields));
    }
    return entities;
  }

  /// Issue #1486: parse a Key Entities fields cell into pairs, accepting
  /// the backticked `` `name: Type` ``, the plain `name: Type`, and any
  /// mix of both, in source order. Backwards compatible by construction:
  /// a backticked span parses exactly as the old [_fieldPair] grammar
  /// (the name must open the span, the type runs to the closing
  /// backtick, commas inside are the type's own), while the unbackticked
  /// text between spans is split on top-level commas only — a comma
  /// nested in `<...>`/`(...)` belongs to its type (`Map<String, int>`).
  static List<EntityField> _parseFieldCell(String cell) {
    final fields = <EntityField>[];
    var inBackticks = false;
    final span = StringBuffer();

    // Plain-pair fragments: split at depth-0 commas, then apply the
    // `name: Type` shape. Fragments without the shape are skipped —
    // purposeful prose in a dedicated cell is tolerated, minted never.
    void flushOutside() {
      final text = span.toString();
      span.clear();
      var depth = 0;
      var start = 0;
      for (var i = 0; i < text.length; i++) {
        final ch = text[i];
        if (ch == '<' || ch == '(') {
          depth++;
        } else if (ch == '>' || ch == ')') {
          if (depth > 0) depth--;
        } else if (ch == ',' && depth == 0) {
          _addFieldFragment(fields, text.substring(start, i));
          start = i + 1;
        }
      }
      _addFieldFragment(fields, text.substring(start));
    }

    for (var i = 0; i < cell.length; i++) {
      final ch = cell[i];
      if (ch != '`') {
        span.write(ch);
        continue;
      }
      if (inBackticks) {
        // Closing backtick: the span content parses under the OLD
        // grammar — raw content, no trim, so `a: ` still yields a
        // (whitespace) type exactly as `_fieldPair` did.
        final m = _fieldPairShape.firstMatch(span.toString());
        if (m != null) {
          fields.add(EntityField(name: m.group(1)!, type: m.group(2)!.trim()));
        }
        span.clear();
      } else {
        // Opening backtick: the text before it is outside the span —
        // flush it as plain-pair fragments so the next span never
        // inherits a stale `, ` prefix (which would anchor-fail the
        // shape and silently drop the pair — the #1486 failure shape).
        flushOutside();
      }
      inBackticks = !inBackticks;
    }
    // A trailing unbackticked tail — or an unterminated backtick span,
    // which degrades to plain-pair parsing rather than vanishing (the
    // exact silence #1486 forbids).
    flushOutside();
    return fields;
  }

  static void _addFieldFragment(List<EntityField> fields, String fragment) {
    final m = _fieldPairShape.firstMatch(fragment.trim());
    if (m == null) return;
    fields.add(EntityField(name: m.group(1)!, type: m.group(2)!.trim()));
  }

  /// Issue #1486: the field NAMES an entity Dart file on disk declares —
  /// the shape phase-0's reuse path compares the plan's declared fields
  /// against, so a pre-fix field-less entity reused by a later run is
  /// named instead of starved silently. Best-effort by design: it feeds
  /// a print-only warning, never a gate; a file that is not an entity
  /// class simply yields fewer (or no) names.
  static List<String> entityFieldNamesFromDartSource(String source) {
    return [for (final m in _dartFinalMember.allMatches(source)) m.group(2)!];
  }

  /// Issue #1196: one FR declaration line, in EITHER grammar the
  /// corpus really contains — the strict bullet
  /// (`- **FR-001**: The system MUST ...`) or the FR-table row
  /// (`| FR-001 | The system MUST ... | variants |`). Variant
  /// continuation rows (empty id cell) are NOT FR lines — they are
  /// auxiliary detail of the row above. Every FR walk (unit
  /// derivation, contract traces, persistence declarations) routes
  /// through this helper so the document-wide U-id numbering stays
  /// aligned across all three.
  static (String, String)? _frLine(String line) {
    final bullet = RegExp(
      r'^\s*-\s*\*\*(FR-\d{3})\*\*:\s*(.+)$',
    ).firstMatch(line);
    if (bullet != null) return (bullet.group(1)!, bullet.group(2)!);
    final table = RegExp(
      r'^\s*\|\s*(FR-\d{3})\s*\|\s*([^|]+?)\s*\|',
    ).firstMatch(line);
    if (table != null) return (table.group(1)!, table.group(2)!);
    return null;
  }

  /// [contractTracedFrIds] carries the FR ids the feature's
  /// `contracts/*.md` files bind (issue #1480's decoupled mapping): a
  /// defaulted FR named there is DECLARED, so the #1484 manual routing
  /// must keep deriving its unit row. Empty (the default) preserves the
  /// spec.md-only contract for every other caller.
  List<Behavior> parse(
    String feature,
    String specMd, {
    Set<String> contractTracedFrIds = const {},
  }) {
    final md = normalizeSpecText(specMd);
    final acceptance = _extractAcceptance(feature, md);
    if (acceptance.isEmpty) {
      // Issue #1196: the refusal names a line — the first content
      // line of the spec — so the author can act on it (the #1186
      // actionable-refusal contract). A spec with zero content lines
      // addresses spec line 1.
      var firstContentLine = 1;
      for (var i = 0; i < md.split('\n').length; i++) {
        if (md.split('\n')[i].trim().isNotEmpty) {
          firstContentLine = i + 1;
          break;
        }
      }
      throw StateError(
        'spec.md for feature "$feature" contains no acceptance scenarios '
        '(`Given ... When ... Then ...` blocks) — first content line is '
        'spec line $firstContentLine. Cannot derive a TDD test list from '
        'a spec with no acceptance criteria. See FR-012.\n'
        '   --> fix: add at least one numbered acceptance scenario '
        '(`1. **Given** ... **When** ... **Then** ...`; bold or plain, '
        'flat or dotted numbering), or declare the criteria '
        '`(manual: owner)`.',
      );
    }
    final unit = _extractUnit(
      feature,
      md,
      contractTracedFrIds: contractTracedFrIds,
    );
    return [...acceptance, ...unit];
  }

  List<Behavior> _extractAcceptance(String feature, String specMd) {
    final behaviors = <Behavior>[];
    // Feature 071 (issue #951): the rung-1 lane declaration. A
    // scenario's `**Type**` marker decides its kind outright; the
    // #830 UI-intent classifier below is the labeled fallback for
    // undeclared scenarios (migration window). Prose never overrides
    // a declaration (FR-001/FR-013).
    final markers = parseScenarioTypeMarkers(specMd);
    final lines = specMd.split('\n');
    var scenarioBuffer = <String>[];
    var aIdx = 0;

    Behavior? flush() {
      if (scenarioBuffer.isEmpty) return null;
      final header = _scenarioHeader.firstMatch(scenarioBuffer.first);
      if (header == null) {
        scenarioBuffer = <String>[];
        return null;
      }
      // Document-wide id (bug #846): every strict scenario consumes one
      // AC number, manual ones included, so the ids stay aligned with
      // the requirement scan even when a manual scenario emits no row.
      aIdx += 1;
      final description = _extractScenarioText(scenarioBuffer.join('\n'));
      // Bug #846: a manual scenario consumes the AC number but emits no
      // row — the id stays aligned with the requirement scan, the
      // evidence simply isn't automated.
      if (manualScenarioMarker.hasMatch(scenarioBuffer.first)) {
        scenarioBuffer = <String>[];
        return null;
      }
      final behavior = Behavior(
        id: 'A$aIdx',
        feature: feature,
        // Bug #830: spec-driven widget marking — an acceptance scenario
        // whose prose is UI-observable gets the widget subject kind so
        // plan writes it into the widget section and gen emits a
        // testWidgets pair instead of a smoke-shaped plain-function stub.
        // Feature 071: a `**Type**` marker (rung 1) outranks the prose
        // classifier; the classifier only routes UNDECLARED scenarios.
        kind:
            markers['A$aIdx']?.declaredType ??
            (isUiAcceptance(description)
                ? BehaviorKind.widget
                : BehaviorKind.acceptance),
        description: description,
        // Bug #846: AC source criterion aligned to the document-wide AC
        // number consumed above (id alignment with the requirement scan).
        sourceCriterion: 'AC-$aIdx',
        target: '',
      );
      scenarioBuffer = <String>[];
      return behavior;
    }

    for (final line in lines) {
      if (_scenarioHeader.hasMatch(line) && scenarioBuffer.isNotEmpty) {
        final flushed = flush();
        if (flushed != null) behaviors.add(flushed);
      }
      scenarioBuffer.add(line);
    }
    final last = flush();
    if (last != null) behaviors.add(last);
    return behaviors;
  }

  /// Issue #1196: the Then marker is matched bold or plain
  /// (`**Then**` / `Then`) — inline-prose scenarios carry it unbolded;
  /// the description is the text after it (verbatim minus bold).
  String _extractScenarioText(String line) {
    final match = RegExp(
      r'(?:\*\*)?Then(?:\*\*)?\s*(.+)$',
      multiLine: true,
    ).firstMatch(line);
    if (match != null) {
      return match.group(1)!.replaceAll('**', '').trim();
    }
    return line.replaceAll('**', '').trim();
  }

  /// Whether an FR line carries the `[persistent]` routing tag,
  /// ignoring bold markers: `**[persistent]**` declares exactly what
  /// `[persistent]` does (round-2 review fix 6 — the two walks must
  /// agree on the tag whether or not it is bold-wrapped).
  static bool _carriesPersistentTag(String frText) =>
      frText.replaceAll('**', '').trim().startsWith('[persistent]');

  List<Behavior> _extractUnit(
    String feature,
    String specMd, {
    Set<String> contractTracedFrIds = const {},
  }) {
    // Feature 1484: the FR→behaviour derivation consults the FR's own
    // declarations. An FR declared `**Type**: manual` — or, by default,
    // an FR with no `traces:` binding — routes to a manual declaration
    // in the traceability matrix instead of a unit behaviour row: it
    // consumes its document-wide unit id (alignment with the
    // requirement scan and the trace walks, the #846 manual-scenario
    // precedent) but emits NO row, so the run loop never sees a unit
    // row that cannot honestly pass make. FRs WITH a binding derive
    // rows exactly as before (backwards compatible — the marker is
    // opt-in and untraced specs are the only ones that re-route).
    //
    // Feature 1484 × issue #1480: a defaulted FR whose trace lives in
    // the feature's `contracts/*.md` files ([contractTracedFrIds]) is
    // DECLARED, not defaulted — it keeps its unit row. An explicit
    // `**Type**: manual` marker always wins (the author's word).
    final routings = parseFrRoutings(specMd);
    final behaviors = <Behavior>[];
    for (final r in routings) {
      if (r.routesManual &&
          (r.manualMarker || !contractTracedFrIds.contains(r.frId))) {
        continue;
      }
      // Feature 071: a `[persistent]` tag is a routing declaration,
      // not prose — strip it from the description (the persistence
      // map carries the mark; the rendered row stays clean). The tag
      // is detected on the RAW text before the `**` strip, so a
      // bold-wrapped tag is honored too (round-2 review fix 6).
      final rawDesc = r.rawText;
      final tagged = _carriesPersistentTag(rawDesc);
      var desc = rawDesc.replaceAll('**', '').trim();
      if (tagged) {
        desc = desc.substring('[persistent]'.length).trim();
      }
      behaviors.add(
        Behavior(
          id: r.unitId,
          feature: feature,
          kind: BehaviorKind.unit,
          description: desc,
          sourceCriterion: r.frId,
          target: '',
        ),
      );
    }
    return behaviors;
  }

  /// `traces:` payload -> tokens, keeping backticked spans intact so a
  /// declared inline signature is never comma-split (round-2 review
  /// fix 2). A span carrying `(` documents an expected signature, not a
  /// contract-row reference — such tokens are dropped so they neither
  /// resolve nor dangle. Every `traces:` consumer (parser, make, func)
  /// routes through this helper so they all see the same tokens.
  static List<String> traceTokens(String raw) => RegExp(r'`[^`]*`|[^,]+')
      .allMatches(raw)
      .map((m) => m.group(0)!.trim())
      .where((t) => t.isNotEmpty)
      .map((t) => t.replaceAll('`', '').trim())
      .where((t) => t.isNotEmpty)
      .where((t) => !t.contains('('))
      .toList();

  /// The FR contract-trace continuation scan (feature 071): a `traces:`
  /// line within an FR's block names the contract rows the requirement
  /// exercises. Keyed by the document-wide unit id.
  ///
  /// Issue #1319: the scan consumes the ENTIRE FR block — every
  /// continuation line after the FR header until the next FR/requirement
  /// header (bullet or FR-table row), a markdown heading, or an
  /// acceptance scenario header — not just the single line immediately
  /// after the header. Multi-line FRs are the common case (the
  /// zuraffa-1.0 template wraps FR text at ~80 columns) and put
  /// `traces:` after the wrap; the old `lines[i + 1]`-only scan silently
  /// dropped it, the plan kept the legacy fallback routing, and
  /// `zfa tdd run` dead-ended vacuous-green (#1308) with no hint that
  /// the author's `traces:` line was never read. The FIRST `traces:`
  /// line of a block wins, so a single-line FR binds byte-identically
  /// to the pre-#1319 behavior.
  static Map<String, List<String>> parseFrContractTraces(String specMd) {
    final traces = <String, List<String>>{};
    // Fenced code blocks are documentation, not declarations (mirrors
    // parseScenarioTypeMarkers): a `traces:`-looking line inside a ```
    // example must neither bind nor count as unbound.
    final blanked = normalizeSpecText(specMd).replaceAllMapped(
      _fencedCodeBlock,
      (m) => '\n' * '\n'.allMatches(m.group(0)!).length,
    );
    final lines = blanked.split('\n');
    var uIdx = 0;
    for (var i = 0; i < lines.length; i++) {
      // Issue #1196: the shared FR-line helper (bullet or table form)
      // keeps the U-id numbering aligned with _extractUnit.
      if (_frLine(lines[i]) == null) continue;
      uIdx += 1;
      // Issue #1319: walk the whole FR block — the continuation lines
      // until the next FR/requirement header, heading, or scenario
      // header — and bind the first `traces:` line in it.
      for (var j = i + 1; j < lines.length; j++) {
        if (_endsFrBlock(lines[j])) break;
        final t = _tracesLine.firstMatch(lines[j]);
        if (t == null) continue;
        traces['U$uIdx'] = traceTokens(t.group(1)!);
        break;
      }
    }
    return traces;
  }

  /// Issue #1319: a line that ends the FR block a `traces:` continuation
  /// may visually attach to — the next FR/requirement header (bullet or
  /// FR-table row), a markdown heading, or an acceptance scenario
  /// header. Shared by the binding scan ([parseFrContractTraces]) and
  /// the owner-attribution walk ([findUnboundFrTraces]) so the two
  /// cannot disagree about where a block ends.
  static bool _endsFrBlock(String line) =>
      _frLine(line) != null ||
      _frBlockBoundary.hasMatch(line) ||
      _scenarioHeader.hasMatch(line);

  /// Markdown ATX headings (`#`..`######`) — a new section starts, so
  /// the FR block above it is over.
  static final RegExp _frBlockBoundary = RegExp(r'^\s*#{1,6}(\s|$)');

  /// The `traces:` continuation line under an FR (feature 071, #1319) —
  /// one shared pattern so the binding scan and the attribution walk
  /// cannot drift apart.
  static final RegExp _tracesLine = RegExp(r'^\s+traces:\s*(.+)$');

  /// Issue #1319: the FR ids whose block contains a `traces:` line that
  /// did NOT yield a contract-row binding in [bound] (the
  /// `parseFrContractTraces` result, keyed by unit id). An FR whose
  /// binding is missing or EMPTY (every token dropped, e.g. a lone
  /// backticked signature) counts as unbound — exactly the silent-
  /// fallback input plan must never stay quiet about.
  ///
  /// The owner of a `traces:` line is the nearest preceding FR header;
  /// a heading or an acceptance scenario header between the two breaks
  /// the visual attachment (the line belongs to no FR). Plan warns
  /// loudly for every reported FR instead of silently falling back to
  /// the legacy classifier — the silent fallback re-created the #1308
  /// vacuous-green dead-end with zero author-facing hint.
  static Set<String> findUnboundFrTraces(
    String specMd,
    Map<String, List<String>> bound,
  ) {
    final unbound = <String>{};
    final blanked = normalizeSpecText(specMd).replaceAllMapped(
      _fencedCodeBlock,
      (m) => '\n' * '\n'.allMatches(m.group(0)!).length,
    );
    final lines = blanked.split('\n');
    String? owner;
    var uIdx = 0;
    for (final line in lines) {
      final fr = _frLine(line);
      if (fr != null) {
        uIdx += 1;
        owner = fr.$1;
        continue;
      }
      if (_frBlockBoundary.hasMatch(line) || _scenarioHeader.hasMatch(line)) {
        owner = null;
        continue;
      }
      if (owner != null && _tracesLine.hasMatch(line)) {
        // The FR owns a traces: line — binding is decided by the
        // caller's map: missing or empty = unbound.
        final id = 'U$uIdx';
        if ((bound[id] ?? const <String>[]).isEmpty) unbound.add(owner);
      }
    }
    return unbound;
  }

  /// The FR routing walk (feature 1484): one [FrRouting] per FR, in
  /// document order, keyed by nothing — the unit id travels with the
  /// record. The walk consumes the ENTIRE FR block exactly like
  /// [parseFrContractTraces] (#1319): fenced code blocks are blanked
  /// (documentation, not declarations), [_frLine] recognises the bullet
  /// AND FR-table grammars, and the block runs to the next
  /// FR/requirement header, heading, or scenario header. Within a
  /// block the FIRST `**Type**:` line decides the marker flag (the
  /// scenario-side value-lowering convention; only `manual` exempts an
  /// FR) and the FIRST `traces:` line binds (first-wins, byte-identical
  /// to the single-line pre-#1319 behavior).
  ///
  /// Manual FRs consume their document-wide unit id but emit no row —
  /// the #846 manual-scenario precedent, so the requirement scan, the
  /// trace walks, and the derived rows stay id-aligned.
  static List<FrRouting> parseFrRoutings(String specMd) {
    final routings = <FrRouting>[];
    final blanked = normalizeSpecText(specMd).replaceAllMapped(
      _fencedCodeBlock,
      (m) => '\n' * '\n'.allMatches(m.group(0)!).length,
    );
    final lines = blanked.split('\n');
    var uIdx = 0;
    for (var i = 0; i < lines.length; i++) {
      final fr = _frLine(lines[i]);
      if (fr == null) continue;
      uIdx += 1;
      var manualMarker = false;
      int? markerLine;
      var typeMarkerSeen = false;
      // Issue #1484 (review fix): the FIRST `traces:` line of the block
      // binds, even when its tokens all drop as signature-shaped. The
      // old `tokens.isEmpty` guard let a LATER `traces:` line overwrite
      // that first (empty) binding — while [parseFrContractTraces] keeps
      // it — so plan could derive a unit row whose traceability binding
      // was empty.
      var traceSeen = false;
      var tokens = const <String>[];
      for (var j = i + 1; j < lines.length; j++) {
        if (_endsFrBlock(lines[j])) break;
        final m = _typeMarkerLine.firstMatch(lines[j]);
        if (m != null && !typeMarkerSeen) {
          // The FIRST `**Type**:` line of the block decides; only the
          // `manual` kind exempts an FR (other kinds are scenario
          // vocabulary, meaningless here — the walk keeps looking for
          // a traces: line).
          typeMarkerSeen = true;
          if (m.group(1)!.toLowerCase() == 'manual') {
            manualMarker = true;
            markerLine = j + 1;
          }
          continue;
        }
        if (!traceSeen) {
          final t = _tracesLine.firstMatch(lines[j]);
          if (t != null) {
            traceSeen = true;
            tokens = traceTokens(t.group(1)!);
          }
        }
      }
      routings.add(
        FrRouting(
          frId: fr.$1,
          unitId: 'U$uIdx',
          specLine: i + 1,
          manualMarker: manualMarker,
          markerLine: markerLine,
          traceTokens: tokens,
          rawText: fr.$2,
        ),
      );
    }
    return routings;
  }

  /// The FR ids routed to a manual declaration (feature 1484) — the set
  /// the coverage gate counts as covered manual declarations instead of
  /// missing behaviours. Explicit `**Type**: manual` markers and the
  /// no-binding default both land here.
  static Set<String> manualFrCriterionIds(String specMd) => {
    for (final r in parseFrRoutings(specMd))
      if (r.routesManual) r.frId,
  };

  /// The criterion-keyed contract-trace scan for the DECOUPLED mapping
  /// (issue #1480): the spec↔contract mapping may live BESIDE the spec —
  /// in the feature's `contracts/*.md` files the planning phase already
  /// writes — instead of requiring hand-authored zuraffa grammar inside
  /// the spec body. Each `- **FR-xxx**:` bullet in the contracts file
  /// names the contract rows its FR exercises, either on the same line
  /// (`- **FR-001**: traces: Row`) or on an indented `traces:`
  /// continuation line within the FR's block (the #1319 whole-block scan,
  /// first `traces:` line wins).
  ///
  /// Keyed by the FR ID (not by sequential unit position) so the file is
  /// robust to reordering — the binding FR id is authoring intent the
  /// file carries literally. A duplicate FR id refuses naming the line.
  /// Fenced code blocks are documentation, not declarations.
  static Map<String, List<String>> parseCriterionContractTraces(String md) {
    final traces = <String, List<String>>{};
    final blanked = normalizeSpecText(md).replaceAllMapped(
      _fencedCodeBlock,
      (m) => '\n' * '\n'.allMatches(m.group(0)!).length,
    );
    final lines = blanked.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final fr = _frLine(lines[i]);
      if (fr == null) continue;
      final frId = fr.$1;
      if (traces.containsKey(frId)) {
        throw StateError(
          'contracts file declares FR "$frId" more than once (line '
          '${i + 1}).\n'
          '   --> fix: keep exactly one trace declaration per FR id.',
        );
      }
      // Same-line form: `- **FR-001**: traces: Row` — the payload IS the
      // trace declaration.
      final inline = RegExp(r'^traces:\s*(.+)$').firstMatch(fr.$2.trim());
      if (inline != null) {
        traces[frId] = traceTokens(inline.group(1)!);
        continue;
      }
      // Continuation form: the indented `traces:` line within the FR's
      // block (until the next FR/requirement header, heading, or
      // scenario header) — the first one wins, byte-identical to the
      // spec.md binding contract (#1319).
      for (var j = i + 1; j < lines.length; j++) {
        if (_endsFrBlock(lines[j])) break;
        final t = _tracesLine.firstMatch(lines[j]);
        if (t == null) continue;
        traces[frId] = traceTokens(t.group(1)!);
        break;
      }
    }
    return traces;
  }

  /// The `_persistence` declaration scan (feature 071): FR lines
  /// carrying a `[persistent]` tag, or a `traces:` continuation naming
  /// a declared storage dependency row. Keyed by the document-wide
  /// unit id (the same walk [_extractUnit] uses, so ids align).
  static Map<String, PersistenceDeclaration> parsePersistenceDeclarations(
    String specMd,
  ) {
    final declarations = <String, PersistenceDeclaration>{};
    final storageNames = const SpecParser()
        .parseContractRows(specMd)
        .where((r) => r.kind == ContractRowKind.storage)
        .map((r) => r.name)
        .toSet();
    final lines = normalizeSpecText(specMd).split('\n');
    var uIdx = 0;
    for (var i = 0; i < lines.length; i++) {
      // Issue #1196: the shared FR-line helper (bullet or table form)
      // keeps the U-id numbering aligned with _extractUnit.
      final m = _frLine(lines[i]);
      if (m == null) continue;
      uIdx += 1;
      final id = 'U$uIdx';
      final tagged = _carriesPersistentTag(m.$2);
      final traceTokens = <String>[];
      if (i + 1 < lines.length) {
        final t = _tracesLine.firstMatch(lines[i + 1]);
        if (t != null) {
          traceTokens.addAll(SpecParser.traceTokens(t.group(1)!));
        }
      }
      final viaStorage = traceTokens.any(storageNames.contains);
      if (tagged) {
        declarations[id] = PersistenceDeclaration(
          behaviorId: id,
          fromTag: true,
          specLine: i + 1,
        );
      } else if (viaStorage) {
        declarations[id] = PersistenceDeclaration(
          behaviorId: id,
          fromTag: false,
          specLine: i + 2,
        );
      }
    }
    return declarations;
  }
}
