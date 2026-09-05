// Probe fixture for the bug #856 contract suite
// (dead_positional_grammar_test.dart).
//
// Runs ONE plugin command's run() directly — the only reachability run()
// has left now that the CLI dispatch always intercepts — and exits with
// whatever the command left in the process exit code. The test suite
// spawns this as a subprocess so an exit() inside a command under test
// (mock's master no-args branch) cannot kill the test runner.
//
// Usage: dart run test/commands/fixtures/plugin_run_probe.dart <name>
library;

import 'package:zuraffa/src/commands/mock_command.dart';
import 'package:zuraffa/src/commands/modular_di_command.dart';
import 'package:zuraffa/src/commands/provider_command.dart';
import 'package:zuraffa/src/commands/repository_command.dart';
import 'package:zuraffa/src/commands/route_command.dart';
import 'package:zuraffa/src/commands/service_command.dart';
import 'package:zuraffa/src/commands/sqlite_command.dart';
import 'package:zuraffa/src/commands/state_command.dart';
import 'package:zuraffa/src/commands/test_command.dart';
import 'package:zuraffa/src/commands/usecase_command.dart';
import 'package:zuraffa/src/plugins/di/di_plugin.dart';
import 'package:zuraffa/src/plugins/mock/mock_plugin.dart';
import 'package:zuraffa/src/plugins/provider/provider_plugin.dart';
import 'package:zuraffa/src/plugins/repository/repository_plugin.dart';
import 'package:zuraffa/src/plugins/route/route_plugin.dart';
import 'package:zuraffa/src/plugins/service/service_plugin.dart';
import 'package:zuraffa/src/plugins/sqlite/sqlite_plugin.dart';
import 'package:zuraffa/src/plugins/state/state_plugin.dart';
import 'package:zuraffa/src/plugins/test/test_plugin.dart';
import 'package:zuraffa/src/plugins/usecase/usecase_plugin.dart';

Future<void> main(List<String> args) async {
  const outputDir = 'lib/src';
  switch (args.single) {
    case 'repository':
      await RepositoryCommand(RepositoryPlugin(outputDir: outputDir)).run();
    case 'provider':
      await ProviderCommand(ProviderPlugin(outputDir: outputDir)).run();
    case 'service':
      await ServiceCommand(ServicePlugin(outputDir: outputDir)).run();
    case 'mock':
      await MockCommand(MockPlugin(outputDir: outputDir)).run();
    case 'state':
      await StateCommand(StatePlugin(outputDir: outputDir)).run();
    case 'test':
      await TestCommand(TestPlugin(outputDir: outputDir)).run();
    case 'sqlite':
      await SqliteCommand(SqlitePlugin(outputDir: outputDir)).run();
    case 'route':
      await RouteCommand(RoutePlugin(outputDir: outputDir)).run();
    case 'di':
      await ModularDiCommand(DiPlugin(outputDir: outputDir)).run();
    case 'usecase':
      await UseCaseCommand(UseCasePlugin(outputDir: outputDir)).run();
    default:
      throw StateError('unknown command: ${args.single}');
  }
}
