import 'package:flutter/material.dart';

/// Shared base shell for generated adaptive page layouts.
abstract class AppShell extends StatelessWidget {
  final String? title;
  final Widget body;
  final Widget? navigation;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? appBar;

  const AppShell({
    super.key,
    this.title,
    required this.body,
    this.navigation,
    this.floatingActionButton,
    this.appBar,
  });

  @protected
  PreferredSizeWidget? buildAppBar() {
    if (appBar != null) {
      return appBar;
    }
    if (title == null || title!.isEmpty) {
      return null;
    }
    return AppBar(title: Text(title!));
  }
}
