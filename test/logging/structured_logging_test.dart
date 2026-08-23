import 'package:logging/logging.dart' as logging;
import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

/// Logging built-in: structured facade over package:logging — child
/// loggers, field encoding, level gating, handler tap.
void main() {
  late logging.LogRecord lastRecord;

  setUp(() {
    lastRecord = _placeholder;
    logging.hierarchicalLoggingEnabled = true;
    logging.Logger.root.clearListeners();
    logging.Logger.root.level = logging.Level.ALL;
    logging.Logger.root.onRecord.listen((record) {
      lastRecord = record;
    });
  });

  test('structured fields are encoded into the record message', () {
    Log.named('session').info('restored session', {'id': 's-1', 'scope': 'A'});

    expect(lastRecord.loggerName, 'zuraffa.session');
    expect(lastRecord.message, contains('restored session'));
    expect(lastRecord.message, contains('id=s-1'));
    expect(lastRecord.message, contains('scope=A'));
  });

  test('child loggers compose dotted names', () {
    final parent = StructuredLogger('zuraffa.auth');
    final child = parent.child('refresh');

    child.warning('token refreshed');

    expect(lastRecord.loggerName, 'zuraffa.auth.refresh');
  });

  test('levels route to package:logging severities', () {
    final logger = StructuredLogger('zuraffa.test');

    logger.debug('d');
    expect(lastRecord.level, logging.Level.FINE);

    logger.info('i');
    expect(lastRecord.level, logging.Level.INFO);

    logger.warning('w');
    expect(lastRecord.level, logging.Level.WARNING);

    logger.error('e');
    expect(lastRecord.level, logging.Level.SEVERE);
  });

  test('Log facade root loggers carry the zuraffa prefix', () {
    Log.error('boom', {'code': 'x1'});

    expect(lastRecord.loggerName, 'zuraffa');
    expect(lastRecord.message, contains('boom'));
    expect(lastRecord.message, contains('code=x1'));
  });

  test('level gating: below-threshold records never reach handlers', () {
    logging.Logger.root.level = logging.Level.WARNING;

    var reached = 0;
    logging.Logger.root.onRecord.listen((_) => reached++);

    Log.debug('quiet');
    Log.info('quiet too');
    expect(reached, 0);

    Log.warning('loud');
    expect(reached, 1);
  });

  test('no-field logs stay plain messages', () {
    Log.named('plain').info('no fields');

    expect(lastRecord.message, 'no fields');
  });
}

final _placeholder = logging.LogRecord(
  logging.Level.ALL,
  'placeholder',
  'placeholder',
);
