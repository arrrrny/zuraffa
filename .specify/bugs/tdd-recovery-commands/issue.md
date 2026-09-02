# Bug Issue: [TDD-120] tdd gen --adopt + zfa tdd reset <feature>: first-class recovery instead of hand-edits

- **Slug**: tdd-recovery-commands
- **Fetched**: 2026-09-02
- **Issue**: 840
- **URL**: https://github.com/arrrrny/zuraffa/issues/840
- **State**: open
- **Severity**: high
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

Context: During the 120-spec run we repeatedly hand-edited run-state.json / moved directories — because recovery commands don't exist. Hand-edits are exactly the trust violation VISION forbids; the system must own its state.

Required:
1. `zfa tdd gen <id> --adopt`: when files exist on disk unowned (post-crash, post-merge), verify content shape matches a generated artifact, then register ownership in artifacts.json — audit-logged.
2. `zfa tdd reset <feature>`: reverts feature TDD state to clean (drops artifacts registry entries + generated tests/subjects it owns), NEVER touching foreign files; prints diff summary before acting.
3. `zfa tdd doctor <feature>`: reconciles the three stores per #828 and prescribes exactly one of: resume / reset / adopt, as a `fix` line.
4. All three emit JSON verdicts and respect the exit protocol.

## Comments

**arrrrny** (2026-09-02): "Part of epic #848 (Wave 1 — unblock the loop). Closing this without the epic context loses the dependency ordering."
