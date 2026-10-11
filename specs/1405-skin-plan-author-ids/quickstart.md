# Quickstart: 1405 — verify the skin plan author fix

## Reproduce the original malformation (pre-fix tree, for reference)

1. Seed a feature spec whose SKIN lane declares:
   `behaviors: [Sign In header and subtitle, W1 (renders the login screen
   pixel-perfect, W2, a full-width guest outline button, an or divider]`.
2. `dart run bin/zfa.dart tdd plan <feature>` — pre-fix, this writes
   `04-SKIN.md` with prose in the id column and exits 0.

## Verify the fix

1. Same spec → the plan exits 2, prints
   `skin plan validator: declared skin behavior "Sign In header and
   subtitle" carries no W<digits> pattern ...`, and writes no
   `04-SKIN.md`.
2. Sanitizable-only spec (`behaviors: [W1 (renders the login screen
   pixel-perfect, W2]`) → exit 0; `04-SKIN.md` carries
   `| W1 | renders the login screen pixel-perfect | ... |`.
3. Clean spec (`behaviors: [W1-W9]` with annotations) → exit 0; nine W
   rows; the test-list reader resolves nine skin behaviors.
4. Canonical issue-#1000 fixture → exit 0, unchanged shape (backward
   compatibility).

## Run the tests

```bash
dart test test/plugins/tdd/services/skin_plan_author_test.dart
dart test test/plugins/tdd/commands/issue_1405_skin_plan_author_ids_test.dart
```
