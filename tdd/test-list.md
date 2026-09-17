# TDD test list — Bug #1677 scalar vacuous-green refusal prints the void/entity explanation

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| U1 | test/plugins/tdd/commands/bug_1677_scalar_vacuous_message_test.dart | unit (slow, driver) | a scalar contract's vacuous-green refusal (`add(int,int) -> int`, the #1651 marker + type-only `isA<int>()` shape) prints the #1651 scalar explanation — the declared return TYPE check the func dummy satisfies — and NEVER the #1308 void/entity template; `stopped_at=<id>:hand` and the `hand step:` line are unchanged | issue #1677 criterion (scalar branch) | RED → GREEN |
| U2 | test/plugins/tdd/commands/bug_1677_scalar_vacuous_message_test.dart | unit (slow, driver) | a void/entity contract's vacuous-green refusal keeps the #1308 hand-delta-seam explanation byte-for-byte (guard pin — the #1308 wording, the machine contract and the `hand step:` line unchanged) | issue #1677 criterion (void/entity branch) | GREEN (guard) |

Guard pins (pre-existing, unchanged and green against the fix — the family
the refusal message lives in):

| id | suite | description |
| -- | ----- | ----------- |
| U-1308-5/6/7/4 | test/plugins/tdd/issue_1308_vacuous_guard_remedy_driver_test.dart | the #1308 marker-present arm: named hand step + journal violation; fallback arm; fail-open unreadable; gen-warning forward |
| U5 | test/plugins/tdd/commands/bug_1651_driver_remedy_test.dart | the #1651 placeholder remedy (marker-ABSENT scalar dummy arm) — untouched |
| U-1651-* | test/plugins/tdd/bug_1651_type_only_vacuous_green_test.dart | the detector's vacuity boundary + the writer's marker emission — the `_typeOnlyScalarExpect` capture group must not change what the detector strips |
| U-1651-* | test/plugins/tdd/bug_1651_scenario_assertions_test.dart | the scenario-derived VALUE assertions (never marker-carrying) — untouched |
| e2e | test/plugins/tdd/commands/bug_1651_make_dummy_green_refusal_test.dart, test/plugins/tdd/bug_1651_vacuous_green_e2e_test.dart | the end-to-end gen → verify-red → func → make vacuous-green refusal — untouched |
| #1482 | test/plugins/tdd/issue_1482_run_preflight_test.dart | the run preflight — untouched |
| #1488/#1512/#1538 | test/plugins/tdd/bug_1488_acceptance_vacuous_green_test.dart, test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart, test/plugins/tdd/services/bug_1538_void_guard_compile_test.dart | the acceptance-lane and void-guard members of the vacuous family — untouched |
| #1320/#1388 | test/plugins/tdd/commands/bug_1320_declared_assertion_reachable_test.dart, test/plugins/tdd/commands/bug_1388_gen_traces_fingerprint_test.dart, test/plugins/tdd/commands/issue_1388_gen_reuse_fingerprint_test.dart | the gen-reuse/gen-fingerprint neighbors (assertion emission) — untouched |
| #1420/#1483/#1626 | test/plugins/tdd/bug_1420_vacuous_stop_declared_trace_test.dart, test/plugins/tdd/bug_1483_vacuous_green_remedy_shape_test.dart (+ driver), test/plugins/tdd/bug_1626_acceptance_remedy_driver_test.dart | the marker-absent arms' remedy shapes — untouched |

## Red evidence (pre-fix, this session)

`dart test --preset=all
test/plugins/tdd/commands/bug_1677_scalar_vacuous_message_test.dart`
on unfixed master a9329746 →

```
00:06 +0 -1: ... U1: a scalar contract's vacuous-green refusal prints the
             #1651 scalar explanation — never the void/entity template
00:13 +1 -1: Some tests failed.
```

The driver's verbatim stop (the bug, on screen):

```
zfa tdd run: step failed — behavior=U1 step=make outcome=vacuous-green
   make: behavior=U1 outcome=vacuous-green feature=1677-scalar-message
   the traced contract's return is void/an entity — the zfa:tdd: vacuous-guard marker IS the designed hand-delta seam (issue #1308): the assertion set is the UnimplementedError guard only, which make refuses vacuous-green (issue #1259).
   hand step: U1:hand — write an assertion on the observable outcome in test/tdd/1677-scalar-message/u1_test.dart (replace the vacuous-guard guard, remove the marker), then re-run `zfa tdd run 1677-scalar-message`.
```

`Which: does not contain 'the traced contract's return is scalar (int)'`
— U1 fails for the RIGHT reason (the void/entity template printed for a
scalar contract). U2 (the void/entity guard pin) passed pre-fix, as it
must.

## Green evidence (post-fix, this session)

```
dart test --preset=all test/plugins/tdd/commands/bug_1677_scalar_vacuous_message_test.dart
→ 00:14 +2: All tests passed!
```

Regression batches — see `tdd/verification.md`.
