// Regression test for issue #377.
//
// `zfa route shell` generated a `<Name>Shell` widget whose constructor took
// `navigationShell` as a POSITIONAL parameter:
//
//     class MainShell extends StatelessWidget {
//       const MainShell(StatefulNavigationShell navigationShell, {super.key});
//       ...
//     }
//
// but the generated `StatefulShellRoute.indexedStack` builder invoked it with a
// NAMED argument:
//
//     MainShell(navigationShell: navigationShell)
//
// That mismatch produced three analyzer errors
// (`final_not_initialized_constructor`, `not_enough_positional_arguments`,
// `undefined_named_parameter`) and a non-compiling `main_shell.dart`.
//
// The fix emits a NAMED `navigationShell` constructor so the builder's named
// call resolves. This test drives `ShellRoutesBuilder` directly (the same code
// path `zfa route shell` uses) and asserts the generated constructor is named.
//
// See: https://github.com/arrrrny/zuraffa/issues/377

import 'package:test/test.dart';

import 'package:zuraffa/src/plugins/route/builders/shell_routes_builder.dart';

void main() {
  group('#377 — route shell constructor must be named', () {
    test('generated shell class uses a named navigationShell constructor', () {
      final builder = ShellRoutesBuilder();
      final output = builder.buildFile(
        namePascal: 'Main',
        branches: [
          ShellBranchSpec(label: 'Home', path: '/home'),
          ShellBranchSpec(label: 'Deals', path: '/deals'),
          ShellBranchSpec(label: 'Profile', path: '/profile'),
        ],
      );

      // The constructor must be named so the shell route builder's
      // `MainShell(navigationShell: navigationShell)` call compiles.
      expect(
        output,
        contains('MainShell({required this.navigationShell'),
        reason:
            'The generated shell constructor must declare `navigationShell` '
            'as a named (this.) parameter to match the builder call.',
      );

      // And it must NOT be a positional parameter (the original bug).
      expect(
        output,
        isNot(contains('MainShell(StatefulNavigationShell navigationShell')),
        reason: 'The original bug emitted a positional `navigationShell`.',
      );

      // The shell route builder must wire the branch via the named argument.
      expect(
        output,
        contains('MainShell(navigationShell: navigationShell)'),
        reason: 'The shell route builder must call the named parameter.',
      );
    });

    test('adaptive (desktop) shell class also uses a named constructor', () {
      final builder = ShellRoutesBuilder();
      final output = builder.buildFile(
        namePascal: 'Main',
        branches: [ShellBranchSpec(label: 'Home', path: '/home')],
        adaptive: true,
      );

      expect(
        output,
        contains('MainShell({required this.navigationShell'),
        reason: 'The primary shell constructor must be named.',
      );
      expect(
        output,
        contains('MainShellDesktop({required this.navigationShell'),
        reason: 'The adaptive desktop shell constructor must also be named.',
      );
    });
  });
}
