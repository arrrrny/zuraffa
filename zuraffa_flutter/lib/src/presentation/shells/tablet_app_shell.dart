import 'package:flutter/material.dart';

import 'app_shell.dart';

/// Split/navigation rail-friendly shell for tablet layouts.
class TabletAppShell extends AppShell {
  const TabletAppShell({
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
            SizedBox(width: 280, child: Material(child: navigation!)),
          Expanded(child: body),
        ],
      ),
    );
  }
}
