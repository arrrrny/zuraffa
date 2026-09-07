# Bug Verification: zfa entity create: primitive types (bool/int/double) rejected — must scaffold an enum dir first

- **Slug**: entity-create-primitive-types-rejected (GitHub issue #1270)
- **Tested**: 2026-09-07
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified

## Summary

`Boolean` (and primitive spellings generally) now resolve in
`zfa entity create` / `zfa entity add-field` without any enum/entity
directory scaffolding: the parsed field type is normalized at the shared
`_parseFields` resolution point (`boolean` → `bool`, case-insensitive,
word-bounded) before `EntityTypeValidator` runs, and the generated entity
declares the Dart built-in directly (`bool get isLoading;`). The issue repro
exits 0 and the custom-type contract is unchanged.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Root-cause reproduction | `zfa entity create -n Login --field isLoading:Boolean --field hasError:Boolean` (pre-fix, sandbox) | fail | exit 1; `Unknown type "Boolean" … no matching entity directory or enum file found under lib/src/domain/entities.` — the verbatim issue signature. |
| Empirical type matrix (pre-fix) | same CLI, `int`/`double`/`num`/`bool`/`String` | pass (pre-existing) | all exit 0 and emit the built-in (`int get value;` etc.) — the broken surface was the `Boolean` alias (+ `add-field` via the shared parse). |
| New tests (RED) | `dart test test/commands/entity_create_primitive_types_test.dart` | fail (expected) | `+2 -3` — 3 failures carry the issue signature for repro / alias forms / add-field. |
| New tests (GREEN) | same command, post-fix | pass | `+8: All tests passed!` — 5 CLI-level + 3 unit. |
| Real-CLI repro (post-fix) | sandbox rerun of the issue command | pass | exit 0; generated `login/login.dart` contains `bool get isLoading;` and `bool get hasError;`, no `Boolean` token. |
| add-field parity | `zfa entity add-field -n Task --field done:Boolean` | pass | exit 0; `bool get done;` appended. |
| Custom-type regression guard | `zfa entity create -n Order --fields product:Product` (no Product on disk) | pass | still exits non-zero with the #296 error; no file written. |
| Neighbor suites (changed code) | `dart test test/utils` / `dart test test/commands` | pass | 104/104 and 314/314; includes the untouched `entity_type_validator_test.dart` (29) and entity command suites (34). |
| Mutation sampling | deliberate mutants M1 (wiring removed) / M2 (case-sensitive blanket replace) | pass | both killed (3 and 2 test failures respectively); restore verified byte-identical, suite re-green 8/8. |
| Static analysis | `dart analyze` on all changed dart files | pass | No issues found! |
| Formatting | `dart format` on touched files; `--set-exit-if-changed` | pass | 0 changed. (Pre-existing drift in unrelated `specs/1142-…/tdd/evidence/*.dart` fixtures left untouched — outside this bug's scope and receipt-bound.) |

Full evidence: ./tdd/verification.md and ./tdd/cycle-log.md.
