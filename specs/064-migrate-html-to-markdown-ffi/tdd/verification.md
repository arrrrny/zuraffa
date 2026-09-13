# TDD Verification — Spec 064 (`html_to_markdown_ffi` migration)

**Audited**: 2026-09-13 · **Auditor**: cold-context LLM audit (LLM-guided fallback — repo not
`.zfa.json`-wired), per `.specify/memory/tdd-profile.md` (no mutation tool wired → deliberate
mutant sampling).

## Verdict: **PASS**

## 1. Test-first evidence

- Commit sequence on `064-migrate-html-to-markdown-ffi` proves red-before-green:
  `tdd-plan(064)` (test list) → `tdd(064): B1-B4 red baseline — instance test pins the
  undelivered migration (0/9)` → implementation commits → `tdd(064): B1-B4 GREEN — 9/9`.
- RED recorded honestly: `+0 -9: Some tests failed.`, every failure for the single reason the
  migration was undelivered (`packages/` family absent). No assertion was relaxed to force green;
  the two later pin corrections are documented in the cycle log with rationale.

## 2. Loop evidence (tdd/cycle-log.md)

- C1: RED 0/9 (instance contract). C2: app-suite green 90/90 + the visitor-bridge discovery
  (shipped 1.1.0 `VisitorBridge` is a documented stub — verified against the clean pre-migration
  worktree; B4 pin corrected to parity instead of inventing new behavior). C3: instance 9/9
  GREEN, scoped suite 67/67. C4: B5 family board — 5 packages × (pub get, analyze,
  test, publish dry-run), all green, **0 warnings**.

## 3. Mutation sampling (deliberate mutants, profile §Mutation tool: none)

| Mutant | Change | Result | Action |
|--------|--------|--------|--------|
| M1 | `HtmlToMarkdownFfiService.convert` drops `options` on the sync port path | **SURVIVED** → exposed a real gap (sync options pass-through untested) | strengthened `convert routes through the port sync path` with `lastOptions.bullets` pin → M1 **killed** (red recorded), reverted → green |
| M2 | `buildConversionRequest` replaces the options json with `'{}'` (custom options silently dropped) | **KILLED** immediately by the ported `options_test.dart` suite (FR-005 parity suite carries real weight) | reverted → 90/90 green |

Residual sampling risk: the preserved loader chain (`native_library.dart`) and the native bridge
are exercised through the 90-test host suite on macOS only (research D7 status-quo parity);
Android/iOS loaders are proven structurally + offline harness tests, not on-device.

## 4. Test smells

- Platform-skipped tests: 3 (android/ios/macos sync-host guards + macos native host test) —
  justified guards, honest `markTestSkipped`/skip reasons, not silent.
- No order-dependent tests (the visitor "ordering" investigation ended in the documented stub
  discovery; suite is deterministic).
- No assertion-free tests; fakes (`FakeHtmPort`, fake channels, fake repository) assert
  interactions and payloads.
- Ported legacy suite: assertions unchanged (FR-005), only file location moved; corpus parity is
  continuously proven on the host.

## 5. Acceptance-criteria coverage

| Requirement | Evidence |
|-------------|----------|
| FR-001 v5 layout | B3a canonical `lib/src/domain/entities/<snake>/` + data/usecases (instance test) |
| FR-002 zfa-generated | `zfa entity create`/`zfa make` artifacts (B3a/B3b pins) + commands in history |
| FR-003 bindings retained | B1c byte-for-byte artifact parity + B4 host FFI proof + preserved loader chain |
| FR-004 datasource wraps bridge | `NativeHtmConversionDataSource` + service → use case → repository → datasource (B3c, B4) |
| FR-005 tests pass, assertions unchanged | 90-test app suite (76 ported) green on host |
| FR-006 public API unchanged | B2a barrels/entry points pinned; ported suite passes unchanged |
| FR-007 no new platform bindings | B1c artifact set == pre-migration set; adapters contain only preserved loader logic |
| FR-008 publish under existing name | family name `html_to_markdown_ffi`; publish pipeline executes in B6 |
| SC-001 suite green + analyze clean | 0 errors/0 warnings per package; 90/6/6/6/6 tests green |
| SC-002 corpus ≥ 20 | `host_ffi_proof_test.dart` corpus (24 inputs) through the migrated stack |
| SC-003 compile+test on supported platforms | macOS executed; android/ios structural + offline harness (recorded honestly) |
| SC-004 publish, dependents compile | B6 (pipeline run); import paths pinned by B2a |
| SC-005 no hand-written architecture | generated artifacts pinned by B3; boundary mapping is explicit product code (research D4) |

## 6. Findings (non-blocking)

1. The shipped `VisitorBridge` stub is preserved as-is; making it functional is a *new feature*
   outside this migration's scope (FR-003/FR-006 protect the shipped behavior).
2. Two instance pins were corrected during green (B1b dep sets) — derivation fixes, logged.
3. Android/iOS on-device execution remains unproven (pre-migration status quo; recorded in D7).
