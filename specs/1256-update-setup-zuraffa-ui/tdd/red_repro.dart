// Spec 1256 RED reproduction — documents the CURRENT (broken) behavior:
//   1. zfa setup/init (DependencyWirer.standardSet) does NOT wire zuraffa_ui.
//   2. The widget-lane default shell is ShadApp (shadcn_ui), not ZuraffaApp
//      (zuraffa_ui).
// Run: dart run scripts/spec_1256_red_repro.dart
import 'package:zuraffa/src/core/dependencies/dependency_wirer.dart';
import 'package:zuraffa/src/plugins/tdd/services/widget_scaffold.dart';

void main() {
  final flutterSet = DependencyWirer.standardSet(isFlutter: true);
  final hasZui = flutterSet.any((s) => s.name == 'zuraffa_ui');
  print('RED-1 standardSet(isFlutter: true) wires zuraffa_ui: $hasZui');
  print('     (expected: true — issue #1256) -> ${hasZui ? "GREEN" : "RED"}');

  final defaultShell = WidgetAppShell.parse(null);
  print('RED-2 default widget shell: ${defaultShell.name} '
      '(${defaultShell.widgetName})');
  print('     (expected: a zuraffaapp shell emitting ZuraffaApp) -> '
      '${defaultShell.widgetName == 'ZuraffaApp' ? "GREEN" : "RED"}');
}
