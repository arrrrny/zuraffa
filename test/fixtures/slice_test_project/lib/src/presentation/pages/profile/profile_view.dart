/// ProfileView (fixture for spec 043) — imports the shared widget barrel
/// WITHOUT a `show` clause and references PrimaryButton + AppCard, so barrel
/// resolution pulls exactly those two files (U14).
library;

import 'package:flutter/material.dart';

import '../../widgets/index.dart';
import 'profile_controller.dart';
import 'profile_state.dart';

/// The profile page.
class ProfileView extends StatelessWidget {
  /// Creates the view.
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ProfileController();
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: AppCard(
          child: PrimaryButton(
            label: 'Refresh',
            onPressed: () => controller.load(),
          ),
        ),
      ),
    );
  }
}
