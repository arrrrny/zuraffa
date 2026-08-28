import 'package:nocterm/nocterm.dart' as nocterm;

/// Container widget for Zuraffa TUIs (FR-004).
///
/// Thin re-export of nocterm's Container so the Zuraffa surface names match
/// the spec vocabulary. Apps get padding / border / decoration without
/// touching nocterm's ContainerConfig directly.
typedef Container = nocterm.Container;
