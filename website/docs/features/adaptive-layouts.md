# Platform-Aware Layouts

Zuraffa v5 supports framework-level platform/device-aware presentation composition. This allows you to share business logic while having specialized layouts for mobile, tablet, desktop, and macOS.

---

## Overview

The platform-aware layout system separates:
- **Shared logic**: presenter, controller, state (generated and reusable)
- **Platform layouts**: layout files that adapt to device/platform

---

## Device Classes

| Class | Width | Use Case |
|-------|-------|----------|
| `watch` | < 300dp | Wearable devices |
| `phone` (mobile) | 300-600dp | Handheld phones |
| `tablet` | 600-950dp | Tablets |
| `desktop` | > 950dp | Desktop screens |

## Platform Classes

| Class | Description |
|-------|-------------|
| `ios` | iOS devices |
| `android` | Android devices |
| `macos` | macOS desktop |
| `windows` | Windows desktop |
| `linux` | Linux desktop |
| `web` | Web browsers |

---

## Generating Adaptive Layouts

### Using the adaptive-feature preset

```bash
zfa make Product \
  --preset=adaptive-feature \
  --methods=get,getList
```

This generates shared presenter/controller/state plus layout files for each target platform/device combination.

### Manual adaptive layout configuration

```bash
zfa make Product \
  --preset=crud \
  --with=vpc,state \
  --adaptive-layouts \
  --layout-targets=mobile,tablet,desktop,macos
```

---

## Layout Fallback Order

When resolving a layout, Zuraffa uses this priority:

1. **compound** (e.g. `macos_desktop`) - platform + device specific
2. **platform** (e.g. `macos`) - platform wide
3. **device** (e.g. `desktop`) - device class wide  
4. **generic** (`default`) - fallback

Example for macOS desktop:
- `macos_desktop` → `macos` → `desktop` → `default`

---

## Generated Structure

```text
lib/src/presentation/pages/<feature>/
├── product_view.dart
├── product_presenter.dart
├── product_controller.dart
├── product_state.dart
└── layouts/
    ├── product_mobile_layout.dart
    ├── product_tablet_layout.dart
    ├── product_desktop_layout.dart
    ├── product_macos_layout.dart
    └── product_layouts.dart  # exports all layouts
```

---

## Using the Layout Resolver

In your code, use `PlatformLayoutResolver` or `AdaptiveViewState`:

```dart
class _ProductListState extends AdaptiveViewState<ProductListPage, ProductListController, ProductListState> {
  _ProductListState() : super(ProductListController());

  @override
  Map<String, WidgetBuilder> get layouts => {
    'mobile': (_) => ProductListView(),
    'tablet': (_) => ProductGridPage(),
    'desktop': (_) => ProductTablePage(),
    'macos': (_) => MacosProductLayout(),
  };
}
```

---

## Application Shells

Zuraffa provides platform-specific shell widgets:

| Shell | Platforms | Layout |
|-------|-----------|--------|
| `MobileAppShell` | iOS, Android phones | Bottom navigation |
| `TabletAppShell` | Tablets | Navigation rail + content |
| `DesktopAppShell` | Windows, Linux | Permanent sidebar |
| `MacosAppShell` | macOS | Safe area + sidebar |

Use `AppShellResolver` to get the appropriate shell:

```dart
final context = PlatformContext.current(deviceClass: DeviceClass.fromWidth(width));
Widget shell = AppShellResolver.resolve(
  platformContext: context,
  title: 'Products',
  body: ProductListLayout(),
);
```

---

## Configuration

Enable adaptive layouts by default in `.zfa.json`:

```json
{
  "ui": {
    "adaptiveLayouts": true,
    "layoutTargets": ["mobile", "tablet", "desktop", "macos"]
  }
}
```

---

## Next Steps

- [CLI Commands Reference](../cli/commands)
- [VPC Generation](./vpc-regeneration)
- [Clean Architecture](./architecture/overview)
