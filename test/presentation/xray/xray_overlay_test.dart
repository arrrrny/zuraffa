import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/presentation/xray/xray_mode.dart';
import 'package:zuraffa/src/presentation/xray/xray_scope.dart';
import 'package:zuraffa/src/presentation/xray/xray_node.dart';
import 'package:zuraffa/src/presentation/xray/xray_node_metadata.dart';
import 'package:zuraffa/src/presentation/xray/xray_activation.dart';
import 'package:zuraffa/src/presentation/xray/xray_colors.dart';
import 'package:zuraffa/src/presentation/xray/xray_shake_detector.dart';
import 'package:zuraffa/src/presentation/xray/xray_scope_overlay.dart';

enum TestViewNode { actionButton, editButton, saveButton }

void main() {
  setUp(() {
    XRayMode.reset();
    XRayMetadataRegistry.clear();
  });

  tearDown(() {
    XRayMode.reset();
    XRayMetadataRegistry.clear();
  });

  // ── Overlay rendering ──

  testWidgets('overlay renders bounding boxes when X-Ray is enabled',
      (WidgetTester tester) async {
    XRayMode.enable();

    await tester.pumpWidget(
      MaterialApp(
        home: XRayScope(
          viewId: 'TestView',
          child: Scaffold(
            body: Column(
              children: [
                XRayNode<TestViewNode>(
                  nodeId: TestViewNode.actionButton,
                  child: ElevatedButton(
                    key: const ValueKey('btn_a'),
                    onPressed: () {},
                    child: const Text('A'),
                  ),
                ),
                XRayNode<TestViewNode>(
                  nodeId: TestViewNode.editButton,
                  child: ElevatedButton(
                    key: const ValueKey('btn_b'),
                    onPressed: () {},
                    child: const Text('B'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Wait for the overlay to measure nodes.
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 200));

    // Buttons should still be findable (touch passthrough).
    expect(find.byKey(const ValueKey('btn_a')), findsOneWidget);
    expect(find.byKey(const ValueKey('btn_b')), findsOneWidget);

    // The scope should be active with nodes.
    final state = tester.state<XRayScopeState>(find.byType(XRayScope));
    expect(state.isActive, isTrue);
    expect(state.tree.length, 2);
    expect(state.tree[0].id, 'TestView.actionButton');
    expect(state.tree[1].id, 'TestView.editButton');
  });

  testWidgets('no overlay when X-Ray is disabled', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: XRayScope(
          viewId: 'TestView',
          child: Scaffold(
            body: XRayNode<TestViewNode>(
              nodeId: TestViewNode.actionButton,
              child: const Text('Hello'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // No overlay should be present.
    expect(find.byType(XRayScopeOverlay), findsNothing);

    // Child renders normally.
    expect(find.text('Hello'), findsOneWidget);
  });

  // ── Metadata ──

  testWidgets('bounding boxes show action name and state from metadata',
      (WidgetTester tester) async {
    XRayMode.enable();

    XRayMetadataRegistry.register(
      'TestView.actionButton',
      const XRayNodeMetadata(
        actionName: 'onButtonTapped',
        isEnabled: true,
        stateJson: {'loading': false, 'data': 'test'},
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: XRayScope(
          viewId: 'TestView',
          child: Scaffold(
            body: XRayNode<TestViewNode>(
              nodeId: TestViewNode.actionButton,
              child: const SizedBox(width: 100, height: 40),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 200));

    final meta = XRayMetadataRegistry.forNode('TestView.actionButton');
    expect(meta, isNotNull);
    expect(meta!.actionName, 'onButtonTapped');
    expect(meta.isEnabled, isTrue);
    expect(meta.stateJson?['data'], 'test');
  });

  testWidgets('disabled node metadata is shown', (WidgetTester tester) async {
    XRayMode.enable();

    XRayMetadataRegistry.register(
      'TestView.editButton',
      const XRayNodeMetadata(
        actionName: 'onEdit',
        isEnabled: false,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: XRayScope(
          viewId: 'TestView',
          child: Scaffold(
            body: XRayNode<TestViewNode>(
              nodeId: TestViewNode.editButton,
              child: const SizedBox(width: 100, height: 40),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final meta = XRayMetadataRegistry.forNode('TestView.editButton');
    expect(meta, isNotNull);
    expect(meta!.isEnabled, isFalse);
  });

  // ── Touch passthrough ──

  testWidgets('tapping child button still works through overlay',
      (WidgetTester tester) async {
    XRayMode.enable();
    var tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: XRayScope(
          viewId: 'TestView',
          child: Scaffold(
            body: XRayNode<TestViewNode>(
              nodeId: TestViewNode.actionButton,
              child: ElevatedButton(
                onPressed: () => tapCount++,
                child: const Text('Tap me'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Tap me'));
    await tester.pumpAndSettle();

    expect(tapCount, 1);
  });

  // ── XRayMode toggle ──

  test('XRayMode toggle works', () {
    expect(XRayMode.isEnabled, isFalse);
    XRayMode.enable();
    expect(XRayMode.isEnabled, isTrue);
    XRayMode.toggle();
    expect(XRayMode.isEnabled, isFalse);
    XRayMode.toggle();
    expect(XRayMode.isEnabled, isTrue);
  });

  test('XRayMode disable always works', () {
    XRayMode.enable();
    expect(XRayMode.isEnabled, isTrue);
    XRayMode.disable();
    expect(XRayMode.isEnabled, isFalse);
  });

  // ── XRayMetadataRegistry ──

  test('metadata registry register/unregister', () {
    expect(XRayMetadataRegistry.forNode('test.node'), isNull);

    XRayMetadataRegistry.register(
      'test.node',
      const XRayNodeMetadata(actionName: 'onTap'),
    );
    expect(XRayMetadataRegistry.forNode('test.node')?.actionName, 'onTap');

    XRayMetadataRegistry.unregister('test.node');
    expect(XRayMetadataRegistry.forNode('test.node'), isNull);
  });

  test('metadata toJson includes all fields', () {
    const meta = XRayNodeMetadata(
      actionName: 'onSave',
      isEnabled: false,
      stateJson: {'loading': true, 'error': 'timeout'},
    );
    final json = meta.toJson();
    expect(json['action'], 'onSave');
    expect(json['enabled'], false);
    expect(json['state']['loading'], true);
    expect(json['state']['error'], 'timeout');
  });

  // ── XRayActivation (two-finger long press) ──

  testWidgets('XRayActivation is pass-through when X-Ray is off',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: XRayActivation(
          child: const Text('Hello'),
        ),
      ),
    );

    expect(find.text('Hello'), findsOneWidget);
    expect(XRayMode.isEnabled, isFalse);
  });

  // ── ShakeDetector ──

  test('ShakeDetector detects shake pattern', () async {
    var shakeCount = 0;
    final detector = ShakeDetector(
      threshold: 10.0,
      shakeCount: 3,
      shakeCountWindow: const Duration(milliseconds: 600),
      onShake: () => shakeCount++,
    );

    final controller = StreamController<Map<String, double>>();
    detector.start(controller.stream);

    for (var i = 0; i < 3; i++) {
      controller.add({'x': 0.0, 'y': 0.0, 'z': 15.0});
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    await controller.close();
    detector.stop();

    expect(shakeCount, 1);
  });

  test('ShakeDetector ignores sub-threshold events', () async {
    var shakeCount = 0;
    final detector = ShakeDetector(
      threshold: 50.0,
      onShake: () => shakeCount++,
    );

    final controller = StreamController<Map<String, double>>();
    detector.start(controller.stream);

    for (var i = 0; i < 5; i++) {
      controller.add({'x': 1.0, 'y': 1.0, 'z': 1.0});
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    await controller.close();
    detector.stop();

    expect(shakeCount, 0);
  });

  // ── Colors ──

  test('XRayColors.forView returns consistent colors', () {
    final c1 = XRayColors.forView('ViewA');
    final c2 = XRayColors.forView('ViewA');
    final c3 = XRayColors.forView('ViewB');

    expect(c1, equals(c2));
    expect(c1, isA<Color>());
    expect(c3, isA<Color>());
  });
}
