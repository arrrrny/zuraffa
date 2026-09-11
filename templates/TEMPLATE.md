# zuraffa plugin-example template

The general shape every `zuraffa_*` plugin example app follows. Two
reference implementations, in the order they established the pattern:

- `~/Developer/zuraffa_intents/example` — share-intents (boot share card /
  live stream feed / record form)
- `~/Developer/zuraffa_permissions/packages/zuraffa_permissions/example` —
  permissions (outcome-matrix simulator / live tab)

## Contract

1. **Scaffold**: `zfa setup <dir> --flutter --platforms=ios,macos,android
   --org=dev.zuraffa --no-git`, then trim `pubspec.yaml` to what the demo
   uses: `flutter`, `get_it`, the plugin (path dep), dev `flutter_test` +
   `flutter_lints`. `publish_to: 'none'`.
2. **Real driver first**: `main()` binds the plugin's composition root
   (`register*Dependencies(GetIt.instance)`) and hands the GetIt-registered
   service to the app widget — the app demonstrates the REAL platform
   stack by default.
3. **Simulator switch**: an app-bar toggle swaps in the plugin's pure-Dart
   in-memory adapter so every outcome is demonstrable without OS
   integration. Producer-side buttons expose the adapter's test seams.
4. **One panel per plugin operation**, wired end to end, with the
   operation name visible in the UI (the panels ARE the API tour).
5. **Errors verbatim**: `PlatformException`s surface in a banner — never
   swallowed (the `channel-error` class proves a missing native half).
6. **Injectable service** on the app widget (`Service? initialService`)
   so widget tests run the full flow over the simulator without channels.
7. **Widget test = executable documentation**: drive the complete flow —
   every operation once, asserting outcomes (including the carrier/field
   mapping), plus the error path.
8. **README**: a table mapping plugin operation → where in the app, then
   per-platform receive/trigger instructions, then the run command.
9. **Verification checklist** (all green before shipping):
   `flutter pub get` · `flutter analyze` (0 issues) · `flutter test` ·
   root `flutter pub publish --dry-run` (0 warnings) · visual run on the
   Android emulator and macOS (`flutter run -d macos`).

## Scaffold

```sh
templates/plugin-example/scaffold.sh <example-dir> <package-import>
```

Creates the skeleton (pubspec, main.dart with the switch + placeholder
panel, widget test, README) with `// TODO(template):` hooks where the
plugin's own API surface goes. Reference the two implementations above
for finished panels.

## Platform notes

- **Android share/permission reachability** is app-manifest work
  (intent filters / permission declarations) — the plugin manifest stays
  empty; document the app-side snippet in the example README.
- **iOS/macOS system integration** that needs Xcode targets (Share
  Extension, permission usage descriptions in Info.plist) is documented
  in the README, not pre-built by the scaffold.
- Commit the example `pubspec.lock` (apps pin their lockfiles); the root
  package `.gitignore` needs `!example/pubspec.lock`.
