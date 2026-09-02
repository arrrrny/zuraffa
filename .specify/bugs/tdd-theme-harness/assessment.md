# Bug Assessment: theme harness — light/dark scheme + typography as executable proof

- **Slug**: tdd-theme-harness
- **Created**: 2026-09-02
- **Source**: https://github.com/arrrrny/zuraffa/issues/841
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

Spec 002 demands brand colors, Axiforma weights, dark mode inverse, sonner themed, zero hardcoded colors. None of that is assertable in generated tests today. The theme harness must turn these requirements into executable widget tests and golden-file baselines. https://github.com/arrrrny/zuraffa/issues/841

## Symptom

Theme requirements (brand colors, typography, dark mode, sonner config, zero hardcoded colors) are declared in specs but have no executable test coverage. Generated tests don't assert on ShadTheme values. No golden-file baselines exist for theme modes. SC-003 (zero hardcoded colors) is not a gate.

## Reproduction

1. Spec 002 declares FR-001..008 (brand colors, typography, dark mode, sonner)
2. `zfa tdd gen` produces plain-function subjects — no theme assertions
3. No widget test pumps app shell under both ThemeModes
4. No hardcoded-color audit exists as a test

## Suspected Code Paths

- `zfa tdd gen` — no theme-kind behavior generation
- No ShadTheme assertion helpers in the test infrastructure
- No golden-file capture/comparison infrastructure
- No analyzer-backed hardcoded-color scan

## Root Cause Hypothesis

High confidence: the TDD pipeline has no theme-aware test generation. Theme requirements are human-readable assertions in specs, not machine-executable tests. The harness must generate widget tests that pump the app shell and assert on ShadTheme values.

## Proposed Remediation

**Preferred**: (1) `zfa tdd gen` theme-kind behaviors produce widget tests that pump app shell under both ThemeModes and assert ShadTheme.of(context).colorScheme.primary == kBrandGreen, typography family/weights, sonner config. (2) Hardcoded-color audit as generated TEST: analyzer-backed scan of lib/ (fail on raw Color(0x...) outside constants file). (3) Golden captures per mode per platform committed as baselines; drift = exit 1. (4) Theme-switch latency: pump-and-measure frame timing assertion with certified tolerance.

**Alternatives** (optional):
- Manual theme testing — doesn't scale; not a gate.

**Files likely to change**:
- Gen command (theme-kind behavior template)
- Test infrastructure (ShadTheme assertion helpers)
- Golden-file capture/comparison
- Hardcoded-color audit (analyzer integration)

**Tests to add or update**:
- Theme-kind A-behaviors generate widget tests with ShadTheme assertions
- Hardcoded-color audit catches raw Color(0x...) outside constants
- Golden baselines per mode per platform
- Theme-switch latency assertion within tolerance

## Risks & Considerations

- Golden files are platform-specific — baselines must be per-platform
- Hardcoded-color audit must not false-positive on constants file
- Theme-switch latency tolerance must be certified, not arbitrary
- 24 UI specs affected (indirectly all consuming theme)
- Depends on #830 (widget-test subject kind)

## Open Questions

- [NEEDS CLARIFICATION: Where is the constants file with kBrandGreen — lib/theme/constants.dart?]
- [NEEDS CLARIFICATION: What is the certified tolerance for theme-switch latency (ms)?]
