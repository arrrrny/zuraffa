import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_flutter/src/presentation/xray/xray_bridge_holder.dart';
import 'package:zuraffa_flutter/src/presentation/xray/xray_mode.dart';
import 'package:zuraffa_flutter/src/presentation/xray/xray_scope.dart';

// XRayScopeState self-registers with XRayBridgeScopeHolder in initState and
// clears itself in dispose(). These tests pin the lifecycle contract: a
// nested scope's disposal must NOT clear the outer scope — the outer scope
// is restored as the active scope.
void main() {
  setUp(() {
    XRayMode.reset();
    XRayBridgeScopeHolder.reset();
  });

  tearDown(() {
    XRayBridgeScopeHolder.reset();
    XRayMode.reset();
  });

  testWidgets('XRayScope registers with the holder and clears it on dispose', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: XRayScope(viewId: 'SingleView', child: SizedBox()),
      ),
    );

    expect(XRayBridgeScopeHolder.activeScope, isNotNull);
    expect(XRayBridgeScopeHolder.activeScope!.viewId, 'SingleView');

    // Tear the scope down — nothing should remain active.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(XRayBridgeScopeHolder.activeScope, isNull);
  });

  testWidgets(
    'disposing a nested XRayScope keeps the outer scope active',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: XRayScope(
            viewId: 'OuterView',
            child: XRayScope(viewId: 'InnerView', child: SizedBox()),
          ),
        ),
      );

      // The innermost scope is active while nested.
      expect(XRayBridgeScopeHolder.activeScope, isNotNull);
      expect(XRayBridgeScopeHolder.activeScope!.viewId, 'InnerView');

      // Remove the inner scope — the outer scope must be restored, not
      // cleared (nested scope disposal must not null the holder).
      await tester.pumpWidget(
        const MaterialApp(
          home: XRayScope(viewId: 'OuterView', child: SizedBox()),
        ),
      );
      expect(XRayBridgeScopeHolder.activeScope, isNotNull);
      expect(XRayBridgeScopeHolder.activeScope!.viewId, 'OuterView');

      // Remove the outer scope — no active scope remains.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(XRayBridgeScopeHolder.activeScope, isNull);
    },
  );
}
