import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/tunnel/tunnel_state.dart';

void main() {
  late Directory tmp;
  late TunnelState state;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('tunnel_state_');
    state = TunnelState(projectRoot: tmp.path);
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  TunnelStateRecord record({String? url, String? failureReason}) =>
      TunnelStateRecord(
        mode: 'quick',
        port: 8080,
        url: url,
        pid: 4242,
        restarts: 1,
        startedAt: DateTime.utc(2026, 11, 4, 10, 0, 0),
        lastRestartAt: DateTime.utc(2026, 11, 4, 10, 0, 5),
        failureReason: failureReason,
        running: true,
      );

  group('TunnelState', () {
    test('state file lives under .zfa/tunnel/state.json of the root', () {
      expect(
        state.stateFilePath,
        p.join(tmp.path, '.zfa', 'tunnel', 'state.json'),
      );
    });

    test('save then read round-trips the record', () async {
      await state.save(record(url: 'https://a-b-c.trycloudflare.com'));
      final read = state.read();
      expect(read, isNotNull);
      expect(read!.mode, 'quick');
      expect(read.port, 8080);
      expect(read.url, 'https://a-b-c.trycloudflare.com');
      expect(read.pid, 4242);
      expect(read.restarts, 1);
      expect(read.startedAt, DateTime.utc(2026, 11, 4, 10, 0, 0));
      expect(read.lastRestartAt, DateTime.utc(2026, 11, 4, 10, 0, 5));
      expect(read.running, isTrue);
    });

    test('read returns null when nothing was ever saved', () {
      expect(state.read(), isNull);
    });

    test('read returns null on a malformed state file', () async {
      final file = File(state.stateFilePath);
      await file.create(recursive: true);
      await file.writeAsString('{not json at all');
      expect(state.read(), isNull);
    });

    test('a failure reason is persisted and read back', () async {
      await state.save(record(failureReason: 'restart budget exhausted'));
      expect(state.read()!.failureReason, 'restart budget exhausted');
    });

    test('a second save overwrites the first', () async {
      await state.save(record(url: 'https://first.trycloudflare.com'));
      await state.save(record(url: 'https://second.trycloudflare.com'));
      expect(state.read()!.url, 'https://second.trycloudflare.com');
    });
  });
}
