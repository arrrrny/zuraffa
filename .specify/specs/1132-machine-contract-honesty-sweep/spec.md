# 1132-machine-contract-honesty-sweep

- **Spec ID**: 1132-machine-contract-honesty-sweep
- **Created**: 2026-09-17
- **Source**: GitHub issue #1132 (EPIC 1: Machine Contract — The Honesty Sweep, priority high)
- **Type**: epic completion pass (P1 — residual lying-success paths on master after the #1239/#856/#839 sweeps, the #1105 envelope unification, the #996/#1138 receipt matrix and the #1383 openwiki generator)
- **Branch**: feat/1132-machine-contract-honesty-sweep
- **Related**: #1139 (exit-code sweep), #1105 (verdict.v1 — closed, backlog emitters remain), #1138 (standalone receipts), #1334 (zero-artifact honesty), #1383 (openwiki docs — closed, generator now broken), #1387 (exit-class drift), #1382 (false-green regression tier)

## Problem

The honesty sweep's earlier lanes landed most of the fleet contract, but a
2026-09-17 audit of master `a9329746` (subprocess probes of all 59 top-level
commands, dynamic receipt audits of every standalone generation verb, live
regeneration of the openwiki docs) found four families of residual
lying-success:

1. **Bare/unknown invocation exits 0 (6 commands).** `zfa cli`, `zfa
   benchmark`, `zfa bone`, `zfa config`, `zfa migrate` and `zfa plugin`
   print their usage block on a bare or unknown-subcommand invocation and
   return without setting `exitCode` — the process exits 0 for an invocation
   that could not run. `zfa migrate <unknown-target>` and `zfa bone
   <unknown-subcommand>` do the same. This is the exact "usage printed,
   exit 0" pattern the #856/#1239 sweeps eliminated for the rest of the
   fleet (SPEC 917: usage errors exit canonical `2`; the task text's legacy
   `64` is retired and maps onto `2` via `ExitProtocol.canonicalize`).
   `zfa config` additionally uses hard `exit()` calls — embedded-dispatch
   unsafe — and files usage-class refusals under exit class `1`.

2. **Three `--json` emitters still diverge from `zuraffa.verdict.v1`.** The
   #1105 unification named a follow-up backlog in
   `test/core/verdict_envelope_emitter_scan_test.dart`'s allow-list; three
   of its verdict-shaped entries reproduce on master today: the generic
   capability path's machine-mode pre-flight error
   (`{"schema":1,"ok":false,...}`), `zfa provider verify <Entity> --json`
   (`{"schema":1,"ok":...}` `ProviderVerifyReport` dump) and `zfa benchmark
   list/compare --json` (raw `{"scenarios":[...]}` with no schema at all).
   An agent parsing `--json` output with the canonical
   `VerdictEnvelope.fromJson` throws `VerdictSchemaException` on all three.

3. **Two standalone generation paths ship no `proof.v1` receipt.** `zfa app
   shell` writes `lib/main.dart` (+ router/app shell files) with exit 0 and
   no receipt; `zfa skin kit` writes
   `lib/src/skin/skin_contract_auditor.dart` with exit 0 and no receipt.
   Every other generation verb audited (entity, usecase, view, controller,
   presenter, datasource, repository, service, mock, api, state, route, gym,
   graphql, cache, sqlite, provider, cli, skin list/form, di, sync,
   feature, make) either leaves a receipt on success or refuses honestly
   (non-zero, no receipt).

4. **The openwiki docs generator can no longer regenerate.** Since #1383,
   command descriptions grew past the 120-column `kUsageLineLength`, so
   `zfa --help` wraps descriptions onto continuation lines;
   `tool/generate_openwiki_cli_docs.dart`'s line-anchored regex stops at the
   first wrapped description and the tool now "generates" a 12-command doc
   (silently clobbering the committed 59-command file). The docs cannot be
   refreshed after any command-surface change — drift is locked in.

## Goal

Close the epic's four sub-issue lanes against the CURRENT master contract
(SPEC 917 exit codes, `zuraffa.verdict.v1` envelopes, `proof.v1` receipts,
regenerable openwiki docs), leaving zero lying-success paths in the fleet:
a machine reader can trust every exit code, parse every `--json` envelope
with one parser, and re-derive every generated artifact's provenance.

## Functional Requirements

- **FR-1 (exit-code sweep)**: A bare invocation of `cli`, `benchmark`,
  `bone`, `config`, `migrate` or `plugin` (no subcommand/args) prints the
  usage block and exits `ExitProtocol.usage` (`2`); explicit `--help`/`-h`
  keeps exiting `0` (help is a successful outcome). An unknown subcommand of
  `bone`, `config`, `migrate` or `plugin` exits `2` with the `--> fix:`
  line. `config`'s usage-class refusals (unknown subcommand, `set` with
  missing key/value) exit `2` (was `1`), and no `config`/`plugin` error path
  may call hard `exit()` — the process returns via `exitCode` so embedded
  (MCP/in-process) dispatch survives.
