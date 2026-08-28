# Bug Issue: [pubspec] Publishable package has git dependencies (zorphy/zorphy_annotation) — 2 invalid_dependency warnings

- **Slug**: issue-238-publishable-package-has-git-dependencies-zorphy-zorphy-annot
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 238
- **URL**: https://github.com/arrrrny/zuraffa/issues/238
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug, setup

## Body

## Summary

`dart analyze` reports 2 warnings for `pubspec.yaml`:

```
warning - pubspec.yaml:31:5 - Publishable packages can't have 'git' dependencies - invalid_dependency
warning - pubspec.yaml:36:5 - Publishable packages can't have 'git' dependencies - invalid_dependency
```

## Root cause

`pubspec.yaml` declares `zorphy` and `zorphy_annotation` as git dependencies pointing at `arrrrny/zorphy.git` (path: `zorphy` / `zorphy_annotation`, ref: `development`). Since the package has no `publish_to: none`, pub considers it publishable and rejects git deps.

## Context

This is the current development-mode setup (pin to the zorphy `development` branch). If the package is meant to be publishable, git deps must be replaced (e.g. with hosted/dev versions). If it is intentionally development-only, the clean fix is `publish_to: 'none'` in `pubspec.yaml`.

## Fix

Add `publish_to: 'none'` to `pubspec.yaml` (if never published), or switch `zorphy`/`zorphy_annotation` to hosted/dev dependencies before publishing.

## Acceptance

- [ ] The 2 `invalid_dependency` warnings are gone
- [ ] Zuraffa still resolves `zorphy`/`zorphy_annotation` correctly for development

## Comments

**coderabbitai** (2026-08-04T03:47:39Z):

<!-- This is an auto-generated issue plan by CodeRabbit -->
<details>
<summary>🔗 Related PRs</summary>

arrrrny/zuraffa#143 - Development [closed]
arrrrny/zuraffa#191 - feat(compiler): Track 1.3 — Decorator-Driven Architecture (DDA) Foundation [merged]
arrrrny/zuraffa#226 - fix: remove export of nonexistent graphql/naming_utils.dart (`#222`) [open]
</details>

---
<details>
<summary>📝 Issue Planner</summary>

<sub>Check the box below or use the `@coderabbitai plan` command to generate an implementation plan and prompts that you can use with your favorite coding assistant.</sub>

- [ ] <!-- {"checkboxId": "8d4f2b9c-3e1a-4f7c-a9b2-d5e8f1c4a7b9"} --> Create Plan
</details>


---
<details>
<summary> 🧪 Issue enrichment is currently in open beta.</summary>


You can configure auto-planning by selecting labels in the issue_enrichment configuration.

To disable automatic issue enrichment, add the following to your `.coderabbit.yaml`:
```yaml
issue_enrichment:
  auto_enrich:
    enabled: false
```
</details>

💬 Have feedback or questions? Drop into our [discord](https://discord.gg/coderabbit)!
