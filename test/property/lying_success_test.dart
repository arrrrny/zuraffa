@Tags(['property'])
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/cache_command.dart';
import 'package:zuraffa/src/commands/controller_command.dart';
import 'package:zuraffa/src/commands/datasource_command.dart';
import 'package:zuraffa/src/commands/gql_command.dart';
import 'package:zuraffa/src/commands/graphql_command.dart';
import 'package:zuraffa/src/commands/gym_command.dart';
import 'package:zuraffa/src/commands/observer_command.dart';
import 'package:zuraffa/src/commands/presenter_command.dart';
import 'package:zuraffa/src/commands/sync_command.dart';
import 'package:zuraffa/src/commands/view_command.dart';
import 'package:zuraffa/src/plugins/cache/cache_plugin.dart';
import 'package:zuraffa/src/plugins/controller/controller_plugin.dart';
import 'package:zuraffa/src/plugins/datasource/datasource_plugin.dart';
import 'package:zuraffa/src/plugins/gql/gql_plugin.dart';
import 'package:zuraffa/src/plugins/graphql/graphql_plugin.dart';
import 'package:zuraffa/src/plugins/gym/gym_plugin.dart';
import 'package:zuraffa/src/plugins/observer/observer_plugin.dart';
import 'package:zuraffa/src/plugins/presenter/presenter_plugin.dart';
import 'package:zuraffa/src/plugins/sync/sync_plugin.dart';
import 'package:zuraffa/src/plugins/view/view_plugin.dart';

/// Every registered command must NOT exit 0 on bare invocation (no args).
///
/// This is the "lying-success" property: a command that prints success or
/// exits 0 when given no arguments is lying about the outcome.
///
/// Commands with auto-registered subcommands (PluginCommand subclasses) are
/// rejected by the `args` framework with a UsageException before `run()` is
/// called — that IS a non-zero exit. Commands without subcommands must
/// handle bare invocation in their own `run()` with `exitCode = 64`.
void main() {
  late CommandRunner<void> runner;

  setUp(() {
    runner = CommandRunner<void>('zfa', 'test runner');
    final out = 'lib/src';
    runner.addCommand(ViewCommand(ViewPlugin(outputDir: out)));
    runner.addCommand(ControllerCommand(ControllerPlugin(outputDir: out)));
    runner.addCommand(DataSourceCommand(DataSourcePlugin(outputDir: out)));
    runner.addCommand(GymCommand(GymPlugin(outputDir: out)));
    runner.addCommand(PresenterCommand(PresenterPlugin(outputDir: out)));
    runner.addCommand(GqlCommand(GqlPlugin(outputDir: out)));
    runner.addCommand(GraphqlCommand(GraphqlPlugin(outputDir: out)));
    runner.addCommand(ObserverCommand(ObserverPlugin(outputDir: out)));
    runner.addCommand(CacheCommand(CachePlugin(outputDir: out)));
    runner.addCommand(SyncCommand(SyncPlugin(outputDir: out)));
  });

  final commandsUnderTest = <String>[
    'view',
    'controller',
    'datasource',
    'gym',
    'presenter',
    'gql',
    'graphql',
    'observer',
    'cache',
    'sync',
  ];

  for (final commandName in commandsUnderTest) {
    test('$commandName exits non-zero on bare invocation', () async {
      exitCode = 0;
      var threw = false;
      try {
        await runner.run([commandName]);
      } on UsageException {
        // The `args` framework rejects missing subcommands with a
        // UsageException before run() is called — this IS non-zero.
        threw = true;
      }
      final isNonZero = exitCode != 0 || threw;
      expect(
        isNonZero,
        isTrue,
        reason:
            'zfa $commandName with no args must exit non-zero '
            '(issue #995: lying-success sweep)',
      );
    });
  }
}
