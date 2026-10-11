// IMPLEMENTED SUBJECT — `zfa tdd gen A6` stub replaced by hand at the
// A6:hand designed hand step (issue #1411; vacuous-guard remediation,
// issue #1488).
//
// behavior_id: A6
// source_criterion: AC-6
// description: it stays router-free (no Flutter imports) — only the Flutter flavor gains router coverage.
// ignore_for_file: non_constant_identifier_names
library;

import 'package:zuraffa/src/cli/writers/tdd/smoke_test_writer.dart';

/// A6 — returns the pure-Dart smoke test emission (the real
/// `SmokeTestWriter(isFlutter: false).render(...)` output). The paired test
/// asserts the pure-Dart flavor stays router-free.
String subject_a6() =>
    const SmokeTestWriter(isFlutter: false).render('todo_app');
