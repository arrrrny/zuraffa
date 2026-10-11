# Spec 917 — Treaty + error API unification: manifest --verify, exit protocol, --json/--stream everywhere

GitHub issue: arrrrny/zuraffa#917
Part of the #908 unification epic. Absorbs: #776 (manifest --verify),
#778 (exit codes + --format json), #838 (--json/--stream), #839 (exit
protocol 0/1/2/3/4), the live drift evidence from #904, and the #876
needs-reproducer note (silent parent-option inertness).

## Problem

The CLI's error surface is prose, not an API. Three treaties are
asserted by humans reading documents instead of machines reading
verdicts:

1. **The manifest treaty is not enforced.** `zfa manifest` lists what
   every plugin's capabilities accept (`inputSchemas`), but nothing
   checks that the advertised contract matches what the CLI actually
   parses and what the help text prints. The drift is not hypothetical:
   #904 recorded live sites — `feature scaffold --use-mock` is
   manifest-declared but the parser only knows `--mock`;
   `outputDir` is declared in the scaffold/json-mock schemas yet
   hardcoded/ignored; shadcn's `ui.schema.export` was unreachable with
   `--project-root`/`--schema-version` unaccepted; benchmark advertised
   `--scenario-ids` while parsing `--scenario`; slice advertised
   `--project-root` ×4 and `--confirm-all` while parsing `--project`
   and `--yes`. #876 added the inverse class: parent options that die
   silently at hand-rolled dispatch layers.
2. **Exit codes are a grab-bag, not a protocol.** VISION §4 ratified
   0 success / 1 failure (RED, honest) / 2 usage / 3 drift /
   4 state conflict — but 75 literal `64` sites across 29 lib files
   predate the protocol, the runner's UsageException path exits 64,
   benchmark shadows `exitCode` with raw `exit(64)`/`exit(1)`, and
   nothing asserts the table in CI. `255`/`-9` paths are external-kill
   artifacts with no documented home.
3. **Machine verdicts are partial.** `--json` exists on 26 of 30 tdd
   verbs (the run-engine/split/status/theater laggards and all four
   top-level corpus subcommands lack it), `--stream` does not exist
   anywhere, so an agent driving the loop must parse prose progress
   lines. And every non-zero exit too often ends in an apology instead
   of the machine-actionable `--> fix:` line (the runner's catch-all
   prints none).

This is VISION §3+§4 made mechanical: the agent never parses prose;
it parses verdicts.

## Deliverables

1. **`zfa manifest --verify` — the treaty gate.** Four mechanical
   legs: (a) capability resolution — every manifest capability route
   resolves to a live command; (b) schema ↔ flags — every
   `inputSchema` property the manifest advertises is accepted by the
   serving command's real `ArgParser` (or its declared `CliFlagSurface`
   for the `allowAnything()` hand-rolled dispatchers); (c) help text —
   every accepted flag the schema advertises appears in the command's
   help; (d) dead flags — flags the CLI accepts but no schema
   advertises, scoped to CLI-aware plugins to avoid hand-rolled false
   positives. Drift findings exit **3**; unverifiable surfaces are
   reported with a fix line, not counted as drift (the gate never
   lies by omission or by inflation). `--verify --format json` emits
   one machine-verifiable `manifest-verify.v1` document. Optional
   trailing plugin ids scope the audit. The #904 sites are the seed
   fixture list and MUST certify green after the fixes.
2. **The exit protocol, ratified in code.** `lib/src/cli/exit_protocol.dart`
   owns the golden table (0/1/2/3/4), the legacy mapping
   (`64 → 2` via `ExitProtocol.canonicalize`; `255`/`-9`/`137`
   documented as external-kill only), and the `--> fix:` line
   factory. Every literal `64` in `lib/` migrates to the canonical
   code (runner UsageException → 2, benchmark's shadowed exits →
   protocol codes, all command-level usage paths). The table is
   printed by the top-level help (EXIT CODES section) and embedded in
   `zfa schema`. Golden-table assertions run against the LIVE CLI in
   `test/commands/exit_protocol_golden_test.dart`, enforced in CI by
   `.github/workflows/conformance.yml`.
3. **Machine verdicts everywhere.** `--json` on every tdd verb (the
   four laggards join the `verdict.v1` envelope) and on all four
   top-level corpus subcommands (import/catalog/run/ledger), closing
   with the schema-versioned envelope. `tdd run --stream` (and the
   engine/skin driving verbs) emits one NDJSON
   `step-verdict.v1` event per completed loop step while the run
   drives, terminated by the final `verdict.v1` envelope. Without the
   flags the output stays byte-identical to today's.
4. **Errors are an API.** Every non-zero exit — including the runner's
   catch-all and the usage paths — ends with a machine-actionable
   `--> fix: ...` line.

## Design

- `ExitProtocol` is an `abstract final class` of constants plus
  `canonicalize()` and `fixLine()` — the single source of truth; no
  command hard-codes a protocol number.
- The gate's flag surface: real `ArgParser.options` for most plugin
  commands; the new `CliFlagSurface` interface for the permissive
  hand-rolled dispatchers (slice, benchmark, shadcn) whose honest
  grammar is the dispatch inside `run()`. The declaration is asserted
  against live dispatch by the gate's fixtures — a flag declared but
  rejected is the #904 drift class by construction.
- Drift is classified (`schema-flag-drift`, `help-text-drift`,
  `flag-surface-unverifiable`) so CI triage is mechanical.
- NDJSON streaming hooks the shared `RunDriverCore` via an
  `onStepEvent` callback — one emission point per completed step, no
  per-command duplication; the streamed events terminate in the final
  verdict envelope when both flags are set.
- CI (`.github/workflows/conformance.yml`) runs the gate live
  (text + JSON), the golden-table test, the gate-fixture tests and the
  machine-verdict tests on every push/PR to master.

## Acceptance criteria

1. `zfa manifest --verify` exits 0 on the live repo (0 drift), exits 3
   with classified findings on the #904 seed fixtures, and refuses
   unknown plugin ids as usage (exit 2, never a silent pass).
2. `dart analyze` reports zero literal `64` exits in `lib/`; the
   golden table (0/1/2/3/4 + legacy mapping) is asserted by tests
   against the live CLI and printed by `zfa`'s top-level help.
3. Every tdd verb and all four corpus subcommands close with the
   `verdict.v1` envelope under `--json`; `tdd run --stream` emits one
   `step-verdict.v1` NDJSON line per completed step, terminated by the
   envelope; flag-absent output is byte-identical to the legacy text.
4. Every non-zero exit path observed in the suites ends with a
   `--> fix:` line.
5. `tools/run_tests_chunked.sh` provably covers every top-level test
   directory (the >40-files-with-test-free-subdirs silent-skip bug —
   which dropped `test/commands` and `test/regression` from every
   previous run — is fixed and covered by a fresh full-suite run).

## Out of scope

- Re-mapping the tdd driver's internal 0/1/2/3/4 outcomes (they
  already match the ratified table); remapping `255`/`-9`/`137`
  (external-kill only, documented, never emitted by zfa).
- Forcing every permissive parser onto real `ArgParser` options —
  `CliFlagSurface` is the honest contract for hand-rolled dispatch;
  full parser migration is a per-plugin refactor, not a treaty item.
- Mutation-audit score requirements: the repo-level spec carries no
  behavior registry, so `zfa tdd verify` reports `not_assessed` —
  recorded honestly in `tdd/verification.md`, never fabricated.
