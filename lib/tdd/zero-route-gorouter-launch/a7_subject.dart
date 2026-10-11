// IMPLEMENTED SUBJECT — hand-written at the A7:hand designed hand step
// (the widget lane refused to scaffold: issue #938 — pure-Dart repo).
//
// behavior_id: A7
// source_criterion: AC-7
// description: the smoke test still constructs the DI container AND also pumps the app shell and asserts the initial `/` resolves to the placeholder screen.
// ignore_for_file: non_constant_identifier_names
library;

import 'package:zuraffa/src/cli/writers/tdd/smoke_test_writer.dart';

/// A7 — returns the Flutter smoke test emission (the real
/// `SmokeTestWriter` Flutter flavor output for the issue's canonical
/// `zik_zak_tdd` repro app). The paired test asserts the emitted template
/// keeps the container check and adds the shell pump.
String subject_a7() => const SmokeTestWriter().render('zik_zak_tdd');
