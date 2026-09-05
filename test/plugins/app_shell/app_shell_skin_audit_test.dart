// Issue #1102 — the app-shell mount: --skin-audit wires the route
// observer onto the GoRouter and the violation-banner chrome into
// MaterialApp.router (the "ZuraffaApp" mount point of the issue).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/app_shell/builders/app_shell_builder.dart';

void main() {
  group('issue #1102 — AppShellBuilder skin-audit mount', () {
    const builder = AppShellBuilder();

    group('buildMyApp(skinAudit: true)', () {
      test('wraps the router in SkinAuditChrome via MaterialApp builder', () {
        final src = builder.buildMyApp(skinAudit: true);
        expect(src, contains('builder:'));
        expect(src, contains('SkinAuditChrome'));
      });

      test('imports the emitted skin kit', () {
        final src = builder.buildMyApp(skinAudit: true);
        expect(src, contains('skin/skin_contract_auditor.dart'));
      });

      test('xray + skinAudit compose (both wraps survive)', () {
        final src = builder.buildMyApp(xray: true, skinAudit: true);
        expect(src, contains('XRayScope'));
        expect(src, contains('SkinAuditChrome'));
      });

      test('without the flag: NO chrome, NO kit import (byte-compat)', () {
        final src = builder.buildMyApp();
        expect(src, isNot(contains('SkinAuditChrome')));
        expect(src, isNot(contains('skin/skin_contract_auditor.dart')));
      });
    });

    group('buildAppRouter(skinAudit: true)', () {
      test('mounts the SkinRouteContractObserver on the GoRouter', () {
        final src = builder.buildAppRouter(skinAudit: true);
        expect(src, contains('observers:'));
        expect(src, contains('SkinRouteContractObserver'));
      });

      test('the observer table is built from getAllRoutes() + root', () {
        final src = builder.buildAppRouter(skinAudit: true);
        // Lesson 3: the navigator root conforms by construction.
        expect(src, contains('navigatorRootRoute'));
        // Declared = conforming: the table reads the live route list.
        expect(src, contains('getAllRoutes()'));
        expect(src, contains('RouteContractTable'));
      });

      test('imports the emitted skin kit', () {
        final src = builder.buildAppRouter(skinAudit: true);
        expect(src, contains('skin/skin_contract_auditor.dart'));
      });

      test('without the flag: bare GoRouter, byte-compat', () {
        final src = builder.buildAppRouter();
        expect(src, isNot(contains('observers:')));
        expect(src, isNot(contains('SkinRouteContractObserver')));
      });
    });
  });
}
