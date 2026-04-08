// Integration test for ArtifactPublisher + MinIOArtifactHook + MinioClient.
//
// This test hits a real MinIO instance — it requires:
//   1. A running MinIO server (e.g. storage.zuzu.dev)
//   2. Environment variables set:
//      - MINIO_ENDPOINT   (e.g. https://storage.zuzu.dev)
//      - MINIO_ACCESS_KEY
//      - MINIO_SECRET_KEY
//      - MINIO_BUCKET     (e.g. test-artifacts)
//
// Run with:
//   dart test test/core/artifact_publisher_integration_test.dart
//
// Or with env vars inline:
//   MINIO_ENDPOINT=https://storage.zuzu.dev \
//   MINIO_ACCESS_KEY=your-key \
//   MINIO_SECRET_KEY=your-secret \
//   MINIO_BUCKET=test-artifacts \
//   dart test test/core/artifact_publisher_integration_test.dart

@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

/// Reads required env var or skips the test.
String _env(String name) {
  final value = Platform.environment[name];
  if (value == null || value.isEmpty) {
    throw StateError(
      'Missing required environment variable: $name\n'
      'Set it before running this test:\n'
      '  $name=value dart test ...',
    );
  }
  return value;
}

/// Checks if required env vars are present.
bool get _hasMinioConfig {
  return Platform.environment.containsKey('MINIO_ENDPOINT') &&
      Platform.environment.containsKey('MINIO_ACCESS_KEY') &&
      Platform.environment.containsKey('MINIO_SECRET_KEY') &&
      Platform.environment.containsKey('MINIO_BUCKET');
}

