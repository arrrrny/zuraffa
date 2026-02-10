import 'package:code_builder/code_builder.dart';

class ViewLifecycleBuilder {
  const ViewLifecycleBuilder();

  Method buildOnInitState({required String initialCall}) {
    return Method(
      (m) => m
        ..name = 'onInitState'
        ..annotations.add(refer('override'))
        ..body = Code('''
    super.onInitState();
    $initialCall
'''),
    );
  }
}
