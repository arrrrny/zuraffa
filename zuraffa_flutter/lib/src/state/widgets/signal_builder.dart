import 'package:flutter/widgets.dart';
import 'package:zuraffa/zuraffa.dart';

/// A widget that rebuilds when a pure UI [Signal<T>] changes.
///
/// Use this for non-domain state like `isEditMode`, `activeTabIndex`,
/// or `scrollOffset` — signals that live in [ViewState].
///
/// ```dart
/// SignalBuilder<bool>(
///   signal: presenter.view.isEditMode,
///   builder: (context, isEditMode) => isEditMode
///       ? EditModeToolbar()
///       : ViewModeToolbar(),
/// )
/// ```
class SignalBuilder<T> extends StatefulWidget {
  const SignalBuilder({super.key, required this.signal, required this.builder});

  final Signal<T> signal;
  final Widget Function(BuildContext context, T value) builder;

  @override
  State<SignalBuilder<T>> createState() => _SignalBuilderState<T>();
}

class _SignalBuilderState<T> extends State<SignalBuilder<T>> {
  late T _value;
  SignalSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _value = widget.signal.value;
    // Subscribe eagerly — a `late final` initializer would only run on the
    // first read (in dispose), so updates would never rebuild the widget.
    _subscription = widget.signal.listen((value) {
      if (!mounted) return;
      setState(() => _value = value);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _value);
  }
}
