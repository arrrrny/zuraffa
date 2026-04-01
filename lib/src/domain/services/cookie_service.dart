import 'package:zuraffa/zuraffa.dart';

/// Service interface for CookieService
abstract class CookieService {
  Future<void> clearCookies(String string);
}
