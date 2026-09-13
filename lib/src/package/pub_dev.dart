import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';

import '../version.dart';

/// The pub.dev endpoint the CLI reads the latest published zuraffa version
/// from — `zfa update` and the package scaffolds' hosted-constraint
/// resolution (issue #1615).
const String zuraffaPubDevUrl = 'https://pub.dev/api/packages/zuraffa';

/// Deadline for a whole pub.dev lookup. `request.close()` completes on the
/// response *headers*, so the body read carries its own timeout — a server
/// that stalls mid-body must not hang the CLI (issue #1615 review).
const Duration pubDevLookupTimeout = Duration(seconds: 5);

/// The caller identity pub.dev's API guidance asks clients to send.
const String _userAgent = 'zfa';

/// Fetches the latest zuraffa version published on pub.dev (e.g. `6.2.2`).
///
/// The one implementation behind `zfa update` and the scaffolds' hosted
/// constraint, so the URL, [timeout], `User-Agent`, and close semantics
/// stay in step.
Future<String> latestZuraffaVersion({
  Duration timeout = pubDevLookupTimeout,
}) async {
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final request = await client.getUrl(Uri.parse(zuraffaPubDevUrl));
    request.headers.set('User-Agent', _userAgent);
    final response = await request.close().timeout(timeout);
    final body = await response.transform(utf8.decoder).join().timeout(timeout);
    return parsePublishedVersion(response.statusCode, body);
  } finally {
    client.close(force: true);
  }
}

/// The hosted constraint for the latest zuraffa release on pub.dev, e.g.
/// `^6.2.2`.
Future<String> latestZuraffaConstraint({
  Duration timeout = pubDevLookupTimeout,
}) async => '^${await latestZuraffaVersion(timeout: timeout)}';

/// Decodes a pub.dev package payload into the published version string.
///
/// Only an HTTP 200 carrying a non-empty `latest.version` string resolves;
/// every other outcome throws. Visible for testing — the socket in
/// [latestZuraffaVersion] is deliberately not unit-tested.
@visibleForTesting
String parsePublishedVersion(int statusCode, String body) {
  if (statusCode != 200) {
    throw HttpException(
      'pub.dev returned HTTP $statusCode',
      uri: Uri.parse(zuraffaPubDevUrl),
    );
  }
  final payload = jsonDecode(body) as Map<String, dynamic>;
  final latest = payload['latest'];
  final resolved = (latest is Map) ? latest['version'] : null;
  if (resolved is! String || resolved.isEmpty) {
    throw const FormatException('pub.dev payload carried no latest.version');
  }
  return resolved;
}

/// Resolves the hosted zuraffa constraint stamped into generated pubspecs:
/// an explicit [explicit] constraint wins, then [resolver] (the pub.dev
/// lookup by default), then — when the lookup fails — the running CLI's
/// version const, announced on [warn] (stderr by default).
///
/// The fallback keeps offline scaffolds working, but it is loud: a dev
/// checkout's version const is the *next unreleased* release, which pub can
/// refuse to resolve, and `--zuraffa-constraint` pins the published version
/// explicitly instead (issue #1615).
Future<String> resolveZuraffaConstraint({
  String? explicit,
  Future<String> Function()? resolver,
  void Function(String message)? warn,
}) async {
  if (explicit != null) return explicit;
  try {
    return await (resolver ?? latestZuraffaConstraint)();
  } catch (e) {
    final fallback = '^$version';
    (warn ?? _warnStderr)(
      'warning: could not read the latest zuraffa version from pub.dev '
      '($e). Falling back to $fallback, which may not resolve. Pass '
      '--zuraffa-constraint to pin the published version explicitly.',
    );
    return fallback;
  }
}

void _warnStderr(String message) => stderr.writeln(message);
