/// Generates the ZikZak 120-spec corpus (issue #1196, part of #908 P0).
///
/// The corpus is REALITY for the spec parser: 120 committed
/// `corpus/zik_zak/<feature>/spec.md` files, one per feature, each
/// authored from a shape class observed in real specs (the zuraffa
/// repo's own spec eras) plus the format dimensions issue #1196 names:
/// missing Lanes sections, inline prose behaviors, FR tables with
/// variants, nested ACs, contracts declared per-feature vs per-epic,
/// HTML entities, CRLF, non-English headers.
///
/// Deterministic by construction (no RNG, no clock): running this tool
/// twice produces byte-identical corpus files, so the committed corpus
/// is reviewable and the sweep evidence is diffable.
///
/// Usage:
///   dart run tool/generate_zikzak_corpus.dart [--out corpus/zik_zak]
///
/// The generator never deletes; it only (re)writes spec.md files under
/// the corpus root. Stale extra directories are reported, not removed.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

// Issue #1196: NEUTRAL feature ids — the corpus exercises SPEC SHAPES,
// not product content. The REAL zik_zak corpus (the product roadmap)
// lives in the private zik_zak project and never enters this public
// repo; shape classes here are identical, so parser coverage is too.
const List<String> featureSlugs = [
  'feature-001',
  'feature-002',
  'feature-003',
  'feature-004',
  'feature-005',
  'feature-006',
  'feature-007',
  'feature-008',
  'feature-009',
  'feature-010',
  'feature-011',
  'feature-012',
  'feature-013',
  'feature-014',
  'feature-015',
  'feature-016',
  'feature-017',
  'feature-018',
  'feature-019',
  'feature-020',
  'feature-021',
  'feature-022',
  'feature-023',
  'feature-024',
  'feature-025',
  'feature-026',
  'feature-027',
  'feature-028',
  'feature-029',
  'feature-030',
  'feature-031',
  'feature-032',
  'feature-033',
  'feature-034',
  'feature-035',
  'feature-036',
  'feature-037',
  'feature-038',
  'feature-039',
  'feature-040',
  'feature-041',
  'feature-042',
  'feature-043',
  'feature-044',
  'feature-045',
  'feature-046',
  'feature-047',
  'feature-048',
  'feature-049',
  'feature-050',
  'feature-051',
  'feature-052',
  'feature-053',
  'feature-054',
  'feature-055',
  'feature-056',
  'feature-057',
  'feature-058',
  'feature-059',
  'feature-060',
  'feature-061',
  'feature-062',
  'feature-063',
  'feature-064',
  'feature-065',
  'feature-066',
  'feature-067',
  'feature-068',
  'feature-069',
  'feature-070',
  'feature-071',
  'feature-072',
  'feature-073',
  'feature-074',
  'feature-075',
  'feature-076',
  'feature-077',
  'feature-078',
  'feature-079',
  'feature-080',
  'feature-081',
  'feature-082',
  'feature-083',
  'feature-084',
  'feature-085',
  'feature-086',
  'feature-087',
  'feature-088',
  'feature-089',
  'feature-090',
  'feature-091',
  'feature-092',
  'feature-093',
  'feature-094',
  'feature-095',
  'feature-096',
  'feature-097',
  'feature-098',
  'feature-099',
  'feature-100',
  'feature-101',
  'feature-102',
  'feature-103',
  'feature-104',
  'feature-105',
  'feature-106',
  'feature-107',
  'feature-108',
  'feature-109',
  'feature-110',
  'feature-111',
  'feature-112',
  'feature-113',
  'feature-114',
  'feature-115',
  'feature-116',
  'feature-117',
  'feature-118',
  'feature-119',
  'feature-120',
];

/// One corpus shape class: its id, the feature indices it covers, and
/// the spec body builder (feature display name in, spec markdown out).
class ShapeClass {
  const ShapeClass(this.id, this.count, this.build);

  /// Stable shape id (asserted by the sweep oracle, committed evidence).
  final String id;

  /// How many of the 120 features carry this shape.
  final int count;

  /// Builds the full spec.md body for one feature.
  final String Function(String slug, String title, int index) build;
}

