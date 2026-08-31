import 'package:zuraffa/zuraffa.dart';

import '../../../domain/usecases/engagement_usecases.dart';

/// Controller for the Ask ZikZak assistant page.
///
/// Engagement capture is automated by the EngagementHook registered in
/// main() — controllers carry no manual engagement call sites (C5).
class AskZikZakController {
  AskZikZakController(this._askZikZak);

  final AskZikZakUseCase _askZikZak;

  /// Asks the assistant a question and returns its answer on success.
  Future<Result<String, AppFailure>> ask(String question) =>
      _askZikZak(question);
}
