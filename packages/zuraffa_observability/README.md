# zuraffa_observability

Optional [Zuraffa](https://github.com/arrrrny/zuraffa) capability package
(issue #1661): carries the heavyweight dependencies so the core package
stays lean.

## Enable

```bash
zfa plugin enable observability
```

Then add the repository-local package to your pubspec:

```yaml
dependencies:
  zuraffa_observability:
    path: packages/zuraffa_observability
```

Then run `dart pub get`.