String titleOf(String slug) {
  final words = slug.split('-').skip(1).map(_capitalize).join(' ');
  return words;
}

String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

String entityOf(int index) {
  const entities = [
    'Session',
    'Profile',
    'Wallet',
    'Order',
    'Receipt',
    'Bookmark',
    'Alert',
    'Message',
    'Notification',
    'Coupon',
    'Ticket',
    'Report',
  ];
  return entities[index % entities.length];
}

/// A pinned, known-grammar header (the zuraffa-1.0 treaty pin).
const String kPin = '**Template Version**: `zuraffa-1.0`';

/// The modern zuraffa-1.0 body: every declared section (Key Entities
/// table, External Dependencies & Contracts table, Layer Contracts,
/// FR bullets with traces, Type-marked scenarios, Lanes). All routing
/// is DECLARED — zero fallback.
String modernBody(
  String title,
  int index, {
  bool lanes = true,
  bool typeMarkers = true,
  bool traces = true,
  String eol = '\n',
}) {
  final entity = entityOf(index);
  final buf = StringBuffer();
  void w(String s) => buf.write('$s$eol');
  w(kPin);
  w('');
  w('# Spec: $title');
  w('');
  w('## Summary');
  w('');
  w('The $title feature, as the ZikZak app ships it.');
  w('');
  w('## Key Entities');
  w('');
  w('| Entity | Fields | Purpose |');
  w('| -- | -- | -- |');
  w('| $entity${''}Params | `id: String`, `value: num` | typed params |');
  w('| ${entity}View | `state: ${entity}State` | rendered row |');
  w('');
  w('## External Dependencies & Contracts');
  w('');
  w('| Dependency | Type | Contract | Mock Priority |');
  w('| -- | -- | -- | -- |');
  w('| Hive | storage: box | `put(String, dynamic) -> void` | high |');
  w('| RestChannel | channel: http | `send(Request) -> Response` | high |');
  w('');
  w('## Layer Contracts');
  w('');
  w('**Domain**:');
  w(
    '- `${entity}Repo`: `save(${entity}Params) -> $entity`, '
    '`get(String) -> $entity?`',
  );
  w('');
  w('**Presentation**:');
  w('- `${entity}Presenter`: `present(${entity}State) -> ${entity}View`');
  w('');
  w('## Functional Requirements');
  w('');
  w(
    '- **FR-001**: The system MUST save a $entity when the user commits the $title form.',
  );
  if (traces) w('  traces: `${entity}Repo.save`');
  w(
    '- **FR-002**: The system MUST restore the last $title state on cold start.',
  );
  if (traces) w('  traces: `Hive.put`, `${entity}Repo.get`');
  w('');
  w('## Acceptance Scenarios');
  w('');
  w(
    '1. **Given** a signed-in user **When** they open $title **Then** the saved $entity list renders.',
  );
  if (typeMarkers) w('   **Type**: widget');
  w(
    '2. **Given** an empty local cache **When** $title loads **Then** the placeholder renders.',
  );
  if (typeMarkers) w('   **Type**: widget');
  w(
    '3. **Given** a committed $entity **When** the device restarts **Then** the value equals the last write.',
  );
  if (typeMarkers) w('   **Type**: acceptance');
  w('');
  if (lanes) {
    w('## Lanes');
    w('');
    w('```yaml');
    w('Lanes:');
    w('  - lane: CORE');
    w('    behaviors: [U1, U2]');
    w('    flutter_allowed: false');
    w('  - lane: SKIN');
    w('    behaviors: [A1, A2]');
    w('    flutter_allowed: true');
    w('  - lane: BOTH');
    w('    behaviors: [A3]');
    w('    flutter_allowed: conditionally');
    w('```');
    w('');
  }
  return buf.toString();
}

