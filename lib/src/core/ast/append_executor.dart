import 'strategies/append_strategy.dart';
import 'strategies/export_append_strategy.dart';
import 'strategies/extension_method_append_strategy.dart';
import 'strategies/field_append_strategy.dart';
import 'strategies/function_statement_append_strategy.dart';
import 'strategies/import_append_strategy.dart';
import 'strategies/method_append_strategy.dart';

class AppendExecutor {
  final List<AppendStrategy> strategies;

  AppendExecutor({List<AppendStrategy>? strategies})
    : strategies =
          strategies ??
          const [
            MethodAppendStrategy(),
            FieldAppendStrategy(),
            ExtensionMethodAppendStrategy(),
            FunctionStatementAppendStrategy(),
            ExportAppendStrategy(),
            ImportAppendStrategy(),
          ];

  AppendResult execute(AppendRequest request) {
    for (final strategy in strategies) {
      if (strategy.canHandle(request)) {
        return strategy.apply(request);
      }
    }
    return AppendResult(
      source: request.source,
      changed: false,
      message: 'No strategy found',
    );
  }
}
