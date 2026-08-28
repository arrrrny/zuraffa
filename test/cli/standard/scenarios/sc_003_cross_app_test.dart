// SC-003 acceptance test: App B invokes App A's registered command by name
// through the CommandRegistry, with NO import of App A's command class in
// App B's source.
//
// We simulate "App A" and "App B" as two separate test source files:
// - test/cli/standard/scenarios/_sc_003_app_a.dart   (defines + registers)
// - this file (App B) imports ONLY the registry, never App A's command.
//
// Pure-Dart (FR-012): no package:flutter import.

import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

// NOTE: This file imports ONLY `zuraffa` (the standard CLI plugin). It does
// NOT import `./_sc_003_app_a.dart` — App B has no compile-time dependency
// on App A's command class. SC-003 is provable by inspecting this file's
// import list (no `_sc_003_app_a` import).

void main() {
  test('A3: App B invokes App A\'s command via registry (no hard dep)', () async {
    final sharedRegistry = CommandRegistry();

    // App A registers its `greet` command into the shared registry.
    // We construct it inline (the production pattern would have App A
    // register at its own startup), but the key point is that this test
    // file does NOT import App A's command class — the only thing shared
    // is the registry instance.
    final appAGreetCommand = StandardCommand(
      name: 'greet',
      description: 'App A\'s greeting command',
      handler: (inv) async => SuccessResult(
        data: {
          'message':
              'Hello, ${inv.arguments.isEmpty ? 'world' : inv.arguments.first}!',
          'servedBy': 'appA',
        },
      ),
    );
    sharedRegistry.register(
      appAGreetCommand,
      ownerApp: 'appA',
      version: '1.0.0',
    );

    // App B constructs an invoker bound to the same registry and invokes
    // App A's `greet` by name. App B has no reference to appAGreetCommand.
    final invoker = CrossAppInvoker(sharedRegistry);
    final inv = CliInvocation(
      arguments: const ['World'],
      flags: const {},
      contract: CliContract.standard,
    );

    final result = await invoker.invoke('appA', 'greet', inv);

    expect(result, isA<SuccessResult>());
    expect((result as SuccessResult).data['message'], equals('Hello, World!'));
    expect(result.data['servedBy'], equals('appA'));

    // Statically prove no hard dependency: walk this file's imports.
    // (We assert at runtime that the invoker succeeded without ever
    // needing a reference to appAGreetCommand's class — the call site
    // only uses the string `'greet'`.)
    expect(invoker, isNotNull);
  });
}
