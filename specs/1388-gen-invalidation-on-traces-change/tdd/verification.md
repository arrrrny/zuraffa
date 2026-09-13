# TDD Verification — Spec 1388 — Verdict: PASS (2026-09-13)

- Test-first: red commit (`ca7b4aaf` — SDD artifacts + regression suite)
  precedes the fix. Red evidence (pre-fix run of
  `issue_1388_gen_reuse_fingerprint_test.dart`): **+3 −3** —
  - U2 red: `verdict=reused` with the `zfa:tdd: guard-only` warning on
    the no-signature traces migration (the issue's exact transcript);
  - U3 red: exit 0 / no refusal for the drifted progressed pair;
  - U4 red: `gen_fingerprint` absent from the created record;
  U1/U5/U6 green pre-fix by design (they pin the #1320 signature path
  and the FR-006 reuse idempotency the fix must not break).
- Post-fix suite: **+6 All tests passed!** (`dart test
  test/plugins/tdd/commands/issue_1388_gen_reuse_fingerprint_test.dart`).
- Touched-area suites (fast tier): artifact_record (+10), artifact_registry
  (+15), bug_912 migrate-paths (+4), bug_1320 / bug_1377 / issue_1309 /
  bug_1518 gen-neighbourhood (+50 combined), tdd services folder (+968).
- Slow tier (tier `slow`, run explicitly): bug_1397 (+10), bug_1380 (+3),
  gen_command_test **+17 −1** — the −1 (`bug #871` pure-description echo)
  fails IDENTICALLY on unpatched master (verified via stash) — a
  pre-existing master failure, not a regression of this change.
- Analyze: `dart analyze` on every changed file — no issues; whole
  package 112 info-level findings == master baseline, **0 warnings,
  0 errors** (no new warnings).
- Format: `dart format` applied to the 3 files the formatter wanted;
  all 6 touched files format-clean.
- AC coverage: AS-1→U1, AS-2→U2, AS-3→U3, AS-4→U5, AS-5→U6; FR-1→U4;
  SC-001→U1+U2, SC-002→the analyze/suite results above.
- Honest scope note: the no-signature migration's regenerated pair stays
  the guard-only SHAPE (no declared signature resolves — the #1420
  class, out of scope per the hard constraints); what #1388 fixes is the
  reuse VERDICT + fingerprint invalidation + the named escape hatch, not
  the rendered assertion surface. The progressed-subject guard keys on
  the subject carrying no `UnimplementedError` at all (pre-existing #683
  semantics, unchanged).

## Post-review additions (PR #1597, 2026-09-13)

The automated review at `26c534fc` raised 5 findings (🟠2 · 🟡2 · 🔵1).
All five are resolved; evidence below.

### 🟠 whole-file `spec.md` hashing made prose edits routing changes

The spec component is now the declared-ROUTING SURFACE — the Layer
Contracts section (`SpecParser.layerContractsSection`, composition tag
`v2`) — so an edit outside it cannot move the digest.

Red evidence (probe: `git stash push -- lib/`, suite run against the
pre-fix code): **+7 −2** —

- U7 red: a prose-only edit reported `verdict=regenerated` — the pair
  was invalidated by documentation, with nothing about routing changed;
- U7b red: the same edit on a progressed pair printed `reuse refused —
  … (reuse fingerprint drifted: the lane-plan traces cell or spec.md
  changed since generation) … --> fix: zfa tdd reset`.

Both pass post-fix (**+9 All tests passed!**).

### 🟠 a docs-only edit landed on the destructive `zfa tdd reset` path

Same fix: the refusal can now only fire for a declared-routing change,
and its wording names the two real surfaces (traces cell / Layer
Contracts) instead of `spec.md`. U7b pins the progressed pair taking
exit-0 `verdict=reused` with the subject untouched.

### 🟡 `forceRebuild` (skipping the byte-equality short-circuit) untested

U8 added: a Layer Contracts declaration that no behavior's traces cell
resolves, no plan re-run → the render stays byte-identical and gen still
reports `verdict=regenerated`, refreshes the digest, and reuses again on
the next run. Red evidence for the leg itself (probe: `forceRebuild:
true` commented out): **+8 −1 — U8 is the only failing test**, i.e. the
test fails exactly when the leg is missing. U8 is green pre-fix too (the
whole-file hash did drift for that edit), so it is a characterization
pin, not a red-first behavior — recorded honestly.

### 🟡 `gen_fingerprint` "preserved through copies" claimed but untested

Table-driven round-trip coverage added (**+38** across the three suites;
baseline **+29**): `toJson` omits the key when null (legacy byte
stability), a present digest round-trips `fromJson`/`toJson`, a copier
table pins `copyWithOwnership` / `copyWithGenFingerprint`, and the
public-path copiers are pinned through `loadAll()`
(`_reanchorRecord`), `append()` (`_canonicalize`) and both
`migrate-paths` rewriters (`_withPaths`, `_withPortablePaths`) — each
paired with a path assertion, so a short-circuiting rewriter fails
before the digest assertion can pass vacuously.

### 🔵 `verdict=refused` omitted `kind`/`featureName`/`featureDisplay`

The #1388 refusal now passes all three, matching the sibling i18n
refusal, so the `--json` envelope carries `kind` on both refusal paths.

### Re-run after the changes

- `issue_1388_gen_reuse_fingerprint_test.dart` — **+9 All tests passed!**
- `spec_parser_routing_surface_1388_test.dart` (new) — **+5**
  (qualified heading, entity-escaped heading, prose exclusion,
  no-section → empty, CRLF).
- gen-neighbourhood (bug_1320 / bug_1377 / issue_1309 / bug_1518) plus
  all six `spec_parser_*` suites — **+125 All tests passed!**
  (`SpecParser` gained a public method; its consumers were re-checked).
- Copy-site suites (artifact_record / artifact_registry /
  bug_912_migrate_paths) — **+38 All tests passed!**
- `dart analyze` on the changed files — No issues found!;
  `dart format` — 0 changed.
- AC coverage (amended): AS-1→U1, AS-2→U2, AS-3→U3, AS-4→U5, AS-5→U6,
  AS-6→U7+U7b, AS-7→U8; FR-1→U4+U9, FR-6→U7b; SC-001→U1+U2.