/// Old-era (pre-919) shape: user stories with restarting scenario
/// numbering, no Template Version pin, prose scenarios only.
String legacyBody(String title, int index, {String eol = '\n'}) {
  final buf = StringBuffer();
  void w(String s) => buf.write('$s$eol');
  w('# Feature Specification: $title');
  w('');
  w('**Feature Branch**: `zikzak-$index`');
  w('**Status**: Draft');
  w('');
  w('## User Scenarios & Testing');
  w('');
  w('### User Story 1 - Save the $title state (Priority: P1)');
  w('');
  w('As a ZikZak user, I want my $title state kept so I do not lose work.');
  w('');
  w('**Acceptance Scenarios**:');
  w(
    '1. **Given** a signed-in user, **When** they commit the form, **Then** the state persists.',
  );
  w(
    '2. **Given** a cold start, **When** the app opens, **Then** the last state restores.',
  );
  w('');
  w('### User Story 2 - Browse $title (Priority: P1)');
  w('');
  w('As a ZikZak user, I want to browse my $title items.');
  w('');
  w('**Acceptance Scenarios**:');
  w(
    '1. **Given** saved items, **When** the list opens, **Then** every item renders.',
  );
  w('');
  return buf.toString();
}

/// FR tables with variants: requirements declared as a markdown table
/// with a Variants column and empty-id variant continuation rows.
String frTableBody(String title, int index, {String eol = '\n'}) {
  final entity = entityOf(index);
  final buf = StringBuffer();
  void w(String s) => buf.write('$s$eol');
  w('# Spec: $title');
  w('');
  w(kPin);
  w('');
  w('## Key Entities');
  w('');
  w('| Entity | Fields | Purpose |');
  w('| -- | -- | -- |');
  w('| ${entity}Row | `id: String` | one row |');
  w('');
  w('## Layer Contracts');
  w('');
  w('**Domain**:');
  w('- `${entity}Repo`: `list(QueryParams) -> List<${entity}Row>`');
  w('');
  w('## Functional Requirements');
  w('');
  w('Requirements are declared as a table; variants are continuation rows.');
  w('');
  w('| ID | Requirement | Variants |');
  w('| -- | -- | -- |');
  w('| FR-001 | The system MUST list $entity rows for $title. | — |');
  w('  traces: `${entity}Repo`');
  w('| | variant: offline — the cached list renders. | v1 |');
  w('| | variant: empty — the placeholder renders. | v2 |');
  w('| FR-002 | The system MUST refresh the $title list on pull. | — |');
  w('  traces: `${entity}Repo`');
  w('');
  w('## Acceptance Scenarios');
  w('');
  w(
    '1. **Given** cached rows **When** $title opens offline **Then** the cached list renders.',
  );
  w('   **Type**: widget');
  w('');
  return buf.toString();
}

/// Nested ACs: scenario numbering is dotted (`1.1.`, `1.2.`) inside
/// per-story sub-sections.
String nestedAcBody(String title, int index, {String eol = '\n'}) {
  final entity = entityOf(index);
  final buf = StringBuffer();
  void w(String s) => buf.write('$s$eol');
  w('# Spec: $title');
  w('');
  w(kPin);
  w('');
  w('## Layer Contracts');
  w('');
  w('**Domain**:');
  w('- `FormValidator`: `validate(Map<String, dynamic>) -> bool`');
  w('- `${entity}Submitter`: `submit($entity) -> void`');
  w('');
  w('## Functional Requirements');
  w('');
  w('- **FR-001**: The system MUST validate the $title form before submit.');
  w('  traces: FormValidator');
  w('- **FR-002**: The system MUST submit the validated $entity.');
  w('  traces: ${entity}Submitter');
  w('');
  w('## Scenarios');
  w('');
  w('### Story A — happy path');
  w('');
  w(
    '1.1. **Given** a valid form **When** the user submits **Then** the $entity is saved.',
  );
  w(
    '1.2. **Given** a saved $entity **When** the user reopens $title **Then** the row renders.',
  );
  w('');
  w('### Story B — validation');
  w('');
  w(
    '2.1. **Given** an invalid field **When** the user submits **Then** an error message renders.',
  );
  w(
    '2.2. **Given** an offline device **When** the user submits **Then** the queued state renders.',
  );
  w('');
  return buf.toString();
}

