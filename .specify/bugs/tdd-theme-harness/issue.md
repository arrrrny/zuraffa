# Bug Issue: [TDD-120] Theme harness: light/dark scheme + typography as executable proof (shadcn_ui/ShadTheme)

- **Slug**: tdd-theme-harness
- **Fetched**: 2026-09-02
- **Issue**: 841
- **URL**: https://github.com/arrrrny/zuraffa/issues/841
- **State**: open
- **Severity**: high
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

Context: Spec 002 FR-001..008 and SC-001..004 demand: brand colors applied everywhere, Axiforma weights, dark mode inverse, sonner themed, zero hardcoded colors. Today none of that is assertable in generated tests.

Required (system fix):
1. `zfa tdd gen` theme-kind behaviors produce widget tests that pump the app shell under both ThemeModes and assert: ShadTheme.of(context).colorScheme.primary == kBrandGreen (constants file), typography family/weights from the manifest, sonner config.
2. Hardcoded-color audit as a generated TEST: analyzer-backed scan of lib/ (fail on raw Color(0x...) outside constants file) — turns SC-003 into a red/green gate.
3. Golden captures per mode per platform committed as baselines; drift = exit 1 with diff path (VISION §6).
4. Theme-switch latency SC-002: pump-and-measure frame timing assertion with a certified tolerance (not flaky sleep).

## Comments

None.
