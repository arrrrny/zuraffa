# Bug Issue: tdd doctor mis-prescribes cross-feature adoption + missing flat→namespaced migration

- **Slug**: tdd-doctor-cross-feature-adoption
- **Fetched**: 2026-09-03
- **Issue**: 874
- **URL**: https://github.com/arrrrny/zuraffa/issues/874
- **State**: open
- **Severity**: high
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

## tdd doctor mis-prescribes cross-feature adoption + missing flat→namespaced migration

Wave-1 rebuild (post #827), fresh project: spec 001 completed on the PRE-fix binary (its artifacts live at legacy flat paths), then spec 004 ran on the POST-fix binary (artifacts namespaced under `test/tdd/004-dependency-injection/`).

### What happened

`zfa tdd doctor 004-dependency-injection` reports 21 drifts like:

```
drift: unowned generated file(s) for "A3": test/tdd/a3_test.dart
...
--> fix: zfa tdd gen A1 --adopt --feature 004-dependency-injection && ... (all 21)
```

But those flat files are OWNED — by feature **001** (confirmed: `specs/001-app-bootstrap/tdd/artifacts.json` records `test/tdd/a1_test.dart`). The doctor's legacy-path scan finds another feature's files and prescribes **adopting them into 004's registry** — following the prescription would corrupt ownership (two features owning one file), the exact trust violation the guardrails exist to prevent.

### Required

1. **Cross-registry awareness**: doctor (and gen's legacy-path fallback) must consult ALL feature registries in `specs/*/tdd/artifacts.json` before declaring a file "unowned". If another feature owns it → distinct verdict `foreign-owned` with fix `migrate`, never `adopt`.
2. **Migration path for #827**: existing projects have pre-fix flat artifacts. Provide `zfa tdd migrate-paths <feature>` (or auto-upgrade on first run): move files to namespaced layout + rewrite registry/test_path/runnable names + keep cycle-log evidence bound. Without this, every project that ran TDD before #827 is permanently "drifted".
3. Doctor verdicts should include the owning feature for foreign files.

### Repro

1. Run any feature to completion on a pre-#827 binary
2. Rebuild with #827, add a second feature, `zfa tdd doctor <second-feature>`
3. Doctor prescribes adopting the first feature's flat files

## Comments

None.
