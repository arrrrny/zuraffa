import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/context/file_system.dart';
import 'package:zuraffa/src/utils/manifest_writer.dart';

/// A minimal but realistic Flutter `AndroidManifest.xml` template,
/// matching what `flutter create` produces (with the `MainActivity`
/// registration). Tests inject deep-link intent-filters into this
/// template and assert the result is idempotent + structurally valid.
const _androidManifestTemplate =
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

/// A minimal but realistic iOS `Info.plist` template, matching what
/// `flutter create` produces (without any existing `CFBundleURLTypes`).
const _iosPlistTemplate = r'''<?xml version="1.0" encoding="UTF-8"?>
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
    <key>CFBundleShortVersionString</key>
    <string>$(FLUTTER_BUILD_NAME)</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>CFBundleVersion</key>
    <string>$(FLUTTER_BUILD_NUMBER)</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UILaunchStoryboardName</key>
    <string>LaunchScreen</string>
    <key>UIMainStoryboardFile</key>
    <string>Main</string>
</dict>
</plist>
''';

void main() {
  late Directory tempDir;
  late String manifestPath;
  late String plistPath;
  late ManifestWriter writer;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('manifest_writer_');
    manifestPath = '${tempDir.path}/AndroidManifest.xml';
    plistPath = '${tempDir.path}/Info.plist';
    await File(manifestPath).writeAsString(_androidManifestTemplate);
    await File(plistPath).writeAsString(_iosPlistTemplate);
    writer = ManifestWriter(fileSystem: const DefaultFileSystem());
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ManifestWriter.ensureAndroidIntentFilter', () {
    test('injects a new <intent-filter> with VIEW/DEFAULT/BROWSABLE + '
        '<data android:scheme="..."/>', () async {
      final result = await writer.ensureAndroidIntentFilter(
        manifestPath: manifestPath,
        scheme: 'gozuzu',
      );

      expect(result, isNotNull);
      final content = await File(manifestPath).readAsString();
      expect(content.contains('android:scheme="gozuzu"'), isTrue);
      expect(
        content.contains('android.intent.action.VIEW'),
        isTrue,
        reason: 'VIEW action must be declared',
      );
      expect(
        content.contains('android.intent.category.DEFAULT'),
        isTrue,
        reason: 'DEFAULT category must be declared',
      );
      expect(
        content.contains('android.intent.category.BROWSABLE'),
        isTrue,
        reason: 'BROWSABLE category must be declared',
      );
      // Sanity: the existing launcher <intent-filter> must remain.
      expect(
        content.contains('android.intent.action.MAIN'),
        isTrue,
        reason: 'existing launcher intent-filter must be preserved',
      );
    });

    test('injects host as <data android:host="..."/> when provided', () async {
      await writer.ensureAndroidIntentFilter(
        manifestPath: manifestPath,
        scheme: 'https',
        host: 'go.zuzu.dev',
        autoVerify: true,
      );

      final content = await File(manifestPath).readAsString();
      expect(content.contains('android:scheme="https"'), isTrue);
      expect(content.contains('android:host="go.zuzu.dev"'), isTrue);
      expect(
        content.contains('android:autoVerify="true"'),
        isTrue,
        reason: 'autoVerify flag must be set on the intent-filter element',
      );
    });

    test(
      'is idempotent — second call returns null and does not duplicate',
      () async {
        final first = await writer.ensureAndroidIntentFilter(
          manifestPath: manifestPath,
          scheme: 'gozuzu',
        );
        expect(first, isNotNull);

        final second = await writer.ensureAndroidIntentFilter(
          manifestPath: manifestPath,
          scheme: 'gozuzu',
        );
        expect(second, isNull, reason: 'second call must be a no-op');

        final content = await File(manifestPath).readAsString();
        final schemeOccurrences = 'android:scheme="gozuzu"'
            .allMatches(content)
            .length;
        expect(
          schemeOccurrences,
          equals(1),
          reason: 'scheme must appear exactly once after re-run',
        );
      },
    );

    test('returns null when AndroidManifest.xml does not exist '
        '(test env / pure-Dart package)', () async {
      final missing = await writer.ensureAndroidIntentFilter(
        manifestPath: '${tempDir.path}/does_not_exist.xml',
        scheme: 'gozuzu',
      );
      expect(missing, isNull);
    });

    test('multiple distinct schemes coexist on MainActivity', () async {
      await writer.ensureAndroidIntentFilter(
        manifestPath: manifestPath,
        scheme: 'gozuzu',
      );
      await writer.ensureAndroidIntentFilter(
        manifestPath: manifestPath,
        scheme: 'https',
        host: 'go.zuzu.dev',
        autoVerify: true,
      );

      final content = await File(manifestPath).readAsString();
      expect(content.contains('android:scheme="gozuzu"'), isTrue);
      expect(content.contains('android:scheme="https"'), isTrue);
      expect(content.contains('android:host="go.zuzu.dev"'), isTrue);
      // The launcher MAIN filter is preserved through both injections.
      expect(content.contains('android.intent.action.MAIN'), isTrue);
    });
  });

  group('ManifestWriter.ensureIosUrlScheme', () {
    test('injects a fresh CFBundleURLTypes block with the scheme', () async {
      final result = await writer.ensureIosUrlScheme(
        plistPath: plistPath,
        scheme: 'gozuzu',
      );

      expect(result, isNotNull);
      final content = await File(plistPath).readAsString();
      expect(content.contains('<key>CFBundleURLTypes</key>'), isTrue);
      expect(content.contains('<string>gozuzu</string>'), isTrue);
      expect(
        content.contains('<key>CFBundleURLSchemes</key>'),
        isTrue,
        reason: 'CFBundleURLSchemes key must be present inside the entry',
      );
    });

    test(
      'is idempotent — second call returns null and does not duplicate',
      () async {
        final first = await writer.ensureIosUrlScheme(
          plistPath: plistPath,
          scheme: 'gozuzu',
        );
        expect(first, isNotNull);

        final second = await writer.ensureIosUrlScheme(
          plistPath: plistPath,
          scheme: 'gozuzu',
        );
        expect(second, isNull, reason: 'second call must be a no-op');

        final content = await File(plistPath).readAsString();
        final occurrences = '<string>gozuzu</string>'
            .allMatches(content)
            .length;
        expect(
          occurrences,
          equals(1),
          reason: 'scheme must appear exactly once after re-run',
        );
      },
    );

    test('multiple distinct schemes coexist in CFBundleURLTypes', () async {
      await writer.ensureIosUrlScheme(plistPath: plistPath, scheme: 'gozuzu');
      await writer.ensureIosUrlScheme(plistPath: plistPath, scheme: 'https');

      final content = await File(plistPath).readAsString();
      expect(content.contains('<string>gozuzu</string>'), isTrue);
      expect(content.contains('<string>https</string>'), isTrue);
    });

    test('returns null when Info.plist does not exist', () async {
      final missing = await writer.ensureIosUrlScheme(
        plistPath: '${tempDir.path}/does_not_exist.plist',
        scheme: 'gozuzu',
      );
      expect(missing, isNull);
    });
  });

  group('ManifestWriter with existing CFBundleURLTypes', () {
    test('appends to existing CFBundleURLTypes array without duplicating '
        'the block', () async {
      // Pre-seed an existing CFBundleURLTypes with one scheme.
      final withExisting = _iosPlistTemplate.replaceFirst(
        '</dict>',
        '  <key>CFBundleURLTypes</key>\n'
            '  <array>\n'
            '    <dict>\n'
            '      <key>CFBundleURLSchemes</key>\n'
            '      <array>\n'
            '        <string>existing</string>\n'
            '      </array>\n'
            '    </dict>\n'
            '  </array>\n'
            '</dict>',
      );
      await File(plistPath).writeAsString(withExisting);

      await writer.ensureIosUrlScheme(plistPath: plistPath, scheme: 'gozuzu');

      final content = await File(plistPath).readAsString();
      expect(content.contains('<string>existing</string>'), isTrue);
      expect(content.contains('<string>gozuzu</string>'), isTrue);
      // Exactly one CFBundleURLTypes block must exist (no duplicate).
      final typesKeys = '<key>CFBundleURLTypes</key>'
          .allMatches(content)
          .length;
      expect(typesKeys, equals(1));
    });
  });
}
