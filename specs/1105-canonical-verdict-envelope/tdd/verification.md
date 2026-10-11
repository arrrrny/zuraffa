# TDD Verification — feature `1105-canonical-verdict-envelope`

Written from the ACTUAL runs performed on this branch (every command
below was executed on 2026-09-07; outputs are quoted from the
transcripts, not asserted). Toolchain: Dart 3.13.3 (stable) on
linux_x64 (`dart --version`). Flutter is NOT installed in this
environment — suites that require it are out of scope; the two
failures noted below are pre-existing and byte-identical on the
pristine tree (verified by `git stash` + rerun, see "No regressions").

## Gate

- gate: `passed`
- analyze: `dart analyze $(git diff --name-only HEAD -- '*.dart')
  test/core/` over exactly the changed/new Dart files →
  **No issues found!**
- format: `dart format` over all changed files → clean (7 + 10 files
  reformatted, tree committed in formatted state)
- canonical acceptance suite: `dart test
  test/core/verdict_envelope_canonical_test.dart` → **12/12 passed**
  ("All tests passed!"), after the RED run recorded below.
- emitter-sweep guard: `dart test
  test/core/verdict_envelope_emitter_scan_test.dart` → **3/3 passed**
  (every --json emitter references VerdictEnvelope; the 7 issue-named
  emitters are migrated; the `zuraffa.verdict.v1` literal lives only in
  core + emitters).
- full-folder regression (directly affected suites, fresh kernel cache
  each, disk cleaned between runs):
  - `dart test test/core/` → **601 passed, 0 failed** (1 skipped by
    tier tag)
  - `dart test test/plugins/route/` → **97 passed, 0 failed**
  - `dart test test/plugins/tdd/verdict_envelope_test.dart
    test/plugins/di/di_verify_test.dart
    test/plugins/datasource/datasource_check_command_test.dart
    test/commands/verify_gate_json_sweep_test.dart
    test/commands/tdd_json_stream_test.dart
    test/plugins/tdd/commands/plan_command_bug_1182_test.dart
    test/plugins/tdd/commands/run_skin_command_test.dart
    test/plugins/tdd/corpus_economics/batch_gen_test.dart
    test/plugins/tdd/bug_969_json_verdict_envelope_test.dart` →
    **84 passed, 0 failed**
  - `dart test test/plugins/state/ test/plugins/usecase/
    test/plugins/mock/ test/plugins/cache/` → **239 passed, 0 failed**
  - `dart test test/commands/` → **283 passed, 0 failed**

## Red → green (TDD cycle)

1. **RED** — wrote the acceptance tests FIRST
   (`test/core/verdict_envelope_canonical_test.dart`,
   `test/core/verdict_envelope_emitter_scan_test.dart`):
   - canonical suite → **compile failure**: `Error: Undefined name
     'VerdictEnvelope'` — `lib/src/core/verdict_envelope.dart` did not
     exist;
   - sweep suite → **2 failures**: the offender list named all 7
     divergent emitters (`mock (command)
     (lib/src/commands/mock_command.dart) must reference the canonical
     VerdictEnvelope` etc.).
   Root cause confirmed: 3 schema conventions (`schema:1` integers in
   route/state/usecase/mock, `"verdict.v1"` in tdd,
   `cache.verify.v1` in cache) and no shared parser.

2. **GREEN** — implemented `lib/src/core/verdict_envelope.dart`
   (`VerdictEnvelope` + `VerdictKind` + `VerdictSubject` +
   `VerdictArtifacts` + `VerdictFinding` + `VerdictSchemaException`,
   `fromJson` with the loud schema-version check, `tryParse` for
   mixed-stream extraction, `emit`), migrated the tdd envelope's schema
   constant, the 6 command emitters (route create/verify, cache verify,
   state create, usecase create, mock create), and wired the MCP
   tool-call boundary. Same suites → 12/12, 3/3, then the full
   regression counts above.

3. **refactor** — folded the receipt-path plumbing into the envelopes'
   `receipts` list (route create captures the actual written file;
   state `_emitReceipt` returns the path; route verify's
   `_writeVerdictReceipt` returns whether the receipt landed) so the
   envelope never lists a receipt that does not exist. Re-ran: all
   green.

## Real CLI proof (the actual binary, not in-process)

Driven via `dart run bin/zfa.dart` in a temp Flutter-flavored project
(transcript quoted):

