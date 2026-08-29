# Chore PR: zfa setup: pass-through wrapper for flutter/dart create flags

- **Slug**: setup-flutter-spm-tdd
- **Opened**: 2026-08-29
- **PR**: 577
- **URL**: https://github.com/arrrrny/zuraffa/pull/577
- **Branch**: chore/setup-flutter-spm-tdd
- **Issue**: 576

Reworks `zfa setup` into a thin pass-through: `--flutter` (default) / `--dart`
select the scaffolder, `--platforms`/`--org` forward as-is, and any other flag
passes through verbatim via `--` to `flutter create` / `dart create`. The
proposed `--swift-package-manager` flag was dropped (removed from current Flutter;
iOS uses SPM by default). Test-env scaffolding deferred to #575.
