// GENERATED STUB — `zfa tdd gen A1144` (spec 044-test-tdd-generation).
library;

import 'package:flutter/material.dart';
import '../../i18n/strings.g.dart';

/// View-builder subject for behavior A1144 (issue #939): returns
/// the deterministic minimal view composed from the declared Presentation
/// layer contract and the scenario assertions of the behavior description
/// (issue #964 finder-kind taxonomy). Scenario-specific behavior
/// (navigation, validation, state) is the sanctioned handcraft seam —
/// implement it in [A1144View] and its per-slot layouts.
Widget subject_a1144() => A1144View();

/// The minimal adaptive view for behavior A1144 (issue #1142
/// skeleton): an AdaptiveViewState with one layout stub per declared
/// platform slot — the production shape the single-layout Column could
/// never be.
///
/// the 'Sign in' button is disabled
class A1144View extends StatefulWidget {
  const A1144View({super.key});

  @override
  State<A1144View> createState() => _A1144ViewState();
}

/// The AdaptiveViewState (issue #1142): platform slot resolution in
/// build, one branch per declared slot.
class _A1144ViewState extends State<A1144View> {
  /// Resolves the platform slot for the current build: a phone-width
  /// surface is the `mobile` slot on every platform; wider surfaces
  /// branch on the host platform (declared slots only).
  String _resolveSlot(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 600) return 'mobile';
    switch (Theme.of(context).platform) {
      case TargetPlatform.macOS:
        return 'macos';
      default:
        return 'mobile';
    }
  }

  @override
  Widget build(BuildContext context) {
    final slot = _resolveSlot(context);
    return Scaffold(
      body: switch (slot) {
        'macos' => const A1144ViewMacosLayout(slotKey: Key('a1144-slot-macos')),
        _ => const A1144ViewMobileLayout(slotKey: Key('a1144-slot-mobile')),
      },
    );
  }
}

/// The `mobile` slot layout stub for behavior A1144 (issue #1142):
/// the platform layout the skin fills — the TODO placeholder follows the
/// adaptive_layout_scaffold_builder pattern (spec 1004's platform
/// matrix; the #1102 runtime auditor reads the live branch through the
/// slot key). Traced independently in the coverage ledger: a slot no
/// green behavior exercised stays NOT-DONE there.
class A1144ViewMobileLayout extends StatelessWidget {
  const A1144ViewMobileLayout({super.key, required this.slotKey});

  /// The slot-identifying key (`a1144-slot-mobile`).
  final Key slotKey;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // TODO: Implement A1144View mobile layout — the sanctioned
          // handcraft seam (the loop certifies compile + assertions).
          Text(
            'TODO: Implement A1144View mobile layout',
            textAlign: TextAlign.center,
          ),
          ElevatedButton(onPressed: () {}, child: Text(t.auth.signIn)),
        ],
      ),
    );
  }
}

/// The `macos` slot layout stub for behavior A1144 (issue #1142):
/// the platform layout the skin fills — the TODO placeholder follows the
/// adaptive_layout_scaffold_builder pattern (spec 1004's platform
/// matrix; the #1102 runtime auditor reads the live branch through the
/// slot key). Traced independently in the coverage ledger: a slot no
/// green behavior exercised stays NOT-DONE there.
class A1144ViewMacosLayout extends StatelessWidget {
  const A1144ViewMacosLayout({super.key, required this.slotKey});

  /// The slot-identifying key (`a1144-slot-macos`).
  final Key slotKey;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // TODO: Implement A1144View macos layout — the sanctioned
          // handcraft seam (the loop certifies compile + assertions).
          Text(
            'TODO: Implement A1144View macos layout',
            textAlign: TextAlign.center,
          ),
          ElevatedButton(onPressed: () {}, child: Text(t.auth.signIn)),
        ],
      ),
    );
  }
}
