# zuraffa_flutter

Flutter UI layer for [Zuraffa](https://pub.dev/packages/zuraffa) — the AI-first Clean
Architecture framework and CLI.

`zuraffa` is pure Dart: entities, use cases, repositories, DI, state, telemetry, and the
`zfa` code generator. `zuraffa_flutter` adds everything that needs the Flutter SDK:

- **Views & presentation** — `View`, `ResponsiveView`, `AdaptiveView`, `Presenter`,
  `Controller`, `ControlledWidget`
- **App shells** — mobile / tablet / desktop / macOS shells with an automatic resolver
- **State widgets** — `SignalBuilder`, `FragmentBuilder` over Zuraffa's signal slices
- **X-Ray** — runtime widget inspection: overlay with bounding boxes, control deck,
  mock payload injection, and an MCP bridge so AI agents can inspect the live UI
- **Module wiring** — `AppRunner` and route building for `ZuraffaEngine` plugins

## Installation

```yaml
dependencies:
  zuraffa: ^6.0.0
  zuraffa_flutter: ^6.0.0
```

Or let the CLI wire it for you:

```bash
dart pub global activate zuraffa
zfa setup
```

## Usage

Generated code from `zfa make ... --with=vpc --state` imports this package directly:

```dart
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ProductView extends View<ProductController> {
  const ProductView({super.key});

  @override
  Widget buildView(BuildContext context, ProductController controller) {
    return SignalBuilder(
      signal: controller.state.products,
      builder: (context, products) => ListView(/* ... */),
    );
  }
}
```

## Documentation

- Framework docs: <https://zuraffa.com>
- Repository & issues: <https://github.com/arrrrny/zuraffa>

## License

MIT — see [LICENSE](LICENSE).
