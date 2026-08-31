# Bug Spec: Misfire: zfa cannot rewrite the zikzak_inappwebview WebView plugin

- **Slug**: zfa-cannot-rewrite-inappwebview
- **Source issue**: https://github.com/arrrrny/zuraffa/issues/477
- **TDD feature dir**: .specify/bugs/zfa-cannot-rewrite-inappwebview
- **Severity**: low (misfire report; verdict from assessment: valid limitation)

## Problem

The reporter attempted to rewrite the `zikzak_inappwebview` Flutter plugin
using only `zfa` CLI commands. `zfa` commands fail inside that repo because the
plugin is not a Zuraffa app: it has no `.zfa.json`, no `zuraffa` dependency,
and no `zorphy_annotation` dependency. Per the assessment for #477 this is
expected behavior, not a code bug: `zfa` is a clean-architecture generator for
Zuraffa apps and has no command that rewrites arbitrary non-Zuraffa Flutter
packages. The gap is expectations: the user-facing docs never state that
scope, so a user (or an agent driving `zfa` per the misfire rule) can believe
`zfa` is a general plugin rewriter and file a misfire when it refuses.

## Acceptance Criteria

- **AC1** — `CLI_GUIDE.md` states `zfa`'s scope: it is a clean-architecture
  generator for **Zuraffa apps** (packages with `zuraffa`/`zorphy_annotation`
  dependencies and a `.zfa.json`), not a general-purpose code rewriter.
- **AC2** — `CLI_GUIDE.md` and `README.md` state that `zfa` does not rewrite
  existing non-Zuraffa Flutter packages or plugins, and that `zfa doctor`'s
  missing-dependency output inside such a package is expected scope behavior,
  not a malfunction of the CLI.
- **AC3** — `CLI_GUIDE.md` tells users what to do instead: rewrite such
  packages by hand, add the Zuraffa dependencies to opt a package into the
  generator, or file a feature request for a command that operates on
  non-Zuraffa Flutter packages.

## Out of scope

- Any change to `zfa` source code (the assessment names no code change; the
  behavior under complaint is correct).
- Implementing a new `zfa` command that rewrites non-Zuraffa plugins (that is
  a separate feature request, per the assessment's option 2).
- Modifying generated or pipeline-owned output; only hand-maintained docs
  (`CLI_GUIDE.md`, `README.md`) change.

## Reproduction (failing scenario)

1. Read `CLI_GUIDE.md` and `README.md` as shipped.
2. Assert each doc states the scope contract above (`Zuraffa apps`,
   `non-Zuraffa`, expected `zfa doctor` output, feature-request path).
3. **Fails**: neither doc contains any of those statements — the scope
   contract the reporter needed was absent, which is exactly why the
   misfire was filed.
