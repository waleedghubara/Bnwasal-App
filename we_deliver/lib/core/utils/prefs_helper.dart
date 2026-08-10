import 'package:shared_preferences/shared_preferences.dart';

class PrefsHelper {
  static Future<void> clearSessionKeepCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
    final savedEmail = prefs.getString('saved_email');
    final savedPassword = prefs.getString('saved_password');
    final rememberMe = prefs.getBool('remember_me');
    final savedAccountsList = prefs.getString('saved_accounts_list');

    await prefs.clear();

    if (onboardingCompleted) {
      await prefs.setBool('onboarding_completed', true);
    }
    if (rememberMe != null) {
      await prefs.setBool('remember_me', rememberMe);
    }
    if (savedEmail != null) {
      await prefs.setString('saved_email', savedEmail);
    }
    if (savedPassword != null) {
      await prefs.setString('saved_password', savedPassword);
    }
    if (savedAccountsList != null) {
      await prefs.setString('saved_accounts_list', savedAccountsList);
    }
  }
}
