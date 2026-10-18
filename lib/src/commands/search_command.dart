import "dart:io";
import 'package:args/command_runner.dart';

import '../cli/exit_protocol.dart';

class SearchCommand extends Command<void> {
  @override
  String get name => 'search';

  @override
  String get description =>
      'Generate an on-device hybrid search layer (FTS5 + vector index)';

  @override
  Future<void> run() async {
    print('❌ Usage: zfa search <subcommand> [arguments]');
    print('   Run `zfa search --help` to list subcommands.');
    exitCode = ExitProtocol.usage;
  }
}
