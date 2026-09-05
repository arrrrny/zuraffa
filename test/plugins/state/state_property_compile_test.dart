// Spec 976 (issue #976) — property-based compile tier for the state
// plugin.
//
// The state builder (1,265 LOC, three emission modes) was previously
// pinned only by two content-`contains` assertions. This suite pins
// COMPILE-CLEANLINESS as the contract: a representative method-set
// matrix (CRUD, getList+pagination, orchestrator, custom-usecase) is
// generated into a real sandbox package whose pubspec declares a path
// dependency on the zuraffa repo itself, `dart analyze` must report
// zero issues, and a driver must round-trip copyWith / == / hashCode
// semantics and the pagination defaults at runtime.
//
// A negative control corrupts one emission into a non-compiling
// copyWith and proves the tier FAILS it — compile-cleanliness is a
// gate, not a string grep (SC-1, AC-1).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/state/builders/state_builder.dart';

import '../helpers/project_root.dart';

void main() {
  late Directory sandbox;
  late String outputDir;

  setUpAll(() async {
    // CWD-independent: parallel test files may contaminate
    // Directory.current (CliRunner mutates it process-globally).
    final repoRoot = await findProjectRoot();
    sandbox = await Directory.systemTemp.createTemp('zfa_state_prop_');
    outputDir = p.join(sandbox.path, 'lib', 'src');

    // The sandbox is a real pure-Dart package depending on the repo via
    // a path dependency: the generated states import
    // `package:zuraffa/zuraffa.dart` (flavor switch, issue #512) and the
    // entities they reference, so `dart analyze` resolves everything the
    // way a consumer project would.
    await File(p.join(sandbox.path, 'pubspec.yaml')).writeAsString('''
name: state_property_sandbox
description: Spec 976 property-tier sandbox (generated, disposable).
publish_to: none
environment:
  sdk: ^3.11.0
dependencies:
  zuraffa:
    path: $repoRoot
''');

    await _writeEntity(
      sandbox,
      snake: 'product',
      name: 'Product',
      members:
          '  final String id;\n  final String name;\n'
          '  const Product(this.id, this.name);',
      equality: 'other.id == id',
      hashCode: 'id.hashCode',
    );
    await _writeEntity(
      sandbox,
      snake: 'order',
      name: 'Order',
      members: '  final String id;\n  const Order(this.id);',
      equality: 'other.id == id',
      hashCode: 'id.hashCode',
    );
    await _writeEntity(
      sandbox,
      snake: 'shipment',
      name: 'Shipment',
      members: '  final String id;\n  const Shipment(this.id);',
      equality: 'other.id == id',
      hashCode: 'id.hashCode',
    );
    await _writeEntity(
      sandbox,
      snake: 'listing',
      name: 'Listing',
      members: '  final String barcode;\n  const Listing(this.barcode);',
      equality: 'other.barcode == barcode',
      hashCode: 'barcode.hashCode',
    );
    await _writeEntity(
      sandbox,
      snake: 'get_listing_by_barcode',
      name: 'GetListingByBarcode',
      members: '  const GetListingByBarcode();',
      equality: 'identical(this, other)',
      hashCode: '0',
    );

    // Orchestrator usecase stubs — the state builder parses these to
    // derive per-usecase response/loading fields (GetShipment returns
    // Shipment; SyncShipment returns void, so no response field).
    final usecaseDir = Directory(
      p.join(outputDir, 'domain', 'usecases', 'shipment'),
    );
    await usecaseDir.create(recursive: true);
    await File(
      p.join(usecaseDir.path, 'get_shipment_usecase.dart'),
    ).writeAsString('''
import 'package:zuraffa/zuraffa.dart';

import '../../entities/shipment/shipment.dart';

abstract class GetShipmentUseCase extends UseCase<Shipment, String> {}
''');
    await File(
      p.join(usecaseDir.path, 'sync_shipment_usecase.dart'),
    ).writeAsString('''
import 'package:zuraffa/zuraffa.dart';

abstract class SyncShipmentUseCase extends UseCase<void, String> {}
''');

    final builder = StateBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );

    // The method-set matrix: entity CRUD, getList+pagination,
    // orchestrator, custom-usecase — the four representative shapes the
    // issue names.
    Future<void> gen(GeneratorConfig config) async {
      final file = await builder.generate(config);
      expect(file.action, anyOf('created', 'overwritten'));
    }

    await gen(
      GeneratorConfig(
        name: 'Product',
        methods: const ['get', 'create', 'update', 'delete'],
        generateState: true,
        outputDir: outputDir,
      ),
    );
    await gen(
      GeneratorConfig(
        name: 'Order',
        methods: const ['get', 'getList'],
        generateState: true,
        outputDir: outputDir,
      ),
    );
    await gen(
      GeneratorConfig(
        name: 'Shipment',
        usecases: const ['GetShipmentUseCase', 'SyncShipmentUseCase'],
        generateState: true,
        outputDir: outputDir,
      ),
    );
    await gen(
      GeneratorConfig(
        name: 'GetListingByBarcode',
        domain: 'listing',
        paramsType: 'String',
        returnsType: 'Listing?',
        generateState: true,
        outputDir: outputDir,
      ),
    );

    await File(p.join(sandbox.path, 'driver.dart')).writeAsString(_driver);

    final pubGet = await _dart(sandbox, ['pub', 'get', '--offline']);
    expect(
      pubGet.exitCode,
      0,
      reason: 'offline pub get must resolve the path dep:\n${pubGet.stderr}',
    );
  });

  tearDownAll(() async {
    if (sandbox.existsSync()) {
      try {
        await sandbox.delete(recursive: true);
      } on FileSystemException {
        // Best-effort cleanup on constrained disks.
      }
    }
  });

  test(
    'SC-1a: the method-set matrix compiles clean (dart analyze, 0 issues)',
    () async {
      final result = await _dart(sandbox, ['analyze']);
      expect(
        result.exitCode,
        0,
        reason:
            'generated states across the matrix must analyze clean '
            '(compile-cleanliness is the contract):\n${result.stdout}',
      );
      expect(result.stdout, contains('No issues found!'));
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );

  test('SC-1b: copyWith/==/hashCode round-trip and pagination defaults hold '
      'at runtime', () async {
    final result = await _dart(sandbox, ['run', 'driver.dart']);
    expect(
      result.exitCode,
      0,
      reason:
          'the round-trip driver must pass every semantic check:\n'
          '${result.stdout}\n${result.stderr}',
    );
    expect(result.stdout, contains('ALL DRIVER CHECKS PASSED'));
  }, timeout: const Timeout(Duration(minutes: 4)));

  test('SC-1c (negative control): a deliberately broken copyWith emission '
      'FAILS the compile tier', () async {
    final stateFile = File(
      p.join(
        outputDir,
        'presentation',
        'pages',
        'product',
        'product_state.dart',
      ),
    );
    final original = await stateFile.readAsString();
    addTearDown(() async {
      await stateFile.writeAsString(original);
    });

    // Corrupt the emission the way a real builder regression would:
    // copyWith references an undefined name, so the file no longer
    // compiles (the issue's example of a broken emission).
    final corrupted = original.replaceFirst(
      'error: error ?? this.error,',
      'error: thisFieldDoesNotExist ?? this.error,',
    );
    expect(corrupted, isNot(original));
    await stateFile.writeAsString(corrupted);

    final result = await _dart(sandbox, ['analyze']);
    expect(
      result.exitCode,
      isNot(0),
      reason:
          'the tier must FAIL a non-compiling copyWith — string-presence '
          'tests cannot see this:\n${result.stdout}',
    );
    expect(result.stdout, contains('thisFieldDoesNotExist'));

    // Restored emission must be clean again (the gate is precise, not
    // flaky).
    await stateFile.writeAsString(original);
    final clean = await _dart(sandbox, ['analyze']);
    expect(clean.exitCode, 0, reason: clean.stdout);
  }, timeout: const Timeout(Duration(minutes: 4)));
}

