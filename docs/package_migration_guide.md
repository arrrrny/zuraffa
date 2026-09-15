# Package Migration Guide — Converting a Dart/Flutter package to Zuraffa

A practical playbook for taking an **existing** Dart or Flutter package and
turning it into a **Zuraffa-native package** (pure architecture) or a
**Zuraffa federated plugin** (platform adapters), rebuilt test-first with the
`zfa` TDD engine.

This guide covers **brownfield** migration — you already have code, tests, and
users. For greenfield packages created from scratch, see
[Writing Zuraffa Packages](writing_zuraffa_packages.md). For the mechanics of
the TDD loop itself, see the [ZFA TDD Guide](zfa-tdd-guide.md).

**Worked example**: [dart_curl](https://github.com/arrrrny/dart_curl) — a pure
Dart FFI HTTP client (~4.4k lines, native curl-impersonate bridge + CLI) — was
migrated with exactly this playbook. The `zuraffa-migrate` speckit extension
automates the guide (see §10).

---

## 0. Why migrate

A Zuraffa-native package is not just a style choice — it changes what the
package **does**:

| Capability | Plain package | Zuraffa package/plugin |
|---|---|---|
| Consuming apps resolve your API | manual construction | **auto-DI** — `engine.registerPackage(module)` registers every usecase/repository/datasource |
| Lifecycle | caller manages init/dispose | `bootstrap()` → `ready()` → `shutdown()`, reverse-order dispose |
| Version gating | pubspec luck | `zuraffaSdkConstraint` checked at registration, fails loudly |
| Agent tools | none | namespaced `<package>.<tool>` MCP tools contributed to the consuming app |
| TDD pipeline | your own harness | `zfa tdd` engine: spec → test-list → red-green-refactor → verified journal |
| Publish pipeline | your own scripts | `zfa package create-plugin` stamps the zikzak publish pipeline |

## 1. Decide the target shape

One decision gates everything else. Run the census, then pick a row:

```bash
# Platform census: does the package touch channels/native beyond FFI?
grep -rn "MethodChannel\|EventChannel\|pigeon" lib/ | head
# Flutter census: does it import Flutter at all?
grep -rln "package:flutter/" lib/ | head
```

| Your package… | Target shape | Scaffold command | Reference repos |
|---|---|---|---|
| Pure Dart, no Flutter/channels (logic, FFI, CLI, parsing) | **Zuraffa package** (single repo) | `zfa package create <name>` | `zuraffa_session` |
| Talks to platform APIs (channels, Keychain, native views) | **Federated plugin monorepo** | `zfa package create-plugin <name>` | `zuraffa_auth`, `zuraffa_permissions` |
| Pure core + separate Flutter wrapper today (two repos) | Package now; wrapper becomes a sibling package or federated adapter later | `zfa package create` for the core | `dart_curl` → `dart_curl_flutter` (planned) |

Rules of thumb:

- **FFI is not a platform channel.** A pure-Dart package that dlopens a native
  library stays a **package** — the FFI bridge is a datasource behind a port,
  not a platform adapter. Don't scaffold a federated monorepo for it.
- If the *only* Flutter-specific part is a widget or a channel wrapper, keep
  the core a package and migrate the wrapper as a second, dependent package —
  mirroring the `dart_curl` / `dart_curl_flutter` split.
- Scaffolding is cheap (`--dry-run` previews without writing). When in doubt,
  scaffold both shapes and diff the file trees against your inventory.

## 2. Phase 0 — Inventory (the migration contract)

Before writing any zuraffa code, freeze what you are migrating. Write
`specs/001-zuraffa-migration/migration-contract.md` in the new repo (or a
`specs/<NNN>-zuraffa-rewrite/` folder in the existing one):

1. **Public API census** — every exported symbol from the barrel, with its
   signature. This is your **parity contract**: the migration is done when the
   new package satisfies this surface (compatibility facade, §6) or when you
   have explicitly decided to break each broken symbol.
2. **Behavior census** — every observable behavior the existing tests pin.
   The existing test suite **is** the behavior census; list the files and the
   behaviors they cover. Tests port first (§5), so nothing is lost.
3. **Native/platform census** — FFI libraries, channels, assets, build
   scripts, and how they are located at runtime.
4. **Dependency census** — pubspec deps, and which become zuraffa-native
   equivalents (e.g., hand-rolled DI → `get_it` via the container).
5. **Consumers** — who imports the package and which symbols they actually
   use (`grep` your own apps before promising facade compatibility).

Classify every public symbol into a **mapping decision** now (see §4). Any
symbol you cannot classify is a spec question, not an implementation detail —
resolve it before Phase 3.

## 3. Phase 1 — Scaffold

### Pure package

```bash
zfa package create <name> --description "<original description>, zuraffa-native"
cd <name>
```

This produces the standard layout (`pubspec.yaml` with `zuraffa ^6.x` +
zorphy deps, `zfa.yaml` package-mode marker, `build.yaml`, the domain/data
skeleton, a runtime module, a package registrar, and a smoke test) that passes
`dart analyze` and `zfa build` with zero edits.

Useful flags: `--zuraffa-path <path>` to develop against a local zuraffa
checkout, `--zuraffa-constraint ^6.2.2` to pin the stamped constraint,
`--dry-run` to preview.

### Federated plugin

```bash
zfa package create-plugin <name> \
  --description "..." --repo <owner>/<name> --platforms android,ios,macos
```

Produces the publish-ready monorepo the `zuraffa_auth` /
`zuraffa_permissions` repos follow:

```text
<name>/
├── README.md / PUBLISH.md / LICENSE / CHANGELOG.md
├── scripts/                        # zikzak publish pipeline
└── packages/
    ├── <name>/                     # app-facing: Port + Service + module + registrar
    ├── <name>_platform/            # shared channel-envelope core (decode, typed errors, timeouts)
    ├── <name>_android/             # adapter over an INJECTED channel seam + register.dart
    ├── <name>_ios/
    └── <name>_macos/
```

Adapters are pure Dart — the transport arrives through the platform envelope,
so every package analyzes and tests without a device.

### Into an existing repo (in-place migration)

When the migration lands as a rewrite of the **same** repository (the
`dart_curl` approach) rather than a fresh repo:

1. Branch (`zuraffa-rewrite`).
2. Recreate the scaffold's *load-bearing* files by hand in the existing repo:
   `zfa.yaml` (`package_mode: true`), `build.yaml` (zorphy +
   json_serializable builders), the `lib/src/{domain,data,module,di}` skeleton
   and barrel. `zfa package create` refuses to run in a non-empty directory —
   copy the generated files from a `--dry-run`-verified scratch scaffold.
3. Add `zuraffa` to `dependencies` (and `zorphy_annotation`; `build_runner`,
   `zorphy`/`json_serializable` to `dev_dependencies`), then `dart pub get`.

## 4. Phase 2 — Map old API to zuraffa shapes

The mapping table below is the heart of the migration. Apply it symbol by
symbol to your Phase-0 census:

| Old shape | Zuraffa shape | Notes |
|---|---|---|
| High-level service class (`FooClient`) | **Port** (abstract, domain) + **Service** (impl) + UseCases per operation | Consumers can use the facade (§6) or the usecases |
| One method per operation (`get`, `post`, `download`) | One **UseCase** per operation (`GetRequestUseCase extends UseCase<Response, RequestParams>`) | `execute(params, cancelToken)`; call syntax returns a `Result` — `fold` it |
| Request/response structs | **Entities** (domain) | Zorphy `@Zorphy` entities when they benefit from codegen; keep existing plain-immutable classes when they are part of the parity surface |
| Callbacks / Streams | **StreamUseCase** | Cancellation comes free via `CancelToken` |
| `init()` / `dispose()` | **Module lifecycle** — `onInit` / `onDispose` on the `PackageModule` | `bootstrap()`/`shutdown()` drive them in the consuming app |
| Singletons / static config | **DI registrations** in the package registrar | `zfa make ... di` keeps the registrar aggregated |
| Error enums / exceptions | **`AppFailure` hierarchy** | Throw `AppFailure` subclasses for expected errors; zuraffa wraps the rest as `UnknownFailure`; map failure→old exception type in the facade |
| Retry / backoff / interceptors | **Strategies** injected through the port | Keep them as pure classes; register defaults in DI |
| Platform channel calls (plugin case) | **Envelope** in `<name>_platform`, adapter impl in `<name>_<platform>` | Transport injected; core never touches channels |
| CLI binary | Thin `bin/` shell over usecases | No business logic in the CLI |

**Layer placement** (both shapes):

```text
lib/src/
├── domain/          # entities, ports (abstract repositories), usecases  — zero I/O imports
├── data/            # datasource impls (FFI/channel/db), repository impls
├── di/              # registrar (generated aggregate)
└── module/          # <name>_package_module.dart — your hand-edit zone
```

The discipline that keeps this honest: **domain never imports data**. The FFI
bindings, the channel envelope, the socket — all of it sits behind an abstract
port in domain, so tests can run the whole usecase layer against fakes with no
native library present.

## 5. Phase 3 — Port test-first (the TDD loop)

Your existing tests are the migration's safety net **and** its spec. Loop:

1. **Baseline green.** On the untouched branch, run the full existing suite
   (`dart test` / `flutter test`). Record the counts — this number must never
   regress during the migration.
2. **Port the unit suite** into the new layout. Unit tests over domain types
   move almost verbatim; datasource tests get re-pointed at fakes of the new
   ports. Red at first (new imports) — that is the loop's red phase, and it is
   *expected* red, not accidental red.
3. **Wire the zfa TDD engine** for the *new* behavior:
   ```bash
   zfa tdd init                 # idempotent baseline: test/, dart_test.yaml, tdd profile
   zfa tdd plan <feature>       # spec.md + tdd/test-list.md (one behavior per criterion)
   zfa tdd run <feature>        # red-green-refactor per behavior, journaling evidence
   zfa tdd status <feature>     # exit 0 iff green
   zfa tdd verify <feature>     # audit discipline + test strength
   ```
   Feature = `specs/<NNN>-zuraffa-rewrite/`. The generated journal
   (`tdd/cycle-log.md`) is committed — it is the rewrite's proof of TDD.
4. **New zuraffa-layer tests**: module lifecycle (bootstrap → ready →
   shutdown ordering), registrar completeness (every public usecase
   resolvable), facade parity (§6), and the native-seam fake (for channels:
   `zfa tdd fake` replays a committed scenario script; for FFI: a fake port).

Known sharp edges when running `zfa tdd` on a non-Flutter host are tracked in
the [TDD guide's sharp-edge table](zfa-tdd-guide.md); the pure-Dart path
(`dart test` profile) is the stable one.

## 6. Phase 4 — Compatibility facade

Do not force a breaking release onto existing consumers. Keep the old public
surface as a thin facade over the new layers:

```dart
// lib/src/legacy/facade.dart
class CurlClient {
  CurlClient({ClientConfig config = ...}) : _execute = ...;
  final ExecuteRequestUseCase _execute;

  Future<Response> get(Uri url, {Map<String, String>? headers}) async {
    final result = await _execute(RequestParams(method: HttpMethod.get, url: url, headers: headers));
    return result.fold(
      (response) => response,
      // map the AppFailure hierarchy back onto the documented exception types
      (failure) => throw mapFailureToLegacyException(failure),
    );
  }
}
```

Rules:

- The old barrel (`lib/<old_name>.dart`) keeps exporting the same names. Each
  export either re-exports the migrated class unchanged, or is a facade, or is
  **explicitly listed as broken** in the migration contract with a migration
  note in the README.
- Facades contain **no logic** beyond failure-mapping; the moment logic
  appears in a facade, push it into a usecase.
- Mark facades `@Deprecated` with the zuraffa-native replacement named, so
  consumers migrate on their own schedule.

## 7. Phase 5 — Parity gates

The migration is complete when **all** of the following hold. Check each one
explicitly (the `zuraffa-migrate` extension's verify command walks this list):

| Gate | Check |
|---|---|
| API parity | every Phase-0 symbol exported, or listed as intentionally broken |
| Behavior parity | full ported suite green; test count ≥ baseline; no test deleted without a contract note |
| Layer discipline | `grep`-able: `lib/src/domain` imports no `dart:io`/`dart:ffi`/channel code |
| DI completeness | every public usecase/repository resolves from a fresh container after `registerPackage` |
| Statics | `dart analyze` clean; `zfa build` (if codegen present) clean |
| Module lifecycle | bootstrap/ready/shutdown test passes; no work outside lifecycle hooks |
| Publish | `dart pub publish --dry-run` (per package) clean; for federated: every package in `packages/` |
| Journal | `specs/<NNN>-zuraffa-rewrite/tdd/cycle-log.md` shows red→green evidence per behavior |

## 8. Phase 6 — Publish

- Pure package: replace any `publish_to: none` / path-deps, then the repo's
  publish flow (`tool/publish.dart` in `dart_curl`'s case) or
  `dart pub publish`.
- Federated plugin: use the generated `PUBLISH.md` + `scripts/` (zikzak
  pipeline). In-family deps stay hosted constraints; sibling path resolution
  lives under `dependency_overrides`, which pub strips on publish.
- Tag the migration as a **minor** (facade complete) — reserve **major** for
  when you delete the facades.

## 9. Rollout order for a package family

When migrating a family (core → flutter wrapper → app-facing tools), migrate
in dependency order, one PR per package:

1. **Core pure package** (e.g. `dart_curl`) — everything above.
2. **Platform/wrapper packages** (e.g. `dart_curl_flutter`) — depends on the
   migrated core; same playbook, shape = whatever the wrapper touches.
3. **Feature-rich packages** (e.g. `dart_web_scraper`) — largest surface; do
   the Phase-0 contract extra carefully and migrate domain first, data second.
4. **Rebrands** (e.g. `zikzak_inappwebview` → `zuraffa_inappwebview`) —
   scaffold fresh with `zfa package create-plugin`, port behavior test-first
   from the old suite, and publish under the new name; keep the old package
   pointing at the new one as a final release if you must preserve consumers.

## 10. Automate it: the `zuraffa-migrate` speckit extension

Install once, then run the guided pipeline in any repo:

```bash
specify extension add zuraffa-migrate
```

Commands:

| Command | Phase | What it does |
|---|---|---|
| `speckit.zuraffa-migrate.analyze` | §1–2 | Runs the censuses, decides the shape, writes the migration contract |
| `speckit.zuraffa-migrate.plan` | §3–4 | Scaffolds, maps every symbol, emits spec.md + test-list.md for the rewrite feature |
| `speckit.zuraffa-migrate.port` | §5–6 | Drives the test-first port loop (red→green per behavior) and the facade |
| `speckit.zuraffa-migrate.verify` | §7 | Walks the parity gates and writes a verdict with remediation tasks |

The extension embeds the mapping table and parity checklist as templates, and
delegates the loop itself to the real engine (`zfa tdd ...`).

## 11. Quick reference

| Concern | Answer |
|---|---|
| Shape decision | FFI/logic-only → package; channels/platform → federated plugin |
| Package scaffold | `zfa package create <name>` |
| Federated scaffold | `zfa package create-plugin <name>` |
| Package-mode marker | `zfa.yaml` → `package_mode: true` |
| Runtime module | `lib/src/module/<name>_package_module.dart` (hand-edit zone) |
| DI aggregate | `lib/src/di/<name>_package_registrar.dart` (generated) |
| Consume | `engine.registerPackage(<Module>())` → `bootstrap()` |
| TDD engine | `zfa tdd init / plan / run / status / verify` |
| Parity gates | §7 table (also embedded in the extension) |
| References | `zuraffa_session` (package), `zuraffa_auth` / `zuraffa_permissions` (federated), `dart_curl` (worked example) |
