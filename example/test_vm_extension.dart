import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Usage: dart test_vm_extension.dart <wsUri> <isolateId> [method]
///
/// Quick smoke-test: calls a single extension method and prints the result.
/// Extract the isolate ID from:
///   curl -s http://127.0.0.1:<port>/.../getVM | python3 -c "
///   import json,sys; d=json.load(sys.stdin)
///   for i in d['result']['isolates']:
///     if not i['isSystemIsolate']: print(i['id'])"
Future<void> main(List<String> args) async {
  if (args.length < 2) {
    print('Usage: dart test_vm_extension.dart <wsUri> <isolateId> [method]');
    exit(1);
  }

  final wsUri = args[0];
  final isolateId = args[1];
  final method = args.length > 2 ? args[2] : 'ext.zuraffa._list';
  final ws = await WebSocket.connect(wsUri);
  final done = Completer<void>();

  ws.listen(
    (data) {
      try {
        final response = jsonDecode(data as String);
        print('Response:');
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
  );

  ws.add(
    jsonEncode({
      'jsonrpc': '2.0',
      'id': '1',
      'method': method,
      'params': {'isolateId': isolateId},
    }),
  );

  await done.future.timeout(const Duration(seconds: 10));
  await ws.close();
}
