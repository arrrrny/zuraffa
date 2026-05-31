import 'package:flutter/material.dart';

import 'app_shell.dart';

/// Compact shell for watch/phone-first experiences.
class MobileAppShell extends AppShell {
  const MobileAppShell({
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
      body: body,
      bottomNavigationBar: navigation,
      floatingActionButton: floatingActionButton,
    );
  }
}
