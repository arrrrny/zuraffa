import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/presentation/xray/xray_mode.dart';
import 'package:zuraffa/src/presentation/xray/xray_scope.dart';
import 'package:zuraffa/src/presentation/xray/xray_node.dart';

enum TestViewNode { actionButton, editButton }

void main() {
  setUp(() {
    XRayMode.reset();
  });

  tearDown(() {
    XRayMode.reset();
  });

  testWidgets('XRayScope is transparent pass-through when disabled', (
    WidgetTester tester,
  ) async {
    final childKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: XRayScope(
          viewId: 'TestView',
          child: Container(key: childKey),
        ),
      ),
    );

    // Child renders normally
    expect(find.byKey(childKey), findsOneWidget);
    // No scope active
    final state = tester.state(find.byType(XRayScope)) as XRayScopeState;
    expect(state.isActive, isFalse);
    expect(state.tree, isEmpty);
  });

  testWidgets('XRayScope.tree returns registered nodes when enabled', (
    WidgetTester tester,
  ) async {
    XRayMode.enable();

    await tester.pumpWidget(
      MaterialApp(
        home: XRayScope(
          viewId: 'TestView',
          child: Column(
            children: [
              XRayNode<TestViewNode>(
                nodeId: TestViewNode.actionButton,
                child: ElevatedButton(onPressed: () {}, child: Text('A')),
              ),
              XRayNode<TestViewNode>(
                nodeId: TestViewNode.editButton,
                child: ElevatedButton(onPressed: () {}, child: Text('B')),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pump();

    final state = tester.state(find.byType(XRayScope)) as XRayScopeState;
    expect(state.isActive, isTrue);
    expect(state.tree.length, 2);
    expect(state.tree[0].id, 'TestView.actionButton');
    expect(state.tree[1].id, 'TestView.editButton');
  });

  testWidgets('XRayNode creates deterministic string ID format', (
    WidgetTester tester,
  ) async {
    XRayMode.enable();

    await tester.pumpWidget(
      MaterialApp(
        home: XRayScope(
          viewId: 'ProductView',
          child: XRayNode<TestViewNode>(
            nodeId: TestViewNode.actionButton,
            child: Container(),
          ),
        ),
      ),
    );

    await tester.pump();

    final state = tester.state(find.byType(XRayScope)) as XRayScopeState;
    final node = state.nodeById('ProductView.actionButton');
    expect(node, isNotNull);
    expect(node!.enumName, 'actionButton');
  });

  testWidgets('XRayNode is transparent pass-through when disabled', (
    WidgetTester tester,
  ) async {
    final childKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: XRayScope(
          viewId: 'TestView',
          child: XRayNode<TestViewNode>(
            nodeId: TestViewNode.actionButton,
            child: Container(key: childKey),
          ),
        ),
      ),
    );

    // Child renders normally even when disabled
    expect(find.byKey(childKey), findsOneWidget);
  });

  test('XRayMode toggle works', () {
    expect(XRayMode.isEnabled, isFalse);
    XRayMode.enable();
    expect(XRayMode.isEnabled, isTrue);
    XRayMode.disable();
    expect(XRayMode.isEnabled, isFalse);
  });
}