Future<ProcessResult> _dart(Directory cwd, List<String> args) => Process.run(
  Platform.resolvedExecutable,
  args,
  workingDirectory: cwd.path,
  stdoutEncoding: utf8,
  stderrEncoding: utf8,
);

Future<void> _writeEntity(
  Directory sandbox, {
  required String snake,
  required String name,
  required String members,
  required String equality,
  required String hashCode,
}) async {
  final dir = Directory(
    p.join(sandbox.path, 'lib', 'src', 'domain', 'entities', snake),
  );
  await dir.create(recursive: true);
  await File(p.join(dir.path, '$snake.dart')).writeAsString('''
class $name {
$members

  @override
  bool operator ==(Object other) => other is $name && $equality;

  @override
  int get hashCode => $hashCode;
}
''');
}

const _driver = r'''
// Spec 976 property-tier driver: round-trip copyWith/equality/hashCode
// semantics for every emission mode. Exits 1 with a failure list if any
// check fails.
import 'dart:io';

import 'package:zuraffa/zuraffa.dart';
import 'package:state_property_sandbox/src/domain/entities/get_listing_by_barcode/get_listing_by_barcode.dart';
import 'package:state_property_sandbox/src/domain/entities/listing/listing.dart';
import 'package:state_property_sandbox/src/domain/entities/order/order.dart';
import 'package:state_property_sandbox/src/domain/entities/product/product.dart';
import 'package:state_property_sandbox/src/domain/entities/shipment/shipment.dart';
import 'package:state_property_sandbox/src/presentation/pages/listing/get_listing_by_barcode_state.dart';
import 'package:state_property_sandbox/src/presentation/pages/order/order_state.dart';
import 'package:state_property_sandbox/src/presentation/pages/product/product_state.dart';
import 'package:state_property_sandbox/src/presentation/pages/shipment/shipment_state.dart';

void main() {
  final failures = <String>[];
  void check(String name, bool ok) {
    if (!ok) failures.add(name);
    stdout.writeln('$name: ${ok ? 'OK' : 'FAIL'}');
  }

  // Entity mode: CRUD (Product: get/create/update/delete).
  const product = Product('p1', 'Widget');
  final crud0 = ProductState();
  check('crud: defaults are inert',
      crud0.product == null && crud0.error == null);
  final crud1 = crud0.copyWith(product: product);
  check('crud: copyWith carries the entity', crud1.product == product);
  check('crud: copyWith preserves other fields', crud1.error == null);
  check('crud: copyWith changes equality', crud1 != crud0);
  check('crud: equal values are equal',
      ProductState().copyWith(product: product) == crud1);
  check('crud: hashCode agrees with ==',
      ProductState().copyWith(product: product).hashCode == crud1.hashCode);
  const boom = ServerFailure('boom');
  final crud2 = crud1.copyWith(error: boom);
  check('crud: hasError tracks the error', crud2.hasError);
  check('crud: copyWith carries the error', crud2.error == boom);
  final crud3 = crud2.copyWith(isCreating: true);
  check('crud: copyWith toggles method booleans',
      crud3.isCreating && !crud2.isCreating && crud3 != crud2);
  final crud4 = ProductState(
    product: product,
    error: boom,
    isUpdating: true,
  );
  check('crud: named constructor round-trips through copyWith',
      crud4 == ProductState().copyWith(
            product: product,
            error: boom,
            isUpdating: true,
          ));

  // Entity mode: getList + pagination (Order: get, getList).
  final page0 = OrderState();
  check('pagination: defaults (offset 0, limit 10, hasMore true, empty)',
      page0.offset == 0 &&
          page0.limit == 10 &&
          page0.hasMore &&
          page0.orderList.isEmpty);
  final page1 = page0.copyWith(
    orderList: const [Order('o1')],
    offset: 20,
    limit: 5,
    hasMore: false,
  );
  check('pagination: copyWith carries the list window',
      page1.orderList.length == 1 &&
          page1.offset == 20 &&
          page1.limit == 5 &&
          !page1.hasMore);
  check('pagination: equal values are equal',
      OrderState().copyWith(
            orderList: const [Order('o1')],
            offset: 20,
            limit: 5,
            hasMore: false,
          ) ==
          page1);
  check('pagination: hashCode agrees with ==',
      OrderState().copyWith(
            orderList: const [Order('o1')],
            offset: 20,
            limit: 5,
            hasMore: false,
          ).hashCode ==
          page1.hashCode);
  check('pagination: isLoading aggregates method booleans',
      OrderState().copyWith(isGettingList: true).isLoading);

  // Orchestrator mode (Shipment: GetShipment + SyncShipment).
  const shipment = Shipment('s1');
  final orch0 = ShipmentState();
  check('orchestrator: per-usecase loading defaults false',
      !orch0.isGetShipmentLoading && !orch0.isSyncShipmentLoading);
  check('orchestrator: void usecase has no response',
      orch0.getShipmentResponse == null);
  final orch1 = orch0.copyWith(shipment: shipment);
  check('orchestrator: copyWith carries the entity', orch1.shipment == shipment);
  final orch2 = orch1.copyWith(getShipmentResponse: shipment);
  check('orchestrator: copyWith carries the response',
      orch2.getShipmentResponse == shipment);
  check('orchestrator: isLoading ORs the per-usecase flags',
      orch0.copyWith(isSyncShipmentLoading: true).isLoading);
  check('orchestrator: equal values are equal',
      ShipmentState().copyWith(shipment: shipment) == orch1);
  check('orchestrator: hashCode agrees with ==',
      ShipmentState().copyWith(shipment: shipment).hashCode == orch1.hashCode);

  // Custom mode (GetListingByBarcode: String -> Listing?).
  const listing = Listing('b1');
  final custom0 = GetListingByBarcodeState();
  check('custom: defaults inert (no loading, no data)',
      !custom0.isLoading && custom0.data == null);
  final custom1 = custom0.copyWith(data: listing);
  check('custom: copyWith carries the data', custom1.data == listing);
  check('custom: copyWith toggles isLoading',
      custom0.copyWith(isLoading: true).isLoading);
  check('custom: equal values are equal',
      GetListingByBarcodeState().copyWith(data: listing) == custom1);
  check('custom: hashCode agrees with ==',
      GetListingByBarcodeState().copyWith(data: listing).hashCode ==
          custom1.hashCode);
  final custom2 = GetListingByBarcodeState(
    getListingByBarcode: const GetListingByBarcode(),
    isLoading: true,
    data: listing,
  );
  check('custom: named constructor round-trips through copyWith',
      custom2 == GetListingByBarcodeState().copyWith(
            getListingByBarcode: const GetListingByBarcode(),
            isLoading: true,
            data: listing,
          ));

  if (failures.isNotEmpty) {
    stderr.writeln('DRIVER FAILURES (${failures.length}):');
    for (final f in failures) {
      stderr.writeln('  - $f');
    }
    exit(1);
  }
  stdout.writeln('ALL DRIVER CHECKS PASSED');
}
''';
