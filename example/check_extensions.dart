import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart check_extensions.dart <wsUri>');
    exit(1);
  }
  final wsUri = args[0];
  final ws = await WebSocket.connect(wsUri);
  final done = Completer<void>();
  var step = 0;

  ws.listen(
    (data) {
      final resp = jsonDecode(data as String);
      if (step == 0) {
        // getVM response
        final isolateId =
            (resp['result']['isolates'] as List).first['id'] as String;
        // Query isolate
        ws.add(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': '2',
            'method': 'getIsolate',
            'params': {'isolateId': isolateId},
          }),
        );
        step = 1;
      } else if (step == 1) {
        // getIsolate response — print extensionRPCs
        final isolate = resp['result'] as Map<String, dynamic>;
        print('Isolate name: ${isolate['name']}');
        print('Isolate id: ${isolate['id']}');
        final rpcs = isolate['extensionRPCs'] as List? ?? [];
        print('extensionRPCs (${rpcs.length}):');
        if (rpcs.isEmpty) {
          print('  (none registered in this isolate)');
        } else {
          for (final rpc in rpcs) {
            print('  ✅ $rpc');
          }
        }
        step = 2;
        // Now try calling _list as top-level RPC
        ws.add(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': '3',
            'method': 'ext.zuraffa._list',
            'params': {},
          }),
        );
      } else {
        // Extension call response
        print('');
        print(
          'Call ext.zuraffa._list: ${resp['error']?['message'] ?? 'SUCCESS'}',
        );
        done.complete();
      }
    },
    onError: (e) {
      print('Error: $e');
      done.complete();
    },
  );

  // Start by getting VM info
  ws.add(
    jsonEncode({'jsonrpc': '2.0', 'id': '1', 'method': 'getVM', 'params': {}}),
  );

  await done.future.timeout(const Duration(seconds: 5));
  await ws.close();
}
