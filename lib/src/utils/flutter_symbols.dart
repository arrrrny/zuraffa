/// Public Flutter symbols (exported via `package:flutter/material.dart`)
/// that generated views never reference but entity class names commonly
/// collide with.
///
/// When a generated view imports both `package:flutter/material.dart` and the
/// entity's file, a colliding entity name (e.g. an entity named `Feedback`)
/// makes every unqualified reference ambiguous (`ambiguous_import`). The view
/// generator hides the colliding symbol from the material import so the
/// entity always wins (#337).
///
/// Symbols the generated view code itself uses (e.g. `Text`, `Widget`,
/// `Scaffold`, `AppBar`, `Container`, `Center`, `ValueKey`, `State`, `Key`)
/// must NOT be listed here — hiding them would break the generated code.
const Set<String> flutterMaterialCollidingSymbols = {
  'Feedback',
  'Table',
  'Divider',
  'Chip',
  'Tooltip',
  'Drawer',
  'Material',
  'Dialog',
  'Card',
  'Switch',
  'Slider',
  'Radio',
  'Checkbox',
  'Icon',
  'Theme',
  'Banner',
  'SnackBar',
  'CircleAvatar',
  'Stepper',
  'TickerMode',
  'GridView',
  'ListView',
  'PageView',
  'ScrollView',
  'Form',
  'FormField',
  'DropdownButton',
  'PopupMenuButton',
  'SelectableText',
  'Spacer',
  'Wrap',
  'Flow',
  'Stack',
  'Positioned',
  'Align',
  'Padding',
  'DecoratedBox',
  'ClipRRect',
  'ClipOval',
  'Transform',
  'Opacity',
  'AspectRatio',
  'ConstrainedBox',
  'FittedBox',
  'IntrinsicHeight',
  'IntrinsicWidth',
  'LimitedBox',
  'OverflowBox',
  'SizedBox',
  'Placeholder',
};

/// Whether [entityName] collides with a Flutter material symbol that the
/// generated view must hide from its material import.
bool collidesWithFlutterSymbol(String? entityName) =>
    entityName != null && flutterMaterialCollidingSymbols.contains(entityName);

/// Issue #1429 — Flutter SDK type names a domain entity must not silently
/// duplicate: `tdd run` phase-0 scaffolds whatever a spec's `### Key
/// Entities` table declares, and a documentation-only row naming a
/// `package:flutter` type (e.g. `PlatformException` as a pigeon error
/// envelope, `BuildContext`) materializes a dead domain duplicate whose
/// unqualified references are ambiguous the moment both imports are in
/// scope. `zfa entity create` consults this set to emit a collision
/// warning (a warning, never a refusal — the duplicate may be
/// intentional).
///
/// Deliberately distinct from [flutterMaterialCollidingSymbols]: that set
/// is the view-generator's import-hiding contract and must never contain
/// the symbols generated view code itself uses; this set is the
/// create-time lint and SHOULD contain them (`Widget`, `Key`, `State` are
/// exactly the names an entity must not take).
const Set<String> flutterSdkTypeNames = {
  // foundation / widgets core
  'BuildContext',
  'Widget',
  'State',
  'StatefulWidget',
  'StatelessWidget',
  'Element',
  'RenderObject',
  'InheritedWidget',
  'Key',
  'GlobalKey',
  'ValueKey',
  'ChangeNotifier',
  'ValueNotifier',
  'Listenable',
  // services / painting
  'PlatformException',
  'AppLifecycleState',
  'TargetPlatform',
  'Brightness',
  'Locale',
  'Size',
  'Offset',
  'Rect',
  'Color',
  'Colors',
  'Image',
  'ImageProvider',
  'IconData',
  // animation / gestures
  'Animation',
  'AnimationController',
  'Curve',
  'FocusNode',
  // controllers
  'ScrollController',
  'TextEditingController',
  // text / layout vocabulary
  'TextStyle',
  'FontWeight',
  'TextAlign',
  'TextDirection',
  'EdgeInsets',
  'Alignment',
  'BorderRadius',
  'BoxFit',
  'MainAxisSize',
  'MainAxisAlignment',
  'CrossAxisAlignment',
  // navigation / overlay
  'Route',
  'Navigator',
  'Overlay',
  'OverlayEntry',
  'MediaQuery',
};

/// Whether [entityName] collides with a Flutter SDK type name that
/// `zfa entity create` must warn about (issue #1429).
bool collidesWithFlutterSdkType(String? entityName) =>
    entityName != null && flutterSdkTypeNames.contains(entityName);
