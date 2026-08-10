import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'features/grocery_scan/grocery_scan_page.dart';
import 'providers/mock_grocery_provider.dart';
import 'providers/mock_grocery_scope.dart';
import 'theme/app_theme.dart';

/// Root of the standalone ZikZak "Grocery Price Match" mock app.
///
/// This is a self-contained UI/UX deliverable: everything is mocked through
/// [MockGroceryProvider], so an external agent can iterate on the camera
/// experience without any backend, camera or ML wiring.
class GroceryScanApp extends StatefulWidget {
  const GroceryScanApp({super.key, this.provider});

  /// Injectable for tests / previews; a fresh [MockGroceryProvider] is used
  /// when omitted.
  final MockGroceryProvider? provider;

  @override
  State<GroceryScanApp> createState() => _GroceryScanAppState();
}

class _GroceryScanAppState extends State<GroceryScanApp> {
  late final MockGroceryProvider _provider =
      widget.provider ?? MockGroceryProvider();

  @override
  void dispose() {
    if (widget.provider == null) _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShadTheme(
      data: AppTheme.darkCameraTheme,
      child: MockGroceryScope(
        provider: _provider,
        child: MaterialApp(
          title: 'ZikZak Grocery Price Match',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.materialTheme,
          // Toaster must sit under MaterialApp (needs Directionality) so
          // toasts float above the whole app.
          builder: (context, child) => ShadToaster(child: child!),
          home: const GroceryScanPage(),
        ),
      ),
    );
  }
}
