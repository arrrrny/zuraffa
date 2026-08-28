# Bug Issue: zfa app shell --xray generates non-compiling main.dart (missing xray_bridge_launcher_stub.dart + undefined XRayBridgeServer)

- **Slug**: issue-469-app-shell-xray-non-compiling
- **Fetched**: 2026-08-23T11:49:39.475676+00:00
- **Issue**: 469
- **URL**: https://github.com/arrrrny/zuraffa/issues/469
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: none

## Body

## Summary
\`zfa app shell --xray --force\` exits 0 but emits a \`lib/main.dart\` that does **not** compile. It imports a \`xray_bridge_launcher_stub.dart\` file that zfa never creates, and references \`XRayBridgeServer\` via a zuraffa_flutter path that does not exist and is not exported. The generated app cannot build.

Found during the v6 \"build a ZikZak clone using only zfa commands\" smoke test (apps/zikzak_demo).

## Command
\`\`\`bash
cd apps/zikzak_demo
zfa app shell --xray --force
\`\`\`
App has zuraffa_flutter as a dependency; DI barrel declares \`void setupDependencies(GetIt getIt)\`; routing exports \`getAllRoutes()\`.

## Expected
\`lib/main.dart\` wires the X-Ray bridge and compiles — \`void main() async { setupDependencies(GetIt.instance); if (kDebugMode) { await _startXRayBridge(); registerAllXRayDecks(); } runApp(const MyApp()); }\`, with \`MyApp\` wrapped in \`XRayScope\` and the bridge server starting in debug.

## Actual — 2 analyze errors in lib/main.dart
\`\`\`
lib/main.dart:7:8   error • Target of URI doesn't exist: 'xray_bridge_launcher_stub.dart'.
lib/main.dart:32:11 error • The function 'XRayBridgeServer' isn't defined.
\`\`\`
Generated imports (from \`lib/src/plugins/app_shell/builders/app_shell_builder.dart\` \`buildMain\`):
\`\`\`dart
import 'package:flutter/foundation.dart';
import 'xray_bridge_launcher_stub.dart'
    if (dart.library.io) 'package:zuraffa_flutter/src/presentation/xray/xray_bridge_server.dart';
...
Future<void> _startXRayBridge() async {
  ...
  await XRayBridgeServer().start();
}
\`\`\`

## Root cause
1. \`app_shell_builder.dart:204\` emits \`import 'xray_bridge_launcher_stub.dart'\`, but **no zfa command writes that file** (grep of \`lib/\`+\`bin/\` for \`xray_bridge_launcher_stub\` shows only the emission site). The unconditional relative import always fails.
2. The conditional \`if (dart.library.io) 'package:zuraffa_flutter/src/presentation/xray/xray_bridge_server.dart'\` target **does not exist** in zuraffa_flutter — there is no \`xray\` directory, no \`xray_bridge_server.dart\`, and \`XRayBridgeServer\` is not exported from \`package:zuraffa_flutter/zuraffa_flutter.dart\`. The X-Ray bridge server appears unimplemented in zuraffa_flutter.

Both references are dead, so the generated \`main.dart\` cannot compile on any platform.

## Suggested fix
- \`zfa app shell --xray\` must emit \`lib/xray_bridge_launcher_stub.dart\` (a web-safe no-op stub, or the real launcher) so the unconditional import resolves.
- Implement and export \`XRayBridgeServer\` from zuraffa_flutter at \`lib/src/presentation/xray/xray_bridge_server.dart\` (or update the conditional import path to where it actually lives). The bridge server is referenced by the generated shell but missing from the runtime package.

## Environment
- zuraffa master @ 0c97c28, zfa v6.0.0 (rebuilt clean from master)
- apps/zikzak_demo: Flutter 3.44.8, zuraffa_flutter (path \`../../zuraffa_flutter\`)
- The non-xray \`zfa app shell --force\` (without \`--xray\`) compiles fine — only the \`--xray\` path is broken.

## Comments

None.
