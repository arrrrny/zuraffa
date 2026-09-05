/// Public runtime skin-contract kit barrel (issue #1102).
///
/// Generated Flutter apps import the auditor's pure core through
/// this library — the emitted kit file
/// (`skin/skin_contract_auditor.dart`) and the generated `--skin`
/// views both resolve `TreeFacts`, `SkinContractRow`,
/// `RouteContractTable`, the audit bus core, the scheduler, and the
/// typed anchor protocol from here. Apps already depend on
/// `package:zuraffa` for their DI tree, so the runtime contract
/// needs no new dependency.
library;

export 'src/skin/skin_contract_kit.dart';
// skin-contract.v1 (issue #1164): the typed declaration surface.
export 'src/skin/contract/skin_contract.dart';
export 'src/skin/contract/skin_contract_parser.dart';
export 'src/skin/contract/skin_contract_schema.dart';
