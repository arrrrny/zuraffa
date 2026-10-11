// IMPLEMENTED SUBJECT — `zfa tdd gen A5` stub replaced by hand at the
// A5:hand designed hand step (issue #1411; vacuous-guard remediation,
// issue #1488).
//
// behavior_id: A5
// source_criterion: AC-5
// description: the placeholder behavior is unaffected because the fallback is runtime-side in the generated router.
// ignore_for_file: non_constant_identifier_names
library;

import 'dart:io';

import 'package:zuraffa/src/plugins/app_shell/builders/app_shell_builder.dart';

/// A5 — returns the two observations the paired test asserts on:
///
/// * `router`: the real bare `app_router.dart` emission — the fallback
///   must be runtime-side in this generated file.
/// * `routeBuilderSource`: the route plugin's index-regenerator source —
///   it must never reference the placeholder, so regenerating
///   `routing/index.dart` cannot clobber the day-zero fallback.
///
/// The source path is resolved relative to the process working directory:
/// both `dart test` and the tdd runner set it to the project root.
Map<String, String> subject_a5() => <String, String>{
  'router': const AppShellBuilder().buildAppRouter(),
  'routeBuilderSource': File(
    'lib/src/plugins/route/builders/route_builder.dart',
  ).readAsStringSync(),
};
