/// `zfa tdd` — top-level TDD plugin command (feature 041).
library;

import 'package:args/command_runner.dart';
import 'dart:math';

import '../plugins/tdd/commands/compose_command.dart';
import '../plugins/tdd/commands/corpus_command.dart';
import '../plugins/tdd/commands/diff_check_command.dart';
import '../plugins/tdd/commands/doctor_command.dart';
import '../plugins/tdd/commands/fake_command.dart';
import '../plugins/tdd/commands/func_command.dart';
import '../plugins/tdd/commands/gen_command.dart';
import '../plugins/tdd/commands/ingest_command.dart';
import '../plugins/tdd/commands/init_command.dart';
import '../plugins/tdd/commands/make_command.dart';
import '../plugins/tdd/commands/migrate_paths_command.dart';
import '../plugins/tdd/commands/plan_command.dart';
import '../plugins/tdd/commands/prove_command.dart';
import '../plugins/tdd/commands/replay_command.dart';
import '../plugins/tdd/commands/realize_command.dart';
import '../plugins/tdd/commands/realize_mock_command.dart';
import '../plugins/tdd/commands/refactor_command.dart';
import '../plugins/tdd/commands/referee_command.dart';
import '../plugins/tdd/commands/reset_command.dart';
import '../plugins/tdd/commands/run_command.dart';
import '../plugins/tdd/commands/run_engine_command.dart';
import '../plugins/tdd/commands/run_skin_command.dart';
import '../plugins/tdd/commands/split_command.dart';
import '../plugins/tdd/commands/status_command.dart';
import '../plugins/tdd/commands/theater_command.dart';
import '../plugins/tdd/commands/verify_command.dart';
import '../plugins/tdd/commands/verify_red_command.dart';
import '../plugins/tdd/commands/verdicts_command.dart';
import '../plugins/tdd/commands/view_command.dart';
import '../plugins/tdd/commands/wire_command.dart';
import '../plugins/tdd/tdd_plugin.dart';

class TddCommand extends Command<void> {
  TddCommand(this.plugin) {
    addSubcommand(InitCommand(plugin));
    addSubcommand(PlanCommand(plugin));
    addSubcommand(GenCommand(plugin));
    addSubcommand(FakeCommand(plugin));
    addSubcommand(VerifyRedCommand(plugin));
    addSubcommand(MakeCommand(plugin));
    addSubcommand(WireCommand(plugin));
    addSubcommand(ComposeCommand(plugin));
    addSubcommand(FuncCommand(plugin));
    addSubcommand(ViewCommand(plugin));
    addSubcommand(RefactorCommand(plugin));
    addSubcommand(RunCommand(plugin));
    addSubcommand(RunEngineCommand(plugin));
    addSubcommand(RunSkinCommand(plugin));
    addSubcommand(SplitCommand(plugin));
    addSubcommand(IngestCommand(plugin));
    addSubcommand(StatusCommand(plugin));
    addSubcommand(ProveCommand(plugin));
    addSubcommand(ReplayCommand(plugin));
    addSubcommand(TheaterCommand(plugin));
    addSubcommand(VerifyCommand(plugin));
    addSubcommand(VerdictsCommand(plugin));
    addSubcommand(MigratePathsCommand(plugin));
    addSubcommand(CorpusCommand(plugin));
    addSubcommand(RefereeCommand(plugin));
    addSubcommand(DiffCheckCommand(plugin));
    addSubcommand(ResetCommand(plugin));
    addSubcommand(DoctorCommand(plugin));
    addSubcommand(RealizeCommand(plugin));
    addSubcommand(RealizeMockCommand(plugin));
  }

  final TddPlugin plugin;

  @override
  String get name => 'tdd';

  @override
  String get description =>
      'Drive the full TDD red-green-refactor cycle (init, plan, gen, '
      'verify-red, make, wire, func, refactor, run, run-engine, run-skin, '
      'split, status, prove, verify). See specs/041-tdd-setup-plugin/spec.md '
      'for the full contract; specs/1000-spec-template-core-skin-lanes/spec.md '
      'for the lane split, specs/1008-two-cycle-driver/spec.md for the '
      'two-cycle runner, and specs/1113-unified-tdd-journal/spec.md for the '
      'unified journal.';

  @override
  String get invocation => 'zfa tdd <subcommand> [options]';

  @override
  Future<void> run() async {
    printUsage();
  }

  static const int _lineLength = 80;

  static String _padRight(String source, int length) =>
      source + ' ' * (length - source.length);

  static List<String> _wrapTextAsLines(
    String text, {
    int start = 0,
    int? length,
  }) {
    assert(start >= 0);
    bool isWhitespace(String text, int index) {
      var rune = text.codeUnitAt(index);
      return rune >= 0x0009 && rune <= 0x000D ||
          rune == 0x0020 ||
          rune == 0x0085 ||
          rune == 0x1680 ||
          rune == 0x180E ||
          rune >= 0x2000 && rune <= 0x200A ||
          rune == 0x2028 ||
          rune == 0x2029 ||
          rune == 0x202F ||
          rune == 0x205F ||
          rune == 0x3000 ||
          rune == 0xFEFF;
    }

    if (length == null) return text.split('\n');

    var result = <String>[];
    var effectiveLength = max(length - start, 10);
    for (var line in text.split('\n')) {
      line = line.trim();
      if (line.length <= effectiveLength) {
        result.add(line);
        continue;
      }

      var currentLineStart = 0;
      int? lastWhitespace;
      for (var i = 0; i < line.length; ++i) {
        if (isWhitespace(line, i)) lastWhitespace = i;

        if (i - currentLineStart >= effectiveLength) {
          if (lastWhitespace != null) i = lastWhitespace;

          result.add(line.substring(currentLineStart, i).trim());

          while (isWhitespace(line, i) && i < line.length) {
            i++;
          }

          currentLineStart = i;
          lastWhitespace = null;
        }
      }
      result.add(line.substring(currentLineStart).trim());
    }
    return result;
  }

  @override
  Never usageException(String message) =>
      throw UsageException(message, _formatUsage());

  String _formatUsage() {
    var names = subcommands.keys.where(
      (name) => !subcommands[name]!.aliases.contains(name),
    );
    var visible = names.where((name) => !subcommands[name]!.hidden);
    if (visible.isNotEmpty) names = visible;
    names = names.toList()..sort();

    var length = names.map((name) => name.length).reduce(max);
    var columnStart = length + 5;

    var buffer = StringBuffer('Available subcommands:');
    for (var name in names) {
      var command = subcommands[name]!;
      var lines = _wrapTextAsLines(
        command.summary,
        start: columnStart,
        length: _lineLength,
      );
      buffer.writeln();
      buffer.write('  ${_padRight(name, length)}   ${lines.first}');
      for (var line in lines.skip(1)) {
        buffer.writeln();
        buffer.write(' ' * columnStart);
        buffer.write(line);
      }
    }
    return 'Usage: $invocation\n'
        '${argParser.usage}\n'
        '$buffer\n'
        'Run "${runner!.executableName} help" to see global options.';
  }
}
