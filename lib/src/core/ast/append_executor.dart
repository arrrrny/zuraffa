import 'strategies/append_strategy.dart';
import 'strategies/export_append_strategy.dart';
import 'strategies/method_append_strategy.dart';

class AppendExecutor {
  final List<AppendStrategy> strategies;

  AppendExecutor({List<AppendStrategy>? strategies})
      : strategies =
            strategies ??
            const [
              MethodAppendStrategy(),
              ExportAppendStrategy(),
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
