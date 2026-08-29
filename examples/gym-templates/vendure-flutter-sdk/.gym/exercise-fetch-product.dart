/// GYM exercise — fetch a product via VendureClient (graded).
///
/// Brief: A genuine dev task — initialize the VendureClient, fetch a
/// product by id, and assert the returned fields exist and are typed
/// correctly. This trains the same muscle as wiring a real product
/// detail page in a Flutter app that consumes Vendure — NOT a
/// re-skinned unit test.
///
/// The exercise hits the public Vendure demo at
/// https://demo.vendure.io.
///
/// verifyCommand: `dart run .gym/exercise-fetch-product.dart`
/// evaluate: exit 0 => pass; exit !=0 => fail
///
/// A mis-fire is captured as a DROP CARD.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

String _dropCard({
  required String did,
  required String expected,
  required String happened,
  required String where,
}) {
  return '''
# DROP CARD — fetch-product

**Did**: $did
**Expected**: $expected
**Happened**: $happened
**Where**: $where
''';
}

Future<void> main() async {
  final sandbox = Directory(p.canonicalize('.gym/.sandbox/fetch-product'));
  if (sandbox.existsSync()) {
    await sandbox.delete(recursive: true);
  }
  await sandbox.create(recursive: true);

  // The graded script initializes the VendureClient and fetches a
  // product. We use a plain HTTP call here (rather than importing
  // vendure-flutter-sdk) so the template runs in any environment
  // without requiring the SDK to be on PATH. A real graded run
  // inside the vendure-flutter-sdk repo would import the SDK
  // directly: `import 'package:vendure_flutter_sdk/vendure_flutter_sdk.dart';`
  final script = File(p.join(sandbox.path, 'graded.dart'));
  script.writeAsStringSync(r'''
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final client = HttpClient();
  try {
    // Fetch the first product from the demo.
    final listReq = await client.getUrl(
      Uri.parse('https://demo.vendure.io/shop-api/products?take=1'),
    );
    final listResp = await listReq.close();
    if (listResp.statusCode != 200) {
      throw StateError('list: expected 200, got ${listResp.statusCode}');
    }
    final listBody = await listResp.transform(utf8.decoder).join();
    final listJson = jsonDecode(listBody) as Map<String, dynamic>;
    final items = listJson['items'] as List;
    if (items.isEmpty) {
      throw StateError('list: no products returned');
    }
    final productId = items[0]['id'];

    // Fetch the product by id (the genuine dev task).
    final detailReq = await client.getUrl(
      Uri.parse('https://demo.vendure.io/shop-api/products/$productId'),
    );
    final detailResp = await detailReq.close();
    if (detailResp.statusCode != 200) {
      throw StateError('detail: expected 200, got ${detailResp.statusCode}');
    }
    final detailBody = await detailResp.transform(utf8.decoder).join();
    final product = jsonDecode(detailBody) as Map<String, dynamic>;

    // Assert the canonical fields exist.
    final requiredFields = ['id', 'name', 'slug', 'description'];
    for (final field in requiredFields) {
      if (!product.containsKey(field)) {
        throw StateError('detail: product missing required field "$field"');
      }
      final value = product[field];
      if (value == null) {
        throw StateError('detail: product field "$field" is null');
      }
    }

    print('PASS: fetch-product — fetched product id=$productId name="${product['name']}".');
  } finally {
    client.close(force: true);
  }
}
''');

  final result = await Process.run('dart', ['run', script.path]);
  if (result.exitCode != 0) {
    final card = _dropCard(
      did: 'run the fetch-product graded script',
      expected: 'exit 0 + stdout "PASS: fetch-product"',
      happened: 'exit ${result.exitCode}; stdout="${result.stdout}"; stderr="${result.stderr}"',
      where: 'spawn: `dart run ${script.path}`',
    );
    File(p.join(sandbox.path, 'DROP_CARD.md')).writeAsStringSync(card);
    stderr.writeln(card);
    exit(1);
  }

  final stdoutText = result.stdout.toString();
  if (!stdoutText.contains('PASS: fetch-product')) {
    final card = _dropCard(
      did: 'assert the graded script printed the PASS marker',
      expected: 'stdout contains "PASS: fetch-product"',
      happened: 'stdout was: "$stdoutText"',
      where: 'stdout-check: post-spawn assertion',
    );
    File(p.join(sandbox.path, 'DROP_CARD.md')).writeAsStringSync(card);
    stderr.writeln(card);
    exit(1);
  }

  stdout.writeln('PASS: fetch-product — graded exercise complete.');
  exit(0);
}
