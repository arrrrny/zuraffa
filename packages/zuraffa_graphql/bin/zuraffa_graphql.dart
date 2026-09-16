import 'package:args/command_runner.dart';
import 'package:zuraffa_graphql/src/graphql_generate_command.dart';

/// The zuraffa_graphql companion entrypoint (spec 1653-trim-heavy-deps,
/// issue #1661).
///
/// The core `zfa graphql generate` command delegates here through the
/// `ZfaExecutable` no-JIT seam when the graphql capability is enabled and
/// this package is resolvable in the target project. Invocation shape is
/// forwarded verbatim: `zuraffa_graphql generate --schema=... --output=...`.
Future<void> main(List<String> args) async {
  final runner = CommandRunner<void>(
    'zuraffa_graphql',
    'Zuraffa GraphQL capability commands',
  )..addCommand(GraphqlGenerateCommand());
  await runner.run(args);
}
