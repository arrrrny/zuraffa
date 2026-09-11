# tdd.verify — Bug #1512 acceptance vacuous composition

- **Verified**: 2026-09-11, this session, on
  `fix/1512-acceptance-vacuous-composition` @ the fix commit (working
  tree, pre-push)
- **Toolchain**: Dart 3.13.3 (stable) on linux_x64
- **Scope**: tests for the two changed files + the new suite, then the
  chunked regression sweep below (the full suite in one process is out of
  scope for this machine — the nested-CLI spawn suites grow a ~9 GB
  kernel cache that exhausts the overlay disk; each chunk was cleaned per
  the disk-housekeeping obligation)

## Verdict: PASS

## 1. Static analysis

```
dart analyze lib/src/plugins/tdd/services/behavior_test_writer.dart \
             lib/src/plugins/tdd/services/generation_planner.dart \
             test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart
→ No issues found!
```

Full-project `dart analyze`: 112 `info` lints, **0 errors / 0 warnings**,
identical with the fix stashed (pre-change baseline = 112) — **no new
issues**.

## 2. The bug suite (red → green, REAL run in this session)

```
dart test test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart
```

- RED (pre-fix): `00:00 +6 -7: Some tests failed.` — every failure the bug
  itself: declared args discarded (`subject.subject_a1();` + `return null;`),
  no declared-outcome assertion / no marker seam on the acceptance guard,
  and every acceptance summary planned `unexpressible`
- GREEN (post-fix): `00:00 +13: All tests passed!`

REQUIRED check — the acceptance capture threads declared args and returns
the declared result: PROVED by A-1512-a1/a2/a3 (scalar literal reaches the
call site; `Object?` degradation captures; the void case stays
compile-safe while still threading args).

REQUIRED check — the acceptance assertion sits on the declared outcome
surface: PROVED by A-1512-b1/b2/b3 (`isA<T>()` non-vacuous; entity and
undeclared guards carry the `zfa:tdd: vacuous-guard` marker seam and are
mechanically refused by `contentIsVacuousGreen`).

REQUIRED check — the planner returns a real make surface for acceptance
rows: PROVED by A-1512-c1/c2/c3 (compose lane; entity pipeline with the
exact #758 argv; explicit target precedence), c4 (the honest #758 refusal
stays), c5 (non-acceptance rows keep the generic misfire).

REQUIRED check — the unit lane is unchanged: PROVED by A-1512-d1/d2 plus
the pre-existing `behavior_test_writer_test.dart` (both copies),
`subject_writer_test.dart` (both copies), `bug_1259_vacuous_green_test`,
`bug_912_literal_safety_test`, `bug_1035` pins — all green.

## 3. Chunked regression sweep (REAL runs in this session)

| Chunk | Result |
| ----- | ------ |
| `test/plugins/tdd/services/` (868 tests) | `All tests passed!` |
| `test/plugins/tdd/commands/` (507 tests) | `All tests passed!` |
| `test/plugins/tdd/*_test.dart` root bug suites (460 tests, 4 batches) | `All tests passed!` (every batch) |
| `test/cli/` (230 tests) | `All tests passed!` |
| `test/commands/` (370 tests, 2 batches) | `All tests passed!` |
| mapped suites re-run post-`dart format` (51 tests) | `All tests passed!` |

**No new failures anywhere.**

## 4. Formatting

```
dart format lib/src/plugins/tdd/services/behavior_test_writer.dart \
            lib/src/plugins/tdd/services/generation_planner.dart \
            test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart
→ Formatted 3 files (2 changed)
```

`generation_planner.dart` was already format-clean; the two reformats are
whitespace-only and the suites were re-run after formatting.

## 5. Environment notes (honest recording)

- The runner's `/tmp` writes exhausted the sandbox overlay disk twice
  (errno 28) — recovered by purging `dart_test.kernel.*` caches (the
  standing disk-housekeeping obligation) and redirecting `TMPDIR`; the
  one load-error this caused (`bug_1357_registry_path_reanchor_test`)
  passes in isolation and in its chunk.
- `dart pub get` resolves the host package cleanly; the `example/`
  subpackage needs a Flutter SDK (pre-existing, out of scope).
