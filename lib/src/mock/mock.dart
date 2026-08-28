/// Zuraffa native mocking library.
///
/// Zuraffa generates its own test doubles — mock datasources, mock data, mock
/// providers, and throwing doubles — so a zuraffa-built app can run end-to-end
/// on full native mocks with **no third-party mocking library** (mocktail /
/// mockito). This library is the canonical import signature for that capability.
///
/// Static tooling (e.g. `speckit-tdd-setup`) detects zuraffa-native mocking by
/// grepping for the `package:zuraffa/mock.dart` import or the [zuraffaMockLibrary]
/// marker constant below. A zuraffa project that imports this library is using
/// zuraffa's built-in mocking rather than a separate double library.
library;

// Re-export the full zuraffa surface so generated mocks and usecase tests can
// resolve every primitive they need (Loggable, FailureHandler, Result,
// AppFailure, the params family, etc.) from the single mock signature.
export 'package:zuraffa/zuraffa.dart';

/// Detectable marker: this project uses zuraffa-native mocking.
///
/// Static analyzers and test-stack detectors grep for this constant (or the
/// `package:zuraffa/mock.dart` import) to recognize zuraffa's built-in mocking
/// without executing any generator.
const bool zuraffaMockLibrary = true;
