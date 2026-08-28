# Fix — `zfa service method` silent on success (no stdout output)

- **Slug**: issue-414-zfa-service-method-silent-on-success-no-stdout-output
- **Status**: resolved
- **Date**: 2026-08-28
- **Verdict**: valid
- **Triage**: issue #414

## Root cause

`zfa service method` is capability-backed: the `ServicePlugin` registers a
`MethodCapability` (targetType `service`) as the `method` subcommand of
`ServiceCommand`, so `zfa service method …` runs through
`CapabilityCommand.run` (`lib/src/commands/capability_command.dart`).

`MethodCapability.execute` (`lib/src/plugins/method_append/capabilities/method_capability.dart`)
correctly returns `ExecutionResult(success: true, data: {'generatedFiles': result.updatedFiles})`.
When the target service already exists, `_appendServiceMethod`
(`lib/src/plugins/method_append/builders/method_append_builder_append.dart`)
mutates the existing host file in place and emits `GeneratedFile`s carrying the
**`updated`** action — that is the expected, correct behaviour for an append.

The bug was in the success printer in `capability_command.dart`. It only
printed the `✅ Success! Created/Modified:` summary for files whose action was
`created` / `overwritten` / `deleted`. Because `service method` emits `updated`
files, the `if (created.isNotEmpty || overwritten.isNotEmpty || updated.isNotEmpty || deleted.isNotEmpty)`
branch was never satisfied for it, and since the file list was non-empty the
fall-through `✅ Success! (No changes required)` message was also skipped — so the
command produced **no stdout output on success**, unlike
`provider create` / `usecase create` which list the touched files.

## Remediation

1. The success printer now also handles the `updated` action. This is the
   shared gap (it affects every append-family capability — `service method`,
   `repo method`, `provider method`, etc.), so fixing the printer corrects all
   of them at once without degrading any other command.
   - File: `lib/src/commands/capability_command.dart`
     (`updated = files.where((f) => f.action == 'updated')` is now included in
     the `created/overwritten/updated/deleted` success branch, and each `updated`
     file is printed with `📝 <path>`).
2. Added a focused regression test that exercises the real `ServicePlugin` +
   `MethodCapability` (service targetType) and asserts (a) `execute` populates
   `generatedFiles` with a handled action, and (b) `CapabilityCommand` emits
   `✅ Success! Created/Modified:` containing the modified service file path.
   - File: `test/plugins/method_append/service_method_414_test.dart`

## Files changed

- `lib/src/commands/capability_command.dart` — success printer handles the
  `updated` action (this is the substantive fix for #414).
- `test/plugins/method_append/service_method_414_test.dart` — new focused
  regression test for the `zfa service method` success-output path.
- `.specify/bugs/issue-414-zfa-service-method-silent-on-success-no-stdout-output/fix.md`
  — this note.

## Verification

- `dart analyze` clean on `lib/src/commands/capability_command.dart`,
  `lib/src/plugins/method_append/capabilities/method_capability.dart`,
  `lib/src/plugins/service/service_plugin.dart`, and the new test file.
- `dart test test/plugins/method_append/service_method_414_test.dart` — 2/2 pass
  (execute populates `generatedFiles` with a handled action; the command prints
  `✅ Success! Created/Modified:` with `my_service.dart`).
- `dart test test/commands/capability_command_test.dart test/plugins/method_append/ test/plugins/service/`
  — all pass (no regressions to sibling capabilities or service plugin).
- Manual reproduction via `runCapturing(['service','method','--target','MyService',
  '--name','doThing','--returns','void','--params','String','--type','sync'])`
  against a project containing `lib/src/domain/services/my_service.dart` now
  prints the success summary instead of being silent.
