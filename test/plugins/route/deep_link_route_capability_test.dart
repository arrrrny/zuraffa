import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/core/context/file_system.dart';
import 'package:zuraffa/src/models/generated_file.dart';
import 'package:zuraffa/src/plugins/route/route_plugin.dart';

void main() {
  late Directory tempDir;
  late String projectRoot;
  late String outputDir;
  late RoutePlugin plugin;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('deep_link_cap_');
    projectRoot = tempDir.path;
    outputDir = '$projectRoot/lib/src';
    await Directory('$projectRoot/lib/src/routing').create(recursive: true);
    plugin = RoutePlugin(
      outputDir: outputDir,
      projectRoot: projectRoot,
      fileSystem: const DefaultFileSystem(),
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<Map<String, dynamic>> runCapability({
    required String name,
    required String path,
    required String scheme,
    String? host,
    bool autoVerify = false,
    String? view,
    bool dryRun = false,
    bool force = true,
    bool verbose = false,
  }) async {
    final capability = plugin.capabilities.firstWhere((c) => c.name == 'deep-link');
    final result = await capability.execute({
      'name': name,
      'path': path,
      'scheme': scheme,
      if (host != null) 'host': host,
      'autoVerify': autoVerify,
      if (view != null) 'view': view,
      'dryRun': dryRun,
      'force': force,
      'verbose': verbose,
    });
    return result.toJson();
  }

  group('DeepLinkRouteCapability.execute', () {
    test('emits a <name>_routes.dart file that parses cleanly', () async {
      final result = await runCapability(
        name: 'ScanBarcode',
        path: '/scan/barcode/:barcode',
        scheme: 'gozuzu',
      );

      expect(result['success'], isTrue);
      final files = (result['data']?['generatedFiles'] as List?)
          ?.cast<GeneratedFile>();
      expect(files, isNotNull);
      expect(
        files!.any((f) => f.path.endsWith('scan_barcode_routes.dart')),
        isTrue,
        reason: 'deep-link route file must be emitted',
      );

      final routesFile =
          File('$outputDir/routing/scan_barcode_routes.dart');
      expect(routesFile.existsSync(), isTrue);

      final content = routesFile.readAsStringSync();
      // Structure: class <Name>Routes + getter <nameCamel>Routes()
      expect(content.contains('class ScanBarcodeRoutes'), isTrue);
      expect(content.contains('scanBarcodeRoutes'), isTrue);
      expect(content.contains("'/scan/barcode/:barcode'"), isTrue);
      expect(content.contains('package:go_router/go_router.dart'), isTrue);
      // Default placeholder builder (no view).
      expect(content.contains('SizedBox'), isTrue);

      final errors = syntaxErrors(content);
      expect(
        errors,
        isEmpty,
        reason: 'generated routes file must parse cleanly; got: '
            '${errors.map((e) => e.message).join(', ')}',
      );
    });

    test('emits List<GoRoute> return type on the routes getter', () async {
      await runCapability(
        name: 'ScanBarcode',
        path: '/scan/barcode/:barcode',
        scheme: 'gozuzu',
      );

      final content =
          File('$outputDir/routing/scan_barcode_routes.dart').readAsStringSync();
      expect(
        content.contains('List<GoRoute> scanBarcodeRoutes()'),
        isTrue,
        reason: 'routes getter must return List<GoRoute> for type safety',
      );
    });

    test('emits the requested view class name when provided', () async {
      await runCapability(
        name: 'ScanBarcode',
        path: '/scan/barcode/:barcode',
        scheme: 'gozuzu',
        view: 'ScanBarcodeView',
      );

      final content =
          File('$outputDir/routing/scan_barcode_routes.dart').readAsStringSync();
      expect(content.contains('ScanBarcodeView'), isTrue);
      expect(content.contains('SizedBox'), isFalse,
          reason: 'placeholder builder must not be emitted when a view is '
              'specified');
    });

    test('regenerates routing/index.dart aggregating the new module '
        'in getAllRoutes()', () async {
      await runCapability(
        name: 'ScanBarcode',
        path: '/scan/barcode/:barcode',
        scheme: 'gozuzu',
      );

      final indexFile = File('$outputDir/routing/index.dart');
      expect(indexFile.existsSync(), isTrue,
          reason: 'index.dart must be regenerated');
      final indexContent = indexFile.readAsStringSync();
      expect(indexContent.contains("scan_barcode_routes.dart"), isTrue,
          reason: 'index must export the new module');
      expect(indexContent.contains('scanBarcodeRoutes'), isTrue,
          reason: 'getAllRoutes() must spread the new routes getter');
      expect(indexContent.contains('getAllRoutes'), isTrue);
    });

    test('writes Android intent-filter + iOS plist entry when platform '
        'files exist', () async {
      // Arrange: create a fake Flutter project skeleton.
      await _seedFakeFlutterProject(projectRoot);

      await runCapability(
        name: 'ScanBarcode',
        path: '/scan/barcode/:barcode',
        scheme: 'gozuzu',
        host: 'go.zuzu.dev',
        autoVerify: true,
      );

      final manifest = await File(
        '$projectRoot/android/app/src/main/AndroidManifest.xml',
      ).readAsString();
      expect(manifest.contains('android:scheme="gozuzu"'), isTrue);
      expect(manifest.contains('android:host="go.zuzu.dev"'), isTrue);
      expect(manifest.contains('android:autoVerify="true"'), isTrue);

      final plist = await File('$projectRoot/ios/Runner/Info.plist')
          .readAsString();
      expect(plist.contains('<string>gozuzu</string>'), isTrue);
      expect(plist.contains('<key>CFBundleURLTypes</key>'), isTrue);
    });

    test('is idempotent — re-running with the same scheme does not '
        'duplicate platform entries', () async {
      await _seedFakeFlutterProject(projectRoot);

      await runCapability(
        name: 'ScanBarcode',
        path: '/scan/barcode/:barcode',
        scheme: 'gozuzu',
      );
      await runCapability(
        name: 'ScanBarcode',
        path: '/scan/barcode/:barcode',
        scheme: 'gozuzu',
      );

      final manifest = await File(
        '$projectRoot/android/app/src/main/AndroidManifest.xml',
      ).readAsString();
      expect(
        'android:scheme="gozuzu"'.allMatches(manifest).length,
        equals(1),
        reason: 'intent-filter must appear exactly once after re-run',
      );

      final plist = await File('$projectRoot/ios/Runner/Info.plist')
          .readAsString();
      expect(
        '<string>gozuzu</string>'.allMatches(plist).length,
        equals(1),
        reason: 'CFBundleURLSchemes string must appear exactly once',
      );
    });

    test('skips platform files silently when the project is pure-Dart '
        '(no android/ or ios/)', () async {
      // No fake Flutter project — pure-Dart package, no platform files.
      final result = await runCapability(
        name: 'ScanBarcode',
        path: '/scan/barcode/:barcode',
        scheme: 'gozuzu',
      );

      expect(result['success'], isTrue);
      // Route file + index still emitted; platform files skipped.
      expect(
        File('$outputDir/routing/scan_barcode_routes.dart').existsSync(),
        isTrue,
      );
      expect(File('$outputDir/routing/index.dart').existsSync(), isTrue);
      // No platform directories were created.
      expect(
        Directory('$projectRoot/android').existsSync(),
        isFalse,
        reason: 'capability must NOT create android/ when absent',
      );
      expect(
        Directory('$projectRoot/ios').existsSync(),
        isFalse,
        reason: 'capability must NOT create ios/ when absent',
      );
    });

    test('regenerateIndex honors dryRun when called directly', () async {
      // Seed a route module so the index regenerator actually has
      // something to aggregate (an empty routing dir returns early and
      // would make this test pass vacuously).
      await File('$outputDir/routing/scan_barcode_routes.dart')
          .writeAsString('// Generated by zfa\n');
      final indexFile = File('$outputDir/routing/index.dart');
      if (indexFile.existsSync()) await indexFile.delete();

      final defaultPlugin = RoutePlugin(
        outputDir: outputDir,
        projectRoot: projectRoot,
        fileSystem: const DefaultFileSystem(),
      );

      await defaultPlugin.routeBuilder.regenerateIndex(dryRun: true);

      expect(
        indexFile.existsSync(),
        isFalse,
        reason: 'regenerateIndex(dryRun: true) must not write files',
      );
    });

    test('rejects non-PascalCase name with ArgumentError', () async {
      expect(
        () => runCapability(
          name: 'scan-barcode',
          path: '/scan/barcode/:barcode',
          scheme: 'gozuzu',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects non-lowercase scheme with ArgumentError', () async {
      expect(
        () => runCapability(
          name: 'ScanBarcode',
          path: '/scan/barcode/:barcode',
          scheme: 'GoZuzu',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects path that does not start with /', () async {
      expect(
        () => runCapability(
          name: 'ScanBarcode',
          path: 'scan/barcode',
          scheme: 'gozuzu',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}

/// Seeds a minimal fake Flutter project skeleton at [projectRoot] with
/// just enough of `AndroidManifest.xml` and `Info.plist` for the
/// ManifestWriter to find and patch them. The templates match what
/// `flutter create --empty <name>` produces.
Future<void> _seedFakeFlutterProject(String projectRoot) async {
  final manifestDir = Directory('$projectRoot/android/app/src/main');
  await manifestDir.create(recursive: true);
  await File('${manifestDir.path}/AndroidManifest.xml').writeAsString(
    _fakeAndroidManifest,
  );
  final iosDir = Directory('$projectRoot/ios/Runner');
  await iosDir.create(recursive: true);
  await File('${iosDir.path}/Info.plist').writeAsString(_fakeIosPlist);
}

const _fakeAndroidManifest = r'''<manifest xmlns:android="http://schemas.android.com/apk/res/android">
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

/// Returns the syntax (parse) diagnostics from [source]. A syntactically
/// valid file yields an empty list.
List<Diagnostic> syntaxErrors(String source) {
  final result = parseString(content: source, throwIfDiagnostics: false);
  return result.errors.cast<Diagnostic>();
}
