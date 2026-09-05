// Issue #1176: emitted `hide` clauses contain only names the resolved
// zuraffa barrel actually exports — an `undefined_hidden_name` warning
// fails `zfa build`'s analyze gate.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/utils/entity_utils.dart';
import 'package:zuraffa/src/utils/zuraffa_barrel_exports.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('barrel_exports_');
    // Fixture target project with a resolved (path-style) zuraffa root.
    final zuraffaRoot = p.join(tmp.path, 'zuraffa');
    Directory(p.join(zuraffaRoot, 'lib', 'src')).createSync(recursive: true);
    File(
      p.join(zuraffaRoot, 'lib', 'zuraffa.dart'),
    ).writeAsStringSync("export 'src/core.dart';\n");
    File(p.join(zuraffaRoot, 'lib', 'src', 'core.dart')).writeAsStringSync(
      'class QueryParams<T> {}\nclass EntityNotFound implements Exception {}\n',
    );
    final dotTool = Directory(p.join(tmp.path, '.dart_tool'));
    dotTool.createSync(recursive: true);
    File(p.join(dotTool.path, 'package_config.json')).writeAsStringSync(
      jsonEncode({
        'configVersion': 2,
        'packages': [
          {
            'name': 'zuraffa',
            'rootUri': Uri.file(zuraffaRoot).toString(),
            'packageUri': 'lib/',
          },
        ],
      }),
    );
  });

  tearDown(() {
    ZuraffaBarrelExports.reset();
    tmp.deleteSync(recursive: true);
  });

  test('hides are filtered to names the barrel actually exports', () {
    ZuraffaBarrelExports.seed(tmp.path);
    // QueryParams IS exported by the barrel — the hide STAYS (the #942
    // collision case this mechanism exists for).
    expect(EntityUtils.barrelHideNames('QueryParams'), ['QueryParams']);
  });

  test('names the barrel does not export are dropped', () {
    ZuraffaBarrelExports.seed(tmp.path);
    // Product/ProductPatch are not in the fixture barrel — the exact
    // warning that failed the sandbox's zfa build gate.
    expect(EntityUtils.barrelHideNames('Product'), isEmpty);
  });

  test('exported colliding names are kept (the #942 case)', () {
    ZuraffaBarrelExports.seed(tmp.path);
    expect(EntityUtils.barrelHideNames('EntityNotFound'), ['EntityNotFound']);
  });

  test('unresolved → legacy unconditional hide', () {
    ZuraffaBarrelExports.reset();
    expect(EntityUtils.barrelHideNames('Product'), ['Product', 'ProductPatch']);
  });
}