/// Inline prose behaviors: unbolded scenario markers (plain
/// `Given`/`When`/`Then`), some single-line, some multi-line.
String inlineProseBody(String title, int index, {String eol = '\n'}) {
  final entity = entityOf(index);
  final buf = StringBuffer();
  void w(String s) => buf.write('$s$eol');
  w('# Spec: $title');
  w('');
  w(kPin);
  w('');
  w('## Layer Contracts');
  w('');
  w('**Domain**:');
  w('- `Total`: `compute(List<$entity>) -> num`');
  w('- `Counter`: `count(List<$entity>) -> int`');
  w('');
  w('## Functional Requirements');
  w('');
  w('- **FR-001**: The system MUST compute the $title total.');
  w('  traces: Total');
  w('- **FR-002**: The system MUST show the $entity count.');
  w('  traces: Counter');
  w('');
  w('## Scenarios');
  w('');
  w(
    '1. Given a filled cart, When the user opens $title, Then the total renders.',
  );
  w('2. Given a partially filled cart,');
  w('   When the user opens $title,');
  w('   Then the partial total renders.');
  w(
    '3. Given an empty cart, When the user opens $title, Then the zero total renders.',
  );
  w('');
  return buf.toString();
}

/// Per-epic contracts: the Layer Contracts heading carries an
/// epic-level qualifier; the section still declares the interfaces.
String epicContractBody(String title, int index, {String eol = '\n'}) {
  final entity = entityOf(index);
  final buf = StringBuffer();
  void w(String s) => buf.write('$s$eol');
  w('# Spec: $title (epic: commerce)');
  w('');
  w(kPin);
  w('');
  w('## Layer Contracts — epic-level');
  w('');
  w('**Domain**:');
  w('- `${entity}Repo`: `save($entity) -> void`');
  w('');
  w('**Function**:');
  w('- `${entity}Total`: `compute(List<$entity>) -> num`');
  w('');
  w('## Functional Requirements');
  w('');
  w(
    '- **FR-001**: The system MUST compute the $title total via the epic contract.',
  );
  w('  traces: `${entity}Total.compute`');
  w('');
  w('## Acceptance Scenarios');
  w('');
  w(
    '1. **Given** two items **When** the total computes **Then** the sum renders.',
  );
  w('   **Type**: acceptance');
  w('');
  return buf.toString();
}

/// HTML entities: the headings and prose carry markdown-escaped
/// entities (`&amp;`, `&quot;`, `&#39;`, `&lt;`).
String htmlEntityBody(String title, int index, {String eol = '\n'}) {
  final entity = entityOf(index);
  final buf = StringBuffer();
  void w(String s) => buf.write('$s$eol');
  w('# Spec: $title');
  w('');
  w(kPin);
  w('');
  w('## Key Entities');
  w('');
  w('| Entity | Fields | Purpose |');
  w('| -- | -- | -- |');
  w('| ${entity}Meta | `label: String` | display name |');
  w('');
  w('## External Dependencies &amp; Contracts');
  w('');
  w('| Dependency | Type | Contract | Mock Priority |');
  w('| -- | -- | -- | -- |');
  w('| Hive | storage: box | `put(String, dynamic) -> void` | high |');
  w('');
  w('## Layer Contracts');
  w('');
  w('**Domain**:');
  w('- `${entity}Repo`: `get(String) -> $entity?`');
  w('');
  w('## Functional Requirements');
  w('');
  w('- **FR-001**: The system MUST escape the &quot;quoted&quot; label.');
  w('  traces: `${entity}Repo`');
  w('- **FR-002**: The system MUST reject values with &lt;script&gt; content.');
  w('  traces: `${entity}Repo`');
  w('');
  w('## Acceptance Scenarios');
  w('');
  w(
    '1. **Given** a &quot;quoted&quot; label **When** $title renders **Then** the label renders escaped.',
  );
  w('   **Type**: widget');
  w('');
  return buf.toString();
}

