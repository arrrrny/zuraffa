import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Usage: dart call_ext.dart <wsUri> <isolateId> [method] [argsJson]
///
/// Calls a registered VM Service extension via WebSocket JSON-RPC.
/// The `isolateId` is required — find it with:
///   curl http://127.0.0.1:<port>/.../getVM | grep -A1 '\"main\"'
Future<void> main(List<String> args) async {
  if (args.length < 2) {
    print('Usage: dart call_ext.dart <wsUri> <isolateId> [method] [argsJson]');
    print(
      'Example: dart call_ext.dart ws://127.0.0.1:12345/XXX=/ws isolates/123 ext.zuraffa._list',
    );
    exit(1);
  }

  final wsUri = args[0];
  final isolateId = args[1];
  final method = args.length > 2 ? args[2] : 'ext.zuraffa._list';
  final argsJson = args.length > 3 ? args[3] : '{}';

  final ws = await WebSocket.connect(wsUri);
  final done = Completer<void>();

  ws.listen(
    (data) {
      try {
        final response = jsonDecode(data as String);
        print('${'─' * 60}');
        print('$method →');
        print(const JsonEncoder.withIndent('  ').convert(response));
        done.complete();
      } catch (e) {
        print('Error parsing response: $e');
        done.complete();
      }
    },
    onError: (e) {
      print('WebSocket error: $e');
      done.complete();
    },
    onDone: () => exit(0),
  );

  final params = <String, String>{'isolateId': isolateId};
  if (argsJson != '{}') {
    params['args'] = argsJson;
  }

  ws.add(
    jsonEncode({
      'jsonrpc': '2.0',
      'id': '1',
      'method': method,
      'params': params,
    }),
  );

  await done.future.timeout(const Duration(seconds: 10));
  await ws.close();
}
