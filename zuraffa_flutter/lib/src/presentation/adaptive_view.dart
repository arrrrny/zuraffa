import 'package:flutter/material.dart';

import 'controller.dart';
import 'platform/device_class.dart';
import 'platform/platform_context.dart';
import 'platform/platform_layout_resolver.dart';
import 'view.dart';

/// An adaptive variant of [CleanViewState] that incorporates platform and
/// device awareness in addition to screen-size breakpoints.
///
/// Unlike [ResponsiveViewState] which only considers screen width, this view
/// uses [PlatformContext] to resolve layouts with the fallback order:
///
/// 1. **compound** (e.g. `macos_desktop`)
/// 2. **platform** (e.g. `macos`)
/// 3. **device** (e.g. `desktop`)
/// 4. **generic/default**
///
/// ## Usage
///
/// Override the layout builder for the keys you care about:
///
/// ```dart
/// class _MyPageState extends AdaptiveViewState<MyPage, MyController, void> {
///   _MyPageState() : super(MyController());
///
///   @override
///   Map<String, WidgetBuilder> get layouts => {
///     'mobile': (ctx) => MobileLayout(),
///     'desktop': (ctx) => DesktopLayout(),
///   };
/// }
/// ```
///
/// Layouts not provided will fall back through the candidate key chain.
abstract class AdaptiveViewState<P extends CleanView, Con extends Controller, S>
    extends CleanViewState<P, Con, S> {
  AdaptiveViewState(super.controller);

  /// Map of layout-key → widget builder.
  ///
  /// Keys should use canonical names like `mobile`, `tablet`, `desktop`,
  /// `macos`, `macos_desktop`, `ios_mobile`, etc.
  ///
  /// The [PlatformLayoutResolver] will pick the best match via the fallback
  /// chain, so you only need to specify the layouts you want to differentiate.
  Map<String, WidgetBuilder> get layouts;

  /// Override to supply a custom [PlatformContext] instead of the detected one.
  ///
  /// Useful for testing or forcing a specific layout at runtime.
  PlatformContext? get overridePlatformContext => null;

  /// The generic key used as the final fallback. Defaults to `'default'`.
  String get genericKey => 'default';

  /// Extra fallback keys to inject before [genericKey].
  Iterable<String> get extraFallbackKeys => const <String>[];

  PlatformContext get _platformContext {
    if (overridePlatformContext != null) {
      return overridePlatformContext!;
    }
    return PlatformContext.current(
      deviceClass: DeviceClass.fromWidth(MediaQuery.sizeOf(context).width),
    );
  }

  @override
  Widget get view {
    return LayoutBuilder(
      builder: (context, _) {
        final ctx = _platformContext;
        final resolved = PlatformLayoutResolver<WidgetBuilder>().resolve(
          layouts,
          ctx,
          extraFallbackKeys: extraFallbackKeys,
        );

        if (resolved != null) {
          return resolved(context);
        }

        // If no layout matched, try to use the first available as a last resort
        if (layouts.isNotEmpty) {
          return layouts.values.first(context);
        }

        return const SizedBox.shrink();
      },
    );
  }
}