/// Non-English headers: section headings in Spanish/German/French with
/// English structural keywords (Given/When/Then, FR ids, the pin).
String nonEnglishBody(String title, int index, {String eol = '\n'}) {
  final entity = entityOf(index);
  final lang = index % 3; // 0 = ES, 1 = DE, 2 = FR
  final headings = switch (lang) {
    0 => ('## Requisitos Funcionales', '## Escenarios de Aceptación'),
    1 => ('## Funktionale Anforderungen', '## Akzeptanzszenarien'),
    _ => ('## Exigences Fonctionnelles', "## Scénarios d'Acceptation"),
  };
  final buf = StringBuffer();
  void w(String s) => buf.write('$s$eol');
  w('# Especificación: $title');
  w('');
  w(kPin);
  w('');
  w('## Layer Contracts');
  w('');
  w('**Domain**:');
  w('- `Guardado`: `guardar($entity) -> void`');
  w('- `Restaurador`: `restaurar() -> List<$entity>`');
  w('');
  w(headings.$1);
  w('');
  w('- **FR-001**: El sistema DEBE guardar el estado de $title.');
  w('  traces: Guardado');
  w('- **FR-002**: El sistema DEBE restaurar la lista de ${entity}s.');
  w('  traces: Restaurador');
  w('');
  w(headings.$2);
  w('');
  w(
    '1. **Given** un usuario conectado **When** abre $title **Then** la lista guarda.',
  );
  w('   **Type**: acceptance');
  w(
    '2. **Given** un dispositivo sin conexión **When** abre $title **Then** el marcador se muestra.',
  );
  w('   **Type**: widget');
  w('');
  return buf.toString();
}

/// The 120-spec corpus shape matrix: deterministic assignment — the
/// first [ShapeClass.count] features of each round-robin pass take the
/// shape, so consecutive features span different shapes.
final List<ShapeClass> shapeClasses = [
  ShapeClass('modern', 16, (slug, title, i) => modernBody(title, i)),
  ShapeClass(
    'modern-no-lanes',
    12,
    (slug, title, i) => modernBody(title, i, lanes: false),
  ),
  ShapeClass(
    'modern-undeclared',
    12,
    (slug, title, i) => modernBody(title, i, typeMarkers: false, traces: false),
  ),
  ShapeClass('legacy-002', 10, (slug, title, i) => legacyBody(title, i)),
  ShapeClass('crlf', 8, (slug, title, i) => modernBody(title, i, eol: '\r\n')),
  ShapeClass('html-entities', 8, (slug, title, i) => htmlEntityBody(title, i)),
  ShapeClass('non-english', 8, (slug, title, i) => nonEnglishBody(title, i)),
  ShapeClass('fr-table', 8, (slug, title, i) => frTableBody(title, i)),
  ShapeClass('nested-ac', 8, (slug, title, i) => nestedAcBody(title, i)),
  ShapeClass('inline-prose', 8, (slug, title, i) => inlineProseBody(title, i)),
  ShapeClass(
    'epic-contracts',
    6,
    (slug, title, i) => epicContractBody(title, i),
  ),
  ShapeClass('pathological', 10, _pathologicalBody),
  ShapeClass('manual', 6, _manualBody),
];

/// Pathological shapes (index mod 10): each is a distinct hard case —
/// they must never CRASH the parser; each outcome is a named refusal
/// (with a spec line) or, for the BOM case, a clean plan.
String _pathologicalBody(String slug, String title, int index) {
  switch (index % 10) {
    case 0: // empty file (0 bytes)
      return '';
    case 1: // whitespace-only
      return '   \n\t\n\n  \n';
    case 2: // BOM + otherwise clean modern spec
      return '﻿${modernBody(title, index)}';
    case 3: // FRs only — no scenarios at all
      return '''
$kPin

# Spec: $title

## Functional Requirements

- **FR-001**: The system MUST do the thing.
- **FR-002**: The system MUST do the other thing.
''';
    case 4: // unknown scenario type marker
      return '''
$kPin

# Spec: $title

## Acceptance Scenarios

1. **Given** a state **When** it changes **Then** the view updates.
   **Type**: integration
''';
    case 5: // duplicate Type markers for one scenario
      return '''
$kPin

# Spec: $title

## Acceptance Scenarios

1. **Given** a state **When** it changes **Then** the view updates.
   **Type**: widget
   **Type**: unit
''';
    case 6: // Type marker outside any scenario block
      return '''
$kPin

# Spec: $title

## Acceptance Scenarios

**Type**: widget

1. **Given** a state **When** it changes **Then** the view updates.
''';
    case 7: // malformed FUNCTION signature
      return '''
$kPin

# Spec: $title

## Layer Contracts

**Function**:
- `Broken`: `computeWithoutReturn(x)`

## Acceptance Scenarios

1. **Given** a state **When** it changes **Then** the view updates.
''';
    case 8: // unknown template version
      return '**Template Version**: `zuraffa-99.0`\n\n'
          '${modernBody(title, index, typeMarkers: false)}';
    case 9: // CRLF + missing pin (double whammy)
      return legacyBody(title, index, eol: '\r\n');
  }
  throw StateError('unreachable');
}

