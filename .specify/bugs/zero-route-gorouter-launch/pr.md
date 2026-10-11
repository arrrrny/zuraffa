# Bug Fix PR: day-zero placeholder route + errorBuilder for the zero-route GoRouter

- **Slug**: zero-route-gorouter-launch
- **Opened**: 2026-09-16
- **PR**: 1684
- **URL**: https://github.com/arrrrny/zuraffa/pull/1684
- **Branch**: fix/zero-route-gorouter-launch
- **Issue**: 1673

The generated `app_router.dart` now installs a day-zero `errorBuilder` and an
empty-table fallback `GoRoute(path: '/')` rendering `ZfaDayZeroPlaceholder`
(bare + skin-audit variants, `zfa setup` + `zfa app shell`), and the Flutter
day-zero smoke test pumps the shell asserting `/` resolves. `Closes #1673` is
in the body; the PR is left OPEN for review — do not merge from the agent side.
