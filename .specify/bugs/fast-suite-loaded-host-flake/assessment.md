# Bug Assessment: the fast suite flakes and does not complete on a loaded shared host

- **Slug**: fast-suite-loaded-host-flake
- **Created**: 2026-10-22
- **Source**: GitHub issue #1994 (`arrrrny/zuraffa`)
- **Verdict**: valid
- **Severity**: medium

## Report (summarized)

> A full fast-suite run (`dart test -j 2`) on a shared host whose load
> average was ~390 produced load-sensitive failures that did not reproduce
> in isolation, and did not finish within a 2-hour bounded window.
>
> - Attempt 1 (2400s bound): killed at `+2417 -1` (39 min). The one failure
>   — `test/plugins/test/test_self_certify_test.dart` ("real scoped dart
>   analyze (U3 real) deliberately non-compiling fixture fails with verdict
>   + fix line") — passes in isolation.
> - Attempt 2 (7200s bound): killed at `+3509 ~5 -32` (119 min). Named
>   failures included `test/plugins/tdd/bug_1261_visual_contract_surface_test.dart`
>   (3 tests), `test/plugins/tdd/bug_1412_refactor_excerpt_tail_test.dart`
>   (1 test) and `test/plugins/tdd/commands/run_command_bug_1471_test.dart`
>   (1 test — a real assertion failure: its temp project's `zfa tdd init` hit
>   `pubspec.yaml not found` mid-setup). All three pass in isolation.

## Symptom

The fast tier fails on a loaded shared host in two distinct shapes, and
neither reproduces in isolation:

1. **False timeouts** on suites that drive a real external child. The
   ceiling that actually governed them was their own per-test override,
   not the global one: the real-analyzer suite carried `timeout: const
   Timeout(Duration(minutes: 2))` (120s), so the global `2x` (60s of
   package:test's 30s base) never applied to it. The analyzer child's
   cold start alone exceeds that budget under contention.
2. **Cross-suite contamination** — a suite reads a sibling's tree
   (`pubspec.yaml not found` mid-setup; a visual-contract surface that
   does not match). This is the signature of a PARALLEL lane, not of a
   slow one.

## Reproduction

The flake needs a loaded host, so it is not reproducible on an idle
machine. What IS reproducible — and what the fix pins — is the
configuration defect the report identifies:

1. `dart_test.yaml` pins `concurrency: 1`; package:test resolves
   `concurrency => _concurrency ?? defaultConcurrency`
   (test_core's `Configuration`), so the CLI's `-j 2` overrides the pin
   SILENTLY. The repo's serial invariant (a correctness requirement —
   `Directory.current` and `dart:io exitCode` are process-global across
   the suites `dart test` runs as isolates of ONE process) is therefore
   not enforced by the config alone.
2. The fast-tier suite that drives a real `dart analyze` child
   (`test/plugins/test/test_self_certify_test.dart`) carries NO timeout
   tag and overrides its own ceiling with a 2-minute constant, so it sits
   under THAT ceiling (120s) — not under the 60s global one, which never
   governed it — while every other test in the file sits under the global
   2x.

## Suspected Code Paths

- `dart_test.yaml` — `timeout: 2x`, `concurrency: 1`, the `tags:` block
  (no ceiling for the fast-tier suites that spawn a real child).
- `test/plugins/test/test_self_certify_test.dart` — the "real scoped dart
  analyze (U3 real)" group builds the production certifier, which shells
  out to `dart analyze` (lib/src/plugins/test/test_certifier.dart,
  `ProcessScopedAnalyzer`); the file carried no tag and pinned its own
  2-minute per-test timeouts.
- `test/tier_integrity_test.dart` — the B5 census scans TEST sources for
  spawns, so a suite that reaches a real child THROUGH THE LIB is
  invisible to it (the gap that let this suite keep its own 2-minute
  per-test ceiling, with no tag to raise it).
- `.github/workflows/ci.yaml` — the `dart_core` lane's `--exclude-tags
  "flutter || e2e"` selector: the local default run (`dart test`) does NOT
  mirror it, which is why the local fast tier pulls in the `e2e`
  temp-project suites and runs unbounded on a loaded host.

## Root Cause Hypothesis

Confidence: **high**.

Two independent amplifiers, both load-sensitive, both configured by the
repo rather than by the report's environment:

1. **The serial invariant was only a config, and the fleet's `-j 2`
   overrode it silently.** The repo already knows the parallel lane is
   unsafe (#1632's three red master runs, #1682's serial pin) — the gap is
   that nothing owned the cap at the invocation, so a fleet-wide `-j 2`
   convention quietly re-enabled the exact failure mode the pin exists to
   prevent. The contamination-shaped failures in the report
   (`pubspec.yaml not found` mid-setup) are that failure mode.
2. **The ceiling ladder stopped at the tier boundary.** The `ffi` lane
   already carries `8x` for a cold child (#1678); the fast-tier suites
   that drive a real child had no equivalent, so the global `2x` (60s)
   applied to them and the real-analyzer suite fell back on its own
   2-minute constant.

## Proposed Remediation

**Preferred** (both parts, together):

1. **A CLI-side cap** — a fast-tier entrypoint that owns the serial
   invariant: it runs the fast lane with an explicit `-j 1` and REFUSES a
   parallel request with the reason, instead of inheriting one. It runs
   CI's `dart_core` selector, so the local fast tier is the bounded lane
   (~12 min in CI) instead of the unbounded whole-tree default run.
2. **A ceiling for the fast-tier suites that drive a real child** — a
   `spawn` tag carrying `8x` (the `ffi` precedent), applied to the
   real-analyzer suite, with the per-test 2-minute override dropped so
   the tag governs.

**Files to change**:

- `tools/run_fast_suite.dart` (new) — the entrypoint; its cap logic is a
  pure function so the fast tier's own pin can assert it without spawning
  a child (a fast-lane suite that spawns is a heavyweight suite under the
  B5 census).
- `dart_test.yaml` — the `spawn` tag (8x) and the concurrency note.
- `test/plugins/test/test_self_certify_test.dart` — the `spawn` tag; the
  per-test timeout overrides dropped.
- `test/tier_integrity_test.dart` — the pins: B9 (the CLI-side cap) and
  B10 (the ceiling ladder, incl. the census gap).
- `test/README.md`, `AGENTS.md` — the loaded-host contract.

**Tests to add or update**:

- `test/tier_integrity_test.dart` B9 — the config pins `concurrency: 1`;
  the entrypoint exists; a parallel request is refused with a message
  naming the knob and the issue; every `-j`/`--concurrency` spelling is
  recognized; the command pins `-j 1` and the CI lane's selector.
- `test/tier_integrity_test.dart` B10 — `dart_test.yaml` declares the
  `spawn` tag at ≥ 8x of the 30s base; every fast-lane-eligible suite
  that reaches a real analyzer child through the lib carries the tag.

## Risks & Considerations

- **The refusal is a hard stop — for the entrypoint, not for a direct
  `dart test`.** An agent that runs `dart run tools/run_fast_suite.dart
  -j 2` out of habit now gets exit 2 instead of a run. That is the
  intent (the parallel lane is the bug), and the message says why and
  points at the entrypoint. A direct `dart test -j 2` is NOT intercepted
  by this change: it does not go through the entrypoint, so it still runs
  in parallel (and still overrides `concurrency: 1`) — the entrypoint
  makes the sanctioned path safe, it does not forbid the unsanctioned
  one.
- **The `spawn` ceiling is a fixed factor** (like `slow`/`e2e`/`ffi`), so
  it cannot read `ZFA_TEST_TIMEOUT_SCALE`; a host that needs more uses
  the scale variable plus `--timeout xN` (documented in `test/README.md`).
- **No CI change.** The `dart_core` lane already runs serial without a
  `-j` flag (pinned by B7); the entrypoint mirrors that lane rather than
  replacing it.
- **The B5 census stays untouched** — the new pin asserts the ceiling
  ladder instead of teaching the census a new spawn shape.

## Open Questions

- None blocking: the issue's two "suggested directions (maintainer's
  call)" are both implemented — the higher tag timeout for the
  spawn-heavy suites, and the CLI-side cap for `concurrency: 1`.
