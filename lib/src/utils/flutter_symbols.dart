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
