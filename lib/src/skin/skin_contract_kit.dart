/// SkinContractKit — the runtime skin-contract auditor's pure core
/// (issue #1102).
///
/// The third enforcement tier of the skin contract: static source
/// guards check the recipe, widget tests check the cake once in CI,
/// THIS kit checks the cake on every audited frame in the oven.
///
/// Everything here is pure Dart (Constitution VII): the Flutter
/// glue — `inspectTree(Element)`, the `SkinContractAuditor` widget,
/// the `SkinRouteContractObserver`, the banner chrome, `ZfaButton`,
/// `debugTapAnchor` — is EMITTED into target projects by
/// `SkinContractKitBuilder` (`zfa skin kit` / `--skin` view
/// generation / `--skin-audit` app shell) and imports this barrel
/// through `package:zuraffa/skin.dart`.
library;

export 'anchors.dart';
export 'route_contract_table.dart';
export 'skin_audit_controller.dart';
export 'skin_audit_scheduler.dart';
export 'skin_contract_row.dart';
export 'skin_violation.dart';
export 'tree_facts.dart';
