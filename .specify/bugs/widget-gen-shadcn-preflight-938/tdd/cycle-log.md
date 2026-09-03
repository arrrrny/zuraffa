# TDD Cycle Log — widget-gen shadcn preflight (bug #938)

feature: widget-gen-shadcn-preflight-938 (GitHub issue #938)
branch: fix/938-widget-gen-shadcn-preflight
loop: red → green → refactor(n/a) → verify

## RED (recorded before the fix existed)

Test commit: `041cce12` — "test(938): widget-lane shadcn preflight pins …"
(contains ONLY test files + bug records; the lib fix is NOT in this commit).

Run at that tree (lib reverted to master via `git stash -- lib/`):

```
$ dart test test/plugins/tdd/commands/bug_938_widget_shadcn_preflight_test.dart
  Expected: not <0>
    Actual: <0>
00:00 +3 -1: Some tests failed.
```

The failing test is the issue-#938 acceptance pin: on a shadcn_ui-less pubspec,
`zfa tdd gen` (widget row) exited 0 and wrote the artifact pair — the exact
defect (the emitted test imports `package:shadcn_ui/shadcn_ui.dart` at line 21
and can only die at `verify-red` compile-error; analyzer ground truth recorded
in `red-evidence.md`).

The unit pins are COMPILE-red at this tree (new API surface, the #912
precedent):

```
$ dart test test/plugins/tdd/services/bug_938_shadcn_preflight_unit_test.dart
bug_938_shadcn_preflight_unit_test.dart:36:12: Error: Undefined name
'WidgetShadcnPreflight'.
```

CLI ground truth captured before any fix (real binary, fresh-project fixture,
pubspec = flutter + zorphy_annotation, NO shadcn_ui):

```
$ zfa tdd gen A1            # widget row
ownership: created/created  # ← defect: artifacts written
{"command":"gen","verdict":"created","kind":"widget",...}
$ dart analyze <emitted test>
error - a1_test.dart:21:8 - Target of URI doesn't exist:
'package:shadcn_ui/shadcn_ui.dart' - uri_does_not_exist
```

## GREEN

Fix commit: `e52739d8` — "fix(938): widget gen preflight — exit with --> fix:
when shadcn_ui absent".

```
$ dart test test/plugins/tdd/commands/bug_938_widget_shadcn_preflight_test.dart \
            test/plugins/tdd/services/bug_938_shadcn_preflight_unit_test.dart
00:00 +11: All tests passed!
```

End-to-end at the fix (real binary):

```
# shadcn-less fresh project:
$ zfa tdd gen A1
--> fix: flutter pub add shadcn_ui (widget-lane behaviors boot a ShadApp shell)
{"command":"gen","behavior":"A1","verdict":"refused",...,"kind":"widget"}
EXIT=1                      # no artifacts written, no registry append

# after the named remedy (pubspec declares shadcn_ui):
$ zfa tdd gen A1
{"command":"gen","behavior":"A1","verdict":"created","kind":"widget",...}
EXIT=0                      # pair created as before
```

## REFACTOR

None required (the preflight is a single read-only probe + one guard clause at
the FR-002 boundary; no duplication introduced).

## VERIFY (suite)

Chunked fast suite (`tools/run_tests_chunked.sh` protocol, per-folder chunks
with kernel-cache hygiene): 68/68 chunks visited, 0 failures, with the fix in
place — including `test/plugins/tdd/commands` and `test/plugins/tdd/services`.
`dart analyze`: zero new errors vs master (branch errors are a strict subset of
master's 33 pre-existing `examples/` diagnostics; none touch the changed
files). `dart format .`: 0 changed.
