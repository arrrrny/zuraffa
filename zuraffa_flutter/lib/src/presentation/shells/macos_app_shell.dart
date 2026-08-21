import 'package:flutter/material.dart';

import 'desktop_app_shell.dart';

/// Desktop shell tuned for macOS-style windowed layouts.
class MacosAppShell extends DesktopAppShell {
  const MacosAppShell({
    super.key,
    super.title,
    required super.body,
    super.navigation,
    super.floatingActionButton,
    super.appBar,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: super.build(context));
  }
}
