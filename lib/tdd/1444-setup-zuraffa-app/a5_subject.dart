// GENERATED IMPLEMENTATION — hand-implemented per the paired test header's
// instruction ("Replace the subject's stub body with real implementation to
// make this test pass"), the sanctioned handcraft seam of the TDD loop.
//
// behavior_id: A5
// source_criterion: AC-5
// description: the existing MaterialApp.router behavior is preserved (backward compatible)
//
// Drives the real generation path — the CLI's AppShellBuilder, the same
// emitter `zfa app shell` calls with `zuraffaApp: false` — and asserts on
// its actual output. The previous body wrote the "generated" file itself
// and asserted on its own text (review of PR #1609): a tautology that
// could never fail for a real regression in the shell emitter.
//
// ignore_for_file: non_constant_identifier_names
library;

import 'package:zuraffa/src/plugins/app_shell/builders/app_shell_builder.dart';

/// Scenario runner for behavior A5.
///
/// Emits the shell widget through the production [AppShellBuilder] and
/// verifies the default (backward-compatible) root stays
/// `MaterialApp.router`; the certified `ZuraffaApp` shell is only emitted
/// on explicit `zuraffaApp: true` (`zfa app shell --zuraffa-app`).
void subject_a5() {
  const builder = AppShellBuilder();

  // `zfa app shell` without --zuraffa-app (the backward-compatible path).
  final shell = builder.buildMyApp(title: 'Test App');
  if (!shell.contains('MaterialApp.router')) {
    throw StateError(
      'Expected the default shell to keep MaterialApp.router '
      '(backward compatible), but the emitted widget does not use it.',
    );
  }
  if (shell.contains('ZuraffaApp')) {
    throw StateError(
      'Expected MaterialApp.router (not ZuraffaApp) in the '
      'backward-compatible shell, but ZuraffaApp was emitted.',
    );
  }

  // The certified shell is opt-in: with `zuraffaApp: true` the widget IS
  // ZuraffaApp — proving the default is the preserved legacy behavior,
  // not a dead branch.
  final certified = builder.buildMyApp(zuraffaApp: true);
  if (!certified.contains('ZuraffaApp')) {
    throw StateError(
      'Expected the certified ZuraffaApp shell when zuraffaApp is '
      'requested, but it was not emitted.',
    );
  }
}
