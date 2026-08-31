@Tags(['regression', 'slow'])
library;

// Regression test for issue #358:
// https://github.com/arrrrny/zuraffa/issues/358
//
// Before this fix, the route plugin generated GoRoute entries but
// had no concept of deep links — `zfa route deep-link` did not exist,
// `zfa route create --deep-link --scheme gozuzu` did not register the
// scheme in AndroidManifest.xml or Info.plist, and `zfa setup
// --deep-link-scheme gozuzu` could not pre-seed the manifest.
//
// The smoke test for v6 ("any agent should build a ZikZak-class app
// with ONLY zfa commands, intuitively") breaks at deep links because
// the agent had to hand-edit `lib/src/routing/deep_link_routes.dart`
// + `android/.../AndroidManifest.xml` — exactly the gap this test
// closes.
//
// This test verifies the end-to-end contract:
//   1. `zfa route deep-link ScanBarcode --path /scan/barcode/:barcode
//       --scheme gozuzu` emits a GoRoute module registered in
//       `getAllRoutes()` AND writes the platform registration.
//   2. Re-running is idempotent (no duplicate manifest entries).
//   3. `zfa setup --deep-link-scheme gozuzu` flag exists on the
//       SetupCommand.
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/route_command.dart';
import 'package:zuraffa/src/commands/setup_command.dart';
import 'package:zuraffa/src/core/context/file_system.dart';
import 'package:zuraffa/src/plugins/route/route_plugin.dart';

