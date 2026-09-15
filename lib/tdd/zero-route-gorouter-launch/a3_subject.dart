// IMPLEMENTED SUBJECT — `zfa tdd gen A3` stub replaced by hand at the
// A3:hand designed hand step (issue #1411; vacuous-guard remediation,
// issue #1488).
//
// behavior_id: A3
// source_criterion: AC-3
// description: it carries the same `errorBuilder` / empty-table fallback alongside the observer.
// ignore_for_file: non_constant_identifier_names
library;

import 'package:zuraffa/src/plugins/app_shell/builders/app_shell_builder.dart';

/// A3 — returns the skin-audit `app_router.dart` emission (the real
/// `AppShellBuilder.buildAppRouter(skinAudit: true)` output). The paired
/// test asserts the day-zero `errorBuilder` / empty-table fallback rides
/// alongside the issue-#1102 `SkinRouteContractObserver`.
String subject_a3() =>
    const AppShellBuilder().buildAppRouter(skinAudit: true);
