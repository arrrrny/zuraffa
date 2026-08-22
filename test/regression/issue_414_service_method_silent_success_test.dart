// Regression test for issue #414:
// `zfa service method` was silent on success (no stdout output) when the
// target service already existed — i.e. the *append* code path. The append
// builder emits `GeneratedFile(action: 'updated')`, but `CapabilityCommand`
// only handled actions 'created' / 'overwritten' / 'skipped' / 'deleted', so
// the `✅ Success! Created/Modified:` block was skipped and nothing was
// printed. Users had to read the file to confirm anything happened.
//
// This test exercises the same path `zfa service method` takes — a
// `CapabilityCommand` wrapping `MethodCapability` — and asserts that
// success is reported on stdout AND the modified file is listed.
import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/capability_command.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/plugins/method_append/builders/method_append_builder.dart';
import 'package:zuraffa/src/plugins/service/service_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_issue_414_');
    outputDir = tempDir.path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'issue #414: zfa service method prints ✅ Success! when appending to an '
    'existing service (action=updated)',
    () async {
      // 1. Pre-create the service file so the *append* path is taken
      //    (the bug only manifested on the append path, which emits
      //    action='updated'; the create path emitted action='created' and
      //    was already reported correctly).
      final servicesDir = Directory('$outputDir/domain/services');
      await servicesDir.create(recursive: true);
      final serviceFile = File('${servicesDir.path}/my_service.dart');
      await serviceFile.writeAsString('''
// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

/// Service interface for MyService
abstract class MyService {}

// END GENERATED
''');

      // 2. Wire up the method capability through CapabilityCommand — the
      //    exact same command path `zfa service method` dispatches to.
      final methodAppendBuilder = MethodAppendBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(),
      );
      final plugin = ServicePlugin(
        outputDir: outputDir,
        methodAppendBuilder: methodAppendBuilder,
      );
      final methodCapability = plugin.capabilities.firstWhere(
        (c) => c.name == 'method',
      );
      final cmd = CapabilityCommand(methodCapability);
      final runner = CommandRunner<void>('zfa', 'Zuraffa CLI test')
        ..addCommand(cmd);

      // 3. Run and capture print() output via a zoned print interceptor.
      final output = <String>[];
      await runZoned(
        () => runner.run([
          'method',
          '--target',
          'MyService',
          '--name',
          'doThing',
          '--returns',
          'void',
          '--params',
          'String',
          '--type',
          'sync',
        ]),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => output.add(line),
        ),
      );

      // 4. Issue #414: success on the append path MUST print a success line
      //    AND list the modified file. Previously this was silent because
      //    CapabilityCommand.run() only handled actions 'created',
      //    'overwritten', 'skipped', 'deleted' — but method_append emits
      //    action='updated' on the append path.
      final combined = output.join('\n');
      expect(
        combined,
        contains('✅ Success! Created/Modified:'),
        reason: 'service method must report success on stdout; '
            'was silent before the fix because action="updated" '
            'was not handled by CapabilityCommand.run()',
      );
      expect(
        combined,
        contains('my_service.dart'),
        reason: 'service method must list the file it modified',
      );

      // 5. Sanity: the file was actually modified (the bug was "silent on
      //    SUCCESS" — the work happened, just nothing was printed).
      final after = serviceFile.readAsStringSync();
      expect(after, contains('void doThing(String params);'));
    },
  );
}