- **FR-2 (verdict envelope)**: `zfa provider verify <Entity> --json`, `zfa
  benchmark list --json`, `zfa benchmark baseline compare <id> --json` and
  the generic capability path's machine-mode missing-arguments refusal emit
  the canonical `zuraffa.verdict.v1` envelope as their machine output
  (`VerdictEnvelope.fromJson` parses them; verdict/exit_class/subject carry
  the real outcome), and the three files leave the emitter-scan allow-list.
- **FR-3 (receipts)**: `zfa app shell` and `zfa skin kit` write a `proof.v1`
  receipt (full `{plugin, capability, entity, hash, files,
  receipt_version: 1}` provenance contract) into `.zfa/receipts/` before
  reporting success — only when artifacts were actually written (a
  nothing-changed skip ships no receipt, matching the #769/#1334 semantics).
- **FR-4 (openwiki docs)**: `tool/generate_openwiki_cli_docs.dart` parses
  wrapped multi-line command descriptions (all 59 commands from live
  `--help`), and `docs/openwiki/cli.md` is regenerated from the live
  dispatcher so every top-level command has an entry with its usage,
  options and exit-code contract; a regression guard pins
  docs-vs-live-dispatcher consistency.

## Success criteria (measurable)

- **SC-1**: A subprocess sweep over all 59 top-level commands finds ZERO
  commands that print a usage block (or an error) on a bare/unknown
  invocation and exit 0. The six named commands exit 2 (their `--help`
  exits 0).
- **SC-2**: `VerdictEnvelope.fromJson` parses the machine output of the
  four FR-2 surfaces; `dart test test/core/verdict_envelope_emitter_scan_test.dart`
  passes with `capability_command.dart`, `provider_verify_command.dart` and
  `benchmark_command.dart` removed from `kExcluded`.
- **SC-3**: After `zfa app shell` / `zfa skin kit` succeed in a fixture
  project, `.zfa/receipts/` contains receipts whose `files` cover the
  written artifacts and whose digests match the disk bytes; `zfa proof
  check` (with coverage roots) passes with zero findings for those paths.
- **SC-4**: Regenerating the openwiki docs emits all commands the live
  `zfa --help` lists (count > 12; the parser handles continuation lines),
  `git diff` after regeneration shows only real command-surface drift, and
  the drift guard test stays green.
- **SC-5** (exit criteria of the epic): `dart test --preset=regression
  test/regression/` passes with zero exit-0-on-error findings (the plain
  `flutter test test/regression/` invocation is the documented #1382
  false-green — slow-tagged files are excluded — and is reported as such,
  not trusted); the receipts machinery demo on a zik_zak-style fixture shows
  `zfa proof check` certifying every generation path; `docs/openwiki/cli.md`
  documents every plugin with envelopes and exit codes.

## Hard constraints

- Do NOT change plugin generation output semantics (bytes of generated
  artifacts stay byte-identical for the same inputs).
- Exit codes follow SPEC 917 only: usage errors exit `2`; the legacy `64`
  is never emitted (`ExitProtocol.usage` everywhere; task text updated to
  the ratified protocol).
- Lane 2 must not break in-process consumers of the migrated reports (the
  Dart objects keep their shape; only the `--json` stdout encoding becomes
  the canonical envelope).
- Receipts are best-effort on the success path only (the #996 contract): a
  receipt failure never flips a green verb red, and a refused/declined run
  (nothing changed) writes NO receipt.
- All changes pass `dart analyze` (no new findings), `dart format lib test`
  (zero drift), and the fast unit tier (`dart test`).

## Out of scope

- The remaining emitter-scan backlog data documents (manifest dump, route
  drift table, doctor report) and ratified bespoke schemas (proof.v1,
  proof-chain.v1, spec-1129 self-cert): those are data documents or
  separately-ratified verdict schemas, not the divergent verdict shapes
  this epic's lane 2 migrates.
- Changing `dart_test.yaml` tag semantics (the #1382 false-green is
  documented, not redesigned here).
- `zfa module create`'s mid-flight failure (pre-existing, honest exit 1 —
  filed separately, not an honesty-sweep finding).
