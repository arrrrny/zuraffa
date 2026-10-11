**Template Version**: `zuraffa-1.0`

# Spec: 1383-openwiki-cli-docs

GitHub issue: arrrrny/zuraffa#1383 (verify-misfire / empty-implementation +
spec-drift, EPIC #1132 Phase A step 5 / B criterion 3, #1104 openwiki fleet docs)

## Summary

`docs/openwiki/cli.md` — the epic's per-plugin CLI documentation deliverable —
was never created, and the criterion's "35 plugins" count does not match the
registry (59 commands across 33 plugin directories; the probe list names
removed/renamed verbs: shadcn, gql, xray_deck, observer).

## Locked decisions

1. The doc is GENERATED from the live dispatcher, never hand-written:
   `tool/generate_openwiki_cli_docs.dart` spawns the CLI's own `--help`
   surface per command and renders `docs/openwiki/cli.md` — usage,
   description, options, and subcommands captured from the binary, so it
   cannot drift from the dispatcher.
2. The doc header carries the SPEC 917 exit taxonomy (0/1/2 + the fix
   line) and the machine-envelope contract (`zuraffa.verdict.v1`,
   `proof.v1` receipts) once, globally — per-command repetition would
   drift.
3. The count is re-emitted from the registry on every regeneration
   ("Registry: **N commands**") — the stale hand-pinned count class is
   structurally gone.
4. The probe list's removed/renamed verbs (shadcn, gql, xray_deck,
   observer) are epic-side history; the generated doc is the
   authoritative surface.

## Functional requirements

- **FR-1**: the doc exists and covers ≥50 command sections.
- **FR-2**: key fleet verbs (entity, make, tdd, mock, sync, route,
  proof, simulate) have sections.
- **FR-3**: the exit taxonomy + envelope contract are documented.
- **FR-4**: regeneration is one command (`dart run
  tool/generate_openwiki_cli_docs.dart`).

## Acceptance scenarios

1. The doc exists and parses (B1).
2. ≥50 `## \`zfa <cmd>\`` sections (B2).
3. Key verbs documented (B3).
4. Taxonomy + envelopes documented (B4).

## Success criteria

- **SC-001**: Exit criterion 3's artifact exists, generated from the
  registry so it cannot drift.
- **SC-002**: The docs pin suite stays green.

## Assumptions

- Count re-baselining: the doc's registry count is emitted at generation
  time (59 commands as of this fix) — the epic's "35" is superseded.
