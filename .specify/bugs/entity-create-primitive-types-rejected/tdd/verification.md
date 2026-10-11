---
feature: entity-create-primitive-types-rejected
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: d3679e0f (branch fix/1270-entity-create-primitive-types-rejected, pre-commit)
behaviors: 5
proven: 5
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 3
criteria_covered: 3
mutation_score: 2/2 deliberate mutants killed (M1 wiring-removed → 3 tests red; M2 case-sensitive-blanket-replace → 2 tests red); no survivors; restore verified byte-identical (git diff = the fix only) and suite re-greened 8/8
mutants_survived: 0
suite: new suite entity_create_primitive_types_test.dart RED pre-fix (+2 -3, failures carry the exact issue signature) → GREEN post-fix (8/8); targeted neighbors for the changed code: dart test test/utils 104/104, dart test test/commands 314/314; dart analyze on all changed dart files: No issues found; dart format clean on every touched file (dart format --set-exit-if-changed: 0 changed); real-CLI repro on a live sandbox: exit 1 + "Unknown type Boolean" pre-fix → exit 0 + `bool get isLoading;` / `bool get hasError;` post-fix
---

# TDD Verification: fix(1270) — entity create recognizes built-in primitive types

**Verdict: PASS.** The bug is real and the fix is proven at three levels:
(1) the new `test/commands/entity_create_primitive_types_test.dart` suite
runs RED pre-fix for the RIGHT reason — every failure carries the verbatim
issue signature (`Expected: <0> / Actual: <1>` + `Unknown type "Boolean" …
no matching entity directory or enum file found under
lib/src/domain/entities`) for the issue repro, the generic/nullable alias
forms, and the `add-field` shared path; (2) the minimal fix (a pure alias
normalizer on `EntityUtils` + one type-only `copyWith` at the shared
`_parseFields` resolution point) turns the suite GREEN 8/8 and a live CLI
repro emits inline Dart built-ins (`bool get isLoading;`) with exit 0 — the
inline-primitive remediation preferred by the assessment; (3) the targeted
neighbor suites for the changed code are green (test/utils 104, test/commands
314) and the custom-type contract is regression-pinned: a `Product` field
with no entity dir/enum file still aborts non-zero with the #296 error and
writes nothing. 2/2 deliberate mutants killed. No existing test was weakened.

## Test-first evidence

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| B1 — the issue repro `entity create -n Login --field isLoading:Boolean --field hasError:Boolean` exits 0 and emits inline primitives | PROVEN | RED first: exit 1 with `Unknown type "Boolean" for field "isLoading"/"hasError"` (both the subprocess test and a manual pre-fix CLI run). Post-fix: exit 0, `✓ Created entity`, and the generated `login/login.dart` contains `bool get isLoading;` + `bool get hasError;` with no `Boolean` token anywhere |
| B2 — every core primitive (bool/int/double/String/num) resolves and is emitted directly as the Dart built-in | PROVEN | `--fields title:String,count:int,ratio:double,active:bool,score:num` → exit 0 and all five getters asserted on the generated source. (RED-phase note: these spellings were already correct — the test pins the contract so the alias fix cannot regress them) |
| B3 — the alias normalizes inside generics and nullability (`List<Boolean>`, `Boolean?`, `Map<String, Boolean>`) | PROVEN | RED first (exit 1, Unknown type). Post-fix: `List<bool> get flags;`, `bool? get maybe;`, `Map<String, bool> get rate;`, source contains no `Boolean` |
| B4 — add-field shares the primitive resolution (`add-field -n Task --field done:Boolean` appends `bool get done;`) | PROVEN | RED first (exit 1). Post-fix: exit 0, entity source asserts `bool get done;`, no `Boolean` |
| B5 — custom (non-primitive) resolution is unchanged | PROVEN | `create -n Order --fields product:Product` (no Product on disk) still exits non-zero, prints `field type(s) could not be resolved` + `Unknown type "Product"`, and writes no file — asserted in-suite; plus test/utils/entity_type_validator_test.dart (29 tests) and test/commands (314) green over the changed code |

## Mutation audit (deliberate-mutant sampling — no mutation tool in profile, per tdd-profile)

| Mutant | Change | Expected to catch | Result |
| ------ | ------ | ----------------- | ------ |
| M1 | disable the `_parseFields` normalization wiring (plain `FieldDefinition.parse`) | B1/B3/B4 must go red | KILLED — `+5 -3: Some tests failed.` (the three alias-acceptance tests) |
| M2 | weaken the normalizer to case-sensitive blanket `replaceAll('Boolean', 'bool')` (no word boundary) | case variants + `BooleanFilter` corruption must be caught | KILLED — `+6 -2: Some tests failed.` (`every spelling` unit test + `leaves built-ins and custom types untouched`) |

Restoration verified after each mutant: `git diff --stat` shows exactly the
2-file fix (+45/-1) and nothing else; the suite re-ran GREEN 8/8 on the
restored bytes. No test was edited during the mutation passes.

## Rubric notes

- No assertion-free, tautological, or implementation-mirroring tests; the CLI
  tests assert observable exits + generated-file contents, the unit tests
  assert the normalizer's input→output contract including negative space.
- The red is recorded verbatim in `tdd/cycle-log.md` with commands and the
  decisive output lines; the compile-time-withheld unit group is disclosed
  there (behavioral red recorded, unit group ships green in the same file).
- Suite scope: per the cloud-agent verify constraint ("only test what you
  changed — never the full suite"), the full-suite chunked runner was
  attempted and died on infrastructure mid-run without producing any test
  failure; in its place the two chunks covering the changed code ran green
  (test/utils 104/104, test/commands 314/314) plus the targeted entity
  neighbor files (34 tests) and the new suite (8 tests).
