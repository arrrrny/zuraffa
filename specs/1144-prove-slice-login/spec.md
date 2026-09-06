# Spec 1144 — [ZIKZAK-REBUILD] Prove slice on login: first real isolation → verify → merge cycle

Issue: https://github.com/arrrrny/zuraffa/issues/1144
Branch: `spec/1144-prove-slice-login`
Part of #1135 (EPIC 4: Isolation). Extends #961.

## Problem

The slice plugin (`cut`/`export`/`merge`/`verify`, feature 043) has 166
acceptance tests but **zero production use**. #961 declared the workflow —
`slice cut` → sandbox TDD → `slice verify --json` → `slice merge` — but the
pipeline had never been driven end-to-end against a real host app. This spec
is the proof: cut the login feature from zik_zak, develop it in the sandbox
with the full TDD loop, emit the verify receipt, merge back with zero
hand-edits, and keep the host suite green.

## Environment note (honest scope)

`~/Developer/zik_zak` is not present on the proof machine (the same condition
recorded in spec 1114's verification). The proof runs against
**zik_zak-stand-in**: a real Flutter 3.47.2 app at the zuraffa conventions —
VPC login page (`lib/src/presentation/pages/login/`), `get_it` service
locator with `register*()` DI files under `lib/src/di/`, hosted `zuraffa
^6.1.0`, and a `flutter test` baseline suite. Every pipeline step is driven
by the real CLI (`dart run bin/zfa.dart slice …`), not by test doubles.

## What was proven (the cycle, verbatim commands)

```
zfa slice cut login --entry login --feature login \
  --route '/login:LoginView' \
  --dependency 'AuthRepository:service:signIn(String email, String password) -> User, signOut() -> void:P1:test/mock/dependencies/auth_repository/fake_auth_repository.dart'
# → 7 project files, 1 boundary interface (AuthRepository via getIt)

cd .zuraffa/slices/login
flutter pub get && dart analyze   # → No issues found!
# sandbox TDD: RED (failing sign-out test) → make → GREEN
flutter test                      # → All tests passed!

cd back to the host
zfa slice verify --json login     # → exit 0; all three checks pass
zfa slice merge login --yes       # → exit 0; Host suite: green
flutter test (host)               # → 5/5 pass (4 baseline + 1 landed)
```

## RED → GREEN: what the proof run surfaced and fixed

The first real run reproduced the RED state and exposed five CLI/generator
defects the 166 tests could not see (they use pure-Dart fixtures and
in-process capability calls). All fixes ship in this branch with tests:

| # | RED evidence (real CLI run) | GREEN fix |
|---|---|---|
| 1 | `zfa slice cut … --feature login` → `Could not find an option named "--feature"` — the 073 runnable-sandbox composition was unreachable from the CLI | `cut` CLI: `--feature`, `--route` (`splitCommas: false` — contract rows carry commas), `--dependency`; declared facts flow into the capability; usage/help updated |
| 2 | `zfa slice verify --json login` → `Could not find an option named "--json"` — the machine verdict was unwritable from the CLI, while `slice merge`'s own fix hint instructs running exactly that command | `verify` CLI: `--json` flag wired through |
| 3 | Sandbox `dart analyze`: 10 errors — generated `main_slice.dart` hardcodes `package:flutter/material.dart`; composed `lib/router.dart` referenced `LoginPage` with no import; `lib/main.dart` called `buildSliceRouter()` which the router never defined; `pageFor` passed the builder as its own `BuildContext` | Router/main generators made consistent (`MaterialApp(routes: sliceRoutes(), initialRoute: …)`); declared pages resolve to their mirrored file and are imported; `pageFor(BuildContext, String)` fixed |
| 4 | Generated boundary mock referenced `User` without importing it — the mock resolves the interface's project-relative imports itself, rewritten for the mock's directory and filtered to the mirror set | `MockStubGenerator` re-emits mirrored interface imports; anchored at the project path (the interface source is read from the sandbox copy when included) |
| 5 | `slice merge` on a sandbox that ran `pub get`/tests: conflicts on `.dart_tool/`, `build/`, `pubspec.lock`, `verify-verdict.json` — ephemeral tooling state scanned as agent work | Merger skips ephemeral segments/files; a re-merge is idempotent (`main == sandbox` → skip for manifest files and for already-landed creations) |

Suite-driver selection (`dart test` vs `flutter test`) is pubspec-driven
(`suite_command.dart`): a Flutter sandbox tests under `flutter test`, a
pure-Dart sandbox under `dart test`; the same selection drives the merge
host-suite run. A Flutter host's suite could otherwise never run at all
(`dart test` cannot resolve `flutter_test` from the SDK).

## Acceptance scorecard (issue #1144)

| Criterion | Verdict | Evidence |
|---|---|---|
| Slice manifest shows correct ownership classification | **PROVED** | `--verbose` cut: `pages/login/*` → `owned` (3), domain/DI files → `shared` (4); boundary `AuthRepository` detected via getIt |
| Generated sandbox compiles (dart analyze clean) | **PROVED** | post-fix sandbox: `dart analyze` → `No issues found!` |
| Verify exit 0 with JSON verdict (self-contained, no unresolved imports) | **PROVED** | `verify --json login` → exit 0; `verify-verdict.json`: selfContainment pass, mockCertification pass, suiteState pass |
| Merge doesn't break host flutter test | **PROVED** | `slice merge login --yes` → exit 0, `Host suite: green`; host `flutter test` post-merge: **5/5** (4 baseline + 1 sandbox-authored logout test), `dart analyze` clean |
| First real proof that isolation → merge works | **PROVED** | the cycle above, zero post-merge hand-edits |

## Known limitations discovered (documented, not fixed here)

1. **Feature-slice merge stops at the gate** — for a composed FEATURE slice
   (`.zfa/slices/<id>/`), `_merge` runs the 1116 receipt audit and then
   returns without merging. The proof uses the cut-slice path (`.zuraffa/`),
   whose merge is fully implemented. Follow-up: wire the feature-slice
   merge-back (the receipt gate already works).
2. **Host DI barrel registration is not slice-carried** — `lib/src/di/index.dart`
   is outside the login walk graph, so a cut slice cannot land a registration
   call there (an agent-created copy would conflict). The agent-created
   `sign_out_usecase_di.dart` lands cleanly; wiring it into the barrel is the
   shared-file conformance problem EPIC 4 item 3 (#962) exists to solve.
3. **A fresh cut sandbox has no test directory** — the suite check correctly
   fails on absence (errors-are-an-api). The agent's first TDD cycle supplies
   the sandbox suite, exactly as the loop prescribes.

## Verification

See `tdd/verification.md` for the full audit: test-first evidence, red/green
transcripts, mutation-style revert discipline, and acceptance coverage.
