// IMPLEMENTED SUBJECT — `zfa tdd gen A8` stub replaced by hand at the
// A8:hand designed hand step (issue #1411; vacuous-guard remediation,
// issue #1488).
//
// behavior_id: A8
// source_criterion: AC-8
// description: they assert the new `errorBuilder` / fallback output and pass.
// ignore_for_file: non_constant_identifier_names
library;

import 'package:zuraffa/src/plugins/app_shell/builders/app_shell_builder.dart';

/// A8 — returns the title-threaded bare emission (the real
/// `AppShellBuilder.buildAppRouter(title: 'Todo App')` output). The paired
/// test pins the new emission surface the updated golden tests assert.
String subject_a8() =>
    const AppShellBuilder().buildAppRouter(title: 'Todo App');
