import 'dart:async';

import 'package:zuraffa/zuraffa.dart';

import '../../../domain/usecases/engagement_usecases.dart';
import '../../../telemetry/create_telemetry_event_use_case.dart';

/// Controller for the Ask ZikZak assistant page (RED — manual call present).
class AskZikZakController {
  AskZikZakController(this._askZikZak, this._telemetry);

  final AskZikZakUseCase _askZikZak;
  final CreateTelemetryEventUseCase _telemetry;

  /// Asks the assistant a question and returns its answer on success.
  Future<Result<String, AppFailure>> ask(String question) async {
    final result = await _askZikZak(question);
    result.fold(
      (_) => _trackQuestionAsked(question),
      (_) {},
    );
    return result;
  }

  void _trackQuestionAsked(String question) {
    unawaited(
      _telemetry.call(<String, dynamic>{'event': 'ASK_ZIKZAK', 'payload': question}),
    );
  }
}
