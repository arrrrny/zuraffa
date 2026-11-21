// Issue #2139: `zfa make` must accept the same `--no-data` grammar that
// `zfa provider create` exposes.
//
// `provider create` synthesizes `--[no-]data` from its config schema, but
// `make` declared `--data` with `negatable: false`, so the equivalent
// provider-generation command
//   zfa make SchedulePriceCheck --provider ... --no-data
// died with exit 2 `Cannot negate option "--no-data"`. The two commands had
// incompatible option grammars for the same data-layer exclusion.
//
// Fast structural + parse pins: the flag exists on make, it is negatable, and
// parsing `--no-data` through the command's own argParser yields `data == false`
// instead of throwing — no subprocess needed.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/commands/make_command.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_registry.dart';

void main() {
  group('issue #2139 — zfa make --no-data grammar', () {
    late MakeCommand command;

    setUp(() {
      command = MakeCommand(PluginRegistry.instance);
    });

    test('the make command exposes a --data flag', () {
      expect(command.argParser.options, contains('data'));
    });

    test('the --data flag is negatable (provider create parity)', () {
      final data = command.argParser.options['data']!;
      expect(data.isFlag, isTrue);
      expect(data.negatable, isTrue);
    });

    test('parsing --no-data succeeds and resolves data to false', () {
      // On the unfixed tree this throws
      // `ArgParserException: Cannot negate option "--no-data"`.
      final results = command.argParser.parse(['--no-data']);
      expect(results['data'], isFalse);
      expect(results.wasParsed('data'), isTrue);
    });
  });
}