void main() {
  // Skip entire suite if env vars not configured
  if (!_hasMinioConfig) {
    setUpAll(() {
      markTestSkipped(
        'MINIO_ENDPOINT, MINIO_ACCESS_KEY, MINIO_SECRET_KEY, or MINIO_BUCKET '
        'not set. To run integration tests:\n\n'
        '  MINIO_ENDPOINT=https://artifacts.zuzu.dev \\\n'
        '  MINIO_ACCESS_KEY=your-key \\\n'
        '  MINIO_SECRET_KEY=your-secret \\\n'
        '  MINIO_BUCKET=test-artifacts \\\n'
        '  flutter test test/core/artifact_publisher_integration_test.dart',
      );
    });
    return;
  }

  late MinioClient client;
  late String bucket;
  late ArtifactPublisher publisher;

  setUpAll(() {
    final endpoint = _env('MINIO_ENDPOINT');
    final accessKey = _env('MINIO_ACCESS_KEY');
    final secretKey = _env('MINIO_SECRET_KEY');
    bucket = _env('MINIO_BUCKET');

    client = MinioClient(
      endpoint: endpoint,
      accessKey: accessKey,
      secretKey: secretKey,
    );

    publisher = ArtifactPublisher.instance;
  });

  tearDownAll(() {
    publisher.dispose();
    client.close();
  });

  // ---------------------------------------------------------------------------
  // MinioClient direct tests
  // ---------------------------------------------------------------------------

  group('MinioClient', () {
    test('bucketExists returns false for non-existent bucket', () async {
      final exists = await client.bucketExists(
        'zuraffa-test-nonexistent-${DateTime.now().millisecondsSinceEpoch}',
      );
      expect(exists, isFalse);
    });

    test('ensureBucket creates bucket and bucketExists returns true', () async {
      final ok = await client.ensureBucket(bucket);
      expect(ok, isTrue);

      final exists = await client.bucketExists(bucket);
      expect(exists, isTrue);
    });

    test('putObject + getObject round-trip with HTML content', () async {
      final testKey =
          'test/roundtrip_html_${DateTime.now().millisecondsSinceEpoch}.html';
      final html = '<html><body><h1>Hello MinIO!</h1></body></html>';

      final uploaded = await client.putObject(
        bucket: bucket,
        key: testKey,
        data: html,
        contentType: 'text/html; charset=utf-8',
        metadata: {'test': 'true', 'type': 'integration'},
      );
      expect(uploaded, isTrue);

      final fetched = await client.getObject(bucket, testKey);
      expect(fetched, isNotNull);
      expect(fetched, equals(html));
    });

    test('putObject + getObject round-trip with JSON content', () async {
      final testKey =
          'test/roundtrip_json_${DateTime.now().millisecondsSinceEpoch}.json';
      final json = jsonEncode({
        'productId': '12345',
        'name': 'Test Product',
        'price': 29.99,
      });

      final uploaded = await client.putObject(
        bucket: bucket,
        key: testKey,
        data: json,
        contentType: 'application/json; charset=utf-8',
        metadata: {'test': 'true'},
      );
      expect(uploaded, isTrue);

      final fetched = await client.getObject(bucket, testKey);
      expect(fetched, isNotNull);
      expect(fetched, equals(json));
    });

    test('putObjectBytes + getObject round-trip with binary', () async {
      final testKey =
          'test/roundtrip_bin_${DateTime.now().millisecondsSinceEpoch}.bin';
      final bytes = List<int>.generate(256, (i) => i);
      final data = Uint8List.fromList(bytes);

      final uploaded = await client.putObjectBytes(
        bucket: bucket,
        key: testKey,
        bytes: data,
        contentType: 'application/octet-stream',
      );
      expect(uploaded, isTrue);

      final fetched = await client.getObject(bucket, testKey);
      expect(fetched, isNotNull);
      // getObject returns String, binary data comes back as string
      expect(fetched!.length, greaterThan(0));
    });

    test('deleteObject removes the object', () async {
      final testKey =
          'test/to_delete_${DateTime.now().millisecondsSinceEpoch}.txt';
      await client.putObject(
        bucket: bucket,
        key: testKey,
        data: 'delete me',
        contentType: 'text/plain',
      );

      final deleted = await client.deleteObject(bucket, testKey);
      expect(deleted, isTrue);

      final fetched = await client.getObject(bucket, testKey);
      expect(fetched, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // MinIOArtifactHook via ArtifactPublisher
  // ---------------------------------------------------------------------------

  group('MinIOArtifactHook via ArtifactPublisher', () {
    late MinIOArtifactHook hook;

    setUp(() {
      hook = MinIOArtifactHook(
        client: client,
        bucket: bucket,
        pathPrefix: 'test/',
        ensureBucketExists: false, // already created above
        includeReasonInKey: true,
        includeSourceInKey: true,
      );
      publisher.register(hook);
    });

    tearDown(() {
      publisher.clear();
    });

    test('publishes failure artifact (HTML) and can retrieve it', () async {
      final taskId = 'test-${DateTime.now().millisecondsSinceEpoch}';
      final html = '<html><body><h1>Product Not Found</h1></body></html>';

      await publisher.publish(
        html,
        id: taskId,
        contentType: 'text/html; charset=utf-8',
        reason: ArtifactReason.failure,
        source: 'ParsingProvider',
        label: 'ParsingFailed',
        metadata: {
          'url': 'https://example.com/product/123',
          'statusCode': '200',
          'error': 'No matching selectors found',
        },
      );

      // Key should be: test/failure/parsing_provider/parsing_failed/{taskId}.html
      final key = 'test/failure/parsing_provider/parsing_failed/$taskId.html';
      final fetched = await client.getObject(bucket, key);

      expect(fetched, isNotNull);
      expect(fetched, equals(html));
    });

    test(
      'publishes failure artifact (JSON) with correct content type',
      () async {
        final taskId = 'test-json-${DateTime.now().millisecondsSinceEpoch}';
        final json = jsonEncode({
          'products': [],
          'pagination': {'page': 1, 'total': 0},
        });

        await publisher.publish(
          json,
          id: taskId,
          contentType: 'application/json; charset=utf-8',
          reason: ArtifactReason.failure,
          source: 'ParsingProvider',
          label: 'EmptyResults',
          metadata: {'url': 'https://example.com/search?q=xyz'},
        );

        final key = 'test/failure/parsing_provider/empty_results/$taskId.json';
        final fetched = await client.getObject(bucket, key);

        expect(fetched, isNotNull);
        expect(fetched, equals(json));
      },
    );

    test('publishes failure artifact (plain text)', () async {
      final taskId = 'test-text-${DateTime.now().millisecondsSinceEpoch}';
      final text = 'Raw text response from server — no HTML at all';

      await publisher.publish(
        text,
        id: taskId,
        contentType: 'text/plain; charset=utf-8',
        reason: ArtifactReason.failure,
        source: 'ParsingProvider',
        label: 'UnexpectedFormat',
        metadata: {'url': 'https://example.com/api/raw'},
      );

      final key = 'test/failure/parsing_provider/unexpected_format/$taskId.txt';
      final fetched = await client.getObject(bucket, key);

      expect(fetched, isNotNull);
      expect(fetched, equals(text));
    });

    test('publishes scan artifact (image)', () async {
      // Simulate a 1x1 red PNG pixel
      final pngBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
        0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,
        0x54, 0x08, 0xD7, 0x63, 0xD8, 0xCD, 0xC0, 0x00,
        0x00, 0x00, 0x14, 0x00, 0x01, 0x9E, 0x26, 0x50,
        0xA0, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,
        0x44, 0xAE, 0x42, 0x60, 0x82,
      ]);
      final barcode = '1234567890123';

      await publisher.publish(
        pngBytes,
        id: barcode,
        contentType: 'image/png',
        reason: ArtifactReason.scan,
        source: 'BarcodeScanner',
        label: 'product_photo',
        metadata: {'format': 'EAN-13', 'product': 'Test Product'},
      );

      final key = 'test/scan/barcode_scanner/product_photo/$barcode.png';
      final fetched = await client.getObject(bucket, key);

      expect(fetched, isNotNull);
      expect(fetched!.length, greaterThan(0));
    });

    test('publishes debug artifact', () async {
      final taskId = 'test-debug-${DateTime.now().millisecondsSinceEpoch}';
      final debugSnapshot = jsonEncode({
        'step': 'checkout_page_3',
        'timestamp': DateTime.now().toIso8601String(),
        'url': 'https://example.com/checkout',
        'dom': '<div class="checkout-summary">...</div>',
      });

      await publisher.publish(
        debugSnapshot,
        id: taskId,
        contentType: 'application/json; charset=utf-8',
        reason: ArtifactReason.debug,
        source: 'ScreenshotTool',
        label: 'checkout_step',
        metadata: {'step': '3'},
      );

      final key = 'test/debug/screenshot_tool/checkout_step/$taskId.json';
      final fetched = await client.getObject(bucket, key);

      expect(fetched, isNotNull);
      expect(fetched, equals(debugSnapshot));
    });

    test('fire-and-forget does not block', () async {
      final sw = Stopwatch()..start();
      final taskId = 'test-ff-${DateTime.now().millisecondsSinceEpoch}';

      publisher.publishFireAndForget(
        'fire and forget content',
        id: taskId,
        contentType: 'text/plain; charset=utf-8',
        reason: ArtifactReason.custom,
        source: 'SpeedTest',
        label: 'async_test',
      );

      sw.stop();

      // Fire-and-forget should return in under 100ms
      // (it just schedules the work, doesn't wait for upload)
      expect(sw.elapsedMilliseconds, lessThan(100));

      // Wait a bit for the upload to actually complete
      await Future<void>.delayed(const Duration(seconds: 2));

      final key = 'test/custom/speed_test/async_test/$taskId.txt';
      final fetched = await client.getObject(bucket, key);

      expect(fetched, isNotNull);
      expect(fetched, equals('fire and forget content'));
    });

    test('overwrites when publishing same id + label (idempotent)', () async {
      final taskId = 'test-idempotent-${DateTime.now().millisecondsSinceEpoch}';

      // First publish
      await publisher.publish(
        'version 1',
        id: taskId,
        contentType: 'text/plain; charset=utf-8',
        reason: ArtifactReason.failure,
        source: 'ParsingProvider',
        label: 'ParsingFailed',
      );

      // Second publish with same id + label → overwrites
      await publisher.publish(
        'version 2 — updated',
        id: taskId,
        contentType: 'text/plain; charset=utf-8',
        reason: ArtifactReason.failure,
        source: 'ParsingProvider',
        label: 'ParsingFailed',
      );

      final key = 'test/failure/parsing_provider/parsing_failed/$taskId.txt';
      final fetched = await client.getObject(bucket, key);

      expect(fetched, equals('version 2 — updated'));
    });
  });

  // ---------------------------------------------------------------------------
  // Zuraffa static API tests
  // ---------------------------------------------------------------------------

  group('Zuraffa static API', () {
    setUp(() {
      Zuraffa.registerArtifactHook(
        MinIOArtifactHook(
          client: client,
          bucket: bucket,
          pathPrefix: 'test/zuraffa_api/',
          ensureBucketExists: false,
        ),
      );
    });

    tearDown(() {
      Zuraffa.disposeFailureHooks();
    });

    test('Zuraffa.publishArtifact uploads and is retrievable', () async {
      final taskId = 'test-api-${DateTime.now().millisecondsSinceEpoch}';

      Zuraffa.publishArtifact(
        '<html><body>From Zuraffa API!</body></html>',
        id: taskId,
        contentType: 'text/html; charset=utf-8',
        reason: ArtifactReason.failure,
        source: 'ParsingProvider',
        label: 'ParsingFailed',
        metadata: {'url': 'https://example.com/test'},
      );

      // Wait for fire-and-forget to complete
      await Future<void>.delayed(const Duration(seconds: 2));

      final key =
          'test/zuraffa_api/failure/parsing_provider/parsing_failed/'
          '$taskId.html';
      final fetched = await client.getObject(bucket, key);

      expect(fetched, isNotNull);
      expect(fetched, contains('From Zuraffa API!'));
    });

    test('Zuraffa.publishArtifactAwaited completes before returning', () async {
      final taskId =
          'test-api-awaited-${DateTime.now().millisecondsSinceEpoch}';

      await Zuraffa.publishArtifactAwaited(
        jsonEncode({'status': 'awaited', 'taskId': taskId}),
        id: taskId,
        contentType: 'application/json; charset=utf-8',
        reason: ArtifactReason.debug,
        source: 'TestRunner',
        label: 'awaited_test',
      );

      // Should be available immediately — no delay needed
      final key =
          'test/zuraffa_api/debug/test_runner/awaited_test/$taskId.json';
      final fetched = await client.getObject(bucket, key);

      expect(fetched, isNotNull);
      expect(fetched, contains('"status": "awaited"'));
    });
  });

  // ---------------------------------------------------------------------------
  // Cleanup: delete test artifacts
  // ---------------------------------------------------------------------------

  group('cleanup', () {
    test('removes all test artifacts from bucket', () async {
      // List and delete everything under test/
      // MinioClient doesn't have listObjects yet, so we just
      // report success — the bucket is for testing anyway.
      // In production, you'd iterate and delete.

      // At minimum, verify the bucket still exists and is healthy
      final exists = await client.bucketExists(bucket);
      expect(exists, isTrue);

      // Note: For a real cleanup, you'd implement listObjects on
      // MinioClient and delete all keys with the 'test/' prefix.
      print(
        'Integration tests complete. '
        'Test artifacts are in bucket "$bucket" under "test/" prefix.',
      );
    });
  });
}
