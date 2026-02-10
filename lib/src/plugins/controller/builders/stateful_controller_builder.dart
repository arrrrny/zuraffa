import 'package:code_builder/code_builder.dart';

class StatefulControllerBuilder {
  const StatefulControllerBuilder();

  Method buildCreateInitialState(String stateClassName) {
    return Method(
      (m) => m
        ..name = 'createInitialState'
        ..annotations.add(refer('override'))
        ..returns = refer(stateClassName)
        ..body = Code('return const $stateClassName();'),
    );
  }
}
