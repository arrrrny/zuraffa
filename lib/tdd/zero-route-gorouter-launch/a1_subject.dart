// IMPLEMENTED SUBJECT — hand-written at the A1:hand designed hand step
// (the widget lane refused to scaffold: issue #938 — pure-Dart repo).
//
// behavior_id: A1
// source_criterion: AC-1
// description: the emitted GoRouter installs an `errorBuilder` that renders a placeholder and a runtime empty-table fallback.
// ignore_for_file: non_constant_identifier_names
library;

import 'package:zuraffa/src/plugins/app_shell/builders/app_shell_builder.dart';

/// A1 — returns the bare `app_router.dart` emission (the real
/// `AppShellBuilder.buildAppRouter()` output). The paired test asserts the
/// day-zero errorBuilder / empty-table fallback installation.
String subject_a1() => const AppShellBuilder().buildAppRouter();
