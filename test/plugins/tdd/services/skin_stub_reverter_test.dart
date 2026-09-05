// Issue #1005 ([ZIKZAK-REBUILD] skin hand-written seam): the stub-revert
// red witness — the cycle replaces ONLY the view-builder function with
// the inert stub (never the whole file, never the test), so the paired
// test fails against the stub (RED) while every other declaration in
// the hand-written file keeps compiling.
//
// RED phase: `skin_stub_reverter.dart` does not exist — the import fails.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/skin_stub_reverter.dart';

void main() {
  group('issue #1005 — stubViewBuilder', () {
    test('replaces an expression-bodied view-builder', () {
      const source = '''
// _XRaySkinHandEdit(behavior: "W1", file: "lib/login_view.dart", logged_at: "2026-09-05T00:00:00Z")
Widget loginView() => const LoginView();

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) => const Text('login');
}
''';
      final stubbed = stubViewBuilder(source, 'loginView');
      expect(stubbed, isNotNull);
      expect(stubbed, contains('UnimplementedError'));
      // The view-builder NAME survives (the test calls it).
      expect(stubbed, contains('Widget loginView()'));
      // The class is untouched — the file still compiles.
      expect(stubbed, contains('class LoginView extends StatelessWidget'));
      expect(stubbed, contains("const Text('login')"));
      // The annotation survives (it documents the hand-edit, not the
      // builder body).
      expect(stubbed, contains('_XRaySkinHandEdit'));
    });

    test('replaces a block-bodied view-builder', () {
      const source = '''
Widget loginView() {
  final state = LoginViewState();
  return LoginView(state: state);
}

class LoginView extends StatelessWidget {
  const LoginView({super.key, this.state});

  final LoginViewState? state;

  @override
  Widget build(BuildContext context) {
    if (state != null) {
      return const Text('login');
    }
    return const SizedBox.shrink();
  }
}
''';
      final stubbed = stubViewBuilder(source, 'loginView');
      expect(stubbed, isNotNull);
      expect(stubbed, contains('UnimplementedError'));
      // The block body (with nested braces) is fully replaced.
      expect(stubbed, isNot(contains('LoginViewState();')));
      // The class and its build method survive.
      expect(stubbed, contains('class LoginView extends StatelessWidget'));
      expect(stubbed, contains('SizedBox.shrink'));
    });

    test('replaces a builder with parameters', () {
      const source = '''
Widget loginView({LoginViewState? state, bool compact = false}) =>
    LoginView(state: state, compact: compact);
''';
      final stubbed = stubViewBuilder(source, 'loginView');
      expect(stubbed, isNotNull);
      expect(stubbed, contains('UnimplementedError'));
      expect(stubbed, isNot(contains('compact: compact')));
    });

    test('returns null when no view-builder matches', () {
      const source = '''
class LoginView extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Text('login');
}
''';
      expect(stubViewBuilder(source, 'loginView'), isNull);
    });

    test('does not confuse a same-named local or method', () {
      const source = '''
Widget otherBuilder() {
  Widget loginView() => const LoginView();
  return loginView();
}
''';
      // A nested declaration of the same name is NOT the top-level
      // builder contract — the scanner keys the top-level shape.
      final stubbed = stubViewBuilder(source, 'loginView');
      expect(stubbed, isNotNull);
      expect(stubbed, contains('UnimplementedError'));
      expect(stubbed, contains('Widget otherBuilder()'));
    });

    test('stubbing is idempotent-friendly: stubbing a stubbed builder', () {
      const source = "Widget loginView() => throw UnimplementedError('old');";
      final stubbed = stubViewBuilder(source, 'loginView');
      expect(stubbed, isNotNull);
      expect(stubbed, contains('UnimplementedError'));
      expect(stubbed, isNot(contains("'old'")));
    });
  });
}
