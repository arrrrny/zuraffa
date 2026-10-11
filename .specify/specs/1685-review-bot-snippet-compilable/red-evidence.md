# Red evidence — spec 1685 (captured in this session, pre-fix)

## 1. The bug reproduced verbatim (the issue's error, this session)

The bot's snippet (`addTearDown(_tmp.deleteRecursively)` — inline comment
id 4023967373 on arrrrny/zuraffa_browser#165) applied verbatim inside the
standard wrapper (dart:io + package:test — the snippet's reachable
surface), analyzed with Dart 3.13.4:

```
$ dart analyze build/1685_repro_snippet_test.dart
Analyzing 1685_repro_snippet_test.dart...

  error - 1685_repro_snippet_test.dart:21:22 - The getter 'deleteRecursively' isn't defined for the type 'Directory'. Try importing the library that defines 'deleteRecursively', correcting the name to the name of an existing getter, or defining a getter or field named 'deleteRecursively'. - undefined_getter
   info - 1685_repro_snippet_test.dart:1:1 - The file name '1685_repro_snippet_test.dart' isn't a lower_case_with_underscores identifier. Try changing the name to follow the lower_case_with_underscores style. - file_names
   info - 1685_repro_snippet_test.dart:20:11 - The local variable '_tmp' starts with an underscore. Try renaming the variable to not start with an underscore. - no_leading_underscores_for_local_identifiers

3 issues found.
```

The `error` line is the issue's exact failure (`undefined_getter`); the
two `info` lines are lint notes on the reproduction wrapper itself, not
the snippet. This is the honest red for the BUG: the snippet's cleanup
call names an API that exists nowhere in its reachable surface.

## 2. The new seam's honest red (regression suite pre-implementation)

`test/plugins/tdd/commands/spec_1685_review_bot_snippet_compilable_test.dart`
imports `package:zuraffa/src/plugins/tdd/services/ci_referee/review_snippets.dart`
and `.../snippet_compile_check.dart` — which do not exist before the fix:

```
$ dart test test/plugins/tdd/commands/spec_1685_review_bot_snippet_compilable_test.dart
00:00 +0 -1: Some tests failed.
  loading .../spec_1685_review_bot_snippet_compilable_test.dart [E]
  Failed to load "...": Error when reading
  .../snippet_compile_check.dart: No such file or directory.
```

The compile-error red is the honest first red for a NEW seam: pre-fix
there is no snippet template catalog / validation gate at all — which IS
the root cause (nothing validates between "template rendered" and
"suggestion posted").
