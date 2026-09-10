// Acceptance test A2 — spec 1444-setup-zuraffa-app (PR #1462).
//
// source_criterion: AC-2 — the main.dart emitted by setup's shell path is
// runnable day zero: its `package:` imports resolve to the written glue
// files. Regression guard for the project-root-prefixed `outputDir` bug
// (review of PR #1462 @ 50c00964: passing `my_app/lib/src` into
// AppShellBuilder.buildMain emitted
// `package:my_app/../my_app/lib/src/app/my_app.dart`, which does not
// resolve — the builder derives imports from [outputDir] relative to
// `lib/`, so setup must pass the lib/-relative `lib/src`).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/app_shell/builders/app_shell_builder.dart';

void main() {
  group('A2 (AC-2): the emitted main.dart package imports resolve', () {
    test('buildMain with the setup output dir emits resolvable imports', () {
      const builder = AppShellBuilder();
      final main = builder.buildMain(
        appName: 'my_app',
        // Exactly the dir setup's _generateAppShell passes after the fix.
        outputDir: 'lib/src',
        diTakesGetIt: true,
        diIsAsync: false,
        coreImport: 'package:zuraffa_flutter/zuraffa_flutter.dart',
      );

      expect(main, contains("import 'package:my_app/src/app/my_app.dart';"));
      expect(main, contains("import 'package:my_app/src/di/index.dart';"));

      // No escaping path segments anywhere — a prefixed outputDir would
      // leak `../` into the emitted package URIs.
      expect(main, isNot(contains('..')));
      expect(main, isNot(contains('package:my_app/my_app/')));
    });
  });
}
