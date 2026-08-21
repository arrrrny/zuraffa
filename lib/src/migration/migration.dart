/// Migration tooling for v5 to v6 upgrade path.
///
/// This library provides:
/// - **Detectors** that scan for v5 patterns
/// - **Fixers** that migrate v5 artifacts to v6 equivalents
/// - **Models** for findings, actions, and reports
///
/// Usage from CLI: `zfa doctor` (detect) or `zfa migrate <target>` (fix).
library;

export 'migration_models.dart';
export 'detectors/base_detector.dart';
export 'detectors/gql_detector.dart';
export 'detectors/state_detector.dart';
export 'detectors/di_detector.dart';
export 'detectors/controlled_widget_detector.dart';
export 'detectors/dependency_overrides_detector.dart';
export 'fixers/base_fixer.dart';
export 'fixers/state_fixer.dart';
export 'fixers/gql_fixer.dart';
