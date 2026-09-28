// Issue #1727 — zuraffa.com must showcase apps built with Zuraffa and link
// ZikZak (the sponsor at zuzu.dev) from that showcase. The landing page is a
// single static file (website/static/index.html) deployed to GitHub Pages, so
// this pin reads it directly and fails if the showcase or the ZikZak link
// disappears.

import 'dart:io';

import 'package:test/test.dart';

void main() {
  final landing = File('website/static/index.html');

  test('the landing page exists', () {
    expect(
      landing.existsSync(),
      isTrue,
      reason: 'website/static/index.html is the zuraffa.com landing page',
    );
  });

  test('the landing page has a Built with Zuraffa showcase', () {
    final source = landing.readAsStringSync();
    expect(
      source,
      contains('id="built-with"'),
      reason:
          'the showcase section anchors the page for the nav and deep links',
    );
    final showcase = source.indexOf('id="built-with"');
    final afterShowcase = source.indexOf('</section>', showcase);
    final sectionHtml = source.substring(
      showcase,
      afterShowcase == -1 ? source.length : afterShowcase,
    );
    final visibleSectionHtml = sectionHtml.replaceAll(
      RegExp(r'<!--.*?-->', dotAll: true),
      '',
    );
    expect(
      RegExp(
        r'<h2\b[^>]*>\s*Built with\s*<br\s*/?>\s*'
        r'<span\b[^>]*>\s*Zuraffa\s*</span>\s*</h2>',
        dotAll: true,
      ).hasMatch(visibleSectionHtml),
      isTrue,
      reason: 'the showcase heading names the section',
    );
  });

  test('the showcase links ZikZak', () {
    final source = landing.readAsStringSync();
    final showcase = source.indexOf('id="built-with"');
    expect(showcase, greaterThanOrEqualTo(0));
    final afterShowcase = source.indexOf('</section>', showcase);
    final sectionHtml = source.substring(
      showcase,
      afterShowcase == -1 ? source.length : afterShowcase,
    );
    expect(
      sectionHtml,
      contains('https://zuzu.dev'),
      reason: 'ZikZak (zuzu.dev) is built with Zuraffa and must be linked',
    );
    expect(
      sectionHtml,
      contains('ZikZak'),
      reason: 'the showcase names ZikZak',
    );
  });
}
