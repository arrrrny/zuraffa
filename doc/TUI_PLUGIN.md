# Zuraffa TUI Plugin — Quickstart

A native, built-in, pure-Dart TUI plugin for Zuraffa apps. Build interactive terminal UIs with a single standardized entry point and a declarative component tree — consistent across all Zuraffa apps.

**Spec**: `specs/017-tui-plugin/spec.md`
**Plan**: `specs/017-tui-plugin/plan.md`

## Why use it

- **Pure-Dart** — works in any Dart 3.11+ environment, no Flutter SDK required (FR-012).
- **One entry point** — `ZuraffaTui.run(rootScreen)` boots the engine, runs the input loop, and shuts down cleanly (FR-001).
- **Declarative** — compose screens from layout + primitive components, just like Flutter widgets (FR-002).
- **Stateful** — `setState(() {})` triggers a re-render of the affected view (FR-003).
- **Standard widget library** — text, containers, rows/columns, list/grid/table, text input, scrollable, progress, navigation, focus/selection (FR-004).
- **Shared theming** — `ZuraffaTuiTheme.defaultTheme()` gives every Zuraffa TUI the same visual vocabulary (FR-005).
- **Canonical keyboard defaults** — `q`/`Ctrl+C` quit, `Enter` confirm, arrows navigate, `Tab`/`Shift+Tab` focus; with plugin/app override precedence (FR-006).
- **Domain `Binding`** — observe a `StreamUseCase` / repository / `UseCase` result without a TUI-local data store (FR-007).
- **DI through your container** — resolves deps via your existing `ZuraffaDIContainer`/`GetIt` (FR-008).
- **Generator support** — `zfa make --with=tui` emits list/detail TUI screens wired to an entity's existing use cases (FR-011).

## Scaffold your first TUI (< 10 minutes, SC-001)

```dart
// bin/my_app.dart
import 'package:zuraffa/zuraffa.dart';
import 'package:nocterm/nocterm.dart';

class HelloScreen extends Screen {
  const HelloScreen();

  @override
  Component build(BuildContext context) =>
    const Center(child: Text('Hello, Zuraffa TUI!'));
}

Future<void> main() async {
  await ZuraffaTui.run(const HelloScreen());
}
```

Run it:

```bash
dart run bin/my_app.dart
```

Press `q` to quit. That's it — your first Zuraffa TUI is running.

## A stateful screen

```dart
class CounterScreen extends StatefulScreen {
  const CounterScreen();

  @override
  TuiScreenState<CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends TuiScreenState<CounterScreen> {
  int _count = 0;

  @override
  Component buildScreen(BuildContext context) =>
    Center(
      child: Column(
        children: [
          Text('count: $_count'),
          Text('press j to increment, q to quit'),
        ],
      ),
    );

  @override
  void onKey(KeyboardEvent event) {
    if (event.logicalKey == LogicalKey.fromCharacter('j')) {
      _count++;
      setState(() {});
    }
  }
}
```

## Bind a screen to a use case (FR-007, SC-004)

```dart
class ProductsScreen extends StatefulScreen {
  const ProductsScreen();

  @override
  TuiScreenState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends TuiScreenState<ProductsScreen> {
  late final StreamUseCaseBinding<List<Product>, void> _binding;

  @override
  void initState() {
    super.initState();
    final di = ZuraffaDIContainer(); // injected by ZuraffaTui.run in real apps
    _binding = StreamUseCaseBinding<List<Product>, void>(
      useCase: WatchProductsUseCase(di.get<ProductRepository>()),
      params: null,
      onValue: (_) => setState(() {}),
    );
    _binding.start();
  }

  @override
  void dispose() {
    _binding.dispose();
    super.dispose();
  }

  @override
  Component buildScreen(BuildContext context) {
    final products = _binding.value ?? const [];
    return Center(
      child: ListView.builder(
        itemCount: products.length,
        itemBuilder: (context, i) => Text(products[i].name),
      ),
    );
  }
}
```

The binding holds NO data store of its own — `_binding.value` IS the domain source's value (SC-004).

## Override keyboard defaults (FR-006)

