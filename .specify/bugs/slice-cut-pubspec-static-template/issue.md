# Bug Issue: slice cut: sandbox pubspec uses a fixed template — packages imported by the copied closure (e.g. zuraffa) are not declared, verify self-containment fails by construction

- **Slug**: slice-cut-pubspec-static-template
- **Issue**: 1304
- **URL**: https://github.com/arrrrny/zuraffa/issues/1304
- **State**: open
- **Severity**: high
- **Labels**: bug
- **Context**: EPIC 4 re-evaluation (#1135), 2026-09-07, against master `239016de`. Record reconstructed verbatim from the GitHub issue body (the committed copy was absent from the clone).

## Body

### Repro

On a real scaffolded app with a working feature (`apps/login_demo`, feature `login` under `lib/src/presentation/pages/login/` with a data-layer repository):

```bash
cd apps/login_demo
zfa slice cut login_feature --entry login --depth full     # exit 0 — "13 project files"
zfa slice verify login_feature --json                      # exit 1
```

### Expected

The composed sandbox should be self-contained by construction: the sandbox `pubspec.yaml` must declare every package the copied closure imports (`package:zuraffa/zuraffa.dart` among them). With `--depth full` and a clean closure, `slice verify` should pass self-containment (or the cut should refuse up-front if the closure cannot be made self-contained).

### Actual

`slice verify --json` fails self-containment with one class of offender for every copied file:

```
lib/src/domain/repositories/login_repository.dart:4: "package:zuraffa/zuraffa.dart" — package "zuraffa" is not declared in pubspec.yaml
lib/src/domain/usecases/login/get_login_usecase.dart:3: "package:zuraffa/zuraffa.dart" — package "zuraffa" is not declared in pubspec.yaml
...
```

The sandbox `pubspec.yaml` written by `slice cut` carries a fixed template set (`flutter`, `shadcn_ui`, `zorphy_annotation`, `zuraffa_flutter`) — it does not derive its dependencies from the imports of the files it actually copied. The host app resolves `package:zuraffa/*` (transitively via `zuraffa_flutter` + analyzer leniency), so the cut succeeds — but the sandbox then cannot resolve the same imports because the template omits `zuraffa`.

The gate itself behaves perfectly (honest exit 1, machine-checkable verdict JSON, `--> fix:` line) — this is a cut-side completeness gap, not a verify-side lie.

Also observed at default `--depth feature`: the closure scan missed `lib/src/data/repositories/mock_login_repository.dart` (imported by a copied presenter via a relative path) — `--depth full` includes it. Worth either documenting the depth/closure interaction or following relative imports regardless of depth for *copied files' own* import closure.

### Root cause

`slice cut`'s pubspec writer emits a static dependency template instead of scanning the copied closure's `package:` imports (the same closure scan the self-containment check itself performs).

### Suggested fix

Derive the sandbox pubspec dependencies from the cut closure: collect every `package:<name>/` import across copied files, then declare each `<name>` with the host's version constraint (falling back to `any` + a warning). This makes "cut → verify green" the default path and lets the merge gate (spec 1116) be reachable on a real feature without hand-editing the sandbox.

### Context

- EPIC 4 re-evaluation (#1135), 2026-09-07, against master `239016de`
- The verify gate + verdict JSON + fix-line conventions all worked as designed

## Comments

None.
