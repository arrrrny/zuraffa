# TDD Verification: Standalone Zero-Artifact Honesty (spec 1334)

**Verified**: 2026-09-09 · **Agent**: verify/epic1-honesty-sweep (cloud) · Dart 3.13.3

## 1. Test-first evidence (red before green)

The behavioral tests were committed and run BEFORE any implementation line existed.

**RED run** (pre-fix, commit state = d23bde35 + tests only):

```
dart test test/regression/issue_1385_1386_zero_artifact_honesty_test.dart
00:00 +1 -3: Some tests failed.
```

Failing (the behaviors that did not exist yet — the misfires themselves):

- `#1385 ... zero-artifact run with a missing-dependency skip exits non-zero`
  Actual: `<0>` — the lying success, reproduced.
- `#1385 ... failure output names the cause and a fix, never a lying success`
  Actual stdout: `⏭ Skipped (use --force to overwrite): test/domain/usecases/general/product_usecase_test.dart` — the misattributed cause, reproduced.
- `#1386 ... zero-file bridge generation with no UseCases exits non-zero`
  Actual: `<0>` — the lying success, reproduced.

Passing pre-fix (intentional — they pin behavior that must NOT change):

- `#1385 ... dry run stays a benign success`
- `#1386 ... dry run stays a benign success`

**GREEN run** (after implementing the capability verdict gates + structured skipReason):

```
dart test test/regression/issue_1385_1386_zero_artifact_honesty_test.dart
00:36 +5: All tests passed!
```

## 2. Test-smell rubric

- **Asserts observable behavior via public surface**: every red test drives the real CLI (`runZfaSource` subprocess) and asserts process exit code + stdout contract — no white-box peeking. PASS.
- **No conditional/weak assertions**: exit codes are exact (`isNot(0)` on the gate tests, `0` on the pins); the `❌` / `--> fix:` / `✅ Success!` assertions are exact substrings. PASS.
- **No test-only production branches**: the gate reads `GeneratedFile.skipReason` — a real domain signal — never a test hook. PASS.
- **Regression safety net**: touched-plugin suites and command/plugin-system suites re-run green (see §4).

## 3. Acceptance-criteria coverage map

| Spec criterion | Evidence | Status |
|---|---|---|
| US1/SC-1 — `test create` missing dependency exits non-zero + `--> fix:` | red→green test B1/B2 | PROVED |
| US1 — no `✅ Success!` on zero-artifact failure | test B2 (`isNot(contains('✅ Success!'))`) | PROVED |
| US1/SC-3 — dry run exempt | test B3 | PROVED |
| US2/SC-2 — `api` no-UseCases exits non-zero + `Failed to generate API bridge` | red→green test B4 | PROVED |
| US2 — dry run exempt | test B5 | PROVED |
| US3 — structured skipReason drives the verdict (not stdout parsing) | implementation: `CreateTestCapability` gates on `skipReason == 'missing-dependency'`; builders emit it; polymorphic path now emits a structured skip instead of contributing nothing | PROVED (by construction + B1–B4) |
| US3 truth table — overwrite-conflict-only zero-artifact run stays benign | structural: the gate fires ONLY on `missing-dependency` skips; pre-1334 null-reason skips keep benign semantics. CLI-level pin not directly constructible for the test verb (no current code path emits an overwrite-conflict skip entry) — pinned instead via the dry-run pins + the gate's narrow predicate. Honest limitation, noted. | PARTIALLY PROVED |
| SC-4 — no regression on existing flows | +91 (test/api plugin suites) + +387 (plugin_system + commands) green; touched-plugin re-runs after fix | PROVED (scoped suites) |
| FR-6 — receipt contract (#769) unchanged | no receipt-layer code touched; wrapper gates on `success`, which now goes false on zero-artifact runs → still no receipt (same as before) | PROVED (by code inspection) |

## 4. Post-fix verification runs

- `dart test test/regression/issue_1385_1386_zero_artifact_honesty_test.dart` → **+5: All tests passed!**
- `dart test test/plugins/test/ test/plugins/api/` → **+91: All tests passed!**
- `dart test test/core/plugin_system/ test/commands/` → **+387: All tests passed!**
- `dart analyze` on all touched files → **No issues found!**
- `dart format .` → tree clean (also formatted 4 pre-existing unformatted tracked fixture/spec files, unrelated to this feature; included per CI format-gate requirement).

## 5. Honest limitations

- The full `--preset=regression` tier (63 files) cannot complete on this 4 GB RAM / 10 GB disk cloud agent within the verify window; it is running chunked in the background (per-file kernel-cache cleanup). Partial results are reported on the epic; the tier's own gate-integrity gap is tracked as misfire #1382.
- The `--json` envelopes of `test create` / `api` still speak their pre-1105 shapes (`{schema: 1}` certification envelope / plain success object); migrating them onto `zuraffa.verdict.v1` belongs to #1105 and is deliberately out of scope here.