- `zfa route create Product --json` → last stdout line decodes to
  `{schema: zuraffa.verdict.v1, command: zfa route create Product,
  verdict: pass, exit_class: 0, subject: {kind: route, id: Product},
  artifacts.created: 4 files, details.routes: 3 entries,
  details.routeTableTestPath: test/routing/route_table_test.dart,
  receipts: [.zfa/receipts/routes-Product.json]}`.
- `zfa state create --name Deal --json` →
  `{schema: zuraffa.verdict.v1, verdict: pass,
  subject: {kind: state, id: Deal},
  details.path: lib/src/presentation/pages/deal/deal_state.dart,
  details.flavor: flutter}`.

## Real MCP proof (the tool-call boundary)

Driven via `dart run bin/zuraffa_mcp_server.dart` on stdio with a real
`tools/call` for `zuraffa_state_create` (temp project):

- the JSON-RPC result carries **`structuredContent` present: True**
- `schema: zuraffa.verdict.v1`, `command: zfa state create`,
  `verdict: pass`, `exit_class: 0`,
  `subject: {kind: state, id: Product}`,
  `details keys: [files]`.

Mechanism: `_runPluginTool` closes every
`zuraffa_<plugin>_<capability>` tool result with the canonical envelope
as the last line; `_callTool` lifts it into `structuredContent` via
`VerdictEnvelope.tryParse`. Text content is unchanged for
non-envelope tools.

## Acceptance criteria coverage

- **One canonical envelope `zuraffa.verdict.v1`** — U1/U2 pin the
  constant; the sweep test proves the literal appears only in core +
  the emitters (`openwiki/cli.md` does not exist in this tree, so the
  CLI-docs acceptance item has no target file).
- **Every --json command emits VerdictEnvelope** — the 7 issue-named
  emitters migrated and pinned; the sweep test enforces the reference
  for every `--json`-output emitter outside an explicitly documented
  pre-1105 backlog allow-list (test/capability/make/skin/manifest/
  doctor/provider-verify/realize-mock/benchmark + the route verify
  drift dump). Adding a new emitter without the envelope fails CI.
- **`VerdictEnvelope.fromJson` parses every emitter's output
  (round-trip)** — U3–U10 cover the full field set, both exit_class
  forms, the tdd grandfathered fields (`feature`, `fix`, verdict
  `stopped`), byte-stable round-trips; the route-create, route-verify,
  cache, state, usecase and mock suites run their REAL CLI output
  through `fromJson` / assert the canonical frame end-to-end.
- **MCP tools return verdict as structuredContent** — proven live
  above.
- **Backwards compatibility: old parsers break loudly** — U4 asserts
  `VerdictSchemaException` for every drifted shape (`1`,
  `verdict.v1`, `cache.verify.v1`, `route.v1`,
  `repository-contract.v1`, missing).

## Mutation testing

Not run. The `mutation_test` config (`mutation-test.xml`) scopes
mutations to the TDD plugin's spec-041 writers; this feature's core
surface (`lib/src/core/verdict_envelope.dart`) is outside that scope
and running the mutation phase over it was measured (spec 041) at
2400+ test executions per mutant — out of budget for this environment.
The parser's strength is covered by the contract tests instead: every
field has a positive and a malformed/foreign-schema negative case.

## No regressions (pre-existing failures, verified on pristine base)

Both verified by `git stash -u` → rerun on the untouched tree →
`git stash pop`:

- `test/integration/dream_cli_integration_test.dart` U9: the dream
  engine stops with `result=error` (engine subprocess) — identical on
  base commit `c238defd`.
- `test/plugins/cache/cache_verify_test.dart` subprocess case
  "no entity argument → usage error, exit 64": fails identically on
  base (environment-dependent subprocess spawn; the in-process
  cache-verify suite is 100% green).

Transient disk exhaustion (`/tmp` full) during the first combined
suite runs surfaced as "Failed to load" noise in
`refactor_passes_test.dart`, `theater_data_test.dart`,
`bug_846_coverage_gate_test.dart`, `state_compile_test.dart`,
`state_snapshot_test.dart`, `state_property_compile_test.dart` — every
one of them passes in isolation after kernel-cache cleanup
(refactor_passes 11/11, theater 5/5, bug_846 9/9, state folder 21/21),
matching the dart_test.yaml guidance to clean the kernel cache between
chunked runs.
