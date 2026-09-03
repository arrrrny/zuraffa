/// `SpecParser` — reads a `spec.md` and emits a list of behaviors.
///
/// Bug #846: acceptance ids are document-wide sequential (AC-1, AC-2, …
/// across user stories — the literal scenario number restarts per story
/// and duplicate criterion ids made traceability ambiguous), and a
/// scenario whose header line carries `(manual: <owner>)` is an explicit
/// non-automatable declaration: it is excluded from the automated loop
/// (no behavior row) and shows up in the traceability matrix as manual.
library;

import '../models/behavior.dart';
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
/// valid Dart identifier), the fields are the backticked `name: Type`
/// pairs the spec carries (empty when the prose declares none). Bug
/// #919: `purpose` is the third column of the zuraffa-1.0 template's
/// table form; empty for legacy bullet declarations.
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

class SpecParser {
  const SpecParser();

  /// The UI-intent signature (bug #830): acceptance prose that names a
  /// UI-observable outcome — rendered surfaces, layout regions, navigation
  /// outcomes, the app shell — cannot be expressed by a plain-function
  /// subject, so such scenarios are marked [BehaviorKind.widget] and their
  /// gen pair is a view-builder stub + a `testWidgets` test.
  ///
  /// Bug #936: Then-clauses are passive/past by convention ("an error
  /// message is rendered", "the user is navigated", "a spinner is shown",
  /// "the avatar is displayed"), so the verb alternation covers the full
  /// conjugation (`render(?:s|ed|ing)?`, `navigat(?:e|es|ed|ion|ing)`)
  /// and adds the missing outcome verbs `display(?:s|ed|ing)?` and
  /// `shows?|shown`. Word boundaries stay anchored; "navigation" already
  /// matched before #936, so this only completes the grammar — it does
  /// not widen the concept set.
  static final RegExp uiAcceptanceIntent = RegExp(
    r'\b(render(?:s|ed|ing)?|sidebar|bottom nav|tab bar|app bar|app shell|'
    r'themes?|widgets?|navigat(?:e|es|ed|ion|ing)|display(?:s|ed|ing)?|'
    r'shows?|shown)\b',
    caseSensitive: false,
  );

  /// Whether an acceptance scenario's prose carries UI intent (bug #830).
  static bool isUiAcceptance(String description) =>
      uiAcceptanceIntent.hasMatch(description);

  /// The inline non-automatable declaration on a scenario header line
  /// (bug #846): a manual scenario consumes an AC number but emits no
  /// row, so the id alignment is preserved even when scenarios are
  /// human-executed.
  static final RegExp manualScenarioMarker = RegExp(r'\(manual:\s*[^)]*\)');

  /// A scenario type marker line (feature 071, rung 1): `**Type**: widget`
  /// on its own line inside a scenario block. The kind must name a
  /// [BehaviorKind] value.
  static final RegExp _typeMarkerLine = RegExp(r'^\s*\*\*Type\*\*:\s*(\S+)\s*$');

  /// The scenario block header (`1. **Given** ...`) — the same walk
  /// [_extractAcceptance] uses, so marker ids stay aligned with the
  /// document-wide AC numbers.
  static final RegExp _scenarioHeader = RegExp(r'^\s*(\d+)\.\s*\*\*Given\*\*');

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
    final lines = specMd.split('\n');
    var inScenario = false;
    var scenarioLine = 0;
    var aIdx = 0;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineNo = i + 1;
      if (_scenarioHeader.hasMatch(line)) {
        aIdx += 1;
        inScenario = true;
        scenarioLine = lineNo;
        continue;
      }
      final m = _typeMarkerLine.firstMatch(line);
      if (m == null) continue;
      if (!inScenario) {
        throw StateError(
          'spec line $lineNo carries a `**Type**` marker outside any '
          'numbered scenario block.\n'
          '   --> fix: move the marker inside the scenario it declares.',
        );
      }
      final raw = m.group(1)!.toLowerCase();
      final kind = BehaviorKind.values
          .where((k) => k.name == raw)
          .firstOrNull;
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
  /// case-insensitively).
  static final RegExp _keyEntitiesHeading = RegExp(
    r'^#{1,6}\s+key\s+entities\s*$',
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

  static final RegExp _dartIdentifier = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

  /// A Key Entities table header (bug #919): the zuraffa-1.0 template
  /// declares entities as a 3-column table `| Entity | Fields | Purpose |`.
  static final RegExp _entityTableHeader = RegExp(
    r'^\s*\|\s*entity\s*\|\s*fields\s*\|\s*purpose\s*\|\s*$',
    caseSensitive: false,
  );

  /// A Key Entities table row: `| Name | `f: T`, `g: U` | purpose |`.
  static final RegExp _entityTableRow = RegExp(
    r'^\s*\|\s*([^|]+?)\s*\|\s*([^|]*?)\s*\|\s*([^|]*?)\s*\|\s*$',
  );

  /// A Key Entities table separator row (`| -- | -- | -- |`).
  static final RegExp _tableSeparator = RegExp(r'^\s*\|\s*[\s\-|]*\|\s*$');

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
  static const Set<String> knownTemplateVersions = {'zuraffa-1.0'};

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
    final stripped = specMd.replaceAll(_fencedCodeBlock, '');
    for (final line in stripped.split('\n')) {
      final m = _templateVersionMarker.firstMatch(line.trim());
      if (m != null) return m.group(1)!.trim();
    }
    return null;
  }

