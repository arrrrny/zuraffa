# Cycle Log — tdd-run-multi-feature-ownership (bug #801)

All commands real runs in this session (Dart 3.13.3, linux_x64). Evidence
logs under session scratch `801-red/` (red_log.txt, green_log.txt,
mutant_log2.txt, e2e_branch_log.txt); the durable pins live in
`test/plugins/tdd/bug_801_run_multi_feature_ownership_test.dart`.

## Cycle 1 — RED: the issue's signature reproduced pre-#827

- Worktree at `447ac1ac^` (b6afda42, the commit immediately before the
  #827 namespacing fix landed). Fixture: the issue's exact shape —
  `zik_zak_tdd` Dart package, `zfa tdd init`, real `dart pub get`, two
  features seeded with identical behavior ids A1/A2.
- `dart test --preset=integration test/plugins/tdd/bug_801_run_multi_feature_ownership_test.dart`
  → exit 1 in 5:56.
- Failure output (verbatim, matches the issue's report):

  ```
  [run] A1 gen -> error
  zfa tdd run: step failed — behavior=A1 step=gen outcome=error
     {"command":"gen","behavior":"A1","verdict":"refused","reason":"ownership conflict: OwnershipConflict: test file \"/tmp/bug801_run_multi_feature_KWRYSK/test/tdd/a1_test.dart\" exists on disk but the registry has no recorded ownership. Refusing to overwrite non-owned content. Run `zfa tdd gen <behavior-id>` after resolving the conflict."}
  run: feature=004-dependency-injection result=stopped pending=2 red=0 green=0 done=0 stopped_at=A1:gen
  ```

- Run 1 completed (`result=complete`, exit 0) before run 2 died — the
  issue's "first run succeeds" precondition, reproduced.

## Cycle 2 — GREEN: the journey passes on this branch

- Same test on `fix/801-tdd-run-multi-feature-ownership` (master bd535c07 +
  this test; zero production changes) → **exit 0 in 6:45, all assertions
  pass**: run 1 completes; run 2 prints `[run] A1 gen -> ok`; no
  `ownership conflict` / `OwnershipConflict`; no `step=gen` / `:gen` stop;
  both features' namespaced pairs and registries coexist; feature-2's
  registry never references feature-1's namespace.
- Real-CLI transcript of the same journey (compiled v6.1.0-master binary):
  run 1 `result=complete` exit 0; run 2 `[run] A1 gen -> ok`, verify-red
  certified, then `A1 make -> generation-error` → `stopped_at=A1:make`
  (bug #877's func-spawn ambiguity — PR #888's scope, tolerated by the
  pin) — e2e_branch_log.txt.

## Cycle 3 — Mutation check: the pin detects the regression class

- Mutant M1: `gen_command.dart` reverts to the pre-#827 flat paths
  (`test/tdd/<id>_test.dart`). The test FAILS with the issue's verbatim
  signature (`[run] A1 gen -> error` + OwnershipConflict +
  `stopped_at=A1:gen`), exit 1 in 5:48 — caught. Mutant restored; `git
  diff lib/` clean.
- Honest note: a FIRST mutant attempt silently no-op'd — the mutation
  script's Python escaping kept literal `\$` sequences, `str.replace`
  matched nothing, and the "mutant" run exercised pristine code (it
  passed, as it must). Detected by inspecting the target lines
  (`rg 'MUTANT|testPath'`), re-applied with the Edit tool, and only then
  scored. The passing-against-pristine run is NOT counted as mutant
  evidence.

## Probe — the journey completes once PR #888 lands

- Scratch worktree = this branch + cherry-picked 349cf752 (PR #888's fix):
  run 1 `result=complete` exit 0; run 2 `result=complete` exit 0 — the
  full two-feature journey green end-to-end, zero ownership conflicts.
  Confirms the ONLY remaining master defect on this journey is #877's, and
  this PR's pin stays valid after #888 merges.
