# Data Model: Setup generates ZuraffaApp as root widget

## Entities

### AppShellConfig

Configuration object that flows through the generation pipeline.

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `appName` | `String` | yes | — | Dart package name from pubspec.yaml |
| `isFlutter` | `bool` | yes | `true` | Whether the target is a Flutter project |
| `zuraffaApp` | `bool` | yes | `false` | Use ZuraffaApp shell instead of MaterialApp.router |
| `coreImport` | `String` | yes | `package:zuraffa/zuraffa.dart` | Resolved core barrel import (zuraffa_flutter for Flutter) |
| `outputDir` | `String` | yes | `lib/src` | Project-root-relative output directory |
| `title` | `String?` | no | `null` | App title for MaterialApp/ZuraffaApp |
| `skinAudit` | `bool` | no | `false` | Mount SkinAuditChrome under the shell |
| `xray` | `bool` | no | `false` | Wire X-Ray bridge into main.dart |

### State: `zfa setup` execution flow

```
[flutter create] → [write bootstrap barrels] → [preflight zuraffa_ui] → [generate app shell] → [done]
                                                   ↓ (if missing)
                                             [error: add zuraffa_ui]
```

## Relationships

- `AppShellConfig` is consumed by `AppShellBuilder.buildMain()` and `AppShellBuilder.buildMyApp()`
- `zuraffaApp: true` causes `buildMyApp()` to emit `ZuraffaApp` instead of `MaterialApp.router`
- `coreImport` (from project flavor detection) determines whether `GetIt` is imported from `zuraffa` or `zuraffa_flutter`