  /// The heading that opens the External Dependencies & Contracts section
  /// (bug #919): `## External Dependencies & Contracts` (any level,
  /// `&` or `and`, case-insensitive).
  static final RegExp _dependenciesHeading = RegExp(
    r'^#{1,6}\s+external\s+dependencies\s+(?:&|and)\s+contracts\s*$',
    caseSensitive: false,
  );

  /// The heading that opens the Layer Contracts section (bug #919):
  /// `## Layer Contracts` (any level, case-insensitive).
  static final RegExp _layerContractsHeading = RegExp(
    r'^#{1,6}\s+layer\s+contracts\s*$',
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

  /// Extract the declared external dependencies (bug #919): each row of
  /// the `| Dependency | Type | Contract | Mock Priority |` table.
  /// Header and separator rows are skipped; rows with fewer than four
  /// cells are ignored rather than fatal.
  List<SpecDependency> parseDependencies(String specMd) {
    final dependencies = <SpecDependency>[];
    var inSection = false;
    for (final line in specMd.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('#')) {
        inSection = _dependenciesHeading.hasMatch(trimmed);
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
    for (final line in specMd.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('#')) {
        inSection = _layerContractsHeading.hasMatch(trimmed);
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

  /// Extract the entities the spec declares under `Key Entities` (bug
  /// #829 remediation 1: plan must surface them so the loop can create
  /// and wire them). Bug #919: the zuraffa-1.0 template declares
  /// entities as a 3-column table — rows are parsed alongside the legacy
  /// bullets, and a section may mix both forms.
  List<SpecEntity> parseKeyEntities(String specMd) {
    final entities = <SpecEntity>[];
    var inSection = false;
    var tableMode = false;
    for (final line in specMd.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('#')) {
        inSection = _keyEntitiesHeading.hasMatch(trimmed);
        tableMode = false;
        continue;
      }
      if (!inSection) continue;
      if (trimmed.isEmpty) continue;
      if (_entityTableHeader.hasMatch(trimmed)) {
        tableMode = true;
        continue;
      }
      if (_tableSeparator.hasMatch(trimmed)) continue;
      if (tableMode) {
        final m = _entityTableRow.firstMatch(trimmed);
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
          final fields = _fieldPair
              .allMatches(m.group(2) ?? '')
              .map(
                (f) => EntityField(name: f.group(1)!, type: f.group(2)!.trim()),
              )
              .toList();
          entities.add(
            SpecEntity(
              name: name,
              fields: fields,
              purpose: (m.group(3) ?? '').trim(),
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
      final fields = _fieldPair
          .allMatches(prose)
          .map((f) => EntityField(name: f.group(1)!, type: f.group(2)!.trim()))
          .toList();
      entities.add(SpecEntity(name: name, fields: fields));
    }
    return entities;
  }

  List<Behavior> parse(String feature, String specMd) {
    final acceptance = _extractAcceptance(feature, specMd);
    if (acceptance.isEmpty) {
      throw StateError(
        'spec.md for feature "$feature" contains no acceptance scenarios '
        '(`Given ... When ... Then ...` blocks). Cannot derive a TDD test '
        'list from a spec with no acceptance criteria. See FR-012.',
      );
    }
    final unit = _extractUnit(feature, specMd);
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
      final header = RegExp(
        r'^\s*(\d+)\.\s*\*\*Given\*\*',
      ).firstMatch(scenarioBuffer.first);
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
        kind: markers['A$aIdx']?.declaredType ??
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
      if (RegExp(r'^\s*\d+\.\s*\*\*Given\*\*').hasMatch(line) &&
          scenarioBuffer.isNotEmpty) {
        final flushed = flush();
        if (flushed != null) behaviors.add(flushed);
      }
      scenarioBuffer.add(line);
    }
    final last = flush();
    if (last != null) behaviors.add(last);
    return behaviors;
  }

  String _extractScenarioText(String line) {
    final match = RegExp(
      r'\*\*Then\*\*\s*(.+)$',
      multiLine: true,
    ).firstMatch(line);
    if (match != null) {
      return match.group(1)!.replaceAll('**', '').trim();
    }
    return line.replaceAll('**', '').trim();
  }

  List<Behavior> _extractUnit(String feature, String specMd) {
    final behaviors = <Behavior>[];
    final frPattern = RegExp(r'^\s*-\s*\*\*(FR-\d{3})\*\*:\s*(.+)$');
    var uIdx = 0;
    for (final line in specMd.split('\n')) {
      final m = frPattern.firstMatch(line);
      if (m != null) {
        uIdx += 1;
        final frId = m.group(1)!;
        final desc = m.group(2)!.replaceAll('**', '').trim();
        behaviors.add(
          Behavior(
            id: 'U$uIdx',
            feature: feature,
            kind: BehaviorKind.unit,
            description: desc,
            sourceCriterion: frId,
            target: '',
          ),
        );
      }
    }
    return behaviors;
  }
}
