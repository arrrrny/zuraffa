# TDD test list — Bug #1488 acceptance vacuous green

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| A-1488-a1 | test/plugins/tdd/bug_1488_acceptance_vacuous_green_test.dart | acceptance | an acceptance test whose only assertion is the UnimplementedError guard cannot certify green — even when it passes (exit 1, outcome=vacuous-green, no green evidence) | FR-1488, MakeCommand step 3c gate | GREEN |
| A-1488-a2 | test/plugins/tdd/bug_1488_acceptance_vacuous_green_test.dart | acceptance | the acceptance test WITH an outcome assertion still certifies green — the refusal keys on the assertion set, not the lane | FR-1488, contentIsVacuousGreen backstop | GREEN |
| A-1488-a3 | test/plugins/tdd/bug_1488_acceptance_vacuous_green_test.dart | acceptance | kindless/legacy rows keep the fail-open skip transition — no resolvable kind, no refusal | FR-1488, #1259 fail-open contract | GREEN |
| U-1488-u1 | test/plugins/tdd/bug_1488_acceptance_vacuous_green_test.dart | unit | the unit lane refusal is unchanged — a guard-only unit test is still refused (#1259 U1 mirror) | FR-1488, unit-lane scope preserved | GREEN |
| U-1259-u3i | test/plugins/tdd/bug_1259_vacuous_green_test.dart | acceptance | INVERTED (cites #1488): acceptance rows are IN the vacuous-green refusal scope — the legacy skip pin now refuses | FR-1488, bug_1259 U3 | GREEN |
| A-1162ei | test/plugins/tdd/bug_1162_bug_subject_green_path_test.dart | acceptance | INVERTED (cites #1488): the unexpressible acceptance make is refused vacuous-green before the composition fallback runs (no compose dispatch) | FR-1488, bug_1162 A-1162e | GREEN |
| R-1259-u1u2 | test/plugins/tdd/bug_1259_vacuous_green_test.dart | unit | regression guard: the unit-lane U1/U2 pins pass byte-for-byte (refusal + assertion-set keying unchanged) | FR-1488, unit-lane scope preserved | GREEN |
| R-052-compose | test/plugins/tdd/make_command_test.dart | acceptance | regression guard: spec-052 compose-fallback acceptance greens (A13/U19, A13b) survive — real-assertion fixtures unaffected | FR-1488, spec 052 composition lane | GREEN |
| R-1345-redrive | test/plugins/tdd/bug_1345_placeholder_re_drive_test.dart | acceptance | regression guard: the tombstoned acceptance placeholder re-drive still re-enters compose (real-assertion fixture; the widened gate does not pre-empt it) | FR-1488, issue #1345 re-entry | GREEN |
| R-1488-analyze | tool | unit | `dart analyze` on the five changed files reports No issues found | FR-1488, no new warnings | GREEN |
| R-1488-format | tool | unit | `dart format .` reports 2764 files, 0 changed (tree format-clean) | FR-1488, formatter clean | GREEN |
