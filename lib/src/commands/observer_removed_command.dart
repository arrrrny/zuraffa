import 'dart:io';

import 'package:args/command_runner.dart';

/// Issue #1149 (kill list, part of EPIC #1132 Machine Contract): the
/// observer plugin was REMOVED.
///
/// The plugin had zero tests, zero artifacts in zik_zak or zikzak_demo,
/// and generated files importing entity barrels that do not exist in a
/// bare project. The modern approach is direct stream subscription: the
/// UseCase result already exposes the stream the old generated observer
/// wrapped, so the indirection only consumed maintenance and deceived
/// agents about what works.
///
/// Instead of vanishing silently, the command survives as an honest
/// removal verdict: it prints why the plugin is gone, points at the
/// replacement, and exits 64 (usage/availability failure) — never 0.
class ObserverRemovedCommand extends Command<void> {
  static const String verdict = '''
❌ The observer plugin was REMOVED (issue #1149, part of EPIC #1132
   Machine Contract).

   Why: zero tests, zero artifacts in any demo app, and generated files
   that could not compile against a bare project. It consumed
   maintenance while promising an abstraction nothing used.

   The modern approach is direct stream subscription — the UseCase
   result already exposes the stream the generated observer wrapped:

     final stream = context.useCase(GetProductListUseCase(di.get()));
     stream.listen(
       (data) => ...,
       onError: (failure) => ...,
       onDone: () => ...,
     );

   See docs/state-management.md for the stream-first state pattern.
''';

  @override
  String get name => 'observer';

  @override
  String get description =>
      'REMOVED (issue #1149) — subscribe directly to the UseCase result '
      'stream instead';

  @override
  String get invocation => 'zfa observer <subcommand> [arguments]';

  @override
  Future<void> run() async {
    // print() (zone-capturable) so scripted pipelines, test harnesses and
    // `runCapturing` all see the verdict; the exit code carries the failure.
    print(verdict);
    exitCode = 64;
  }
}
