# Assessment — Issue #1189 (analyzer constraint breaks Flutter consumers)

## Root cause (empirically confirmed on Flutter 3.47.2 / Dart 3.13.2)

Two regular dependencies of the root package are hostile to Flutter
consumer resolution:

1. **`test: any` in `dependencies:` (pubspec.yaml line 66) — the direct
   blocker.** `flutter_test` pins `test_api 0.7.12` and `matcher 0.12.20`.
   The solver proves NO published `test` version fits the graph once
   graphql ^5.2.3 (web_socket_channel ^3.0.1) is present:
   `test` <1.25.5 needs web_socket_channel ^2.0.0; 1.25.13–1.28 needs
   matcher <0.12.18; 1.29–1.31.0 needs test_api 0.7.11 or analyzer <11;
   ≥1.31.1 needs test_api 0.7.13/0.7.14 or analyzer <14. Every branch is
   dead against flutter_test's pins, so the solver reports
   `zuraffa from path is incompatible with flutter_test from sdk`.

2. **`analyzer: ^14.3.0` in `dependencies:` — the reported constraint.**
   Its 14.3.0 lower bound is what forces `test` up the version ladder
   (only test ≥1.31.1 tolerates analyzer ≥14), closing every escape
   route. Any consumer graph that caps analyzer below 14.3.0 (e.g. an app
   dev-depending on an older `test`) also conflicts directly.

## Why analyzer cannot simply move to dev_dependencies

The report's first suggestion is conditional on analyzer being
generator/dev-only. It is NOT: `lib/zuraffa.dart` **publicly exports**
`src/core/ast/ast_helper.dart`, `file_parser.dart`, `ast_modifier.dart`,
`node_finder.dart` (lib/zuraffa.dart:241–244), and 30 lib/ files import
package:analyzer (commands, engine, plugins, core/ast). Every consumer
that imports `package:zuraffa/zuraffa.dart` compiles these sources;
dropping analyzer from the regular deps would turn a resolution failure
into a compile failure. Moving it to dev_dependencies is therefore
rejected.

Why `test` CAN move: every `package:test` reference in lib/src/ is inside
string templates that WRITE test files for generated consumer projects
(those projects declare test in their own dev_dependencies — verified in
package_scaffold.dart:392, behavior_test_writer.dart, contract_test_writer.dart,
golden_harness_writer.dart, smoke_test_writer.dart). The only real Dart
imports of package:test under lib/ are the lib/tdd/** self-hosting TDD
subjects — fixtures for THIS package's own corpus, which resolve against
this package's dev_dependencies.

## Remediation (what the fix implements)

1. Move `test: any` → `dev_dependencies:` (removes the direct blocker).
2. Widen analyzer to `>=14.0.0 <15.0.0` — verified honest: with a local
   override pinning analyzer 14.0.0, `dart analyze lib test` exits 0.
3. Silence the resulting `depend_on_referenced_packages` infos on the
   lib/tdd/** fixtures via analysis_options.yaml (baseline had 103 infos,
   the naive fix produced 218, the shipped fix restores 103).
4. Add `tools/flutter_smoke_gate.sh` + a `flutter_consumer_smoke` CI job:
   resolves example/ AND a synthesized core+flutter_test app with zero
   overrides, then `flutter test`-compiles the public surface. The gate
   is proven non-vacuous: it exits 1 on the pre-fix tree, 0 on the fix.
5. Drop example/'s `meta` override (its own comment said to drop it once
   Flutter re-pins meta; Flutter 3.47.2 pins meta ^1.18.3) so the consumer
   needs ZERO overrides — the bug's acceptance condition.

## Files likely to change

- `pubspec.yaml` (constraint fix)
- `analysis_options.yaml` (lint delta)
- `example/pubspec.yaml` (drop obsolete override)
- `tools/flutter_smoke_gate.sh` (new gate)
- `.github/workflows/ci.yaml` (wire the gate)
- `.specify/bugs/1189-analyzer-constraint-flutter/**` (records)

## Risks & considerations

- Widening the analyzer lower bound is only honest if the code compiles
  at 14.0.0 — verified before shipping (see cycle-log).
- Repo-wide `depend_on_referenced_packages: ignore` is broader than the
  fixture-scoped ideal; accepted because the pre-fix baseline proves zero
  occurrences outside lib/tdd/**, and the file already uses repo-wide
  `errors:` ignores by convention.
- No runtime code changes → no behavioral regression surface; the full
  fast suite re-run is the regression backstop.
