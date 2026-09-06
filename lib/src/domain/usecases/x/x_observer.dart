// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../entities/x/x.dart';

class XObserver extends Observer<X> {
  XObserver({
    required this.onDataCallback,
    required this.onErrorCallback,
    required this.onDoneCallback,
  });

  final void Function(X) onDataCallback;

  final void Function(AppFailure) onErrorCallback;

  final void Function() onDoneCallback;

  @override
  void onData(X data) {
    onDataCallback(data);
  }

  @override
  void onError(AppFailure failure) {
    onErrorCallback(failure);
  }

  @override
  void onDone() {
    onDoneCallback();
  }
}

// END GENERATED
