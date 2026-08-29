# reference_package_app

Spec 025 demo: consumes [`../notes_package`](../notes_package) through its
**package module** — auto-DI (zero manual registration), engine lifecycle
(init → ready → dispose), and the namespaced agent tool
(`notes_package.get_note`).

```bash
dart pub get
dart run bin/app.dart   # the whole integration story in one main()
dart test               # the SC-002 acceptance proof
```

See [Writing Zuraffa packages](../../docs/writing_zuraffa_packages.md).
