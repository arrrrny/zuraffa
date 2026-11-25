import 'zfa_signal.dart';

/// A state signal holding a state [S] with helper updates.
class ZfaStateSignal<S> extends ZfaSignal<S> {
  ZfaStateSignal(super.initialValue, {super.owner, super.equals});
}
