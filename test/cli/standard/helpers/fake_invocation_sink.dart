// Helper: captures handler invocations for assertion in tests.
//
// Pure-Dart (FR-012).

import 'package:zuraffa/zuraffa.dart';

/// A [StandardCommand] handler that records every [CliInvocation] it receives,
/// for use in tests that assert on dispatch behavior.
class FakeInvocationSink {
  final List<CliInvocation> invocations = [];

  Future<CommandResult> handler(CliInvocation inv) async {
    invocations.add(inv);
    return const SuccessResult();
  }

  /// Build a [StandardCommand] whose handler delegates to [handler].
  StandardCommand command({
    String name = 'fake',
    String description = 'fake command for tests',
    List<CommandArgument> arguments = const [],
    List<CommandFlag> flags = const [],
  }) {
    return StandardCommand(
      name: name,
      description: description,
      arguments: arguments,
      flags: flags,
      handler: handler,
    );
  }
}
