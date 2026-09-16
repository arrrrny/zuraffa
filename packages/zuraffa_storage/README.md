# zuraffa_storage

Optional [Zuraffa](https://github.com/arrrrny/zuraffa) capability package
(issue #1661): carries the heavyweight dependencies so the core package
stays lean.

## Enable

```bash
zfa plugin enable storage
```

Then add the repository-local package to your pubspec:

```yaml
dependencies:
  zuraffa_storage:
    path: packages/zuraffa_storage
```

Then run `dart pub get`.