/// Manual declarations: `(manual: @owner)` scenarios mixed with
/// automated ones; the empty-owner variant is an honest coverage-gate
/// refusal that must name the offending line.
String _manualBody(String slug, String title, int index) {
  final emptyOwner = index.isEven;
  final marker = emptyOwner ? '(manual: )' : '(manual: @qa-zikzak)';
  return '''
$kPin

# Spec: $title

## Layer Contracts

**Domain**:
- `LaneShipper`: `ship(String) -> void`

## Functional Requirements

- **FR-001**: The system MUST ship the $title lane.
  traces: LaneShipper

## Acceptance Scenarios

1. **Given** a release build **When** the lane opens **Then** the $title screen renders.
   **Type**: widget
2. **Given** a release build **When** the beta banner shows $marker **Then** the banner renders.
3. **Given** a support request **When** the user files feedback **Then** the ticket is created.
   **Type**: acceptance
''';
}

/// Round-robin shape assignment: shape i takes the features at
/// i, i+len(shapes), i+2*len(shapes), … until its count is exhausted.
/// One corpus assignment: the feature slug, its shape id, and the
/// built spec body.
class ShapeAssignment {
  const ShapeAssignment(this.slug, this.shapeId, this.body);

  final String slug;
  final String shapeId;
  final String body;
}

/// Round-robin shape assignment: shape i takes features at
/// i, i+len(shapes), i+2*len(shapes), … until its count is exhausted.
List<ShapeAssignment> assignShapes() {
  final out = <ShapeAssignment>[];
  final total = shapeClasses.fold<int>(0, (a, s) => a + s.count);
  if (total != 120) {
    throw StateError('shape matrix covers $total features, expected 120');
  }
  final remaining = [for (final s in shapeClasses) s.count];
  for (var i = 0; i < 120; i++) {
    // Find the next shape class that still needs features, skipping
    // exhausted ones — deterministic round-robin over the classes.
    var shape = 0;
    while (remaining[shape] == 0) {
      shape = (shape + 1) % shapeClasses.length;
    }
    remaining[shape]--;
    final slug = featureSlugs[i];
    final cls = shapeClasses[shape];
    out.add(ShapeAssignment(slug, cls.id, cls.build(slug, titleOf(slug), i)));
  }
  return out;
}

void main(List<String> args) {
  final outArg = args.where((a) => a.startsWith('--out=')).firstOrNull;
  final outDirPath = outArg != null ? outArg.substring(6) : 'corpus/zik_zak';
  final root = p.normalize(p.absolute(outDirPath));
  final rootDir = Directory(root);
  rootDir.createSync(recursive: true);
  final assignments = assignShapes();

  var written = 0;
  for (final a in assignments) {
    final dir = Directory(p.join(root, a.slug));
    dir.createSync(recursive: true);
    File(p.join(dir.path, 'spec.md')).writeAsStringSync(a.body);
    written++;
  }
  // The shape oracle: one line per feature, `<slug> <shape-id>` — the
  // sweep tests read it to assert per-shape expectations, and it keeps
  // the generator and the tests honest about the assignment.
  File(p.join(root, 'corpus-shapes.txt')).writeAsStringSync(
    [for (final a in assignments) '${a.slug} ${a.shapeId}'].join('\n'),
  );

  // Report any stale directories (features we did not assign) without
  // deleting anything — the corpus is committed data.
  final stale = <String>[];
  final assigned = {for (final a in assignments) a.slug};
  for (final entity in rootDir.listSync()) {
    if (entity is Directory) {
      final name = p.basename(entity.path);
      if (!assigned.contains(name)) stale.add(name);
    }
  }
  stdout.writeln(
    'zikzak corpus: wrote $written specs to $root '
    '(${stale.isEmpty ? 'no stale dirs' : 'stale (kept, not deleted): ${stale.join(', ')}'})',
  );
}
