# Fix: #1539 mock-cert analysis crash (infra, not drift)

- **Slug**: 1539-mock-cert-analysis-crash
- **Status**: applied
- **Branch**: fix/1539-mock-cert-analysis-crash
- **Date**: 2026-09-13

## Remediation

An analysis-server crash inside the scoped `dart analyze` subprocess is
an infra failure of the verification TOOL, never mock drift. The gate
now classifies it, retries once, and — when the retry also crashes while
the structural certification is clean (the condition the persisted
receipt records as `conforms`) — leaves the certification standing with
a loud `UNVERIFIED` disclosure. The exit path no longer contradicts the
engine's own persisted evidence.

### `lib/src/plugins/mock/services/mock_certification.dart`

- `CertifyReport` gained `analyzeUnverified` (String?): non-null only in
  the crash-twice + structurally-clean shape, carrying the crash output
  so callers disclose it — never a silent pass, never a fix line.
- `MockCertifier.gate`: on a failed analyze matching the crash shape
  (`_isAnalyzerCrash`: non-zero exit, no `error -` diagnostics, either
  dogfood crash string verbatim), the pass is retried ONCE. A clean
  retry gates normally. A second crash with `fixes.isEmpty` (no
  structural drift) returns `passed: true` + `analyzeUnverified`; with
  structural drift the gate still fails (the crash must not paper over
  real drift), and real `error -` output is untouched.

### `lib/src/commands/mock_command.dart` (`mock create --certify`)

- On `report.passed` with `analyzeUnverified`, prints the ⚠️ disclosure
  (crash, retried once; verdict UNVERIFIED; the structural
  certification stands with the registry id; re-proof path
  `zfa mock verify <Entity>`) — exit stays 0.

### `lib/src/commands/mock_verify_command.dart` (`mock verify`)

- Same disclosure on the human path; the `--json` envelope carries
  `details.analyzeUnverified`. The crash tail no longer surfaces as an
  `analyze_error` finding (it never enters `fixLines`).

### Tests (new)

`test/plugins/mock/bug_1539_analyzer_crash_not_drift_test.dart` — 6
tests (4 gate-level, 2 CLI-level) pinning FR-1..FR-5; see
`tdd/test-list.md`.

## Out of scope (follow-up)

Issue suggestion 3 — short-circuit "already certified" on re-run when
the receipt is present — changes re-run semantics for every re-run, not
just crash recovery; tracked on the issue for a separate cycle.

## TDD artifacts

- spec synthesized: `spec.md` (FR-1..FR-5, AC-1..AC-5)
- red: compile-red on `analyzeUnverified` (contract absent on master)
- green + mutation kills: `tdd/verification.md`
