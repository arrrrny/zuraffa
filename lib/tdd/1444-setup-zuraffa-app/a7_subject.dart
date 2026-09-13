// GENERATED IMPLEMENTATION — hand-implemented per the paired test header's
// instruction ("Replace the subject's stub body with real implementation to
// make this test pass"), the sanctioned handcraft seam of the TDD loop.
//
// behavior_id: A7
// source_criterion: AC-7
// description: no errors are reported (the imports resolve correctly)
//
// Drives the real generation path — the CLI's AppShellBuilder.buildMain,
// the same emitter `zfa app shell` / `zfa setup` call — and inspects the
// emitted entrypoint instead of a hand-written fixture (review of PR
// #1609: the previous body asserted on a file it wrote itself). Every
// `package:` import in the emitted main.dart must name a file the shell
// path writes: the #1462 project-root-prefixed outputDir regression
// emitted `package:my_app/../my_app/lib/src/…`, which never resolves.
//
// ignore_for_file: non_constant_identifier_names
library;

import 'package:zuraffa/src/plugins/app_shell/builders/app_shell_builder.dart';

/// Scenario runner for behavior A7.
void subject_a7() {
  const builder = AppShellBuilder();
  const appName = 'demo_app';

  final main = builder.buildMain(
    appName: appName,
    naming: AppShellNaming.fromAppName(appName),
    // Exactly the lib/-relative outputDir setup's shell step passes
    // (the #1462 fix).
    outputDir: 'lib/src',
    diTakesGetIt: true,
    diIsAsync: false,
    coreImport: 'package:zuraffa_flutter/zuraffa_flutter.dart',
  );

  final imports = RegExp(
    r"import '([^']+)';",
  ).allMatches(main).map((match) => match.group(1)!).toList();

  const shellImport = 'package:$appName/src/app/demo_app.dart';
  const diImport = 'package:$appName/src/di/index.dart';
  if (!imports.contains(shellImport)) {
    throw StateError(
      'main.dart must import the shell widget it runs ($shellImport); '
      'got: $imports',
    );
  }
  if (!imports.contains(diImport)) {
    throw StateError(
      'main.dart must import the DI barrel it calls ($diImport); '
      'got: $imports',
    );
  }
  for (final uri in imports) {
    if (uri.contains('..')) {
      throw StateError('emitted import does not resolve (path escapes): $uri');
    }
  }

  if (!main.contains('void main()')) {
    throw StateError('generated main.dart is missing void main()');
  }
  if (!main.contains('setupDependencies(GetIt.instance);')) {
    throw StateError(
      'generated main.dart must call the canonical '
      'setupDependencies(GetIt.instance)',
    );
  }
  if (!main.contains('runApp(const DemoApp());')) {
    throw StateError(
      'generated main.dart must runApp the shell widget it imports',
    );
  }
}
