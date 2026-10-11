/// `SpecTemplateWriter` — ensures the project's spec authoring template
/// carries the zuraffa-1.0 grammar (issue #1480).
///
/// Bug #1480: the `.specify/templates/spec-template.md` a spec-kit
/// project receives is the STOCK spec-kit template — none of zuraffa's
/// authoring grammar (`## Layer Contracts`, the `traces:` continuation,
/// the `**Type**` markers, the `### Key Entities` table) — and no zfa
/// verb installed zuraffa's own template, so every spec-kit-authored
/// spec dead-ended the unit lane: the declared-routing path reads
/// contract rows only from the spec body, and a contract row name is
/// authoring intent no classifier can invent.
///
/// The treaty (matching #1183's authoring-side fix in the zuraffa repo
/// itself): `zfa tdd init` — the wiring verb — propagates the template.
/// Three states, decided by the same `**Template Version**` pin the
/// #919 plan gate enforces:
///   1. **absent** -> the embedded zuraffa-1.0 template is installed;
///   2. **grammarless** (no known zuraffa version pin — the stock
///      spec-kit scaffold, exactly the #1480 dead-end carrier) ->
///      replaced with the grammar template (a loud notice, never
///      silent);
///   3. **pinned** (already carries a known zuraffa version marker) ->
///      untouched, byte-identical — the pin is the customization
///      treaty: a template an author adapted under a known version is
///      user content (FR-008), never clobbered.
///
/// Idempotent: re-running init on a wired project is a no-op.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../plugins/tdd/services/spec_parser.dart';

/// What the writer did (or declined to do) for the invoking command's
/// output line.
enum SpecTemplateWriteAction { created, replaced }

/// One writer outcome: [action] is null when the existing template
/// already pins a known zuraffa version (nothing was written).
typedef SpecTemplateWriteResult = ({
  SpecTemplateWriteAction action,
  String path,
});

class SpecTemplateWriter {
  const SpecTemplateWriter();

  /// Ensure `<projectRoot>/.specify/templates/spec-template.md` carries
  /// the zuraffa-1.0 authoring grammar. Returns null when the existing
  /// template is already current; otherwise the write outcome.
  Future<SpecTemplateWriteResult?> write(String projectRoot) async {
    final dir = Directory(p.join(projectRoot, '.specify', 'templates'));
    final file = File(p.join(dir.path, 'spec-template.md'));

    if (await file.exists()) {
      final existing = await file.readAsString();
      final version = const SpecParser().parseTemplateVersion(existing);
      final pinned =
          version != null && SpecParser.knownTemplateVersions.contains(version);
      if (pinned) {
        // The customization treaty: a template that already pins a known
        // zuraffa version carries the grammar (and possibly the author's
        // adaptations) — never clobbered, never re-rendered.
        return null;
      }
      await dir.create(recursive: true);
      await file.writeAsString(kZuraffaSpecTemplate);
      return (action: SpecTemplateWriteAction.replaced, path: file.path);
    }

    await dir.create(recursive: true);
    await file.writeAsString(kZuraffaSpecTemplate);
    return (action: SpecTemplateWriteAction.created, path: file.path);
  }
}

