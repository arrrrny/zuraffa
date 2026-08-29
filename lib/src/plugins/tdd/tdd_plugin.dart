/// The built-in `zfa tdd` plugin (feature 041-tdd-setup-plugin).
library;

import 'package:args/command_runner.dart';

import '../../commands/tdd_command.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';

export 'models/artifact_record.dart';
export 'models/behavior.dart';
export 'models/cycle_entry.dart';
export 'models/mutation_outcome.dart';
export 'models/ownership.dart';
export 'models/run_state.dart';
export 'models/tdd_profile.dart';

class TddPlugin extends ZuraffaPlugin implements CliAwarePlugin {
  TddPlugin();

  @override
  String get id => 'tdd';

  @override
  String get name => 'TDD Plugin';

  @override
  String get version => '1.0.0';

  @override
  List<String> get runAfter => const ['test'];

  @override
  Command createCommand() => TddCommand(this);
}
