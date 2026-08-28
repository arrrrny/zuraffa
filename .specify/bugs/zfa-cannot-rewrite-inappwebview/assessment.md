# Bug Assessment: Misfire: zfa cannot rewrite the zikzak_inappwebview WebView plugin

- **Slug**: zfa-cannot-rewrite-inappwebview
- **Created**: 2026-08-28T00:00:00Z
- **Source**: https://github.com/arrrrny/zuraffa/issues/477
- **Verdict**: valid
- **Severity**: low

## Report (verbatim or summarized)

Misfire report: `zfa` CLI v6.0.0 cannot rewrite the `zikzak_inappwebview` Flutter plugin because it is a clean-architecture generator for Zuraffa apps, not a tool for rewriting existing Flutter plugins. The plugin has no Zuraffa/zorphy dependency, so `zfa doctor` fails with missing configuration and dependencies.

## Symptom

`zfa` commands fail when run inside `zikzak_inappwebview/` because the plugin is not a Zuraffa app and lacks required dependencies (.zfa.json, zuraffa package, zorphy_annotation).

## Reproduction

1. Clone `arrrrny/zikzak_inappwebview`
2. Run `zfa doctor` inside the plugin directory
3. Observe: "No .zfa.json found", "Zuraffa package not found in pubspec.yaml", "zorphy_annotation not found"

## Suspected Code Paths

- `lib/src/commands/doctor_command.dart:101-129` — Checks for .zfa.json, Zuraffa dependency, and zorphy_annotation in pubspec.yaml
- `lib/src/commands/plugin_command.dart:218-326` — `_addPlugin()` only works with Zuraffa apps (requires lib/main.dart with ZuraffaEngine)
- `lib/src/commands/module_command.dart:68-69` — Only scaffolds `zuraffa_feature_*` packages
- `lib/src/commands/make_command.dart:14-17` — Only generates architecture code for Zuraffa entities

## Root Cause Hypothesis

`zfa` is purpose-built for Zuraffa apps and has no command to rewrite arbitrary Flutter plugins. The issue reports a valid limitation: `zfa` cannot operate on non-Zuraffa Flutter packages like `zikzak_inappwebview`. This is expected behavior, not a bug — the original request was misaligned with `zfa`'s capabilities. Confidence: high.

## Proposed Remediation

**Preferred**: No code change needed. This is a documentation/expectations issue. The reporter correctly identified the limitation. Options:

1. **Clarify intent**: Determine if the goal is to (a) scaffold new Zuraffa-style modules inside a Zuraffa app, (b) rewrite only a Zuraffa-compatible subset, or (c) accept hand-written code for the plugin.
2. **Feature request**: If `zfa` should support plugin rewrites, file a separate feature request for a command that operates on non-Zuraffa Flutter packages.

**Files likely to change**: None (documentation/expectations only)

**Tests to add or update**: None

## Risks & Considerations

- This is a valid misfire report, not a bug in `zfa`'s code.
- The issue correctly identifies a feature gap: `zfa` cannot rewrite existing Flutter plugins.
- The "no hand-written code" constraint conflicts with SDD's implement phase, which writes source code.

## Open Questions

- [NEEDS CLARIFICATION: Is the goal to extend `zfa` to support plugin rewrites, or to clarify that this task requires a different approach?]
