# Contract: Sandbox Layout (what `slice cut` emits)

## Invocation

```text
zfa slice cut --feature <feature> --from <host> [--into <dir>]
```

## Emits (deterministic, manifest-keyed)

1. `pubspec.yaml` — standalone package: feature's real deps only; the
   host appears nowhere.
2. `lib/main.dart` — shell bootstrap: pumps the feature's shell with
   mock DI (per 072 rail: dependency mocks for service/storage rows,
   channel fakes for channel rows).
3. `lib/router.dart` — `routes()` exposes exactly the manifest's
   declared routes; nothing else is routable.
4. `lib/di.dart` — one certified binding per declared dependency
   (`DependencyBinding.diToken` → mock artifact).
5. `specs/<feature>/` — spec.md + tdd/ (test list, artifacts.json,
   journal, registry) copied from the host.
6. `test/` — the feature's suites.

## Refusals

- host path missing / not a zfa project → exit 2 naming the path and
  the missing marker (`--> fix:` point at `zfa setup` / correct path).
- feature spec absent in host → exit 3 naming the expected spec path.
- duplicate route declarations in the manifest → exit 4 naming both.

## Determinism

Same host state + feature ⇒ byte-identical scaffolding files (2-4 and
wiring; copied artifacts are copies).
