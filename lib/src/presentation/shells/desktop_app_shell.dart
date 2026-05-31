import 'package:flutter/material.dart';

import 'app_shell.dart';

/// Wide-screen shell with permanent side navigation support.
class DesktopAppShell extends AppShell {
  const DesktopAppShell({
    super.key,
    super.title,
    required super.body,
    super.navigation,
    super.floatingActionButton,
    super.appBar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(),
      floatingActionButton: floatingActionButton,
      body: Row(
        children: [
          if (navigation != null)
            SizedBox(width: 320, child: Material(child: navigation!)),
          Expanded(child: body),
        ],
      ),
    );
  }
}
