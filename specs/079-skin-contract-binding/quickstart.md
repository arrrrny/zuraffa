# Quickstart: skin-contract runtime binding (079)

```bash
dart test test/plugins/skin_contract/ test/tdd/079-skin-contract-binding/
dart analyze lib/src/skin/contract
```

```dart
final declaration = parseSkinContractDeclaration(specMarkdown); // name + contract
final binding = SkinContractRuntimeBinding.fromContract(
  name: declaration.name, contract: declaration.contract,
);
binding.routeTable.allows('/login');        // true
binding.stateBindingFor('LoginPage').error; // StateErrorKind.toaster
```
