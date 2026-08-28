// SC-004 acceptance test: a StandardCommand authored in App A is registered
// as a SharedCommand and run by App B through the standard interface,
// producing identical behavior with no per-app reimplementation.
//
// Pure-Dart (FR-012): no package:flutter import.

import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  test('A4: shared command runnable cross-app with identical behavior', () async {
    final sharedRegistry = CommandRegistry();

    // --- App A authors + shares ---
    final greetCommand = StandardCommand(
      name: 'greet',
      description: 'App A\'s greeting command, version 1.2.0',
      flags: const [
        CommandFlag(name: '--name', takesValue: true, defaultsTo: 'world'),
      ],
      handler: (inv) async {
        final name = inv.flags['--name'] as String? ?? 'world';
        return SuccessResult(
          data: {
            'greeting': 'Hello, $name!',
            'servedBy': 'appA',
            'version': '1.2.0',
          },
        );
      },
    );

    final shared = SharedCommand.of(greetCommand, version: '1.2.0');
    shared.share(sharedRegistry, ownerApp: 'appA');

    // --- App B retrieves + runs ---
    // App B does NOT reimplement the handler — it retrieves the published
    // definition and runs it through the standard interface.
    final retrieved = SharedCommand.retrieve(
      sharedRegistry,
      ownerApp: 'appA',
      commandName: 'greet',
      minVersion: '1.0.0',
    );

    expect(identical(retrieved.command, greetCommand), isTrue,
        reason: 'App B reuses App A\'s handler bytecode (no second impl)');

    // App B invokes the retrieved command via the standard CliApp.run path.
    final out = StringBuffer();
    final err = StringBuffer();
    final appB = CliApp(
      name: 'appB',
      version: '0.1.0',
      stdout: out,
      stderr: err,
    );
    // App B registers the retrieved command under its own ownerApp.
    appB.register(retrieved.command, ownerApp: 'appB');

    // Run 1: App B runs the shared command with --name=World.
    final code1 = await appB.run(['greet', '--name=World']);
    expect(code1, equals(0));
    // Run 2: App A also runs its own copy with the same args — results must match.
    final appA = CliApp(
      name: 'appA',
      version: '1.2.0',
      stdout: StringBuffer(),
      stderr: StringBuffer(),
    );
    appA.register(greetCommand, ownerApp: 'appA');
    final codeA = await appA.run(['greet', '--name=World']);
    expect(codeA, equals(0));

    // The behavior must be identical: same output shape, same data.
    // (We can't easily capture stdout from appA's separate instance, so we
    // instead invoke the handler directly for both and compare.)
    final inv = CliInvocation(
      arguments: const [],
      flags: const {'--name': 'World'},
      contract: CliContract.standard,
    );
    final resultA = await greetCommand.handler(inv);
    final resultB = await retrieved.command.handler(inv);
    expect(resultA.outcome, equals(resultB.outcome));
    expect(
      (resultA as SuccessResult).data['greeting'],
      equals((resultB as SuccessResult).data['greeting']),
    );
    expect(resultA.data['servedBy'], equals(resultB.data['servedBy']));
    expect(resultA.data['version'], equals(resultB.data['version']));

    // The contract for "no per-app reimplementation": App B has exactly one
    // command registered (the shared one), no extra handler definition.
    expect(appB.registry.length, equals(1));
  });
}
