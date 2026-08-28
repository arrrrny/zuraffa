# Bug Assessment: dart analyze produces 2010 errors on dart-only installations

- **Slug**: dart-analyze-produces-2010-errors-on-dart-only-installations
- **Created**: 2026-08-27T14:26:38.214699+00:00
- **Source**: https://github.com/arrrrny/zuraffa/issues/512
- **Verdict**: likely valid, needs reproduction
- **Severity**: unknown

## Report (verbatim or summarized)

# Bug Assessment: Dart analyze produces 2010 errors on dart-only installations

- **Slug**: zuraffa-flutter-dart-analyze-errors
- **Created**: 2026-08-27
- **Source**: pasted text
- **Verdict**: likely valid, needs reproduction
- **Severity**: high

## Report (verbatim or summarized)

> create a new repo for zuraffa_flutter running dart analyze produces 2010 errors on dart only installations

## Symptom

When creating a new repository (likely using `zfa setup` or similar) and running `dart analyze` in a pure Dart installation (without Flutter SDK), the analysis produces approximately 2010 errors. The expected behavior is zero errors for a properly generated pure Dart project.

## Reproduction

1. Install only the Dart SDK (no Flutter).
2. Create a new repository using `zfa setup <name> --dart` (or possibly without `--dart` flag).
3. Run `dart analyze` in the new repository.
4. Observe ~2010 errors.

[NEEDS CLARIFICATION: The exact command sequence and whether the user specified `--dart` flag is unknown. Also unclear whether the errors are from generated code or from the zuraffa_flutter package itself.]

## Suspected Code Paths

- `lib/src/plugins/route/builders/route_builder.dart` — generates Flutter material imports without checking ProjectFlavor
- `lib/src/plugins/shadcn/builders/shadcn_builder.dart` — generates Flutter material imports without checking ProjectFlavor
- `lib/src/plugins/app_shell/builders/app_shell_builder.dart` — generates Flutter imports without checking ProjectFlavor
- `lib/src/plugins/xray/xray_deck_barrel_writer.dart` — generates Flutter foundation imports without checking ProjectFlavor
- `lib/src/commands/create_command.dart` — generates Flutter view files without checking ProjectFlavor
- `lib/src/commands/module_command.dart` — generates Flutter plugin files without checking ProjectFlavor

## Root Cause Hypothesis

The root cause is that several plugins and commands generate Flutter-specific code (imports of `package:flutter/material.dart`, `package:zuraffa_flutter/...`, etc.) without checking the target project's flavor (Flutter vs pure Dart). While the presentation-layer plugins (controller, presenter, view) were fixed in issue #420 to respect ProjectFlavor, other plugins (route, shadcn, app_shell, xray, create, module) still unconditionally emit Flutter imports. When a user creates a pure Dart project and runs these generators, the resulting code contains Flutter dependencies that cannot be resolved under a Dart-only installation, causing thousands of analysis errors. Confidence: medium (need to verify which plugins are actually invoked in the user's scenario).

## Proposed Remediation

**Preferred**: Add ProjectFlavor detection to all plugins that generate Flutter-specific code. For each plugin, before generating Flutter imports, call `detectProjectFlavor` on the output directory. If the flavor is `pureDart`, either skip generation entirely (with a warning) or generate a pure Dart alternative (if feasible). This aligns with Constitution VII (Engine Purity) and the fix applied in issue #420.

**Alternatives**:
- Modify `zfa make` to automatically exclude Flutter-specific plugins when the target project is pure Dart (centralized filtering).
- Add a global flag `--pure-dart` that forces all plugins to skip Flutter generation.

**Files likely to change**:
- `lib/src/plugins/route/builders/route_builder.dart`
- `lib/src/plugins/shadcn/builders/shadcn_builder.dart`
- `lib/src/plugins/app_shell/builders/app_shell_builder.dart`
- `lib/src/plugins/xray/xray_deck_barrel_writer.dart`
- `lib/src/commands/create_command.dart`
- `lib/src/commands/module_command.dart`
- Possibly other plugins under `lib/src/plugins/` that generate Flutter imports.

**Tests to add or update**:
- Extend the regression test pattern from `test/regression/issue_420_pure_dart_presentation_generation_test.dart` to cover route, shadcn, app_shell, xray, create, and module plugins.
- Add integration test that creates a pure Dart project, runs `zfa make` with various plugins, and verifies `dart analyze` passes with zero errors.

## Risks & Considerations

- Some plugins (like route) may be inherently Flutter-only; skipping generation may break expected workflows for Flutter users. Need to ensure the detection is accurate and only skips when appropriate.
- The `zfa setup` command defaults to Flutter when `--dart` is not specified; users may inadvertently create Flutter projects in a Dart-only environment, causing errors later.
- The error count (2010) suggests many generated files; need to identify which plugins produce the bulk of errors to prioritize fixes.

## Open Questions

- [NEEDS CLARIFICATION: What exact command sequence was used to create the repository? (`zfa setup --dart` or `zfa setup` without `--dart`?)]
- [NEEDS CLARIFICATION: Are the errors from generated code in the new repository, or from the zuraffa_flutter package itself?]
- [NEEDS CLARIFICATION: Which plugins were invoked during generation? (default preset?)]
- [NEEDS CLARIFICATION: Does the user have a minimal reproduction repository we can examine?]

See https://github.com/arrrrny/zuraffa/issues/512.

## Symptom

[NEEDS CLARIFICATION]

## Reproduction

[NEEDS CLARIFICATION]

## Suspected Code Paths

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to locate the code, or fill in manually.]

## Root Cause Hypothesis

[NEEDS CLARIFICATION — not yet analyzed.]

## Proposed Remediation

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to propose a fix, or apply a fix directly with /skill:speckit-bug-fix.]

## Risks & Considerations

- Loaded from an existing GitHub issue; triage is incomplete until refined.

## Open Questions

- [NEEDS CLARIFICATION: confirm the exact code path and a safe remediation.]
