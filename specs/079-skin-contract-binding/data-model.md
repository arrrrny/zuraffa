# Data Model: skin-contract runtime binding (079)

- **SkinContractDeclaration**: {name (from heading), contract (parsed body)}.
- **SkinContractRuntimeBinding**: {name, routeTable: RouteContractTable, stateBindings: Map<view, StateBinding>, auditRows: List<ContractStateRow>}.
- **StateBinding**: {view, error: none|toaster|inline, empty: bool}.
- Parsing strictness unchanged; heading name is declaration metadata, not schema data.
