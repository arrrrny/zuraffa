/// GYM warmup rep #3 — authenticated smoke call.
///
/// "Authenticated" for vendure-flutter-sdk means: prove the
/// network path to the Vendure demo instance is reachable. A real
/// graded exercise would then drive the SDK's `VendureClient` to
/// fetch a product; the warmup just confirms the demo is up.
///
/// Run: `dart run .gym/warmup/03-smoke.dart`
library;

import 'dart:io';

import 'package:path/path.dart' as p;

Future<void> main() async {
  // Write a smoke script that pings the Vendure demo.
  final smoke = File(p.join('.gym', '.sandbox', 'smoke-vendure.dart'));
  await smoke.parent.create(recursive: true);
  smoke.writeAsStringSync(r'''
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.parse('https://demo.vendure.io/shop-api/products?take=1'));
    final resp = await req.close();
    if (resp.statusCode != 200) {
      throw StateError('smoke: expected 200, got ${resp.statusCode}');
    }
    final body = await resp.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;
    if (!json.containsKey('items')) {
      throw StateError('smoke: response missing "items" key. Got: ${json.keys.toList()}');
    }
    final items = json['items'] as List;
    if (items.isEmpty) {
      throw StateError('smoke: response items list is empty.');
    }
    print('SMOKE PASS: Vendure demo reachable; first product id=${items[0]['id']}.');
  } finally {
    client.close(force: true);
  }
}
''');

  final result = await Process.run('dart', ['run', smoke.path]);
  if (result.exitCode != 0) {
    stderr.writeln('REP FAIL: 03-smoke — smoke script exited ${result.exitCode}');
    stderr.writeln(result.stdout);
    stderr.writeln(result.stderr);
    stderr.writeln(
      'Note: this rep requires network access to https://demo.vendure.io. '
      'If the demo is down, the rep will fail — that is the intended '
      'behavior (the gate stays closed until the service is reachable).',
    );
    exit(result.exitCode);
  }

  final stdoutText = result.stdout.toString();
  if (!stdoutText.contains('SMOKE PASS')) {
    stderr.writeln(
      'REP FAIL: 03-smoke — smoke script ran but did not print SMOKE PASS. '
      'Mis-fire — drop a card.',
    );
    exit(1);
  }

  stdout.writeln('REP PASS: 03-smoke — Vendure demo reachable.');
  exit(0);
}
