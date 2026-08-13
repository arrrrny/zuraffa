// Regression tests for issue #299.
//
// `CommonPatterns.findUseCaseDomain` had a prefix-based fallback that ran:
//
//   usecaseSnake.replaceFirst(prefix, '').replaceFirst('_list', '');
//
// The second `replaceFirst('_list', '')` strips `_list` as a SUBSTRING,
// not as a suffix. For entity names whose snake form contains `_list`
// mid-name (e.g. `url_listing`, `text_listing`, `barcode_listing`), it
// silently corrupts the derived domain:
//
//   get_url_listing    -> url_listing    -> urling    (BUG)
//   get_text_listing   -> text_listing   -> texting   (BUG)
//   get_barcode_listing -> barcode_listing -> barcoding (BUG)
//
// The fix only strips `_list` when it is a TRAILING suffix (genuine
// list-style usecases like `get_product_list` -> `product`).
//
// These tests exercise the prefix-stripping fallback in isolation by
// pointing `findUseCaseDomain` at an empty/non-existent output dir with no
// discovery engine, which forces it to skip active discovery and the
// directory scan and fall straight into the prefix-stripping branch.

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  late Directory emptyOutputDir;

  setUp(() async {
    // A unique temp dir that definitely has no `domain/usecases/` folder,
    // so the filesystem-scan branch is skipped and we land in the
    // prefix-stripping fallback — the exact branch that contained the bug.
    // A hardcoded `/tmp` path could collide with a stale directory left by
    // an earlier run and is not portable to Windows.
    emptyOutputDir =
        await Directory.systemTemp.createTemp('zuraffa_issue_299_');
  });

  tearDown(() async {
    if (await emptyOutputDir.exists()) {
      await emptyOutputDir.delete(recursive: true);
    }
  });

  group('#299 findUseCaseDomain — _list substring stripping', () {
    group('entities whose snake name CONTAINS `_list` mid-name', () {
      // These are the exact entities called out in the issue.
      test('get_url_listing -> url_listing (NOT urling)', () async {
        final domain = await CommonPatterns.findUseCaseDomain(
          'get_url_listing',
          'fallback',
          emptyOutputDir.path,
        );
        expect(domain, 'url_listing');
      });

      test('get_text_listing -> text_listing (NOT texting)', () async {
        final domain = await CommonPatterns.findUseCaseDomain(
          'get_text_listing',
          'fallback',
          emptyOutputDir.path,
        );
        expect(domain, 'text_listing');
      });

      test('get_barcode_listing -> barcode_listing (NOT barcoding)',
          () async {
        final domain = await CommonPatterns.findUseCaseDomain(
          'get_barcode_listing',
          'fallback',
          emptyOutputDir.path,
        );
        expect(domain, 'barcode_listing');
      });

      test('update_url_listing -> url_listing (NOT urling)', () async {
        final domain = await CommonPatterns.findUseCaseDomain(
          'update_url_listing',
          'fallback',
          emptyOutputDir.path,
        );
        expect(domain, 'url_listing');
      });

      test('create_text_listing -> text_listing (NOT texting)', () async {
        final domain = await CommonPatterns.findUseCaseDomain(
          'create_text_listing',
          'fallback',
          emptyOutputDir.path,
        );
        expect(domain, 'text_listing');
      });

      test('delete_barcode_listing -> barcode_listing (NOT barcoding)',
          () async {
        final domain = await CommonPatterns.findUseCaseDomain(
          'delete_barcode_listing',
          'fallback',
          emptyOutputDir.path,
        );
        expect(domain, 'barcode_listing');
      });

      test('watch_url_listing -> url_listing (NOT urling)', () async {
        final domain = await CommonPatterns.findUseCaseDomain(
          'watch_url_listing',
          'fallback',
          emptyOutputDir.path,
        );
        expect(domain, 'url_listing');
      });
    });

    group('genuine list-style usecases still strip the trailing _list', () {
      // These MUST continue to strip the trailing `_list` suffix.
      test('get_product_list -> product', () async {
        final domain = await CommonPatterns.findUseCaseDomain(
          'get_product_list',
          'fallback',
          emptyOutputDir.path,
        );
        expect(domain, 'product');
      });

      test('watch_order_list -> order', () async {
        final domain = await CommonPatterns.findUseCaseDomain(
          'watch_order_list',
          'fallback',
          emptyOutputDir.path,
        );
        expect(domain, 'order');
      });

      test('create_cart_list -> cart', () async {
        final domain = await CommonPatterns.findUseCaseDomain(
          'create_cart_list',
          'fallback',
          emptyOutputDir.path,
        );
        expect(domain, 'cart');
      });
    });

    group('plain entity usecases (no _list at all) are unaffected', () {
      test('get_user -> user', () async {
        final domain = await CommonPatterns.findUseCaseDomain(
          'get_user',
          'fallback',
          emptyOutputDir.path,
        );
        expect(domain, 'user');
      });

      test('update_store -> store', () async {
        final domain = await CommonPatterns.findUseCaseDomain(
          'update_store',
          'fallback',
          emptyOutputDir.path,
        );
        expect(domain, 'store');
      });
    });

    group('unknown prefix falls back to default domain', () {
      test('toggle_url_listing -> default domain (toggle not in prefixes)',
          () async {
        // `toggle_*` is intentionally not in the prefix list — it should
        // fall through to the default domain. (Real `toggle_*` resolution
        // happens via active discovery, which is bypassed here.)
        final domain = await CommonPatterns.findUseCaseDomain(
          'toggle_url_listing',
          'fallback_domain',
          emptyOutputDir.path,
        );
        expect(domain, 'fallback_domain');
      });
    });
  });
}
