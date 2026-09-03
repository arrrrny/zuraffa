/// Widget-test scaffold surface (issue #912 defects 2+3).
///
/// Defect 2: the widget test template's app shell (ShadApp vs MaterialApp)
/// is configurable — zuraffa apps are shadcn_ui apps, so the default is
/// [WidgetAppShell.shadapp]; plain-Material projects opt out via
/// `zfa tdd gen --widget-shell materialapp` or `.zfa.json`
/// `tdd.widgetShell: "materialapp"`.
///
/// Defect 3: when the widget template cannot derive concrete scenario
/// finders from the behavior description, the emitted test is a
/// PLACEHOLDER (its mounted-view `findsOneWidget` is greenable by a bare
/// `SizedBox()`), so it carries [scaffoldedMarker]. The green
/// certification (`zfa tdd make`) reads that marker and EXCLUDES the
/// behavior from contract-green accounting — a placeholder test never
/// certifies green.
library;

/// The app shell a generated widget test pumps the feature view in.
enum WidgetAppShell {
  /// shadcn_ui's ShadApp — the default shell for zuraffa apps (issue
  /// #912 defect 2: ZikZak is ShadApp; SC-001 asserts ShadTheme).
  shadapp,

  /// Flutter's MaterialApp — for projects that do not use shadcn_ui.
  materialapp;

  /// The shell widget identifier emitted into the generated test.
  String get widgetName =>
      this == WidgetAppShell.shadapp ? 'ShadApp' : 'MaterialApp';

  /// Parses a `.zfa.json`/CLI string value; unknown values fall back to
  /// the default.
  static WidgetAppShell parse(String? value) =>
      value == 'materialapp' ? materialapp : shadapp;
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
