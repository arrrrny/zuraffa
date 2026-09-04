# Contract: DI Graph Check (merge gate)

## Generated proof

Merge generates a conformance test in the merged host that:
1. constructs the host's service locator with the feature's binding
   module registered (flavor-switched: mock and real),
2. resolves EVERY manifest `BindingDecl.token`,
3. fails naming any token that cannot resolve per flavor.

The check runs as a real test via the host's suite runner — the
bootstrap smoke pattern (existing smoke_test_writer shape) pointed at
the feature's bindings. Evidence, not grep.

## Pass condition

Every token resolves in every declared flavor. The graph constructs
fully (no missing factory, no cycle surfaced at construction).

## Failure output

```text
DI token '<token>' (flavor: mock) did not resolve after merge.
--> fix: register <token> in the feature's binding module
    (lib/src/di/<feature>_binding.dart), then re-run
    `zfa slice merge --into <host>`.
```

## Flavors

Both flavors declared by the manifest must resolve. A host that boots
mock-flavor must serve the certified mock at every feature touchpoint
(mock-first), real-flavor the real adapter.
