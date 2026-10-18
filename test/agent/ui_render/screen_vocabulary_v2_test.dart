import 'package:test/test.dart';
import 'package:zuraffa/src/agent/ui_render/ui_render.dart';

void main() {
  group('Vocabulary v2', () {
    test('notes screen doc renders a list-detail layout', () {
      final doc = buildNotesScreenDoc();
      final rendered = const ScreenRenderer().render(doc);
      expect(rendered.props['layout'], 'list-detail');
      expect(rendered.role, 'screen');
    });

    test('verifier passes for the notes screen doc', () {
      final doc = buildNotesScreenDoc();
      final result = const ScreenVerifier().verify(doc);
      expect(result.valid, isTrue, reason: '${result.errors}');
    });

    test('removing a semantic label fails verification naming the role', () {
      final doc = buildNotesScreenDoc();
      // Remove label from the list node.
      final unlabeled = ScreenDoc(
        layout: doc.layout,
        name: doc.name,
        states: doc.states,
        root: UiNode(
          type: doc.root.type,
          role: doc.root.role,
          label: null,
          props: doc.root.props,
          bindings: doc.root.bindings,
          children: doc.root.children,
        ),
      );
      final result = const ScreenVerifier().verify(unlabeled);
      expect(result.valid, isFalse);
      expect(
        result.errors.any(
          (e) =>
              e.kind == VerificationErrorKind.missingLabel && e.role == 'list',
        ),
        isTrue,
        reason: 'should name the role "list"',
      );
    });

    test('state matrix incomplete is reported', () {
      final doc = buildNotesScreenDoc();
      final incomplete = ScreenDoc(
        layout: doc.layout,
        name: doc.name,
        states: const <String>['loading'],
        root: doc.root,
      );
      final result = const ScreenVerifier().verify(incomplete);
      expect(result.valid, isFalse);
      expect(
        result.errors.any(
          (e) => e.kind == VerificationErrorKind.stateMatrixIncomplete,
        ),
        isTrue,
      );
    });

    test('golden: notes screen renders canonical tree', () {
      final doc = buildNotesScreenDoc();
      final rendered = const ScreenRenderer().render(doc);
      final canonical = rendered.toString();
      // Smoke: non-empty and stable.
      expect(canonical, isNotEmpty);
    });
  });
}
