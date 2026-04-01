import 'package:code_builder/code_builder.dart';

class StatefulControllerBuilder {
  const StatefulControllerBuilder();

  Method buildCreateInitialState(
    String stateClassName, {
    String? initialEntityField,
    String? entityCamel,
  }) {
    final args = <String, Expression>{};
    if (initialEntityField != null && entityCamel != null) {
      args[entityCamel] = refer(initialEntityField);
    }

    final useConst = args.isEmpty;
    return Method(
      (m) => m
        ..name = 'createInitialState'
        ..annotations.add(refer('override'))
        ..returns = refer(stateClassName)
        ..body = Block(
          (b) => b
            ..statements.add(
              useConst
                  ? refer(
                      stateClassName,
                    ).constInstance([], args).returned.statement
                  : refer(stateClassName).call([], args).returned.statement,
            ),
        ),
    );
  }
}
