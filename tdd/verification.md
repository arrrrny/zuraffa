# Verification — 1693-mock-cert-format-canonical-digest

- **Date**: 2026-09-18 (this session, from the actual runs below — no
  content copied from an earlier spec's file); **follow-up round** added
  the same day on top of `76a00027` for the PR #1700 review findings
  (§7)
- **Branch**: `fix/1693-mock-cert-format-canonical-digest` (working tree,
  pre-push; base `a9329746`)
- **Toolchain**: Dart 3.13.4 (stable) on linux_x64 (the task's "Dart
  3.13+" floor; the repo pins `sdk: ^3.11.0`)
- **Scope audited**: `spec.md` (SC-1..SC-5), `plan.md`,
  `tdd/test-list.md`, the changed code
  (`lib/src/plugins/mock/certification/cert_registry.dart`,
  `mock_cert_receipt.dart`, `mock_certifier.dart`, and the new
  `format_canonical_digest.dart`), the new test files, and the
  `mutation-test-1693.xml` audit config.
- **Verify path**: `/speckit.tdd.verify` Step 0 detected `ZFA_MISSING`
  (this repo is the zuraffa framework itself — no `.zfa.json` consumer
  wiring), so the command's documented FALLBACK PATH ran: the LLM-guided
  audit with real in-session red/green/mutation evidence. `zfa tdd
  verify`'s mutation phase was covered equivalently by the repo's own
  `mutation_test` tool driven through a spec-scoped config
  (`mutation-test-1693.xml`) — the same tool `zfa tdd verify` dispatches.

## Verdict: PASS

| id | criterion | verdict | evidence |
|----|-----------|---------|----------|
| SC-1 | format-only drift after certification → `certified`, no second certification | PASS | G1 (red→green) + W1; the pre-fix tree refused both (behavioral red captured) |
| SC-2 | a real entity edit after certification still refuses as `stale` | PASS | G2 + W2 (blocked entity, stale reason, exact fix command); G5 additionally proves the digest overrides a lying-fresh mtime |
| SC-3 | pre-1693 receipts keep the mtime freshness semantics | PASS | G4/G4b (both directions) + the untouched spec-1110 suite `cert_registry_test.dart` 9/9 |
| SC-4 | the certifier records the format-canonical digest for both entry points; JSON omits the field when absent | PASS | G6/G6b/G7/G8/G8b — both CLI entry points (`mock create --certify`, `mock certify`) flow through the single changed `certify()` choke point; legacy receipts stay byte-stable, and the digest's canonicalizer identity is recorded beside it (review finding 2) |
| SC-5 | existing suites stay green; analyze clean; format clean | PASS | guard suites below; `dart analyze` on all 7 touched files: `No issues found!`; `dart format --set-exit-if-changed .` exit 0 |

## 1. Red → green (this session, base a9329746)

- **Red (behavioral, the issue's bug)** — the gate test file was written
  to compile against the PRE-FIX tree (receipt JSON hand-written with
  `entity_digest`; the pre-fix loader ignores the unknown key):
  `dart test test/plugins/mock/certification/spec_1693_gate_format_drift_test.dart`
  → `00:00 +4 -2: Some tests failed.`
  G1 failed with format-only drift read as `stale` (the #1693
  repro at the gate decision point); G5 failed with a lying-fresh mtime
  accepted. The four guards (G2/G3/G4/G4b) passed, so the red set is
  exactly the two claims the fix changes.
- **Red (new seam)** — `dart test
  test/plugins/mock/certification/spec_1693_receipt_and_certifier_test.dart`
  → load error: `The getter 'entityDigest' isn't defined for the type
  'MockCertReceipt'` (+ unresolved `format_canonical_digest.dart`) — the
  honest first red for a new seam.
- **Green** — after the fix: the two spec files → `00:00 +11: All tests
  passed!`; the run-preflight pins → `00:00 +2: All tests passed!`.

## 2. Semantic-drift case re-run explicitly (spec §4 step 5)

G2 (unit) and W2 (`tdd run` preflight wiring): a real entity edit after
certification refuses with `CertRegistryStatus.stale`, reason prefix
`mock-cert.UserSession.json is stale:`, fix
`zfa mock create UserSession --certify`. G5 adds the strongest form: a
receipt re-touched AFTER a real edit (mtime says fresh, digest says
stale) still refuses. All three ran green in this session.

## 3. Mutation audit (the `tdd verify` mutation phase, equivalent path)

`dart run mutation_test mutation-test-1693.xml -f md -o
mutation-test-1693-report` — scoped by line whitelist to the spec-1693
freshness block of `cert_registry.dart` and the digest seam
`format_canonical_digest.dart`; test command
`bash tools/run-1693-mutation-tests.sh` (the three gate suites, `-j 1`,
kernel-cache hygiene per the repo convention).

Original round (whitelist `cert_registry.dart` 193–242,
`format_canonical_digest.dart` 38–58):

```
Total tests: 16
Undetected Mutations: 0 (0.00%)
Timeouts: 0
Not covered by tests: 0
Success: true
```

First pass: `FAILED: 2/16 (12.50%) mutations were not detected!` — both
survivors were character-level mutations of the stale-reason string
literal (`mock-cert` → `mock+cert`), which no test pinned. G2/G4 were
strengthened to assert the reason prefix
(`startsWith('mock-cert.Login.json is stale:')`) — a legitimate contract
pin (the refusal receipt and `zfa tdd status` render this string
verbatim) — and the audit re-ran clean.

Follow-up round: the whitelist moved to the new line ranges —
`cert_registry.dart` 216–257 (the `digestTrusted` condition through the
mtime fallback) and `format_canonical_digest.dart` 84–105 (both helper
functions):

```
Total tests: 19
Undetected Mutations: 0 (0.00%)
Timeouts: 0
Not covered by tests: 0
Elapsed: 0:05:21.643705
Success: true
```

The new mutants of the identity check (`&&` → `||`, `==` → `!=` on
`entityDigestStyle`, and the whole `digestTrusted` condition) are killed
by G1/G5 on one side and G10 on the other. `canonicalizerId` is
deliberately OUTSIDE the whitelist: both sides read it from the same
source, so a character mutant of it is unobservable through the gate's
own behavior (a receipt is always recorded with whatever the running
build computes) — the honest scope is the consumer of the value, not the
value itself.

## 4. Gates

- `dart analyze` on the 3 changed lib files, the new helper, and the 3
  new test files → `No issues found!`
- `dart format .` → re-check `--set-exit-if-changed` exit 0 (zero
  remaining diffs across 2947 files).
- Mapped-scope test run (fresh kernel-cache cleanup per §5):
  `dart test test/plugins/mock/certification/
  test/plugins/mock/cert_registry_test.dart
  test/plugins/tdd/commands/spec_1693_run_gate_format_drift_test.dart
  test/engine/mock_certifier_test.dart` → `00:14 +55: All tests passed!`
- Adjacent sweep: `run_engine_command_test.dart` + `test/engine/` +
  `test/plugins/slice/` → `00:19 +217: All tests passed!`

## 5. Pre-existing failures flagged (not introduced, not fixed here)

`test/integration/mock_certification_e2e_test.dart` (tagged `slow`,
excluded from the default lane) — 2 of 3 tests fail in THIS environment
with the sandbox unable to resolve `package:zuraffa/zuraffa.dart` /
`package:zuraffa/mock.dart` inside the throwaway sandbox project.
Verified pre-existing by `git stash -u` → re-run on base `a9329746` →
the same `[E]` at the same assertion. The failure is environmental
(sandbox framework-root resolution against this machine's pub layout),
not related to the digest change; it was NOT "fixed" to keep the PR
minimal and honest.

## 6. Constraints audit

1. **Format-only drift is not staleness** — G1/W1 (and the digest-first
   branch replaced the mtime read for receipts that carry
   `entity_digest`).
2. **Real entity source changes still detected** — G2/G3/G5/W2; the
   mutation audit killed all 16 mutants in the changed logic, including
   the "ignore digest mismatch" and "digest raw bytes" classes.
3. **No second certification per entity** — the gate returns
   `certified` on format-only drift; nothing in the fix path re-runs the
   sandbox.
4. **Works under Flutter sandbox certification** — the digest is
   computed in-process by the driving zfa (`dart_style`, a direct
   dependency); no toolchain subprocess was added to cert or gate, so
   the Flutter-host path (spec 1600's `flutterTest` sandbox) is
   untouched and the recorded digest is toolchain-independent.

## 7. Follow-up round — PR #1700 review findings (base 76a00027)

The review accepted the direction and flagged four boundaries of the new
basis. All four were verified against the head code before fixing; none
was stale. One behavior per finding, each proved red against the pre-fix
tree of this round before the fix landed.

| # | finding | fix | test | red evidence |
| - | ------- | --- | ---- | ------------ |
| 1 | 🟠 the recording side (`entityFileRel`) and the comparing side (`_locateEntityFile`) resolved the entity differently, so the format-canonical basis was silently skipped outside the canonical layout | `CertRegistry._locateEntityFile` → public `locateEntityFile`, now also used by `MockCertifier.certify`; `formatCanonicalDigestOfFile` takes a nullable `File?` so the call site stays one expression | G9, G12b | with the certifier back on `entityFileRel`: `Expected: 'b65aa851…'  Actual: <null>` |
| 2 | 🟡 the recorded digest was byte-coupled to the resolved `dart_style`, so one `dart pub upgrade` that changes formatter output would turn every receipt in the project `stale` at once | `MockCertReceipt.entityDigestStyle` (JSON `entity_digest_style`) records `canonicalizerId`; the gate trusts the digest only when the recorded id matches, else it takes the pre-1693 mtime leg | G10, G6/G7/G8 | with the old condition (`recordedDigest != null && isNotEmpty`): `Expected: <stale>  Actual: <certified>` |
| 3 | 🟡 only `FormatterException` was normalized to `null`; any other `dart_style` failure escaped the gate as a crash | the helper's catch is total — `catch (_)`, the file's own defensive convention | G12 | with `on FormatterException`: `Expected: return normally  Actual: threw _TypeError:<Null check operator used on a null value>` |
| 4 | 🔵 `G6b` was asserted by the suite but had no row in `tdd/test-list.md`, and was missing from the SC-4 row here | the row is added above, and this SC-4 row now names `G6b` | — | bookkeeping |

Notes on the chosen identity for finding 2: the review suggested the
resolved `dart_style` version / `DartFormatter.latestLanguageVersion`.
The language version alone does **not** identify the engine — 3.1.10
pinned `latestLanguageVersion` at 3.13.0 and 3.1.11–3.1.13 changed the
emitted bytes anyway (3.1.13's enum trailing comma is explicitly "not
language versioned"), so `canonicalizerId` carries
`DartFormatter.latestLanguageVersion` **plus** a fingerprint of the
running formatter's output on a fixed probe. Two builds produce the same
id iff their bytes match.

Consequence worth stating plainly: the mtime fallback is the requested
semantics, so after a formatter bump a *reformatted* entity still reads
`stale` and re-certifies once. What the identity removes is the
project-wide simultaneous flip from a bare dependency bump — the mass
re-certification the finding is about. G10 pins both halves.

### Gates (this round)

- `dart analyze` on `lib/src/plugins/mock/certification` +
  `test/plugins/mock/certification` → `No issues found!`
- both spec suites → `00:07 +15: All tests passed!`
- mapped scope (`test/plugins/mock/certification/`,
  `test/plugins/mock/cert_registry_test.dart`, the two
  `spec_1693_run_gate_format_drift_test.dart` wiring pins,
  `test/engine/mock_certifier_test.dart`) →
  `00:20 +59: All tests passed!`
- adjacent sweep (`run_engine_command_test.dart` + `test/engine/`) →
  `00:31 +57: All tests passed!`; `test/plugins/slice/` →
  `01:03 +120: All tests passed!`
- `dart format --set-exit-if-changed lib test` → `0 changed`, exit 0
- mutation audit on the moved whitelist → `Total tests: 19`,
  `Undetected Mutations: 0 (0.00%)`, `Success: true` (§3)

One wiring pin (`W1`) needed a change that is a consequence of finding 2,
not a fix workaround: it hand-wrote a receipt carrying `entity_digest`
with no `entity_digest_style`, which the gate now correctly reads through
the mtime leg. It writes the identity the certifier records
(`canonicalizerId`), so the pin tests the #1693 fix rather than the
fallback.
