# RED evidence — bug #938 (widget-gen shadcn preflight)

Fixture: fresh zfa-style project — pubspec declares flutter + zorphy_annotation,
NO shadcn_ui (the issue's repro shape, issue.md).

- `zfa tdd gen A1` (widget row) currently EXITS 0 and writes the artifact pair.
- The generated test imports `package:shadcn_ui/shadcn_ui.dart` and pumps
  `ShadApp` — unresolvable on this project.
- `dart analyze` on the generated test (ground truth the verify-red step dies
  on — compile-error, never an honest RED):

```
error - a1_test.dart:21:8 - Target of URI doesn't exist: 'package:shadcn_ui/shadcn_ui.dart'. Try creating the file referenced by the URI, or try using a URI for a file that does exist. - uri_does_not_exist
```

(The pure-dart analyze context also reports the flutter/flutter_test URIs — in
the real fresh Flutter project those resolve; `shadcn_ui` is the one that does
not, which is this bug. Note the generated import sits at line 21 — the SAME
line the issue cites: `test/tdd/002-login/a1_test.dart:21:8`.)

- Acceptance test (test/plugins/tdd/commands/bug_938_widget_shadcn_preflight_test.dart):
  `+3 -1` — ONLY the issue-#938 acceptance test fails:
  "shadcn-less project: widget gen exits non-zero with the --> fix: line and
  writes NO artifacts" → Expected exitCode ≠ 0, Actual 0.
