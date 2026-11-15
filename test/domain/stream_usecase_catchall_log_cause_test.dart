import 'dart:async';

import 'package:logging/logging.dart' as logging;
import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

/// Regression test for issue #2079.
///
/// `StreamUseCase.call`'s final catch-all used to log
/// `logger.severe('$runtimeType failed unexpectedly', e, stackTrace)` — the
/// cause rode the `package:logging` error FIELD and the message BODY was only
/// the generic `'<StreamUseCase> failed unexpectedly'`. A log pipeline that
/// ships the body (not the field) lost the cause entirely, the same symptom
/// #2077 reported for `UseCase` and #2078 fixed there. This pins the
/// `StreamUseCase` twin to the same contract.
class _UnexpectedFailureStreamUseCase extends StreamUseCase<String, String> {
  /// Known trace supplied with the error so the test can assert the catch-all
  /// preserves it, not just the error object.
  final StackTrace trace = StackTrace.current;

  @override
  Stream<String> execute(String params, CancelToken? cancelToken) {
    return Stream<String>.error(StateError('token refresh exploded'), trace);
  }
}

void main() {
  late List<logging.LogRecord> records;
  late StreamSubscription<logging.LogRecord> subscription;

  setUp(() {
    records = <logging.LogRecord>[];
    logging.hierarchicalLoggingEnabled = true;
    logging.Logger.root.clearListeners();
    logging.Logger.root.level = logging.Level.ALL;
    subscription = logging.Logger.root.onRecord.listen(records.add);
  });

  tearDown(() async {
    await subscription.cancel();
    logging.Logger.root.clearListeners();
    logging.hierarchicalLoggingEnabled = false;
  });

  test('catch-all SEVERE carries the error in its message body', () async {
    final useCase = _UnexpectedFailureStreamUseCase();
    final results = <Result<String, AppFailure>>[];
    await for (final result in useCase('params')) {
      results.add(result);
    }

    expect(results, isNotEmpty);
    expect(results.last.isFailure, isTrue);

    final severe = records
        .where((r) => r.level == logging.Level.SEVERE)
        .where((r) => r.loggerName.contains('_UnexpectedFailureStreamUseCase'))
        .toList();

    expect(severe, hasLength(1));
    expect(severe.single.message, contains('token refresh exploded'));
    // The error field is still attached for handlers that read it.
    expect(severe.single.error, isA<StateError>());
    // The stack trace from the source Stream.error is preserved too.
    expect(severe.single.stackTrace, same(useCase.trace));
  });
}
