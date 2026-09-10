# Test List: zfa-setup-app-name

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | the shell is emitted at `lib/src/app/zik_zak.dart` declaring `class ZikZakApp extends StatelessWidget`, and the command exits 0. | AC-1 | DONE |
| A2 | it imports `package:zik_zak/src/app/zik_zak.dart` and calls `runApp(const ZikZakApp());`. | AC-2 | DONE |
| A3 | the shell is emitted at `lib/src/app/xyx.dart` declaring `class XyxApp`, and `main.dart` imports `package:xyx/src/app/xyx.dart` and calls `runApp(const XyxApp());`. | AC-3 | DONE |
| A4 | the file is `lib/src/app/my_app.dart` and the class is `MyApp` (the derivation collapses to the legacy literals). | AC-4 | DONE |
| A5 | the shell is emitted at `<outputDir>/app/zik_zak.dart` declaring `class ZikZakApp`, and `main.dart` imports `package:zik_zak/src/app/zik_zak.dart` and calls `runApp(const ZikZakApp());`. | AC-5 | DONE |
| A6 | the legacy file is left untouched (never deleted) and an informational notice names it. | AC-6 | DONE |
| A7 | `main.dart` calls `runApp(const ZikZakApp());` and the X-Ray wiring/compilation contract is unchanged. | AC-7 | DONE |
| A8 | the app-shell, setup, and related regression tests pass (with their pinned expectations updated to the new derived names where the fix changes them). | AC-8 | DONE |

## Outer loop: widget behaviors

UI acceptance scenarios (bug #830): asserted through a testWidgets pair — a view-builder subject stub plus a widget test that pumps the view and asserts the scenario.

The `kind` cell is the finder-kind taxonomy (issue #1140): the scenario verbs' predicted assertion classes — presence, absence, route-outcome, enabled-state, sequence — or `none` when no finder is derivable. `zfa tdd gen` selects the assertion template by it and refuses a row whose kind column drifted from the scenario prose; verify-red's kind gate (issue #959/#964) certifies on the same vocabulary.

| id | behavior | kind | traces | state |
| -- | -------- | ---- | ------ | ----- |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |

## Routing provenance

Per-behavior routing decisions (issue #951): what each decision consulted — a declared marker/contract row, or the labeled legacy fallback to migrate.

route: A1 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A2 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A3 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A4 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A5 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A6 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A7 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A8 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]

