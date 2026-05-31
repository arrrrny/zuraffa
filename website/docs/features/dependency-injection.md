# Dependency Injection

Zuraffa can generate DI setup alongside the rest of your architecture.

The v5 public workflow is:

1. create the entity
2. run `zfa make` with `--di`
3. run `zfa build`

---

## Basic usage

### 1. Generate with DI

```bash
zfa make Product --preset=crud --methods=get,getList,create --di
```

### 2. Initialize in `main.dart`

Import the generated DI entrypoint and initialize it before `runApp()`.

```dart
import 'package:get_it/get_it.dart';
import 'src/di/index.dart';

final getIt = GetIt.instance;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupDependencies(getIt);
  runApp(MyApp());
}
```

---

## Development with mocks

Use `--mock --use-mock` when you want DI to bind the mock path by default:

```bash
zfa make Product --preset=crud --methods=get,getList --mock --di --use-mock
```

---

## Next steps

- [Mock Data](./mock-data)
- [Caching](./caching)
- [CLI Commands Reference](../cli/commands)
