# Bug Issue: tdd gen A5 refuses on registry path-form mismatch

- **Slug**: gen-path-form-mismatch
- **Fetched**: 2026-09-09T11:17:54Z
- **Issue**: 1397
- **URL**: https://github.com/arrrrny/zuraffa/issues/1397
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: missing-integration, verify-misfire

## Body

## Misfire discovered during EPIC verify
**Epic:** #1133
**Verify branch:** verify/epic2-tdd-loop-completeness
**Phase:** A (step 2 — `zfa tdd gen` on 004-login-ui)
**Sub-issue:** exit criterion 2 / #966 (absence ledger rows — A5 is the absence behavior)

## What I tried
```bash
zfa tdd gen A5 --feature 004-login-ui --project example --widget-shell materialapp
zfa tdd doctor 004-login-ui --project example --json
```

## Expected
`gen A5` reuses/regenerates the absence test for AC-5 ("the 'Sign in failed' banner is not shown"). If a registry conflict exists, `zfa tdd doctor` (the tool's own prescribed recovery step, printed in the refusal message) should detect and prescribe a fix.

## Actual
```
gen: behavior=A5 verdict=refused reason="ownership conflict: OwnershipConflict: the registry test path \"test/tdd/004-login-ui/a5_test.dart\" does not match \"/home/z/my-project/zuraffa/example/test/tdd/004-login-ui/a5_test.dart\". Refusing to overwrite non-owned content. Run `zfa tdd gen <behavior-id>` after resolving the conflict."
```
But doctor on the same feature:
```
zfa tdd doctor: feature 004-login-ui (specs/004-login-ui/tdd)
  stores agree — no drift detected
{"schema":"zuraffa.verdict.v1","command":"doctor",...,"prescription":"none",...}
```
Root cause: `example/specs/004-login-ui/tdd/artifacts.json` (committed) mixes path forms across records — A4 stores a machine-specific ABSOLUTE path (`/home/z/.../a4_test.dart`, only matches clones at the identical path), A5 stores a RELATIVE path (`test/tdd/004-login-ui/a5_test.dart`). gen's ownership gate compares path strings; A5 mismatches and is refused. doctor's drift check does not cover path-form normalization, so the prescribed recovery loop is dead for this case.

## Gap classification
- [x] Missing integration (doctor ↔ gen ownership gate)
- [ ] Empty implementation
- [ ] Missing dependency
- [ ] Spec drift

## Suggested fix
Normalize registry paths at write AND compare time (resolve both to absolute against the project root before comparing), and add path-form normalization to doctor's drift check. Also scrub committed artifacts.json of machine-specific absolute paths — they are non-portable and only match by coincidence on same-path clones.

## Workaround applied
Normalized A5's record paths in artifacts.json to the resolved absolute form via a local jq edit, re-ran `gen A5` successfully, then reverted the registry edit to keep the verify branch clean.

## Comments

None.
