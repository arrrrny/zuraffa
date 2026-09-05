/// SkinContractKitBuilder — emits the Flutter glue of the runtime
/// skin-contract auditor into target projects (issue #1102).
///
/// The framework itself is pure Dart (Constitution VII: `lib/` never
/// imports Flutter), so the Flutter half of the kit — the element
/// walker, the auditor widget, the route observer, the banner
/// chrome, the typed anchor button, the VM-service driver seam — is
/// EMITTED into the target project as one self-contained file at
/// `<outputDir>/skin/skin_contract_auditor.dart`, exactly the way
/// the app shell and the XRay bridge launcher are emitted. The
/// emitted file imports the pure core (`TreeFacts`,
/// `SkinContractRow`, `RouteContractTable`, the bus, the scheduler,
/// the anchor registry) from `package:zuraffa/skin.dart`.
///
/// Emission is deterministic (same routes → same bytes) and wrapped
/// in GENERATED markers; generation sites (view `--skin`, app shell
/// `--skin-audit`, `zfa skin kit`) write it skip-if-exists so hand
/// edits survive — the #1005 hand-written-seam precedent.
library;

import 'package:dart_style/dart_style.dart';

/// Route names the emitted kit's contract table allows.
///
/// The table ALWAYS also conforms the navigator root `'/'` by
/// construction (pilot lesson 3 — WidgetsApp pushes it on every
/// cold start).
class SkinContractKitBuilder {
  const SkinContractKitBuilder();

