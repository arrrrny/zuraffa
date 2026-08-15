import '../core/context/file_system.dart';
import '../models/generated_file.dart';
import 'file_utils.dart';

/// Idempotent writer for the platform deep-link registration files
/// (Android `AndroidManifest.xml` and iOS `Info.plist`).
///
/// Both platforms need explicit registration for an external URL scheme
/// to be routed into the app:
///
///  - Android: a `<intent-filter>` block on `MainActivity` with a
///    `<data android:scheme="..."/>` child (and optionally
///    `android:autoVerify="true"` plus `<data android:host="..."/>` for
///    App Links).
///  - iOS: a `CFBundleURLTypes` array entry whose `CFBundleURLSchemes`
///    contains the scheme string.
///
/// This class is intentionally side-effect free with respect to the
/// `FileSystem` (it accepts an injectable [FileSystem] for testing) and
/// idempotent: re-running with the same scheme is a no-op, so it is safe
/// to call from `zfa setup` AND from `zfa route deep-link` AND from
/// `zfa route create --deep-link` without producing duplicate entries.
///
/// When the target platform file does not exist (e.g. during tests on a
/// temp directory, or in a pure-Dart package), the writer silently skips
/// the update and returns `null` — deep-link code generation is never
/// blocked by the absence of platform files. The route files are still
/// emitted; only the platform manifest is skipped.
class ManifestWriter {
  final FileSystem fileSystem;

  ManifestWriter({FileSystem? fileSystem})
    : fileSystem = fileSystem ?? const DefaultFileSystem();

  /// Ensures an `<intent-filter>` block declaring [scheme] exists on the
  /// `MainActivity` element of the Android manifest at [manifestPath].
  ///
  /// - When [host] is provided, an additional
  ///   `<data android:host="..."/>` child is emitted (used for App
  ///   Links).
  /// - When [autoVerify] is `true`, the `android:autoVerify="true"`
  ///   attribute is set on the `<intent-filter>` element so Android
  ///   attempts to verify the App Link ownership at install time.
  ///
  /// Idempotency: if the manifest already contains an
  /// `android:scheme="<scheme>"` attribute, the file is left untouched
  /// (and `null` is returned — the caller treats that as "no change").
  ///
  /// No-op when [manifestPath] does not exist on the file system.
  Future<GeneratedFile?> ensureAndroidIntentFilter({
    required String manifestPath,
    required String scheme,
    String? host,
    bool autoVerify = false,
    bool dryRun = false,
    bool verbose = false,
  }) async {
    if (!await fileSystem.exists(manifestPath)) {
      if (verbose) {
        print('  ⏭ AndroidManifest.xml not found at $manifestPath; '
            'skipping platform registration.');
      }
      return null;
    }

    final content = await fileSystem.read(manifestPath);

    // Idempotency: the scheme is already declared. Skip the write
    // entirely so re-runs never duplicate the intent-filter.
    if (content.contains('android:scheme="$scheme"')) {
      if (verbose) {
        print('  ⏭ Android intent-filter for scheme "$scheme" already '
            'present; skipping.');
      }
      return null;
    }

    final intentFilter = _buildAndroidIntentFilter(
      scheme: scheme,
      host: host,
      autoVerify: autoVerify,
    );

    final updated = _injectIntoMainActivity(content, intentFilter);
    if (updated == null) {
      if (verbose) {
        print('  ⚠️ No <activity android:name=".MainActivity"> found in '
            '$manifestPath; skipping intent-filter injection.');
      }
      return null;
    }

    return FileUtils.writeFile(
      manifestPath,
      updated,
      'android_manifest',
      force: true,
      dryRun: dryRun,
      verbose: verbose,
      fileSystem: fileSystem,
    );
  }

  /// Ensures a `CFBundleURLTypes` entry exists in the iOS `Info.plist`
  /// at [plistPath] declaring [scheme] under `CFBundleURLSchemes`.
  ///
  /// Idempotency: if `<string><scheme></string>` already appears inside
  /// a `CFBundleURLSchemes` array, the file is left untouched.
  ///
  /// No-op when [plistPath] does not exist on the file system.
  Future<GeneratedFile?> ensureIosUrlScheme({
    required String plistPath,
    required String scheme,
    bool dryRun = false,
    bool verbose = false,
  }) async {
    if (!await fileSystem.exists(plistPath)) {
      if (verbose) {
        print('  ⏭ Info.plist not found at $plistPath; skipping platform '
            'registration.');
      }
      return null;
    }

    final content = await fileSystem.read(plistPath);

    // Idempotency: the scheme is already declared as a URL scheme
    // string somewhere in the plist. Skip.
    //
    // We match the exact `<string>scheme</string>` element — a bare
    // `content.contains(scheme)` would false-positive when the scheme
    // is a substring of another plist value (e.g. scheme "go" inside
    // "google" or "gozuzu-app") and wrongly skip the registration.
    if (content.contains('<string>$scheme</string>')) {
      if (verbose) {
        print('  ⏭ iOS CFBundleURLSchemes for "$scheme" already present; '
            'skipping.');
      }
      return null;
    }

    final String updated;
    if (content.contains('<key>CFBundleURLTypes</key>')) {
      updated = _appendToExistingUrlTypes(content, scheme);
    } else {
      updated = _injectNewUrlTypes(content, scheme);
    }

    if (updated == content) {
      if (verbose) {
        print('  ⚠️ Could not locate insertion point for CFBundleURLTypes '
            'in $plistPath; skipping.');
      }
      return null;
    }

    return FileUtils.writeFile(
      plistPath,
      updated,
      'ios_plist',
      force: true,
      dryRun: dryRun,
      verbose: verbose,
      fileSystem: fileSystem,
    );
  }

