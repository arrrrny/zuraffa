# Bug Assessment: `zfa mock create --force` silently overwrites a hand-authored `<Entity>DataSource` interface

- **Slug**: mock-force-interface-overwrite
- **Created**: 2026-10-20
- **Source**: https://github.com/arrrrny/zuraffa/issues/1952 (also carries the `spec` label; the bug label governs — this assessment is the triage artifact)
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

Issue #1952: `zfa mock create <Entity> --force --certify` silently replaces a
hand-authored `<Entity>DataSource` interface (e.g. `recent()` / `record()` /
`clear()`) with a generated CRUD surface (`get` / `update` / `toggle`), then
certifies against the interface it just overwrote. Exit 0 — the destructive
contract change is invisible to a scripted pipeline. This is the remaining
half of #1931 after PR #1945: the mock datasource purge is fixed, the
interface file itself is not. Related: #1418 (force must regenerate a stale
GENERATED interface), #1922 (member-shape refusal must precede the first
write), #1951 (enum --certify refusal, same verification pass).

## Symptom

A `--force` mock run rewrites an existing declared interface whose members
the run's `--methods` cannot reproduce, without asking and without failing.
Expected: the declared interface is the authoritative contract (#1931's
premise); a run that would remove declared members must refuse loudly.

## Reproduction

1. Hand-author `lib/src/data/datasources/<snake>/<snake>_datasource.dart`
   declaring non-CRUD members (`recent`, `record`, `clear`).
2. Run `zfa mock create <Entity> --force --certify`.
3. The interface now declares the CRUD templates only; exit 0; the
   certification grades the rewritten contract. (Unit-level repro: the red
   test in `test/plugins/mock/bug_1952_force_handauthored_interface_test.dart`.)

## Suspected Code Paths

- `lib/src/plugins/mock/builders/mock_builder.dart:370` — the force guard
  `(config.force && !config.revert && !interfacePending)` invokes the
  interface writer unconditionally under `--force` (the #1418 contract).
- `lib/src/plugins/datasource/builders/interface_generator.dart` —
  `DataSourceInterfaceBuilder.generate` falls through to
  `FileUtils.writeFile(..., force: options.force)`, which force-overwrites
  the on-disk interface with the CRUD/custom templates built from
  `config.methods`.
- `lib/src/utils/method_extractor.dart` — `extractMethodsFromInterface`
  parses the on-disk declared members (the same primitive the #1570
  staleness detector uses); reusable to compute what would be lost.

## Root Cause Hypothesis

The #1418 fix made `--force` regenerate the interface unconditionally so a
stale GENERATED interface cannot drift from the current `--methods`. It did
not distinguish a generator-owned interface (its members are all in the
interface vocabulary the writer can emit) from a hand-authored one (members
the writer could never reproduce). Confidence: high — the overwrite site and
write path are exactly as the issue describes.

## Proposed Remediation

**Preferred** (issue option 1 + option 3 escape hatch): in `MockBuilder`'s
pre-flight (beside the #1922 `validateMemberShapes` gate, so a refused run
still writes nothing), when the run would force-overwrite an EXISTING
interface, parse the on-disk declared members and compare their names with
the member names the fresh emission would declare
(`DataSourceInterfaceBuilder.plannedMemberNames(config)`). Any lost member
whose name is NOT in the interface's CRUD emission vocabulary proves a
hand-authored contract → throw (`StateError`, the lane's cert-refusal type)
naming the file and the lost members, exit non-zero, no bytes written.
`--overwrite-interface` (new `GeneratorConfig.overwriteInterface` flag,
plumbed through the `mock create` capability schema) opts in and lets the
overwrite proceed. Lost CRUD-vocabulary members stay the #1418
methods-driven drift and keep regenerating; a generated-then-hand-edited
file loses a non-CRUD member and is refused the same way (#1922's seeded
interface, whose `remove(String id)` disappears under today's force run).

**Alternatives**:
- Preserve the interface and certify against the on-disk contract (issue
  option 2) — friendlier but leaves the run silently producing a mock for a
  contract the user never asked this run to implement.
- Provenance-header sniffing (generated files carry a header) — rejected:
  #1922's own hand-maintained fixture carries the header, so header presence
  does not imply generator-owned.

**Files likely to change**:
- `lib/src/plugins/mock/builders/mock_builder.dart` (the refusal guard)
- `lib/src/plugins/datasource/builders/interface_generator.dart`
  (`plannedMemberNames` + public CRUD-emission vocabulary)
- `lib/src/models/generator_config.dart` (`overwriteInterface` field)
- `lib/src/plugins/mock/capabilities/create_mock_capability.dart` (schema +
  arg plumb)
- `lib/src/commands/mock_command.dart` (CLI `--overwrite-interface` flag)
- `test/plugins/mock/bug_1952_force_handauthored_interface_test.dart` (red→green)

**Tests to add or update**:
- Hand-authored interface + force → throws, names file + lost members, tree
  byte-identical.
- `--overwrite-interface` opt-in → overwrite proceeds, mock emitted.
- Lost CRUD member only (#1418 stale generated interface) → still
  regenerates (A1 contract intact).
- No lost members (idempotent force) → proceeds.
- Non-force run → untouched (existing A3 covers it; keep green).

## Risks & Considerations

- `zfa make X --mock --force` rides the same builder: a make run over a
  hand-authored interface now refuses too. Same bug class, protective, and
  the escape hatch exists — noted in the PR body.
- The datasource lane (`zfa datasource create --force`) intentionally
  regenerates interfaces; out of scope, untouched.
- A generated interface that was hand-edited but kept only CRUD members is
  still regenerated under force (undecidable from stale-generator output);
  documented limitation, name-level comparison only.

## Open Questions

- None blocking; the issue offers the refusal as the safer default.
