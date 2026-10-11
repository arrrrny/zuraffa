# TDD Verification — SPEC 1127 (service: --json, verify, receipts, error handling, --explain)

Issue: [#1127](https://github.com/arrrrny/zuraffa/issues/1127) · Branch:
`spec/1127-service-json-verify-receipts` · Dart SDK 3.13.3 (stable)

This document records the REAL red→green evidence, the test-smell audit and
the acceptance-criteria coverage. Nothing below is claimed without a logged
command run in this working clone.

## 1. Subjects changed

| File | Change |
|---|---|
| `lib/src/core/verdict_envelope.dart` | ADOPTED AS-IS from master — the canonical `zuraffa.verdict.v1` envelope (SPEC 1105) landed on master while this branch was in flight; the branch rebased onto it and drops its own duplicate |
| `lib/src/plugins/service/service_receipt.dart` | NEW — `ServiceReceiptWriter`: deterministic `service-<Entity>.json` proof.v1 receipt (provider-<Entity>.json precedent), `load()` |
| `lib/src/plugins/service/conformance/service_conformance_checker.dart` | NEW — AST grammar-conformance gate; the expected surface is re-derived by driving the SAME `ServiceInterfaceBuilder` generation drives (gate cannot drift from grammar) |
| `lib/src/plugins/service/capabilities/create_service_capability.dart` | try/catch around the entire `execute()` path (di pattern, spec 0974 order 4); stable receipt written on real runs; `projectRoot` injection |
| `lib/src/commands/service_create_command.dart` | NEW — first-party `zfa service create`: `--json` FLAG → canonical envelope (last stdout line, `explain` block per issue #1122), `--explain`, dry-run via `plan()`, name validation (structured usage refusals) |
| `lib/src/commands/service_verify_command.dart` | NEW — `zfa service verify <Entity>`: receipt-then-flags knob resolution, file resolution (receipt → conventional paths), exit 1 on grammar mismatch, `--json` envelope |
| `lib/src/commands/service_command.dart` | `manualSubcommandNames = {'create','verify'}` + manual registration (issue #761-safe) |
| `test/commands/cli_runner_cwd_race_test.dart` | vehicle migrated to the live grammar (`--name` + bare `--json`); assertions read `verdict == 'pass'` |
| `test/plugins/service/service_schema_grammar_parity_test.dart` | `nonKnobs` += `explain` (output flag, not a generation knob — same class as `json`) |

Not changed: the schema-grammar sync behavior (constraint honored —
`configSchema`, `inputSchema` knobs and the builder are untouched; the gate
consumes them, it does not redefine them).

## 2. RED evidence (before implementation)

Captured in the working clone at `/tmp/zfa-red/ws` and via a direct
capability probe. Commands actually run:

1. **No canonical `--json`** (order 1) —
   `zfa service create SendEmail --params EmailParams --returns SendResult --json`
   → `❌ Missing argument for "--json".` (`--json` was the machine-INPUT
   option; the output envelope did not exist).
2. **No verify gate** (order 2) —
   `zfa service verify SendEmail`
   → `❌ Could not find a subcommand named "verify" for "zfa service".`
3. **No stable receipt** (order 3) — after `zfa service create SendEmail ...`
   only the #996 timestamped wrapper document
   (`service-create-SendEmail-<stamp>.json`) existed; the
   acceptance-required `.zfa/receipts/service-SendEmail.json` did not.
4. **Uncaught exception on malformed entity** (order 4) — direct
   `CreateServiceCapability().execute({'name': 12345})` probe →
   `UNCAUGHT EXCEPTION TYPE: _TypeError — type 'int' is not a subtype of
   type 'String'` (propagates out of `execute()` uncaught).
5. **No `--explain`** (order 5) — `zfa service create --explain` →
   `Could not find an option named "--explain".`

New/updated suites written first (they fail to compile/parse RED against the
pre-fix tree): `verdict_envelope_test.dart`,
`service_create_json_verdict_test.dart` (rewritten to the canonical
contract), `service_verify_command_test.dart`, `service_receipt_test.dart`,
`service_error_handling_test.dart`, `service_explain_test.dart`.

## 3. GREEN evidence (after implementation)

Final state, run in this clone (Dart 3.13.3):

```
dart test test/plugins/service/ test/core/verdict_envelope_test.dart
→ 00:16 +57: All tests passed!
```

Suite breakdown of the 57 (all GREEN):

| Suite | Tests | Covers |
|---|---|---|
| `verdict_envelope_test.dart` | 7 | schema constant, `fromJson`, loud throw on unknown schema (`1` / `verdict.v1`), full round-trip, uniform key set, verdict vocabulary, minimal document defaults |
| `service_create_json_verdict_test.dart` | 6 | canonical envelope (pass/fail/skip), exit classes 0/1/2, artifacts + receipts lists, details (serviceClass/methods/type/conformance), prose mode unchanged |
| `service_verify_command_test.dart` | 9 | fresh-conform exit 0, hand-edit → `missing_method` exit 1, return-type drift → `signature_mismatch`, missing file finding, `--json` pass/fail envelopes, usage exit 2, knob overrides, malformed-entity no-crash |
| `service_receipt_test.dart` | 5 | proof.v1 shape + digests + ledger extras, latest-wins refresh on `--force`, dry-run writes nothing, skipped run does not lie, `load()` |
| `service_error_handling_test.dart` | 2 | `execute({'name': 12345})` → `success:false` (no throw); CLI malformed name → structured verdict, no `Unhandled exception`/`TypeError` |
| `service_explain_test.dart` | 3 | shape/knobs/methods described without generating, provider binding resolved from provider receipt/file, `--explain --json` → `verdict: skip` envelope |
| pre-existing service suites (parity, triad, compile, engine, builder, method append, skip verdict, plugin) | 25 | unchanged behavior — including the #978 schema ≡ grammar treaty (updated only by classifying `--explain` as a non-knob output flag) |

### Full fast-tier regression sweep (chunked, `--exclude-tags flutter`)

Every fast-tier chunk of the default suite was run individually (kernel
cache cleared between batches per the spec's disk housekeeping). Result:
**0 failures across ~4,000 fast-tier tests.** Selected counts: commands 283,
agent 233, graphql 192, simulation 192, slice 142, xray 133, cli 200,
tdd/commands 299, mock 147, templates 44, regression 19, property 9.

Two environmental notes (neither caused by this branch, neither hidden):

* `flutter`-tagged suites need the Flutter SDK (absent in this environment);
  `dart_test.yaml`'s default tier already excludes them by design. Verified
  by `test/plugins/controller` passing 5/5 with `--exclude-tags flutter`.
* `test/plugins/mcp/mcp_server_plugin_test.dart` hangs past 70s in this
  sandbox; reproduced identically on a stashed clean master, and every
  sibling mcp file passes individually. Pre-existing, out of scope.

### Analyze + format

```
dart analyze <every changed/new .dart file>   → No issues found!
dart format .                                  → Formatted 2456 files (0 changed)
rm -rf .dart_tool/test/ && rm -f $TMPDIR/dart_test.kernel.* → done
```

## 4. Acceptance criteria — PROVED live (installed grammar, fresh workspace)

| Criterion | Live evidence |
|---|---|
| `zfa service create <Entity> --json` emits the envelope | `{"schema":"zuraffa.verdict.v1","command":"zfa service create","verdict":"pass","exit_class":0,"subject":{"kind":"service","id":"SendEmailService"},"artifacts":{"created":["lib/src/domain/services/send_email_service.dart"],...},"receipts":[".../service-SendEmail.json"],"details":{"serviceClass":"SendEmailService","provider":null,"methods":["sendEmail"],"type":"usecase","conformance":{"ok":true,"expectedSignatures":["Future<SendResult> sendEmail(EmailParams params)"]}}}` |
| `zfa service verify <Entity>` reports grammar conformance | `✅ verified: the service grammar matches the schema (conformance proven).` exit 0; after hand-editing the file: `[missing_method]` + `--> fix:` + exit 1 |
| `.zfa/receipts/service-<entity>.json` exists after create | `ls` shows `/tmp/zfa-accept/.zfa/receipts/service-SendEmail.json` (proof.v1, `interface: SendEmailService`, sha256 digests) |
| A malformed entity does not crash with uncaught exception | `zfa service create 'Bad Entity!!' --json` → `verdict:"fail"`, `exit_class:2`, structured error detail + `--> fix:` (exit 2); capability-level `execute({'name': 12345})` → `ExecutionResult(success:false, message: 'service create failed for 12345: ...')` |

## 5. Test-smell audit

* **No assertion-free tests** — every test asserts observable output
  (stdout JSON, exit codes, on-disk bytes, receipt digests).
* **No test-after-only** — the five order areas each have a RED artifact
  recorded above before their implementation landed.
* **No sleep/flake hacks** — the only timing-sensitive suite touched
  (`cli_runner_cwd_race_test`) keeps its original deterministic
  window-probe design; only the invocation vehicle moved to the live
  grammar.
* **No contract lies** — the skip verdict (declined generation) exits 1 and
  carries its remediation as a finding; a dry run writes no receipt; a
  skipped regeneration does not rewrite the ledger.
* **Mirror-drift risk retired** — method names reported in envelopes come
  from the conformance checker, which reads the builder's own output; the
  capability's legacy inner verdict keeps its documented single-object
  shape for direct (MCP) callers only.

## 6. Constraint compliance

* **Canonical envelope (issue #1105)** — the service emitters emit the ONE
  canonical `zuraffa.verdict.v1` envelope. SPEC 1105's core envelope type
  landed on master mid-flight (via the #1131 sweep); this branch rebased
  onto it, dropped its own duplicate file, and emits master's
  `VerdictEnvelope` (`VerdictKind` pass/fail/skip/error, `VerdictSubject`,
  top-level `fix`, the additive `explain` block, parser throwing
  `VerdictSchemaException` on unknown schema). The remaining legacy
  emitter migrations (tdd/state/usecase/route/cache/mock) stay that
  spec's work.
* **Schema-grammar sync unchanged** — knobs, enums, defaults and the
  builder are byte-identical; the parity treaty suite still passes.

## 7. Mutation-ish spot checks (behavioral probes)

Beyond the hand-edit probes above, the gate was probed with: a renamed
method (`missing_method`), a changed return type
(`Future`→`Stream`, `signature_mismatch`), a knob override at verify time
(`--returns int` against a `void` file → exit 1), and a
regenerate-with-`--force` refresh of the stable receipt (latest-wins,
single document).