  /// Builds the `<intent-filter>` block for the given scheme/host.
  ///
  /// The intent-filter always declares `VIEW`/`DEFAULT`/`BROWSABLE` so it
  /// matches both launched-from-app and launched-from-browser deep
  /// links. When [autoVerify] is `true`, the
  /// `android:autoVerify="true"` attribute is set on the
  /// `<intent-filter>` element (used for App Links).
  String _buildAndroidIntentFilter({
    required String scheme,
    String? host,
    required bool autoVerify,
  }) {
    final buffer = StringBuffer();
    if (autoVerify) {
      buffer.writeln('            <intent-filter android:autoVerify="true">');
    } else {
      buffer.writeln('            <intent-filter>');
    }
    buffer.writeln('              <action android:name="android.intent.action.VIEW" />');
    buffer.writeln('              <category android:name="android.intent.category.DEFAULT" />');
    buffer.writeln('              <category android:name="android.intent.category.BROWSABLE" />');
    buffer.writeln('              <data android:scheme="$scheme" />');
    if (host != null && host.isNotEmpty) {
      buffer.writeln('              <data android:host="$host" />');
    }
    buffer.write('            </intent-filter>');
    return buffer.toString();
  }

  /// Injects [intentFilter] just before the closing `</activity>` tag
  /// of the `MainActivity` element.
  ///
  /// Returns `null` when no MainActivity `<activity>` is found (the
  /// manifest is too far from a standard Flutter template to patch
  /// safely).
  String? _injectIntoMainActivity(String content, String intentFilter) {
    // The standard Flutter template names MainActivity as
    // `android:name=".MainActivity"`. Match that block first; fall back
    // to any `<activity` element if the named one is absent (rare).
    final namedActivity = RegExp(
      r'(<activity[^>]*android:name="\.MainActivity"[^>]*>)([\s\S]*?)(</activity>)',
    );
    final match = namedActivity.firstMatch(content);
    if (match == null) return null;

    final openTag = match.group(1)!;
    final body = match.group(2)!;
    final closeTag = match.group(3)!;

    // Preserve the existing activity body; inject the intent-filter
    // immediately before `</activity>`.
    final injected = '$openTag$body$intentFilter\n        $closeTag';
    return content.replaceRange(match.start, match.end, injected);
  }

  /// Appends a new `<dict>` entry to an existing
  /// `CFBundleURLTypes</key><array>...</array>` block.
  ///
  /// The insertion point (the `</array>` closing the CFBundleURLTypes
  /// array) is found by counting nested `<array>`/`</array>` tags — a
  /// regex cannot do this reliably because each entry's
  /// `CFBundleURLSchemes` introduces its own nested `<array>`.
  String _appendToExistingUrlTypes(String content, String scheme) {
    final startRegex = RegExp(r'<key>CFBundleURLTypes</key>\s*<array>');
    final match = startRegex.firstMatch(content);
    if (match == null) return content;

    var depth = 1;
    var pos = match.end;
    while (depth > 0 && pos < content.length) {
      final openIdx = content.indexOf('<array>', pos);
      final closeIdx = content.indexOf('</array>', pos);

      if (closeIdx == -1) return content;
      if (openIdx != -1 && openIdx < closeIdx) {
        depth++;
        pos = openIdx + '<array>'.length;
      } else {
        depth--;
        if (depth == 0) {
          final newEntry = '          <dict>\n'
              '            <key>CFBundleURLSchemes</key>\n'
              '            <array>\n'
              '              <string>$scheme</string>\n'
              '            </array>\n'
              '          </dict>\n';
          return content.substring(0, closeIdx) +
              newEntry +
              content.substring(closeIdx);
        }
        pos = closeIdx + '</array>'.length;
      }
    }
    return content;
  }

  /// Inserts a fresh `CFBundleURLTypes` block before the closing
  /// `</dict>` of the top-level plist dict.
  String _injectNewUrlTypes(String content, String scheme) {
    final entry = '  <key>CFBundleURLTypes</key>\n'
        '  <array>\n'
        '    <dict>\n'
        '      <key>CFBundleURLSchemes</key>\n'
        '      <array>\n'
        '        <string>$scheme</string>\n'
        '      </array>\n'
        '    </dict>\n'
        '  </array>\n';

    // Insert before the LAST `</dict>` at the top level (the plist root).
    final lastCloseDict = content.lastIndexOf('</dict>');
    if (lastCloseDict == -1) return content;

    return content.substring(0, lastCloseDict) +
        entry +
        content.substring(lastCloseDict);
  }
}
