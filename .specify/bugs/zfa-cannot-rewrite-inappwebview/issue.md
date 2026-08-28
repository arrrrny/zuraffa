# Bug Issue: Misfire: zfa cannot rewrite the zikzak_inappwebview WebView plugin

- **Slug**: zfa-cannot-rewrite-inappwebview
- **Fetched**: 2026-08-28T00:00:00Z
- **Issue**: 477
- **URL**: https://github.com/arrrrny/zuraffa/issues/477
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

## Context
Task attempted: **rewrite the `zikzak_inappwebview` Flutter plugin using *only* `zfa` CLI commands, no hand-written code.**

This is a **misfire report** filed per the rule: _"when zfa cli does not work as expected, stop on first misfire and create a github issue."_

> Note: the original instruction named the repo `Developer/zuraffa`, which does not resolve. The accessible repo under the active account is `arrrrny/zuraffa` — filing here.

## Why `zfa` misfires for this task

`zfa` (Zuraffa CLI v6.0.0) is a **clean-architecture generator for Zuraffa apps** — it scaffolds entities, controllers, repositories, data sources, DI, etc. It is not a tool for rewriting an existing Flutter plugin.

Empirical evidence (`zfa doctor` run inside `zikzak_inappwebview/`):

```
Configuration: No .zfa.json found (run "zfa config init" to create one)
Project: Found pubspec.yaml
Dependencies: Zuraffa package not found in pubspec.yaml
              zorphy_annotation not found - required for entity generation
```

- `zikzak_inappwebview` is a **Flutter WebView bridge plugin** (native Android/iOS code + Dart platform interfaces). It is not a Zuraffa app and has no Zuraffa/zorphy dependency.
- There is **no `zfa` command that rewrites an existing plugin**. The closest commands (`zfa module`, `zfa plugin`) scaffold *new* Zuraffa feature packages / manage Zuraffa's own plugin system — neither applies to rewriting this plugin.
- Therefore a "whole rewrite using only zfa CLI, no hand-written code" is not achievable with the current tool.

## Additional contradiction in the request

The same instruction also says:
- _"NO HAND WRITTEN CODE PERIOD"_
- _"whole SDD cycle /skill:speckit-specify plan, tasks, implement"_

The SDD `implement` phase writes source code, which conflicts with "no hand-written code" unless `implement` is itself delegated to `zfa` — but `zfa` already misfires for this codebase. The two constraints cannot be satisfied simultaneously for this plugin.

## Recommended next steps (for maintainers / requester)

1. **Clarify intent.** Is the goal to (a) scaffold *new* Zuraffa-style modules inside a Zuraffa app, (b) rewrite only a specific, Zuraffa-compatible subset of the plugin, or (c) accept hand-written code for the plugin rewrite?
2. **If `zfa` should support plugin rewrites**, this is a feature gap: `zfa` would need a command that operates on non-Zuraffa Flutter packages (e.g. generating platform-interface stubs), which does not exist today.
3. **Repo-name correction:** use `arrrrny/zuraffa` (not `Developer/zuraffa`).

## Environment
- `zfa` CLI: v6.0.0
- Dart: 3.13.1 (stable)
- Flutter: installed
- Target repo: `arrrrny/zikzak_inappwebview` (monorepo of `zikzak_inappwebview*` packages)


## Comments

None.