```dart
await ZuraffaTui.run(
  const HelloScreen(),
  keys: KeyBindings.merge(
    appOverrides: {
      KeyAction.quit: {'Q'}, // uppercase Q quits instead of q
    },
  ),
);
```

App overrides win any conflict with plugin overrides; unoverridden actions retain their defaults.

## Generate entity TUI screens (FR-011, SC-005)

```bash
zfa entity create -n Product \
  --field id:String \
  --field name:String \
  --field price:double

zfa make Product \
  --preset=crud \
  --with=tui \
  --methods=get,getList,create,update,delete \
  --state \
  --di \
  --test

zfa build
```

The generator emits `ProductListScreen` and `ProductDetailScreen` under `lib/src/presentation/tui/`, both wired to the entity's existing use cases. Zero manual wiring required.

## Edge cases (FR-009)

- **Non-TTY stdout**: the TUI refuses to start with `TuiNonTtyException` rather than corrupting piped output.
- **Terminal resize**: `ResizeHandler` relays new dimensions to registered listeners so screens can reflow.
- **In-flight input**: only `Escape` (cancel) and the effective quit binding are accepted during an in-flight action; all other input is dropped. Each dispatched action gets a child `CancelToken` linked to the session's root token; on quit/dispose, the root cancels every in-flight action.
- **Engine-init failure**: if `nocterm` cannot initialize the terminal (missing native libs / unsupported platform), the TUI throws `TuiEngineInitException` with an actionable message rather than crashing.
- **Minimal config**: a TUI built from hand-composed screens alone (no entity scaffolding) runs.

## Conformance (SC-003)

Two independently built Zuraffa TUIs each pass `test/plugins/tui/conformance_test.dart`. The test verifies:
1. Both use the shared `ZuraffaTuiTheme.defaultTheme()` vocabulary.
2. Both use the canonical `KeyBindings.defaults()` keys.
3. One configured override takes precedence while unoverridden keys retain their defaults.
4. The entry-point signature is identical across both TUIs.

## API reference

| Surface | File |
|---------|------|
| Entry point | `lib/src/plugins/tui/runtime/zuraffa_tui.dart` → `ZuraffaTui.run` |
| Declarative component model | `lib/src/plugins/tui/core/component.dart` → `Screen` |
| Stateful screens | `lib/src/plugins/tui/core/stateful_screen.dart` → `StatefulScreen`, `TuiScreenState` |
| Standard widgets | `lib/src/plugins/tui/widgets/widgets.dart` (barrel) |
| Theme | `lib/src/plugins/tui/theme/theme.dart` → `ZuraffaTuiTheme.defaultTheme()` |
| Keyboard defaults + overrides | `lib/src/plugins/tui/input/key_bindings.dart` → `KeyBindings.defaults()`, `KeyBindings.merge(...)` |
| Domain `Binding` | `lib/src/plugins/tui/binding/binding.dart` → `StreamUseCaseBinding`, `RepositoryBinding`, `UseCaseResultBinding` |
| DI | `lib/src/plugins/tui/di/tui_di_resolver.dart` → `TuiDiResolver` (wraps your `ZuraffaDIContainer`) |
| Edge cases | `lib/src/plugins/tui/edge/tty_guard.dart` → `TtyGuard`, `ResizeHandler`, `TuiException` family |
| Plugin registration | `lib/src/plugins/tui/tui_plugin.dart` → `ZuraffaTuiPlugin` |
| Generator | `lib/src/plugins/tui/generator/tui_screen_generator.dart` → `TuiScreenGenerator` |
| Generator capability | `lib/src/plugins/tui/generator/capabilities/create_tui_screens_capability.dart` → `CreateTuiScreensCapability` |

## Pure-Dart guarantee (FR-012)

The TUI plugin path (`lib/src/plugins/tui/` + `test/plugins/tui/`) contains **zero** `import 'package:flutter/...'` statements — enforced statically by `test/plugins/tui/no_flutter_import_test.dart`. Any future Flutter-only rendering path MUST live in `zuraffa_flutter`, never forced on pure-Dart consumers.
