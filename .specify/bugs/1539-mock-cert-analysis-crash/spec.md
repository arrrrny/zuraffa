# Spec: 1539-mock-cert-analysis-crash (synthesized from the assessment)

## Intent

`mock create --certify` must never convert a transient analysis-server
crash of its verification TOOL into a drift verdict against a mock whose
structural certification passed and whose `(conforms)` receipt is
already persisted. Infra failure ≠ generation failure.

## Requirements

- **FR-1 (crash detection)**: `MockCertifier.gate` classifies a scoped
  analyze failure as an analysis-server CRASH when the output carries
  the crash signature (`The analysis server crashed unexpectedly` /
  `The analysis server shut down unexpectedly`) and contains no
  parseable `error -` diagnostics.
- **FR-2 (one retry)**: a detected crash retries the analyze pass
  exactly once with the same runner/files.
- **FR-3 (infra, not drift — certification stands)**: when the retry
  also crashes AND structural drift is absent (missing and invented
  members empty — the condition the persisted receipt records as
  `conforms`), the gate passes: no `--> fix:` line is emitted for the
  crash, the report exposes `analyzeUnverified` (with the crash output
  disclosed), and the CLI exits 0 printing a loud warning that the
  compiler verdict is UNVERIFIED and names `zfa mock verify` as the
  re-proof path.
- **FR-4 (safe failure unchanged)**: structural drift (missing/invented
  members) still fails the gate even when the analyze crashes; real
  `error -` diagnostics still fail the gate with fix lines; a clean
  retry of a crashed pass gates normally.
- **FR-5 (shared machinery)**: `mock verify` — which consumes the same
  gate — maps the crash-only shape to its pass verdict with the same
  loud disclosure, and no longer reports the crash tail as an
  `analyze_error` finding.

## Acceptance Criteria

- **AC-1**: crash → retry clean → pass, exactly one analyze invocation
  pair observed (2 calls), no fix line.
- **AC-2**: crash twice + structurally clean → passed=true,
  `analyzeUnverified=true`, no `--> fix:` line, exit 0, warning printed
  naming `zfa mock verify`.
- **AC-3**: crash twice + structural drift → passed=false, exit 1
  (the drift fix line stands).
- **AC-4**: real `error -` output (no crash signature) → passed=false,
  fix lines, exit 1 (existing U6 contract unchanged).
- **AC-5**: `mock verify` on the crash-only shape → pass verdict with
  the disclosure and no crash-tail finding.

## Test List

See `tdd/test-list.md` (U-1539-*). Suite: fast tier, injected analyze
runner via `MockCertifier.analyzeRunnerOverride` — the same seam the
#970 gate tests use.
