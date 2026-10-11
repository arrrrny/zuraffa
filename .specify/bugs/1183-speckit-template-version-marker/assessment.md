# Bug Assessment: 1183 — speckit template ships no Template Version marker; first plan deterministically drifts

- **Slug**: 1183-speckit-template-version-marker
- **Created**: 2026-09-06
- **Source**: GitHub issue #1183 (task bug context; repo carried no local record)
- **Verdict**: valid
- **Severity**: medium

## Symptom

Every new feature spec authored by `/speckit-specify` fails its FIRST
`zfa tdd plan` with exit 3 (`contract drift — missing **Template Version**
marker`). The `--migrate-spec` escape hatch (issue #990) repairs the spec in
place, so the pain is a guaranteed one-time failure per feature rather than a
blocked workflow — but the authoring pipeline and the planning pipeline
disagree about the spec contract, and the failure is 100% deterministic.

## Reproduction (this session, master @ 42840d81)

1. `bash .specify/scripts/bash/create-new-feature.sh "Repro first plan drift
   bug 1183" --short-name repro-1183` → `specs/1139-repro-1183/spec.md`
   created from the template; `grep -c "Template Version"` → **0 matches**.
2. `dart run bin/zfa.dart tdd plan 1139-repro-1183` → exit 3 with the drift
   message and the `--> fix:` line naming `--migrate-spec` (issue #990).

## Root Cause (high confidence, code-read + repro)

`create-new-feature.sh` authors specs by copying the spec template verbatim
(`resolve_template_content "spec-template"` → `specs/<feature>/spec.md`).
The template override stack has no overrides and no presets in this repo, so
the resolved layer is exactly `.specify/templates/spec-template.md` — and
that file ships **no** `**Template Version**` marker (grep over the file: 0
matches). The #919 contract gate in `PlanCommand._run`
(`lib/src/plugins/tdd/commands/plan_command.dart:143-171`) runs BEFORE any
parsing: a spec whose `SpecParser.parseTemplateVersion` is null or unknown
exits 3. `SpecParser.knownTemplateVersions` contains only `zuraffa-1.0`
(`lib/src/plugins/tdd/services/spec_parser.dart:279-285`), and the parser
strips fenced code blocks first, so a marker inside a documentation fence
would not count either. Issue #990 deliberately kept the gate unchanged and
shipped only the migration flag — it fixed the reader side, not the authoring
side. Hence: every template-authored spec is born contract drift.

## Fix Decision (bug's option 1 — the template ships the marker)

Make `.specify/templates/spec-template.md` carry
`**Template Version**: `zuraffa-1.0`` in the frontmatter position (right
after the `# Feature Specification:` heading), matching (a) where green specs
already author it (e.g. `.specify/bugs/tdd-120-template-structures/spec.md`
line 3) and (b) the frontmatter position `SpecMigrator` inserts at. This
fixes every authoring path that copies the template (the bash/PowerShell/
Python create-new-feature twins and the agent flow that fills the template)
with a 2-line change, no script logic, no runner coupling. The gate itself is
UNCHANGED — a hand-authored spec without the marker still exits 3 (issue #990
contract preserved).

## Non-goals

- No change to `PlanCommand`, `SpecParser`, or `SpecMigrator` (reader side is
  correct; #919/#990 own it).
- No injection logic added to the create-new-feature script twins (three
  script rewrites for what a template line does in one).
- No backfill of existing specs — `--migrate-spec` remains the migration path
  for pre-fix specs (077-081 etc. already migrated by the operator).
