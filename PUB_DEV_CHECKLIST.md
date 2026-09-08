# Global pub.dev Package Checklist — Zuraffa Ecosystem

**Last audit:** 2026-09-08
**Scope:** every publishable Dart/Flutter package in the Zuraffa ecosystem.

This is the single gate every package passes before `flutter pub publish`.
Work through it top to bottom per package; the status table at the bottom
records where each package stands as of the last audit.

---

## Part 1 — Per-package checklist (run for EVERY package)

### A. pubspec.yaml metadata

- [ ] `name:` valid, lowercase_with_underscores, matches repo/package intent
- [ ] `version:` follows semver; matches the head entry of CHANGELOG.md exactly
- [ ] `description:` present, ≤ 180 characters, plain English (no quotes-wrapped markdown)
- [ ] `repository:` git URL of the package's own repo (or the monorepo dir path)
- [ ] `issue_tracker:` GitHub issues URL (pub.dev uses it for the issue links)
- [ ] `topics:` 1–5 topics (optional but boosts discoverability; each ≤ 20 chars, lowercase)
- [ ] `environment:` realistic `sdk:` (and `flutter:` for plugins) floors — don't over-constrain
- [ ] `publish_to:` absent for publishable packages (present = intentionally private)
- [ ] For plugins: `flutter.plugin.platforms` declares EXACTLY the supported platforms
      — delete stub platform folders rather than shipping dead pluginClasses
      (see the zuraffa_intents linux/windows/web removal, 2026-09-08)

### B. Required files at package root

- [ ] `LICENSE` — BSD-3-Clause across the ecosystem (must match for legal consistency)
- [ ] `README.md` — what/why, install, minimal usage example (pub.dev renders it as the package page)
- [ ] `CHANGELOG.md` — head entry version == pubspec version; user-facing changes, not commit logs
- [ ] Federated sub-packages get their own LICENSE + README + CHANGELOG (pub.dev packages are independent)
- [ ] `.pubignore` where generated/test scaffolding must not ship (e.g. zuraffa excludes `lib/tdd/`)

### C. Dependency hygiene (publish blocker if violated)

- [ ] ZERO `path:` dependencies on other published packages (dev-time overrides are fine, but
      the pubspec itself must resolve hosted)
- [ ] ZERO `dependency_overrides:` on published deps (pub hints on this; cyclic-dev exceptions documented)
- [ ] `git dependency_overrides` section removed
- [ ] Constraint floors match what you actually tested against; ceilings follow semver (`^`)

### D. Quality gates (the zfa TDD discipline — no publish without these)

- [ ] `dart run build_runner build` (or `zfa build`) clean, generated files committed or `.pubignore`d consistently
- [ ] `flutter analyze` (or `dart analyze`) — **zero** issues, including info
- [ ] `dart format --set-exit-if-changed .` — clean (pub.dev scores formatting)
- [ ] Full test suite green (record count, e.g. "42/42")
- [ ] TDD verification green: `zfa tdd verify <feature>` PASS / mutation sweep 0 SURVIVED for behavior-bearing code
- [ ] `flutter pub publish --dry-run` — 0 errors, 0 warnings (hints triaged and justified)
- [ ] `dart doc` (or `flutter doc`) runs without errors — pub.dev flags broken dartdoc

### E. Publish mechanics

- [ ] Publish federated packages in dependency order:
      platform_interface → platform implementations (_android, _ios, _macos) → app-facing package
- [ ] After each publish, flip the dependent packages' `path:` deps to hosted in the NEXT PR
- [ ] Tag the release (`v<version>`) and merge the version bump back to master
      (gap found 2026-09-08: zuraffa v6.2.1 tag exists but master pubspec still says 6.2.0)
- [ ] Verify the pub.dev page renders: README, description, topics, issue tracker link
- [ ] `pub.dev` score check (pana): aim 140+/160 — docs pass points and platform-tag points are the usual deductions

---

## Part 2 — Ecosystem status (audit 2026-09-08)

| Package | pub.dev | version | LICENSE | README | CHANGELOG | repo/issue_tracker | Verdict |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `zuraffa` | ✅ 6.2.1 | local pubspec **6.2.0** ⚠️ | ✅ | ✅ | ✅ | ✅ | Publish OK; **merge 6.2.1 bump back to master** |
| `zuraffa_flutter` | ✅ 6.2.1 | 6.2.1 | ✅ | ✅ | ✅ | ✅ (points at zuraffa repo) | Healthy |
| `zuraffa_ui` | ✅ 0.1.0 | 0.1.0 | ✅ | ✅ | ✅ | ⚠️ repo URL redirects (renamed repo); homepage points at the upstream shadcn port docs | Fix URLs next release |
| `zuraffa_agent` | ❌ `publish_to: none` | — | ✅ | ❌ | ❌ | — | Intentionally private (fill docs if it ever goes public) |
| `zuraffa_browser` | ❌ `publish_to: none` | 1.0.0+1 | ❌ | ✅ | ❌ | — | Intentionally private (needs LICENSE+CHANGELOG if promoted) |
| `zuraffa_intents` | ❌ not yet | 1.0.0 | ✅ | ✅ | ✅ | ✅ | **READY** — Android/iOS/macOS only, 42/42 tests, mutation 0 SURVIVED, dry-run clean |
| `zuraffa_permissions` (+4 federated) | ❌ not yet | 0.1.0×5 | ❌ all 5 | ⚠️ 1/5 | ❌ all 5 | ⚠️ missing on all 5 | **BLOCKED** — see arrrrny/zuraffa_permissions#10 |

### Open gaps, ecosystem-wide (as of this audit)

1. **zuraffa**: pubspec on master lags the published 6.2.1 (tag exists, bump not merged back).
2. **zuraffa_ui**: `repository:` URL is a stale redirect; `homepage:` points at the upstream
   flutter-shadcn-ui docs, not Zuraffa's own docs.
3. **zuraffa_permissions**: all 5 packages blocked (LICENSE/README/CHANGELOG/repo metadata +
   hosted deps) — tracked in arrrrny/zuraffa_permissions#10.
4. **zuraffa_intents**: ready — publish when the 1.0.0 release is wanted, then tag `v1.0.0`.
5. **TDD gate before every publish**: re-run the suite + `zfa tdd verify`/mutation sweep on the
   day of publish, not just at feature completion (this checklist makes it a standing rule).

---

## Part 3 — Quick commands (per package root)

```bash
# metadata + files
grep -E '^(name|version|description|repository|issue_tracker):' pubspec.yaml
ls LICENSE README.md CHANGELOG.md

# quality gates
dart run build_runner build --delete-conflicting-outputs
flutter analyze
dart format --set-exit-if-changed --output=none . || dart format .
flutter test

# publish gate
flutter pub publish --dry-run
```

> Rule of thumb: **if `--dry-run` shows anything other than the "package has 0 warnings"
> path, it is not publish ready.** Fix or file an issue — never publish with warnings.