/// The zuraffa-1.0 spec authoring template — byte-identical to the
/// repo-local `.specify/templates/spec-template.md` the #1183/#1186
/// fixes authored (PR #1217, PR #1227), embedded so the SHIPPED package
/// propagates it without a repo checkout. Every contract row declared in
/// the `## Layer Contracts` section parses through the real
/// `SpecParser.parseContractRows`, so a template-authored spec routes
/// declared out of the box once its FRs name the rows on `traces:` lines.
const String kZuraffaSpecTemplate = r'''# Feature Specification: [FEATURE NAME]

**Template Version**: `zuraffa-1.0`

**Feature Branch**: `[###-feature-name]`

**Created**: [DATE]

**Status**: Draft

**Input**: User description: "$ARGUMENTS"

## User Scenarios & Testing *(mandatory)*

<!--
  IMPORTANT: User stories should be PRIORITIZED as user journeys ordered by importance.
  Each user story/journey must be INDEPENDENTLY TESTABLE - meaning if you implement just ONE of them,
  you should still have a viable MVP (Minimum Viable Product) that delivers value.

  Assign priorities (P1, P2, P3, etc.) to each story, where P1 is the most critical.
  Think of each story as a standalone slice of functionality that can be:
  - Developed independently
  - Tested independently
  - Deployed independently
  - Demonstrated to users independently
-->

### User Story 1 - [Brief Title] (Priority: P1)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently - e.g., "Can be fully tested by [specific action] and delivers [specific value]"]

**Acceptance Scenarios**:

<!--
  Routing declaration (issue #1186): every scenario MUST carry a `**Type**`
  marker on the line after its Given/When/Then header — `zfa tdd plan` routes
  the behavior by it (never by prose sniffing) and `--strict-routing` refuses
  a scenario without one. Use `acceptance` for plain business outcomes,
  `widget` for UI-observable outcomes (renders, navigates, shows), and the
  other declared kinds (unit, theme, ffi, platform) when the scenario
  exercises that lane.
-->

1. **Given** [initial state], **When** [action], **Then** [expected outcome]
   **Type**: acceptance
2. **Given** [initial state], **When** [action], **Then** [expected outcome]
   **Type**: acceptance

---

### User Story 2 - [Brief Title] (Priority: P2)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]
   **Type**: acceptance

---

### User Story 3 - [Brief Title] (Priority: P3)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]
   **Type**: acceptance

---

[Add more user stories as needed, each with an assigned priority]

### Edge Cases

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right edge cases.
-->

- What happens when [boundary condition]?
- How does system handle [error scenario]?

## Requirements *(mandatory)*

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right functional requirements.
-->

### Functional Requirements

<!--
  Contract traces (issue #1186): every functional requirement that exercises
  a declared contract row (Layer Contracts, Key Entities, External
  Dependencies) MUST name it on a `traces:` continuation line — the plan
  routes the behavior by the DECLARED row (never by prose sniffing) and
  `--strict-routing` requires it. A trace to a name that no row declares is
  refused (dangling reference) naming the spec line.
-->

- **FR-001**: System MUST [specific capability, e.g., "allow users to create accounts"]
- **FR-002**: System MUST [specific capability, e.g., "validate email addresses"]
            traces: Validator
- **FR-003**: Users MUST be able to [key interaction, e.g., "reset their password"]
- **FR-004**: System MUST [data requirement, e.g., "persist user preferences"]
- **FR-005**: System MUST [behavior, e.g., "log all security events"]

*Example of marking unclear requirements:*

- **FR-006**: System MUST authenticate users via [NEEDS CLARIFICATION: auth method not specified - email/password, SSO, OAuth?]
- **FR-007**: System MUST retain user data for [NEEDS CLARIFICATION: retention period not specified]

## Layer Contracts

<!--
  ACTION REQUIRED (issue #1186): declare the interfaces the requirements
  exercise, one bullet per row under a bold layer label. `zfa tdd plan`
  derives a CONTRACT behavior per declared method (issue #1007) and routes
  traced FRs by these rows (issue #1186: `traces:` under the FR). Declared
  signatures must be `name(Params) -> Return` — a malformed Function
  signature refuses the plan naming the row. Delete this section when the
  feature declares no interfaces.
-->

**Function**:
- `Validator`: `validate(Input) -> Result`

**Domain**:
- `[Interface]`: `[method](Params) -> Return`

**Presentation**:
- `[Controller]`: `[method](Params) -> Return`

### Key Entities

<!--
  ACTION REQUIRED: declare the feature's data entities as a 3-column table
  (the zuraffa-1.0 grammar). Each row is a declared contract row an FR can
  trace to (`traces: <Entity>`); the loop creates and wires them at run
  time. Delete this section when the feature involves no data.
-->

| Entity | Fields | Purpose |
| -- | -- | -- |
| [Entity1] | `id: String`, `status: String` | [What it represents] |

## Lanes *(include when the feature splits engine vs. skin)*

<!--
  ACTION REQUIRED (engine/skin split, issue #1000): declare which behaviors
  are pure Dart (CORE / engine), Flutter (SKIN / skin), or both (BOTH / the
  shared seam). Behavior ids reference the acceptance scenarios (`A1`, ...)
  and functional requirements (`U1`, ...) this spec derives; ranges like
  `U1-U6` expand; an id only the skin owns (e.g. `W1-W4`) is a hand-declared
  lane row — annotate it (`W1 (renders the login form)`) to give it a
  description. `adaptive_slots` lists the adaptive-layout contract slots the
  skin must provide.

  A spec WITHOUT this section plans the legacy single-file test list; a spec
  WITH it makes `zfa tdd plan` emit the split plan: `tdd/04-ENGINE.md`
  (CORE + BOTH — pure Dart, the noFlutter guard rejects any Flutter
  reference), `tdd/04-SKIN.md` (SKIN + BOTH + the AdaptiveViewSlots), and
  `tdd/04-CONTRACT.md` (the engine/skin seam). `tdd/test-list.md` becomes
  the lane meta-index. Every spec-derived behavior must be declared in a
  lane — an undeclared behavior refuses the plan with the declaration to
  add. Features planned before this grammar migrate with the one-shot
  `zfa tdd split <feature>` (kind heuristic: widget/theme rows are SKIN,
  the rest CORE) which records the classification in
  `tdd/split-receipt.json`.
-->

```yaml
Lanes:
  - lane: CORE
    behaviors: [A1, A2, U1-U6]
    flutter_allowed: false
  - lane: SKIN
    behaviors: [W1-W4]
    flutter_allowed: true
    adaptive_slots: [mobile, ios, android, macos]
  - lane: BOTH
    behaviors: [A3 (acceptance: navigates to deal_list)]
    flutter_allowed: conditionally
```

## Skin Contract *(include when the skin surface needs a declared contract)*

<!--
  ACTION REQUIRED (issue #1004, adaptive-layout platform matrix):
  declare the skin's typed contract — the adaptive platform slots, the
  per-platform overrides, the view state machine, and the routes the
  skin can navigate to. `zfa tdd plan` renders these into `tdd/04-SKIN.md`
  as typed rows (the platform matrix, the state machine, the route
  table) plus a machine-parseable JSON contract the loop referees the
  skin against — never prose. Requires a `## Lanes` section (the
  contract rides the SKIN lane), and the `adaptive_slots` declared here
  must match the SKIN lane's. Unknown keys, duplicates, and slot/override
  drift refuse the plan naming the offending key.
-->

```yaml
Skin Contract:
  adaptive_slots: [mobile, ios, android, macos]
  platform_overrides:
    ios:
      home_indicator_safe_area: required
    macos:
      title_bar_alignment: trailing
  states: [initial, loading, data, error, empty]
  routes: [login, deal_list, settings]
```

## Success Criteria *(mandatory)*

<!--
  ACTION REQUIRED: Define measurable success criteria.
  These must be technology-agnostic and measurable.
-->

### Measurable Outcomes

- **SC-001**: [Measurable metric, e.g., "Users can complete account creation in under 2 minutes"]
- **SC-002**: [Measurable metric, e.g., "System handles 1000 concurrent users without degradation"]
- **SC-003**: [User satisfaction metric, e.g., "90% of users successfully complete primary task on first attempt"]
- **SC-004**: [Business metric, e.g., "Reduce support tickets related to [X] by 50%"]

## Assumptions

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right assumptions based on reasonable defaults
  chosen when the feature description did not specify certain details.
-->

- [Assumption about target users, e.g., "Users have stable internet connectivity"]
- [Assumption about scope boundaries, e.g., "Mobile support is out of scope for v1"]
- [Assumption about data/environment, e.g., "Existing authentication system will be reused"]
- [Dependency on existing system/service, e.g., "Requires access to the existing user profile API"]
''';
