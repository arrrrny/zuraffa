/// Widget-test scaffold surface (issue #912 defects 2+3).
///
/// Defect 2: the widget test template's app shell (ZuraffaApp vs MaterialApp)
/// is configurable — zuraffa apps are zuraffa_ui apps, so the default is
/// [WidgetAppShell.zuraffaapp]; plain-Material projects opt out via
/// `zfa tdd gen --widget-shell materialapp` or `.zfa.json`
/// `tdd.widgetShell: "materialapp"`.
///
/// Defect 3: when the widget template cannot derive concrete scenario
/// finders from the behavior description, the emitted test is a
/// PLACEHOLDER (its mounted-view `findsOneWidget` is greenable by a bare
/// `SizedBox()`), so it carries [scaffoldedMarker]. Since issue #959 the
/// placeholder cannot certify red at all: against the widget lane's INERT
/// stub (`SizedBox.shrink()`) the vacuous finder passes, the red-time run
/// is green, and `verify-red` refuses with `unexpected-green` — the
/// mechanical gate. The green certification (`zfa tdd make`) still reads
/// the marker and EXCLUDES the behavior from contract-green accounting as
/// a backstop with a clearer message: a placeholder test never certifies
/// green, and now it never certifies red either.
///
/// Issue #938: the default ZuraffaApp shell emits
/// `import 'package:zuraffa_ui/zuraffa_ui.dart';` — a dependency a fresh
/// zfa setup / zfa-init project does not necessarily declare. A generated
/// test that cannot resolve its imports dies at compile-error inside
/// `verify-red` and the loop never reaches an honest RED. The
/// [WidgetSkinPreflight] makes that dependency explicit (VISION §4
/// errors-are-an-API): the gen command refuses BEFORE writing artifacts,
/// naming the exact machine-parseable fix.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// The app shell a generated widget test pumps the feature view in.
enum WidgetAppShell {
  /// zuraffa_ui's ZuraffaApp — the default shell for zuraffa apps (issue
  /// #912 defect 2: ZikZak is ZuraffaApp; SC-001 asserts ZfaTheme).
  zuraffaapp,

  /// Flutter's MaterialApp — for projects that do not use zuraffa_ui.
  materialapp;

  /// The shell widget identifier emitted into the generated test.
  String get widgetName =>
      this == WidgetAppShell.zuraffaapp ? 'ZuraffaApp' : 'MaterialApp';

  /// The package path the shell's test emission needs to import
  /// (null = none beyond material.dart, which the template always
  /// imports). Co-located with [widgetName] so a future rename of the
  /// shell widget or its host package forces both ends to update
  /// together (issue #1277 review).
  String? get importPath => switch (this) {
    WidgetAppShell.zuraffaapp => 'package:zuraffa_ui/zuraffa_ui.dart',
    WidgetAppShell.materialapp => null,
  };

  /// Parses a `.zfa.json`/CLI string value; null/unknown values fall back
  /// to the default ([zuraffaapp]). Unknown non-empty values emit a
  /// one-line warning so a typo in `tdd.widgetShell` is visible in the
  /// gen log (issue #1277 review).
  static WidgetAppShell parse(String? value) {
    if (value == 'materialapp') return materialapp;
    if (value == 'zuraffaapp' || value == null || value.isEmpty) {
      return zuraffaapp;
    }
    // ignore: avoid_print
    print(
      "warning: tdd.widgetShell='$value' is not a recognized shell; "
      "defaulting to 'zuraffaapp'. Valid values: zuraffaapp, materialapp.",
    );
    return zuraffaapp;
  }
}

/// Machine-readable scaffold marker emitted by the widget template when
/// its scenario assertions are placeholder finders only (issue #912
/// defect 3). Greppable by the green certification.
const String scaffoldedMarker = 'zfa:tdd: scaffolded';

/// The comment block the widget template emits alongside
/// [scaffoldedMarker], naming the exact remedy.
const String widgetScaffoldComment =
    '''// $scaffoldedMarker — placeholder finders only (issue #912 defect 3):
      // a green here proves nothing about the scenario (a bare SizedBox()
      // would pass). Replace the mounted-view placeholder with concrete
      // scenario-derived finders (find.text / find.byType ...) and remove
      // this marker before certifying green.''';

/// Whether [content] carries the scaffold marker (a scaffolded test is
/// excluded from contract-green accounting, issue #912 defect 3).
bool contentIsScaffolded(String content) => content.contains(scaffoldedMarker);

/// Issue #938 preflight — the widget lane boots generated widget tests in
/// a ZuraffaApp shell, whose import must resolve in the TARGET project.
///
/// VISION §4 (errors-are-an-API): a missing dependency is surfaced as a
/// named, machine-parseable fix BEFORE any artifact is written — never as
/// a generated test that can only die at `verify-red` with
/// `compile-error` (the loop would never reach an honest RED), and never
/// as a silent pubspec mutation (this class only READS the pubspec).
abstract final class WidgetSkinPreflight {
  /// The package the zuraffaapp shell's import needs.
  static const String skinPackage = 'zuraffa_ui';

  /// The canonical fix line (machine-parseable: tools and humans grep for
  /// the `--> fix:` prefix; the remainder names the exact remedy).
  static const String fixLine =
      '--> fix: flutter pub add zuraffa_ui '
      '(widget-lane behaviors boot a ZuraffaApp shell)';

  /// Whether [projectRoot]'s `pubspec.yaml` declares [skinPackage] in
  /// its `dependencies:` map.
  ///
  /// A project with NO pubspec.yaml has nothing to resolve — the check
  /// passes and gen keeps its pre-#938 behavior (bug-830-era fixture
  /// contexts are not pubspec-carrying projects; a real zfa project
  /// always has a pubspec).
  static bool projectDeclaresZuraffaUi(String projectRoot) {
    final pubspecFile = File(p.join(projectRoot, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) return true;
    final YamlNode? doc;
    try {
      doc = loadYaml(pubspecFile.readAsStringSync());
    } on YamlException {
      // An unparseable pubspec is not this bug's problem — gen's own
      // resolution and the project's tooling will surface it. The
      // preflight only refuses on a READABLE pubspec that omits the
      // dependency (deterministic: same pubspec, same verdict).
      return true;
    }
    if (doc is! YamlMap) return true;
    final dependencies = doc['dependencies'];
    if (dependencies is! YamlMap) return false;
    return dependencies.containsKey(skinPackage);
  }

  /// Whether a gen for [shell] on [projectRoot] must stop at the #938
  /// preflight (widget kind is enforced by the caller).
  static bool skinImportRequired(WidgetAppShell shell) =>
      shell == WidgetAppShell.zuraffaapp;
}
