// IMPLEMENTED SUBJECT — `zfa tdd gen A4` stub replaced by hand at the
// A4:hand designed hand step (issue #1411; vacuous-guard remediation,
// issue #1488).
//
// behavior_id: A4
// source_criterion: AC-4
// description: the runtime empty-check leaves the real route table untouched (fallback only fires on an empty table).
// ignore_for_file: non_constant_identifier_names
library;

import 'package:zuraffa/src/plugins/app_shell/builders/app_shell_builder.dart';

/// A4 — returns the bare `app_router.dart` emission (the real
/// `AppShellBuilder.buildAppRouter()` output). The paired test asserts the
/// `routes:` argument is a runtime ternary that preserves the real table.
String subject_a4() => const AppShellBuilder().buildAppRouter();
