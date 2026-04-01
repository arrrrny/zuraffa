import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/presentation/controller.dart';

class TestState {
  final String value;
  final bool isLoading;

  const TestState({required this.value, this.isLoading = false});

  TestState copyWith({String? value, bool? isLoading}) {
    return TestState(
      value: value ?? this.value,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestState &&
          runtimeType == other.runtimeType &&
          value == other.value &&
          isLoading == other.isLoading;

  @override
  int get hashCode => value.hashCode ^ isLoading.hashCode;
}

class TestController extends Controller with StatefulController<TestState> {
  TestController() : super();

  @override
  TestState createInitialState() => const TestState(value: 'initial');

  void updateValue(String newValue) {
    updateState(viewState.copyWith(value: newValue));
  }

  void setLoading(bool loading) {
    updateState(viewState.copyWith(isLoading: loading));
  }
}

void main() {
  group('StatefulController', () {
    late TestController controller;

    setUp(() {
      controller = TestController();
      // Mock global key to avoid issues with context access if needed,
      // though for this test we only care about state.
      controller.initController(GlobalKey<State<StatefulWidget>>());
    });

    test('initial state is set correctly', () {
      expect(controller.viewState.value, 'initial');
      expect(controller.viewState.isLoading, false);
    });

    test('updateState updates the state and notifies listeners', () {
      int notifyCount = 0;
      controller.addListener(() {
        notifyCount++;
      });

      controller.updateValue('new value');
      expect(controller.viewState.value, 'new value');
      expect(notifyCount, 1);
    });

    test('resetState resets the state to initial and notifies listeners', () {
      controller.updateValue('changed');
      controller.setLoading(true);
      expect(controller.viewState.value, 'changed');
      expect(controller.viewState.isLoading, true);

      int notifyCount = 0;
      controller.addListener(() {
        notifyCount++;
      });

      controller.resetState();

      expect(controller.viewState.value, 'initial');
      expect(controller.viewState.isLoading, false);
      expect(notifyCount, 1);
    });
  });
}
