// IMPLEMENTED SUBJECT — hand-written at the A2:hand designed hand step
// (the widget lane refused to scaffold: issue #938 — pure-Dart repo).
//
// behavior_id: A2
// source_criterion: AC-2
// description: the resolution renders the placeholder instead of throwing `no route for location: /`.
// ignore_for_file: non_constant_identifier_names
library;

import 'package:zuraffa/src/plugins/app_shell/builders/app_shell_builder.dart';

/// A2 — returns the bare `app_router.dart` emission (the real
/// `AppShellBuilder.buildAppRouter()` output). The paired test asserts the
/// initial `/` resolution lands on the placeholder, not the GoException.
String subject_a2() => const AppShellBuilder().buildAppRouter();
