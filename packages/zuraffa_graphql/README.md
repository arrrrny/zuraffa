# zuraffa_graphql

Optional [Zuraffa](https://github.com/arrrrny/zuraffa) capability package
(issue #1661): carries the heavyweight dependencies so the core package
stays lean.

## Enable

```bash
zfa plugin enable graphql
```

Then add the repository-local package to your pubspec:

```yaml
dependencies:
  zuraffa_graphql:
    path: packages/zuraffa_graphql
```

Then run `dart pub get`.
