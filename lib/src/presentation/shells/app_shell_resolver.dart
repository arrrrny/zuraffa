import 'package:flutter/material.dart';

import '../platform/device_class.dart';
import '../platform/platform_class.dart';
import '../platform/platform_context.dart';
import '../platform/platform_layout_resolver.dart';
import 'desktop_app_shell.dart';
import 'macos_app_shell.dart';
import 'mobile_app_shell.dart';
import 'tablet_app_shell.dart';

/// Resolves a concrete shell implementation using the same adaptive fallback
/// policy as page layouts.
class AppShellResolver {
  const AppShellResolver._();

  static Widget resolve({
    Key? key,
    required PlatformContext platformContext,
    String? title,
    required Widget body,
    Widget? navigation,
    Widget? floatingActionButton,
    PreferredSizeWidget? appBar,
  }) {
    final resolver = PlatformLayoutResolver<Widget Function()>();
    final builder = resolver.resolve(<String, Widget Function()>{
      PlatformClass.macos.layoutKey: () => MacosAppShell(
        key: key,
        title: title,
        body: body,
        navigation: navigation,
        floatingActionButton: floatingActionButton,
        appBar: appBar,
      ),
      DeviceClass.desktop.layoutKey: () => DesktopAppShell(
        key: key,
        title: title,
        body: body,
        navigation: navigation,
        floatingActionButton: floatingActionButton,
        appBar: appBar,
      ),
      DeviceClass.tablet.layoutKey: () => TabletAppShell(
        key: key,
        title: title,
        body: body,
        navigation: navigation,
        floatingActionButton: floatingActionButton,
        appBar: appBar,
      ),
      DeviceClass.watch.layoutKey: () => MobileAppShell(
        key: key,
        title: title,
        body: body,
        navigation: navigation,
        floatingActionButton: floatingActionButton,
        appBar: appBar,
      ),
      DeviceClass.phone.layoutKey: () => MobileAppShell(
        key: key,
        title: title,
        body: body,
        navigation: navigation,
        floatingActionButton: floatingActionButton,
        appBar: appBar,
      ),
      'default': () => MobileAppShell(
        key: key,
        title: title,
        body: body,
        navigation: navigation,
        floatingActionButton: floatingActionButton,
        appBar: appBar,
      ),
    }, platformContext);

    return builder != null ? builder() : body;
  }
}
