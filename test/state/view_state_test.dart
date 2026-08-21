import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('ViewState', () {
    test('holds Signal<T> fields for transient UI state', () {
      final view = _TestViewState();
      expect(view.isDropdownOpen, isA<Signal<bool>>());
      expect(view.activeTabIndex, isA<Signal<int>>());
    });

    test('signals have correct initial values', () {
      final view = _TestViewState();
      expect(view.isDropdownOpen.value, false);
      expect(view.activeTabIndex.value, 0);
      expect(view.scrollOffset.value, 0.0);
    });

    test('signals can be updated independently', () {
      final view = _TestViewState();
      view.isDropdownOpen.value = true;
      view.activeTabIndex.value = 2;

      expect(view.isDropdownOpen.value, true);
      expect(view.activeTabIndex.value, 2);
    });

    test('dispose cleans up all registered signals', () {
      final view = _TestViewState();
      view.dispose();
      expect(view.isActive, false);
      expect(() => view.isDropdownOpen.value, throwsStateError);
    });

    test('registerSignal tracks signals for disposal', () {
      final view = _EmptyViewState();
      final signal = Signal<String>('test');
      view.registerSignal(signal);
      expect(view.isActive, true);

      view.dispose();
      expect(signal.isDisposed, true);
    });
  });
}

class _TestViewState extends ViewState {
  _TestViewState() : super() {
    registerSignal(isDropdownOpen);
    registerSignal(activeTabIndex);
    registerSignal(scrollOffset);
  }

  final isDropdownOpen = Signal<bool>(false);
  final activeTabIndex = Signal<int>(0);
  final scrollOffset = Signal<double>(0.0);
}

class _EmptyViewState extends ViewState {}
