// Login domain model — feature 004-login-ui (spec 044 TDD cycle,
// EPIC #1136 verify SDD cycle).
//
// Implements the declared contracts:
//   - Layer contract `LoginValidation.validate(email, password) -> LoginVerdict`
//   - External dependency row `AuthGateway.signIn(email, password) -> LoginResult`
//
// Pure Dart: no Flutter imports (Constitution VII). Deterministic by
// construction (FR-006): the same input always yields the same verdict.
library;

/// The credential pair the user submits (Key Entity `LoginCredentials`).
class LoginCredentials {
  const LoginCredentials({required this.email, required this.password});

  final String email;
  final String password;
}

/// The outcome of validating [LoginCredentials] (declared contract
/// return type `LoginVerdict`).
class LoginVerdict {
  const LoginVerdict._(this.ok, this.reasons);

  final bool ok;
  final List<String> reasons;

  /// The submit gate (FR-003): the submit action is enabled exactly
  /// when the verdict is valid.
  bool get submitEnabled => ok;
}

/// The mapped outcome of an auth attempt (Key Entity `LoginResult`):
/// exactly one of [email]/[error] is non-null (FR-004/FR-005).
class LoginResult {
  const LoginResult._(this.email, this.error);

  /// FR-004 — a success carries the user's email and a null error.
  const LoginResult.success(String userEmail) : this._(userEmail, null);

  /// FR-005 — a failure carries a non-empty reason and a null email.
  const LoginResult.failure(String reason) : this._(null, reason);

  final String? email;
  final String? error;

  bool get isSuccess => email != null;
}

/// The declared `AuthGateway.signIn(email, password) -> LoginResult`
/// contract, abstracted as the function seam the submit path invokes.
typedef AuthGateway = LoginResult Function(String email, String password);

/// FR-001 — an email is well-formed only when it has a non-empty local
/// part, an `@` separator, and a non-empty domain containing a `.`.
bool isWellFormedEmail(String email) {
  final at = email.indexOf('@');
  if (at <= 0) return false; // no separator or empty local part
  if (email.indexOf('@', at + 1) != -1) return false; // extra separator
  final domain = email.substring(at + 1);
  if (domain.isEmpty || !domain.contains('.')) return false;
  final labels = domain.split('.');
  if (labels.any((l) => l.isEmpty)) return false; // empty domain label
  return true;
}

/// FR-002 — the password must be at least 8 characters long.
bool satisfiesPasswordPolicy(String password) => password.length >= 8;

/// The declared contract
/// `LoginValidation.validate(email, password) -> LoginVerdict`.
/// Reason order is stable: email reasons precede password reasons, so
/// empty input names the email field first (AC-1).
LoginVerdict validateLogin(String email, String password) {
  final reasons = <String>[];
  if (!isWellFormedEmail(email)) reasons.add('email');
  if (!satisfiesPasswordPolicy(password)) reasons.add('password');
  return LoginVerdict._(reasons.isEmpty, List.unmodifiable(reasons));
}

/// The declared `AuthGateway.signIn` mapper (FR-004/FR-005): a success
/// carries the authenticated user's email with a null error; a failure
/// carries a non-empty reason with a null email. The precondition that
/// credentials are valid-shaped (the submit gate, FR-003) is enforced
/// by refusing to invoke the gateway otherwise.
LoginResult submitLogin(LoginCredentials credentials, AuthGateway gateway) {
  final verdict = validateLogin(credentials.email, credentials.password);
  if (!verdict.submitEnabled) {
    return const LoginResult._(
      null,
      'credentials are invalid; submit is disabled',
    );
  }
  return gateway(credentials.email, credentials.password);
}
