# Issue #1185 — [MAKE] zfa make <E> --with=vpc --view --skin without --methods crashes "Bad state: No element"

- **GitHub issue:** https://github.com/arrrrny/zuraffa/issues/1185
- **Severity:** medium
- **State (at triage):** open
- **Component:** `zfa make` → PresenterPlugin (`lib/src/plugins/presenter/presenter_plugin.dart`)

## Observed (live, Flutter fixture)

```bash
zfa make Product --with=vpc --view --skin --no-entity
# ❌ Generation failed: Bad state: No element
```

Adding an explicit method set makes it work:

```bash
zfa make Product --with=vpc --view --skin --methods=get --no-entity
# ✅ Done. — view/presenter/controller + auditor wrap + kit emitted
```

## Expected

Either a default method set (the engine preset has one — see
`MakeCommand._engineDefaultMethods`) or a clear usage error naming the
missing flag. A bare `Bad state: No element` from a `firstWhere`/`single`
deep in generation is none of those.

## Context

Fresh Flutter fixture (flutter sdk + zuraffa_flutter deps), entity present,
zfa master. The `--with=vpc --view` combination without `--methods` is the
exact shape the AGENTS.md canonical examples do NOT show — which is how it
went unnoticed.

## Hard constraints

- Fix the crash.
- Add default methods or a clear error.
- One PR for the bug.
