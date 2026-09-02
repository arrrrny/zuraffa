# Bug Assessment: tdd doctor mis-prescribes cross-feature adoption + missing flat→namespaced migration

- **Slug**: tdd-doctor-cross-feature-adoption
- **Created**: 2026-09-03
- **Source**: https://github.com/arrrrny/zuraffa/issues/874
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

Wave-1 rebuild (post #827): feature 001 completed on the pre-fix binary (legacy flat artifacts), feature 004 ran on the post-fix binary (namespaced artifacts). `zfa tdd doctor 004-dependency-injection` reports 21 drifts `unowned generated file(s) for "A3": test/tdd/a3_test.dart` and prescribes `zfa tdd gen A1 --adopt --feature 004-dependency-injection && ...` — adopting files that are OWNED by feature 001 (`specs/001-app-bootstrap/tdd/artifacts.json` records `test/tdd/a1_test.dart`). Following the prescription corrupts ownership.

## Symptom

The doctor's legacy-path scan (`_scanGeneratedLayout` over `test/tdd/*.dart` + `lib/tdd/*.dart`) classifies every generated-shape file the QUERIED feature's registry does not own as "unowned" → prescription `adopt`. Another feature's ownership is never consulted, so a completed feature's pre-#827 flat artifacts look like adoptable orphans to every OTHER feature's doctor run.

## Reproduction

1. Run any feature to completion on a pre-#827 binary (flat artifacts recorded in its registry)
2. Rebuild with #827, add a second feature
3. `zfa tdd doctor <second-feature>` → 21 drifts, `--> fix: zfa tdd gen A1 --adopt --feature <second-feature> && ...`

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/doctor_command.dart` — `_scanGeneratedLayout` + the unowned→adopt branch: ownership is checked ONLY against the queried feature's `ownedTestPaths`/`ownedSubjectPaths`; no cross-registry consult.
- `lib/src/plugins/tdd/commands/gen_command.dart` — the `--adopt` recovery path (the fix line the doctor prescribes): declares a file "unowned" from THIS feature's registry alone; a file owned by another feature's registry could be adopted into a second registry.
- `lib/src/plugins/tdd/commands/migrate_paths_command.dart` — the #827 flat→namespaced migration (registered in `tdd_command.dart`); exists already, is what the `migrate` fix should name.

## Root Cause Hypothesis

High confidence: the doctor's unowned scan (and gen's adopt fallback) resolve ownership against a single registry — the queried feature's. The fix introduced by #827/#840 never taught these recovery surfaces that `specs/*/tdd/artifacts.json` is a SET of registries. Any pre-#827 (flat) feature in a multi-feature project therefore presents its legacy artifacts as adoptable to every other feature's doctor.

## Proposed Remediation

**Preferred**:
1. Add a cross-registry ownership scan: map every recorded artifact path across ALL `specs/*/tdd/artifacts.json` → owning feature (normalized absolute-path comparison so absolute and project-relative recorded forms both resolve).
2. Doctor: partition the legacy-layout scan into foreign-owned (another feature's registry owns the path) vs unowned (nobody owns it). Foreign-owned → distinct verdict `foreign-owned`, prescription `migrate`, fix `zfa tdd migrate-paths <owner>` (single owner) or `zfa tdd migrate-paths` (multiple owners) — NEVER adopt. Unowned keeps the existing #840 adopt prescription.
3. Doctor verdict JSON includes `owned_by` (foreign path → owning feature) per requirement 3.
4. Gen `--adopt`: before adopting an existing file, consult the same cross-registry map; a foreign-owned file is refused with verdict `foreign-owned` and a migrate hint — never registered into a second registry.
5. `zfa tdd migrate-paths` (requirement 2) already exists and is registered on master — verified; no new migration surface needed.

**Alternatives** (optional):
- Auto-upgrade flat layouts on first run — rejected: the issue offers it as an alternative to the command, the command exists, and silent auto-mutation of another feature's registry from a doctor read violates the least-surprise/ownership rule.

**Files likely to change**:
- `lib/src/plugins/tdd/commands/doctor_command.dart` (foreign-owned partition + verdict fields)
- `lib/src/plugins/tdd/commands/gen_command.dart` (adopt + non-adopt conflict foreign check)
- new `lib/src/plugins/tdd/services/cross_feature_ownership.dart` (shared scan)
- `test/plugins/tdd/bug_874_doctor_cross_feature_adoption_test.dart` (new)

**Tests to add or update**:
- Doctor 004 with 001's flat registry → verdict foreign-owned, prescription migrate, fix names `zfa tdd migrate-paths <owner>`, never `--adopt`
- `owned_by` in the verdict JSON names the owning feature (requirement 3)
- Relative-path registry records are still recognized (normalization)
- Multiple foreign owners → bare `zfa tdd migrate-paths`
- Truly unowned flat file → adopt prescription unchanged (#840 control)
- Doctor for the OWNING feature → healthy (its own files are not foreign to itself)
- `gen --adopt` on a foreign-owned file → refused, verdict foreign-owned, registry unchanged, file content untouched
- `gen --adopt` on a genuinely unowned file → adopted (controls; #840 semantics preserved)

## Constraint Check

- Depends on #827 (namespaced layout + registry shape) — merged on master (`migrate_paths_command.dart`, namespaced gen defaults).
- Interacts with #840 (doctor/adopt/reset) — extends the doctor's verdict vocabulary; existing adopt/reset/resume prescriptions unchanged for single-registry states.
- Interacts with #837 — none: verify/mutation path untouched.
- Minimal-change: reset's informational foreign count and run_command's legacy deferral fallback are NOT ownership declarations and stay untouched.
