/// LoginView — the first hand-written skin under the issue #1005 seam.
///
/// _XRaySkinHandEdit(behavior: "W1",
///   file: "lib/src/presentation/pages/login/login_view.dart",
///   logged_at: "2026-09-05T04:35:00Z")
///
/// The adaptive login view: the platform slots declared by the
/// spec's SKIN lane `adaptive_slots` contract (issue #1000) are the
/// branches this view fills — `mobile` (phone-width layout),
/// `ios` (home-indicator safe area), `android` (surface-tone layout),
/// and `macos` (title bar with trailing alignment). Every slot branch
/// reports itself through a SkinEvent (issue #1005) so the run-skin
/// cycle can verify the declared contract from the live stream, never
/// from source string matching.
///
/// The view-builder [loginView] below is the skin contract the paired
/// widget test boots — the hand-edit keeps it, exactly as the generated
/// stub declared it.
library;

import 'package:flutter/material.dart';

/// The declared adaptive platform slots this view fills (the spec's
/// SKIN lane contract).
const List<String> kLoginPlatformSlots = ['mobile', 'ios', 'android', 'macos'];

/// The behavior id this skin implements (the receipt's hand-edit key).
const String kLoginSkinBehavior = 'W1';

/// Emits one SkinEvent line (issue #1005): the machine-greppable trace
/// the `zfa tdd run-skin` cycle digests into the skin receipt. Debug
/// builds only — the trace matters while the tests run, never in
/// release.
void emitSkinEvent(String slot) {
  assert(() {
    debugPrint('skin-event: behavior=$kLoginSkinBehavior slot=$slot');
    return true;
  }());
}

/// The view-builder contract the paired widget test boots.
Widget loginView() => const LoginView();

/// The adaptive login view (AdaptiveViewState shape: platform-aware
/// slot resolution in build, one branch per declared slot).
class LoginView extends StatefulWidget {
  /// Creates the login view.
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  /// Resolves the platform slot for the current build: a phone-width
  /// surface is the `mobile` slot on every platform; wider surfaces
  /// branch on the host platform (`ios` / `android` / `macos`).
  String _resolveSlot(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 600) return 'mobile';
    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.macOS:
        return 'macos';
      default:
        return 'mobile';
    }
  }

  @override
  Widget build(BuildContext context) {
    final slot = _resolveSlot(context);
    emitSkinEvent(slot);
    return Scaffold(
      backgroundColor: _paneColor(context, slot),
      body: switch (slot) {
        'ios' => const _SafeAreaLoginPane(slotKey: Key('login-slot-ios')),
        'android' => const _WideLoginPane(slotKey: Key('login-slot-android')),
        'macos' => const _TrailingTitleLoginPane(
          slotKey: Key('login-slot-macos'),
        ),
        _ => const _MobileLoginPane(slotKey: Key('login-slot-mobile')),
      },
    );
  }

  Color _paneColor(BuildContext context, String slot) {
    final scheme = Theme.of(context).colorScheme;
    return switch (slot) {
      'android' => scheme.surfaceContainerLow,
      'macos' => scheme.surfaceContainerLowest,
      _ => scheme.surface,
    };
  }
}

/// The `mobile` slot: a phone-width centered card with a full-width
/// layout.
class _MobileLoginPane extends StatelessWidget {
  const _MobileLoginPane({required this.slotKey});

  final Key slotKey;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _LoginCard(
          slotKey: slotKey,
          headingAlignment: MainAxisAlignment.start,
          maxWidth: 420,
        ),
      ),
    );
  }
}

/// The `ios` slot: the #1004 platform override — the home-indicator
/// safe area is REQUIRED, so the pane wraps its content in a bottom
/// `SafeArea`.
class _SafeAreaLoginPane extends StatelessWidget {
  const _SafeAreaLoginPane({required this.slotKey});

  final Key slotKey;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // The home-indicator contract: bottom padding is mandatory.
      bottom: true,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _LoginCard(
            slotKey: slotKey,
            headingAlignment: MainAxisAlignment.start,
            maxWidth: 420,
          ),
        ),
      ),
    );
  }
}

/// The `android` slot: the credential card on a wide surface-tone
/// pane.
class _WideLoginPane extends StatelessWidget {
  const _WideLoginPane({required this.slotKey});

  final Key slotKey;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _LoginCard(
          slotKey: slotKey,
          headingAlignment: MainAxisAlignment.start,
          maxWidth: 480,
        ),
      ),
    );
  }
}

/// The `macos` slot: the #1004 platform override — the title bar
/// alignment is TRAILING, so the heading row aligns to the trailing
/// edge of the wide window.
class _TrailingTitleLoginPane extends StatelessWidget {
  const _TrailingTitleLoginPane({required this.slotKey});

  final Key slotKey;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _LoginCard(
          slotKey: slotKey,
          headingAlignment: MainAxisAlignment.end,
          maxWidth: 520,
        ),
      ),
    );
  }
}

/// The credential card every slot composes — carries the [slotKey] so
/// the paired test asserts the resolved branch, plus the heading row
/// (its alignment is the macos title-bar contract) and the shared
/// credential form.
class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.slotKey,
    required this.headingAlignment,
    required this.maxWidth,
  });

  /// The slot-identifying key (`login-slot-<slot>`).
  final Key slotKey;

  /// The heading row's alignment (trailing on the macos slot).
  final MainAxisAlignment headingAlignment;

  /// The card's max width per slot.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Card(
        key: slotKey,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: headingAlignment,
                children: [
                  Text(
                    'Sign in',
                    key: const Key('login-heading'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const _LoginForm(),
            ],
          ),
        ),
      ),
    );
  }
}

/// The shared credential form + submit affordance.
class _LoginForm extends StatefulWidget {
  const _LoginForm();

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const Key('login-email'),
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('login-password'),
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('login-submit'),
            onPressed: () {
              if (_formKey.currentState?.validate() ?? false) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Session started')),
                );
              }
            },
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
  }
}