  /// Emits the complete kit source.
  ///
  /// [routes] become the `kSkinRouteContract` table's allowed route
  /// names (the static manifest side of the route contract; the app
  /// shell builds its runtime table from `getAllRoutes()`).
  String build({List<String> routes = const []}) {
    final routesLiteral = routes.isEmpty
        ? 'const <String>{}'
        : 'const <String>{\n    ${routes.map((r) => "'$r'").join(',\n    ')},\n  }';
    final src = _template.replaceAll('__SKIN_ROUTES__', routesLiteral);
    return DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
    ).format(src);
  }

  /// The file name the kit lands under (relative to the output dir).
  static const String kitFileName = 'skin_contract_auditor.dart';

  /// The kit directory (relative to the output dir).
  static const String kitDir = 'skin';

  static const String _template = '''
// GENERATED - DO NOT EDIT — runtime skin-contract auditor (issue
// #1102, productized from the 006-login-skin pilot). The pure
// contract core lives in package:zuraffa/skin.dart; this file is the
// Flutter glue: the live-tree walker, the per-frame auditor widget,
// the route observer, the violation banner, the typed anchor button,
// and the debugTapAnchor VM-service driver seam.
//
// Debug-only: every mount point no-ops unless kDebugMode — zero
// release cost. Extend the per-view contract row lists (the
// k<ViewName>SkinRows seam) — this kit is regenerated, your rows are
// yours.

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:zuraffa/skin.dart';

/// The pure audit bus core: auditors and the route observer publish
/// here; the [SkinAuditBus] below bridges it into a Listenable for
/// the debug chrome.
final SkinAuditController skinAuditBusCore = SkinAuditController();

/// The bridge the debug chrome subscribes to (the pilot's
/// `skinAuditBus` name, kept).
final SkinAuditBus skinAuditBus = SkinAuditBus(skinAuditBusCore);

/// The typed-anchor registry backing [debugTapAnchor] (pilot
/// lesson 7: drive skins through the Dart VM service, never
/// synthetic clicks).
final ZfaAnchorRegistry zfaAnchorRegistry = ZfaAnchorRegistry();

/// The route contract table (issue #1102): every route this app's
/// skin contract declares. The navigator root '/'
/// (RouteContractTable.navigatorRootRoute) conforms by construction,
/// so cold start never flags a phantom violation (pilot lesson 3).
final RouteContractTable kSkinRouteContract =
    RouteContractTable.fromRouteNames(
  __SKIN_ROUTES__,
);

/// Walks the live element tree under [root] and collects exactly
/// what the contract rows need: rendered texts, `zfa:` anchor keys,
/// whether a progress indicator is on screen, and the platform the
/// THEME reports (pilot lesson 8: the same override-aware source
/// the layout gates on — auditor and skin can never disagree about
/// platform).
TreeFacts inspectTree(Element root) {
  final texts = <String>[];
  final anchors = <String>{};
  var hasProgressIndicator = false;

  void collect(Widget widget) {
    if (widget is Text) {
      final data = widget.data;
      if (data != null && data.isNotEmpty && !texts.contains(data)) {
        texts.add(data);
      }
    } else if (widget is RichText) {
      final span = widget.text;
      if (span is TextSpan) {
        final plain = span.toPlainText();
        if (plain.isNotEmpty && !texts.contains(plain)) {
          texts.add(plain);
        }
      }
    } else if (
        widget is CircularProgressIndicator ||
        widget is LinearProgressIndicator ||
        widget is CupertinoActivityIndicator ||
        widget is RefreshIndicator) {
      hasProgressIndicator = true;
    }
    final key = widget.key;
    if (key is ValueKey && key.value is String) {
      final value = key.value as String;
      if (value.startsWith('zfa:')) {
        anchors.add(value);
      }
    }
  }

  void visit(Element element) {
    collect(element.widget);
    element.visitChildElements(visit);
  }

  visit(root);

  return TreeFacts(
    texts: texts,
    anchors: anchors,
    hasProgressIndicator: hasProgressIndicator,
    platform: _platformOf(root),
  );
}

SkinTargetPlatform? _platformOf(Element element) {
  try {
    final target = Theme.of(element).platform;
    return switch (target) {
      TargetPlatform.iOS => SkinTargetPlatform.ios,
      TargetPlatform.android => SkinTargetPlatform.android,
      TargetPlatform.macOS => SkinTargetPlatform.macos,
      _ => SkinTargetPlatform.other,
    };
  } catch (_) {
    // No Theme ancestor: facts carry no platform — rows gated to a
    // platform SKIP instead of flagging (never a phantom violation).
    return null;
  }
}

/// Publishes the widget-audit half, preserving any live route
/// breaches (the bus carries the union; the banner shows both).
void _publishWidgetViolations(List<SkinViolation> violations) {
  final routeViolations = skinAuditBusCore.violations
      .where((v) => v.kind == SkinViolationKind.route)
      .toList();
  skinAuditBusCore.publish([...violations, ...routeViolations]);
}

/// The per-view auditor: wraps the view at the `Widget get view`
/// seam (pilot lesson 2: the overridable skin seam is the view
/// getter, NOT build — CleanViewState.build is @nonVirtual).
///
/// Subscribe-don't-poll (pilot lesson 5): the auditor NEVER
/// self-reschedules. Real signals (dependency changes, row updates)
/// mark the scheduler dirty and ask for ONE post-frame audit; a
/// quiet tree runs zero audits and `pumpAndSettle` settles.
class SkinContractAuditor extends StatefulWidget {
  const SkinContractAuditor({
    super.key,
    required this.rows,
    required this.child,
    this.listenable,
  });

  /// The contract this view must satisfy, every audited frame.
  final List<SkinContractRow> rows;

  /// The view being audited.
  final Widget child;

  /// Optional rebuild signal (subscribe-don't-poll, pilot lesson 5):
  /// the Listenable whose notifications drive this view's rebuilds
  /// (the controller's state notifier in a Clean view). The auditor
  /// re-audits when it notifies — never on a timer.
  final Listenable? listenable;

  @override
  State<SkinContractAuditor> createState() => _SkinContractAuditorState();
}

class _SkinContractAuditorState extends State<SkinContractAuditor> {
  final SkinAuditScheduler _scheduler = SkinAuditScheduler();

  @override
  void initState() {
    super.initState();
    widget.listenable?.addListener(_onListenableNotified);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!kDebugMode) return;
    _scheduler.markDirty('view-dependency-changed');
    _scheduleAudit();
  }

  @override
  void didUpdateWidget(SkinContractAuditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listenable != widget.listenable) {
      oldWidget.listenable?.removeListener(_onListenableNotified);
      widget.listenable?.addListener(_onListenableNotified);
    }
    if (!kDebugMode) return;
    if (oldWidget.rows != widget.rows) {
      _scheduler.markDirty('rows-updated');
    }
    _scheduleAudit();
  }

  /// The pilot's chaos-edit channel: hot reload calls reassemble on
  /// every mounted State — edit the skin, hit reload, the banner
  /// answers on the next audited frame (and reverts clear it).
  @override
  void reassemble() {
    super.reassemble();
    if (!kDebugMode) return;
    _scheduler.markDirty('hot-reload-reassemble');
    _scheduleAudit();
  }

  void _onListenableNotified() {
    if (!kDebugMode) return;
    _scheduler.markDirty('listenable-notified');
    _scheduleAudit();
  }

  @override
  void dispose() {
    widget.listenable?.removeListener(_onListenableNotified);
    super.dispose();
  }

  void _scheduleAudit() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _audit());
  }

  void _audit() {
    if (!kDebugMode) return;
    // Quiet tree: nothing consumed the dirty mark — do NOT audit and
    // do NOT reschedule (the pilot's polling auditor could never let
    // pumpAndSettle settle; this one can).
    if (!_scheduler.consumeDirty()) return;
    if (!mounted) return;
    // State.context is always the StatefulElement (Flutter's own
    // State.context contract), so the walk can start from it.
    if (context is! Element) return;
    final facts = inspectTree(context as Element);
    final violations = <SkinViolation>[];
    for (final row in widget.rows) {
      if (!row.evaluate(facts)) {
        violations.add(
          SkinViolation.widget(
            rowId: row.id,
            requirement: row.requirement,
            message: 'row failed for facts \${facts.toJson()}',
          ),
        );
      }
    }
    _publishWidgetViolations(violations);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The route half of the runtime contract: validates EVERY push
/// against the [table] (or [allowedRouteNames], or the emitted
/// [kSkinRouteContract]). The pilot drove a real guest sign-in and
/// validated the deal_list push this way.
///
/// The navigator root '/' and unnamed helper routes conform by
/// construction (pilot lesson 3).
class SkinRouteContractObserver extends NavigatorObserver {
  SkinRouteContractObserver({
    RouteContractTable? table,
    Set<String>? allowedRouteNames,
    this.onViolation,
  }) : table = table ??
           (allowedRouteNames != null
               ? RouteContractTable.fromRouteNames(allowedRouteNames)
               : kSkinRouteContract);

  /// The route contract this observer enforces.
  final RouteContractTable table;

  /// Optional violation tap (the pilot's driver wired its receipts
  /// here).
  final void Function(SkinViolation violation)? onViolation;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _validate(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _validate(newRoute);
  }

  void _validate(Route<dynamic>? route) {
    if (!kDebugMode || route == null) return;
    final violation = table.validatePush(route.settings.name);
    if (violation == null) return;
    onViolation?.call(violation);
    final violations = skinAuditBusCore.violations;
    if (violations.contains(violation)) return;
    skinAuditBusCore.publish([...violations, violation]);
  }
}

/// The bridge that makes the pure bus core a Listenable the debug
/// chrome can watch.
class SkinAuditBus extends ValueNotifier<List<SkinViolation>> {
  SkinAuditBus(this._core) : super(const []) {
    _core.addListener(_sync);
  }

  final SkinAuditController _core;

  void _sync() {
    value = _core.violations;
  }

  @override
  void dispose() {
    _core.removeListener(_sync);
    super.dispose();
  }
}

/// The debug chrome: mounts the [SkinViolationBanner] above the app
/// whenever live violations exist. Wire it through
/// `MaterialApp.router(builder:)`. Inert in release builds.
class SkinAuditChrome extends StatelessWidget {
  const SkinAuditChrome({super.key, required this.child});

  /// The app content (the router's navigator).
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return child;
    return ValueListenableBuilder<List<SkinViolation>>(
      valueListenable: skinAuditBus,
      builder: (context, violations, _) {
        if (violations.isEmpty) return child;
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SkinViolationBanner(violations: violations),
            ),
          ],
        );
      },
    );
  }
}

/// The impossible-to-miss banner: deep red, full-width, pinned top,
/// one line per live violation — the pilot's chaos-edit receipt
/// shape (`[google-text] Continue with Google renders`).
class SkinViolationBanner extends StatelessWidget {
  const SkinViolationBanner({super.key, required this.violations});

  final List<SkinViolation> violations;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.red.shade900,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'SKIN CONTRACT VIOLATIONS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
              for (final violation in violations)
                Text(
                  violation.toDisplayLine(),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The typed anchor button (issue #1099's protocol proof): carries
/// `ValueKey('zfa:\$contractId')`, registers its REAL onPressed
/// into the anchor registry while mounted, and disables cleanly
/// through [contractEnabled].
///
/// Drive it through the VM service: `debugTapAnchor('zfa:<id>')` —
/// the presenter → certified-mock → push flow runs for real, on
/// every platform (pilot lesson 7).
class ZfaButton extends StatefulWidget {
  const ZfaButton({
    super.key,
    required this.contractId,
    required this.onPressed,
    required this.child,
    this.contractEnabled = true,
  });

  /// The anchor's contract id — the `zfa:` key and registry handle.
  final String contractId;

  /// Whether the anchor is enabled (a disabled anchor refuses taps
  /// but stays discoverable in the tree).
  final bool contractEnabled;

  /// The real presenter callback the driver invokes.
  final VoidCallback? onPressed;

  final Widget child;

  @override
  State<ZfaButton> createState() => _ZfaButtonState();
}

class _ZfaButtonState extends State<ZfaButton> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _register();
  }

  @override
  void didUpdateWidget(ZfaButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onPressed != widget.onPressed ||
        oldWidget.contractEnabled != widget.contractEnabled) {
      _register();
    }
  }

  void _register() {
    if (!kDebugMode) return;
    zfaAnchorRegistry.register(widget.contractId, _invoke);
  }

  void _invoke() {
    final onPressed = widget.onPressed;
    if (onPressed == null || !widget.contractEnabled) return;
    onPressed();
  }

  @override
  void dispose() {
    if (kDebugMode) {
      zfaAnchorRegistry.unregister(widget.contractId);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: ValueKey('zfa:\${widget.contractId}'),
      child: FilledButton(
        onPressed: widget.contractEnabled ? widget.onPressed : null,
        child: widget.child,
      ),
    );
  }
}

/// The VM-service driver seam (pilot lesson 7): invokes the REAL
/// onPressed registered under [zfaKey] (accepts both
/// 'zfa:signin-guest' and 'signin-guest'). Returns whether the
/// anchor was found and tapped — an unknown anchor refuses
/// honestly, so a driver harness can never silently no-op.
Future<bool> debugTapAnchor(String zfaKey) async {
  if (!kDebugMode) return false;
  return zfaAnchorRegistry.tap(zfaKey);
}

// END GENERATED
''';
}
