# TDD verification — spec 1144 (prove slice on login)

Feature: `1144-prove-slice-login` · Date: 2026-09-06 · Machine: Linux x64,
Dart 3.13.3, Flutter 3.47.2 (stable) · CLI under test:
`dart run bin/zfa.dart` from this repo at `spec/1144-prove-slice-login`.

This is a REAL verification: every claim below was executed on this machine
during this run; command transcripts are quoted verbatim. No step is claimed
that was not run.

## 1. What the cycle proved (end-to-end, zero hand-edits)

| Step | Command (CWD) | Result |
|---|---|---|
| Cut | `zfa slice cut login --entry login --feature login --route '/login:LoginView' --dependency 'AuthRepository:service:signIn(String email, String password) -> User, signOut() -> void:P1:test/mock/dependencies/auth_repository/fake_auth_repository.dart' --verbose` (zik_zak) | exit 0 — `Cut slice "login": 7 project files, 1 boundary interface.` |
| Ownership | same run, `--verbose` | `pages/login/{view,state,controller}.dart` → **owned** (3); `domain/entities/user/user.dart`, `domain/repositories/auth_repository.dart`, `domain/usecases/login/sign_in_usecase.dart`, `di/usecases/sign_in_usecase_di.dart` → **shared** (4); `boundary AuthRepository`; certified fake installed at the declared artifact path |
| Sandbox tooling | `flutter pub get && dart analyze` (sandbox) | `No issues found!` |
| Sandbox TDD — RED | write `test/login_logout_test.dart` FIRST (imports `SignOutUseCase`, calls `controller.logout()`), then `flutter test test/login_logout_test.dart` | **RED recorded** — compilation failure: `Error: Method not found: 'SignOutUseCase'.` / `Error: No named parameter with the name 'signOut'.` |
| Sandbox TDD — make | add `lib/src/domain/usecases/login/sign_out_usecase.dart`, `lib/src/di/usecases/sign_out_usecase_di.dart`, `LoginController.logout()` — all INSIDE the sandbox | — |
| Sandbox TDD — GREEN | `flutter test` (sandbox) | `00:00 +1: All tests passed!` · `dart analyze` → `No issues found!` |
| Verify receipt | `zfa slice verify --json login` (host root) | **exit 0** — `slice-verify: feature=login self-containment=pass mock-certification=pass suite=pass outcome=verified` |
| Merge gate | `zfa slice merge login --yes` (host root) | **exit 0** — sandbox deleted on clean merge; `Host suite: green` (the merge ran the host suite itself via the Flutter-aware runner) |
| Host post-merge | `dart analyze && flutter test` (host) | `No issues found!` · **`00:01 +5: All tests passed!`** — 4 baseline + 1 landed sandbox-authored test |

The verify receipt as written by the run (captured before the clean-merge
deleted the sandbox):

```json
{
  "check": "slice-verify",
  "selfContainment":  {"pass": true, "offenders": []},
  "mockCertification": {"pass": true, "offenders": []},
  "suiteState":       {"pass": true, "offenders": []},
  "passed": true
}
```

## 2. Test-first evidence (the loop saw red before green)

- The sandbox's new behavior (sign-out) had its test written BEFORE the
  implementation existed; the red run failed for the right reason (the
  behavior's symbols did not exist), not for an incidental one. The green
  run passed with no test edits — only implementation files were added.
- Every CLI/generator fix in this branch is test-first in the same sense:
  the RED was a real CLI failure captured in `specs/1144-prove-slice-login/spec.md`
  § RED → GREEN (e.g. `Could not find an option named "--json"`), and the
  tests that now pin the behavior were added with the fix.

## 3. New tests in the repo suite (7, all passing)

| Test | Pins |
|---|---|
| `slice_cli_declared_facts_test.dart` B1 | `cut --feature/--route/--dependency` records declared facts and composes the runnable sandbox (lib/main.dart, lib/router.dart importing the real page, lib/di.dart with the `sandbox.bind('dependencies/auth_repository')` token, certified fake artifact, receipts travel) |
| B2 | declared routes without `--feature` refuse with exit 1 |
| B3 | `verify --json` writes `verify-verdict.json` (flat named checks) and exits non-zero when a check fails — absence never passes |
| B4 | `suiteCommandFor` picks `flutter` for Flutter pubspecs, `dart` otherwise |
| `slice_merger_test.dart` B-1144a | `.dart_tool/`, `build/`, `pubspec.lock` in a sandbox are never scanned as agent-created (no conflicts, no leaks into the host) |
| B-1144b | a re-merge over an identical already-landed creation skips; a drifted one still conflicts |
| `conflict_detector_test.dart` U39c | `main == sandbox` (≠ cut) → `skip`, not conflict (idempotent re-merge) |

## 4. Repo suite state (honest counts)

- Slice test folder (`dart test --preset=all test/plugins/slice/`), this
  branch: **+232 −11** (243 tests).
- Same folder on pristine `master` (changes stashed): **+225 −11** (236
  tests) — the **same 11 failures pre-exist on master** in this environment;
  none were introduced or masked by this branch. All 7 new tests pass.
- Merger/detector folders: `+16 −0` after the change (13 pre-existing + 3 new).
- Generator folder: `+18 −0` (unchanged tests still pass after the scaffold
  and mock fixes — no assertion had to be weakened).

## 5. Mutation-style discipline

Generator fixes were validated by re-running the affected capability against
the real host after each change (re-cut → `dart analyze` → suite), not only
by unit tests:

- Router/mock fixes: re-cut produced `No issues found!` where the previous
  iteration produced 10 errors / 4 errors / 2 errors / 1 error — each
  intermediate failure mode is recorded in § RED → GREEN of `spec.md`.
- Merger idempotency: the merge was re-run until clean (attempt 1: 12
  ephemeral conflicts; attempt 2: 2; attempt 3: 3 self-landed-creation
  conflicts; final: exit 0). Each run's conflict list named exactly the
  files the fix targeted — the intermediate runs are the mutants, the final
  run is the kill. The host was restored between runs only by deleting the
  merge's own outputs (no source edits).
- No behavior artifacts were registered for mutation (no engine contracts in
  this slice), so mutation buckets are empty by design (`mutation_was_run:
  false`).

## 6. Acceptance-criteria coverage (issue #1144)

| # | Criterion | Coverage |
|---|---|---|
| 1 | Correct ownership classification | §1 Ownership row (cut `--verbose` transcript) |
| 2 | Generated sandbox compiles | §1 Sandbox tooling row |
| 3 | Verify exit 0 with JSON verdict | §1 Verify receipt row + receipt body |
| 4 | Merge doesn't break host flutter test | §1 Merge gate + Host post-merge rows (5/5) |
| 5 | First real proof isolation → merge works | §1 as a whole: cut → TDD → verify → merge → host green, zero hand-edits |

## 7. Smells and limitations (recorded, not hidden)

- The host app is a stand-in (see `spec.md` § Environment note): zik_zak
  proper is not on this machine. The stand-in is a real Flutter app with
  real get_it wiring; the proof is of the PIPELINE, driven by the real CLI.
- Feature-slice (compose/worktree) merge-back stops at the receipt gate —
  pre-existing on master, out of scope here, follow-up filed in
  `spec.md` § Known limitations.
- Host DI barrel registration (`di/index.dart`) is not slice-carried — the
  shared-file conformance gate is EPIC 4 item 3 (#962).
- The 11 pre-existing master failures were not triaged in this branch (they
  reproduce identically with the changes stashed; triage belongs to their
  own spec).
