/// Application Configuration
class AppConfig {
  AppConfig._();

  static const String appName = 'Benwasal';
  static const String appVersion = '1.0.0';
  static const String buildNumber = '1';

  // Developer Info
  static const String developerName = 'Walid Ghubara';
  static const String developerGithub = 'https://github.com/waleedghubara';
  static const String developerProfile = 'waleedghubara.dev';
  static const String developerLinkedIn =
      'https://www.linkedin.com/in/walid-ghubara-1358742ba/';
  static const String developerEmail = 'walidghubara@gmail.com';

  // Environment
  static const bool isProduction = true;
  static const bool enableLogging = true;

  // API Configuration
  static String get baseUrl {
    return isProduction
        ? 'https://bnwasal.com/api/'
        : 'https://bnwasal.com/api/';
  }
}
