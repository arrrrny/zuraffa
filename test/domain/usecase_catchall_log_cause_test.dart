import 'dart:async';

import 'package:logging/logging.dart' as logging;
import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

/// Regression test for issue #2077.
///
/// `UseCase.call`'s final catch-all used to log
/// `logger.severe('$runtimeType failed unexpectedly', e, stackTrace)` — the
/// cause rode the `package:logging` error FIELD and the message BODY was only
/// the generic `'<UseCase> failed unexpectedly'`. A log pipeline that ships
/// the body (not the field) lost the cause entirely, which is how a consumer
/// counted 89 body-only SEVERE records in 7 days with no diagnosable cause.
///
/// The `on AppFailure` branch already interpolates the error into its body;
/// this pins the catch-all to the same contract.
class _UnexpectedFailureUseCase extends UseCase<String, String> {
  @override
  Future<String> execute(String params, CancelToken? cancelToken) async {
    throw StateError('token refresh exploded');
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
    final result = await _UnexpectedFailureUseCase()('params');

    expect(result.isFailure, isTrue);

    final severe = records
        .where((r) => r.level == logging.Level.SEVERE)
        .where((r) => r.loggerName.contains('_UnexpectedFailureUseCase'))
        .toList();

    expect(severe, hasLength(1));
    expect(severe.single.message, contains('token refresh exploded'));
    // The error field is still attached for handlers that read it.
    expect(severe.single.error, isA<StateError>());
  });
}
