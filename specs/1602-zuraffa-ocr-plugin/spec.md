# Feature Specification: `zuraffa_ocr` federated plugin delivery

**Feature Branch**: `1602-zuraffa-ocr-plugin`

**Created**: 2026-09-13

**Status**: Draft

**Origin**: GitHub issue [#684](https://github.com/arrrrny/zuraffa/issues/684) (sub-issue of epic #214: migrate all ZikZak pub.dev packages to be built on zuraffa)

**Input**: User description: "create a new repo for this zuraffa_ocr, follow the zuraffa_auth, zuraffa_permission and other packages, use the same create-plugin. ONLY IMPLEMENT using spec definitions and spec-whole."

## User Scenarios & Testing *(mandatory)*

<!--
  The "user" is the maintainer migrating tesseract_ocr (#684) onto zuraffa.
  The generator (`zfa package plugin` / `create-plugin`, spec 1601) already
  exists and is proven generically; this feature delivers its OCR
  INSTANCE — the repo, the stamped metadata, the family health — with
  every claim verified through the spec-driven loop.
-->

### User Story 1 - One command scaffolds the zuraffa_ocr family (Priority: P1)

The maintainer runs `zfa package create-plugin zuraffa_ocr` (with the OCR
description and the `arrrrny/zuraffa_ocr` repository identity) and obtains
the five-package federated family — `zuraffa_ocr`, `zuraffa_ocr_platform`,
and the Android/iOS/macOS adapters — with every package's metadata stamped
for OCR: the OCR description in each pubspec, the `arrrrny/zuraffa_ocr`
repository and issue-tracker URLs, OCR-derived class nouns (`Ocr*`), and
OCR topics.

**Why this priority**: The scaffold is the deliverable; without a
correctly stamped family nothing else in the feature exists.

**Independent Test**: Run the real CLI into a temp directory and assert
the family layout and every OCR stamp structurally.

**Acceptance Scenarios**:

1. **Given** an empty working directory, **When** the maintainer runs
   `zfa package create-plugin zuraffa_ocr --repo arrrrrny/zuraffa_ocr
   --description "…"` with the default platform set, **Then** exactly five
   package directories are created (app-facing, platform core, and the
   three adapters), each with dependency manifest, analysis configuration,
   README, changelog, license, library barrel, sources, and test harness.
   **Type**: acceptance
2. **Given** the scaffolded family, **When** the developer inspects any
   package's manifest, **Then** the description is the stamped OCR
   description verbatim, the repository is
   `https://github.com/arrrrny/zuraffa_ocr`, the issue tracker its
   `/issues`, the topics include `ocr`, and no package sets
   `publish_to: none`.
   **Type**: acceptance
3. **Given** the scaffolded family, **When** the developer inspects the
   dependency graph, **Then** the app-facing package depends only on
   hosted zuraffa, the core only on the app package, each adapter on the
   app package and the core, and no package depends on an adapter.
   **Type**: acceptance
4. **Given** the scaffolded family, **When** the developer browses the
   generated sources, **Then** the public surface carries the OCR-derived
   names (`OcrPort`, `OcrService`, `AndroidOcr…`/`IosOcr…`/`MacosOcr…`)
   and each package ships a passing-shape test harness over a test double.
   **Type**: acceptance

---

### User Story 2 - The generated family is healthy out of the box (Priority: P1)

Every package in the freshly scaffolded `zuraffa_ocr` family resolves,
analyzes, and tests clean with zero manual edits, and every package
passes a publish dry-run — the family is publish-ready the moment it
exists.

**Why this priority**: "Built on zuraffa" is only proven when the family
compiles and passes its own gates; publish-readiness is the epic's end
state.

**Independent Test**: For the scaffolded family, run per-package
resolve/analyze/test and a publish dry-run per package.

**Acceptance Scenarios**:

1. **Given** the scaffolded family, **When** the developer runs
   `dart pub get`, `dart analyze --no-fatal-warnings`, and `dart test` in
   each package, **Then** all exit zero for all five packages.
   **Type**: acceptance
2. **Given** the scaffolded family, **When** the developer runs
   `dart pub publish --dry-run` in each package, **Then** all exit zero
   (overrides hints are acceptable; missing LICENSE/CHANGELOG or path
   dependencies in `dependencies` are not).
   **Type**: acceptance
3. **Given** any adapter package, **When** the developer resolves
   dependencies, **Then** the framework resolves the current published
   zuraffa v6 line without a local checkout.
   **Type**: acceptance

---

### User Story 3 - The zuraffa_ocr repository exists on GitHub (Priority: P2)

The maintainer addressing #684 ends the feature with a real repository:
`~/Developer/zuraffa_ocr`, initialized on `master`, pushed to
`arrrrny/zuraffa_ocr` — resolvable where the tesseract_ocr migration can
begin.

**Why this priority**: The repo is the issue's concrete deliverable; it
depends on Stories 1–2 being green so the initial commit is verified
work.

**Independent Test**: After scaffolding into `~/Developer/zuraffa_ocr`,
running the family gates, and pushing, the GitHub repository resolves.

**Acceptance Scenarios**:

1. **Given** the verified family, **When** the maintainer initializes
   git and pushes to `arrrrny/zuraffa_ocr`, **Then** the repository
   resolves publicly and `master` carries the scaffold.
   **Type**: acceptance
2. **Given** the pushed repository, **When** a fresh clone resolves and
   analyzes any package, **Then** it succeeds without local paths — the
   committed state is self-contained.
   **Type**: acceptance

---

### Edge Cases

- What happens if `~/Developer/zuraffa_ocr` already exists? (The
  scaffold refuses — the delivery must not overwrite.)
- What happens if a pub.dev name (`zuraffa_ocr*`) is already taken at
  publish time? (Out of scope here: this feature proves dry-run
  readiness; the publish run is a follow-up decision.)
- What happens on a machine without network for `pub get`? (The slow
  tier skips honestly; the fast structural tier stays green offline.)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST deliver the `zuraffa_ocr` family by
  running the existing `zfa package create-plugin` command with the OCR
  description and `arrrrny/zuraffa_ocr` repository identity — no
  hand-assembled package trees.
            traces: PluginScaffold
- **FR-002**: Every generated package MUST carry the OCR stamps: the
  provided description verbatim, the `arrrrny/zuraffa_ocr` repository and
  issue tracker, an `ocr` topic, and OCR-derived public class names.
- **FR-003**: The generated family MUST satisfy the federated dependency
  invariants (app → zuraffa only; core → app; adapters → app + core; no
  adapter dependents) with in-family constraints at the scaffold version.
- **FR-004**: Every generated package MUST pass `dart pub get`,
  `dart analyze`, and `dart test` with zero manual edits.
- **FR-005**: Every generated package MUST pass `dart pub publish
  --dry-run` (complete metadata, per-package LICENSE and CHANGELOG,
  dev-only overrides placement).
- **FR-006**: The delivered repository MUST be pushed to
  `arrrrny/zuraffa_ocr` and be self-contained (no local path
  dependencies in the committed manifests).

### Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| OcrFamily | `baseName: zuraffa_ocr`, `packages: List<String> (5)`, `repository: arrrrrny/zuraffa_ocr` | The delivered federated family instance |
| OcrStamps | `description: String`, `topics: contains ocr`, `classNoun: Ocr` | The OCR-specific metadata asserted on every package |
| FamilyGate | `pubGet: exit 0`, `analyze: exit 0`, `test: exit 0`, `publishDryRun: exit 0` | Per-package health board the delivery must post |

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `zfa package create-plugin zuraffa_ocr` produces the
  five-package family with every OCR stamp verified structurally in an
  automated test.
  - **Verification**: The spec's fast-tier test asserts layout, stamps,
    wiring, and harness integrity on a temp-dir scaffold.
- **SC-002**: The scaffolded family posts a full green board:
  5/5 packages × (pub get, analyze, test) and 5/5 publish dry-runs.
  - **Verification**: The slow-tier e2e test (temp family) plus the
    delivery board run on the real repository.
- **SC-003**: `https://github.com/arrrrny/zuraffa_ocr` resolves with the
  scaffold pushed to `master`.
  - **Verification**: `gh repo view` + an HTTP check at delivery.

## Assumptions

- **Same generator, new instance.** The generic generator behaviors were
  proven in spec 1601; this spec pins the OCR instance (stamps + health +
  delivery) and does not re-litigate the generator contract.
- **The wasm/FFI-shaped generic surface ships as-is.** As with
  zuraffa_ffi (#678), the scaffold is the migration starting point;
  OCR-specific domain code (recognition requests, text results) lands on
  top in follow-up migration work.
- **Initial version 0.1.0**, in-family constraints `^0.1.0`, zuraffa
  hosted `^6.2.2` — matching the zuraffa_ffi release.
- **Publishing to pub.dev is out of scope**; the family is left
  dry-run-clean so the publish decision is a one-command follow-up.
- **Repository identity** `arrrrny/zuraffa_ocr`, homepage
  `https://zuraffa.com` — the family defaults.
