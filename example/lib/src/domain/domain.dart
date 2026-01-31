/// Domain layer exports.
///
/// This layer contains the business logic and entities.
/// It should be independent of other layers.
library;

// Entities
export 'entities/prime_result.dart';

// Repositories (contracts)
export 'repositories/todo_repository.dart';

// Use Cases
export 'usecases/calculate_primes_usecase.dart';