void main() {
  late Directory tempDir;
  late String projectRoot;
  late String outputDir;
  late RoutePlugin plugin;
  late RouteCommand command;
  late CommandRunner<void> runner;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('issue_358_');
    projectRoot = tempDir.path;
    outputDir = '$projectRoot/lib/src';
    await Directory('$projectRoot/lib/src/routing').create(recursive: true);
    plugin = RoutePlugin(
      outputDir: outputDir,
      projectRoot: projectRoot,
      fileSystem: const DefaultFileSystem(),
    );
    command = RouteCommand(plugin);
    runner = CommandRunner<void>('zfa', 'Zuraffa Code Generator')
      ..addCommand(command);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> seedFakeFlutterProject() async {
    final manifestDir = Directory('$projectRoot/android/app/src/main');
    await manifestDir.create(recursive: true);
    await File(
      '${manifestDir.path}/AndroidManifest.xml',
    ).writeAsString(_fakeAndroidManifest);
    final iosDir = Directory('$projectRoot/ios/Runner');
    await iosDir.create(recursive: true);
    await File('${iosDir.path}/Info.plist').writeAsString(_fakeIosPlist);
  }

  group('issue #358 — deep-link support in route plugin', () {
    test('`zfa route deep-link` emits the GoRoute module + index + '
        'platform manifest entries', () async {
      await seedFakeFlutterProject();

      await runner.run([
        'route',
        'deep-link',
        'ScanBarcode',
        '--path',
        '/scan/barcode/:barcode',
        '--scheme',
        'gozuzu',
        '--host',
        'go.zuzu.dev',
        '--auto-verify',
        '--force',
      ]);

      final routesFile = File('$outputDir/routing/scan_barcode_routes.dart');
      expect(routesFile.existsSync(), isTrue);
      final content = routesFile.readAsStringSync();

      expect(content.contains('class ScanBarcodeRoutes'), isTrue);
      expect(content.contains("'/scan/barcode/:barcode'"), isTrue);
      expect(content.contains('GoRoute'), isTrue);
      // Default placeholder builder (no --view).
      expect(content.contains('SizedBox'), isTrue);
      // Routes file must parse cleanly.
      expect(syntaxErrors(content), isEmpty);

      // index.dart aggregates the new module.
      final indexFile = File('$outputDir/routing/index.dart');
      expect(indexFile.existsSync(), isTrue);
      final index = indexFile.readAsStringSync();
      expect(index.contains('scan_barcode_routes.dart'), isTrue);
      expect(index.contains('scanBarcodeRoutes'), isTrue);

      // Android intent-filter registered with autoVerify + host.
      final manifest = await File(
        '$projectRoot/android/app/src/main/AndroidManifest.xml',
      ).readAsString();
      expect(manifest.contains('android:scheme="gozuzu"'), isTrue);
      expect(manifest.contains('android:host="go.zuzu.dev"'), isTrue);
      expect(manifest.contains('android:autoVerify="true"'), isTrue);

      // iOS plist entry registered.
      final plist = await File(
        '$projectRoot/ios/Runner/Info.plist',
      ).readAsString();
      expect(plist.contains('<string>gozuzu</string>'), isTrue);
    });

    test('`zfa route deep-link` is idempotent across re-runs', () async {
      await seedFakeFlutterProject();

      for (var i = 0; i < 2; i++) {
        await runner.run([
          'route',
          'deep-link',
          'ScanBarcode',
          '--path',
          '/scan/barcode/:barcode',
          '--scheme',
          'gozuzu',
          '--force',
        ]);
      }

      final manifest = await File(
        '$projectRoot/android/app/src/main/AndroidManifest.xml',
      ).readAsString();
      expect('android:scheme="gozuzu"'.allMatches(manifest).length, equals(1));

      final plist = await File(
        '$projectRoot/ios/Runner/Info.plist',
      ).readAsString();
      expect('<string>gozuzu</string>'.allMatches(plist).length, equals(1));

      // Re-running with --force overwrites the routes file cleanly;
      // the index still has exactly one export.
      final indexFile = File('$outputDir/routing/index.dart');
      final index = indexFile.readAsStringSync();
      expect(
        RegExp(r"export 'scan_barcode_routes.dart';").allMatches(index).length,
        equals(1),
        reason: 'index must export the module exactly once',
      );
    });

    test('`zfa route deep-link --view <View>` emits the requested view '
        'instead of the placeholder', () async {
      await runner.run([
        'route',
        'deep-link',
        'ScanBarcode',
        '--path',
        '/scan/barcode/:barcode',
        '--scheme',
        'gozuzu',
        '--view',
        'ScanBarcodeView',
        '--force',
      ]);

      final content = File(
        '$outputDir/routing/scan_barcode_routes.dart',
      ).readAsStringSync();
      expect(content.contains('ScanBarcodeView'), isTrue);
      expect(content.contains('SizedBox'), isFalse);
    });

    test('`zfa route deep-link` without --path exits without writing '
        'the route file', () async {
      await runner.run([
        'route',
        'deep-link',
        'ScanBarcode',
        '--scheme',
        'gozuzu',
      ]);

      expect(
        File('$outputDir/routing/scan_barcode_routes.dart').existsSync(),
        isFalse,
        reason: 'no route file must be emitted on a usage error',
      );
    });

    test('`zfa route deep-link` without --scheme exits without writing '
        'the route file', () async {
      await runner.run([
        'route',
        'deep-link',
        'ScanBarcode',
        '--path',
        '/scan/barcode/:barcode',
      ]);

      expect(
        File('$outputDir/routing/scan_barcode_routes.dart').existsSync(),
        isFalse,
        reason: 'no route file must be emitted on a usage error',
      );
    });

    test('`zfa route create <Entity> --deep-link --scheme gozuzu` '
        'registers the scheme in the platform manifest', () async {
      await seedFakeFlutterProject();

      // zfa route create Product — the route plugin needs the entity
      // to exist on disk to generate routes for it. Seed a minimal
      // entity file.
      final entityDir = Directory('$outputDir/domain/entities/product');
      await entityDir.create(recursive: true);
      await File('${entityDir.path}/product.dart').writeAsString(
        "class Product {\n"
        "  final String id;\n"
        "  Product({required this.id});\n"
        "}\n",
      );
      // Seed the view file so the route generator emits a GoRoute
      // instead of skipping (the route generator probes the view
      // file on disk — see issue #328).
      final viewDir = Directory('$outputDir/presentation/pages/general');
      await viewDir.create(recursive: true);
      await File('${viewDir.path}/product_view.dart').writeAsString(
        "import 'package:flutter/material.dart';\n"
        "class ProductView extends StatelessWidget {\n"
        "  const ProductView({super.key});\n"
        "  @override\n"
        "  Widget build(BuildContext context) => const SizedBox.shrink();\n"
        "}\n",
      );

      await runner.run([
        'route',
        'create',
        'Product',
        '--methods=get,getList',
        '--deep-link',
        '--scheme',
        'gozuzu',
        '--force',
      ]);

      final manifest = await File(
        '$projectRoot/android/app/src/main/AndroidManifest.xml',
      ).readAsString();
      expect(manifest.contains('android:scheme="gozuzu"'), isTrue);

      final plist = await File(
        '$projectRoot/ios/Runner/Info.plist',
      ).readAsString();
      expect(plist.contains('<string>gozuzu</string>'), isTrue);
    });

    test('`zfa setup --deep-link-scheme gozuzu` flag is declared on '
        'SetupCommand', () {
      final cmd = SetupCommand();
      expect(cmd.argParser.options, contains('deep-link-scheme'));
      expect(cmd.argParser.options, contains('deep-link-host'));
      expect(cmd.argParser.options, contains('auto-verify'));
    });

    test('`zfa route create` with invalid --scheme throws BEFORE '
        'generating any route files', () async {
      await seedFakeFlutterProject();

      // Seed a minimal entity so route create does not skip.
      final entityDir = Directory('$outputDir/domain/entities/product');
      await entityDir.create(recursive: true);
      await File('${entityDir.path}/product.dart').writeAsString(
        "class Product {\n"
        "  final String id;\n"
        "  Product({required this.id});\n"
        "}\n",
      );
      final viewDir = Directory('$outputDir/presentation/pages/general');
      await viewDir.create(recursive: true);
      await File('${viewDir.path}/product_view.dart').writeAsString(
        "import 'package:flutter/material.dart';\n"
        "class ProductView extends StatelessWidget {\n"
        "  const ProductView({super.key});\n"
        "  @override\n"
        "  Widget build(BuildContext context) => const SizedBox.shrink();\n"
        "}\n",
      );

      // Invalid scheme with uppercase characters should throw ArgumentError
      // BEFORE any route files are generated.
      expect(
        () => runner.run([
          'route',
          'create',
          'Product',
          '--scheme',
          'GoZuzu',
          '--force',
        ]),
        throwsA(isA<ArgumentError>()),
      );

      // Verify no route files were generated.
      final routesFile = File('$outputDir/routing/product_routes.dart');
      expect(
        routesFile.existsSync(),
        isFalse,
        reason: 'route files must NOT be generated when --scheme is invalid',
      );

      // Verify manifest files were not modified.
      final manifest = await File(
        '$projectRoot/android/app/src/main/AndroidManifest.xml',
      ).readAsString();
      expect(
        manifest.contains('android:scheme="GoZuzu"'),
        isFalse,
        reason: 'invalid scheme must not be written to manifest',
      );
    });

    test('`zfa route create` with invalid --host throws BEFORE '
        'generating any route files', () async {
      await seedFakeFlutterProject();

      // Seed a minimal entity so route create does not skip.
      final entityDir = Directory('$outputDir/domain/entities/product');
      await entityDir.create(recursive: true);
      await File('${entityDir.path}/product.dart').writeAsString(
        "class Product {\n"
        "  final String id;\n"
        "  Product({required this.id});\n"
        "}\n",
      );
      final viewDir = Directory('$outputDir/presentation/pages/general');
      await viewDir.create(recursive: true);
      await File('${viewDir.path}/product_view.dart').writeAsString(
        "import 'package:flutter/material.dart';\n"
        "class ProductView extends StatelessWidget {\n"
        "  const ProductView({super.key});\n"
        "  @override\n"
        "  Widget build(BuildContext context) => const SizedBox.shrink();\n"
        "}\n",
      );

      // Invalid host with whitespace should throw ArgumentError
      // BEFORE any route files are generated.
      expect(
        () => runner.run([
          'route',
          'create',
          'Product',
          '--scheme',
          'gozuzu',
          '--host',
          'invalid host',
          '--force',
        ]),
        throwsA(isA<ArgumentError>()),
      );

      // Verify no route files were generated.
      final routesFile = File('$outputDir/routing/product_routes.dart');
      expect(
        routesFile.existsSync(),
        isFalse,
        reason: 'route files must NOT be generated when --host is invalid',
      );

      // Verify manifest files were not modified.
      final manifest = await File(
        '$projectRoot/android/app/src/main/AndroidManifest.xml',
      ).readAsString();
      expect(
        manifest.contains('android:host="invalid host"'),
        isFalse,
        reason: 'invalid host must not be written to manifest',
      );
    });
  });
}

List<Diagnostic> syntaxErrors(String source) {
  final result = parseString(content: source, throwIfDiagnostics: false);
  return result.errors.cast<Diagnostic>();
}

const _fakeAndroidManifest =
    r'''<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="zuraffa_smoke"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
''';

const _fakeIosPlist = r'''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleDisplayName</key>
    <string>Zuraffa Smoke</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>zuraffa_smoke</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
</dict>
</plist>
''';
