/// Build-time configuration.
///
/// Values are injected with `--dart-define` (or `--dart-define-from-file=.env`,
/// see `.env.example` and the README). Nothing here is read at runtime from
/// disk, so a build made without the defines has empty strings.
class Env {
  // Supabase
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// True when both Supabase defines were supplied at build time.
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Names of the required defines that are missing from this build.
  static List<String> get missingDefines => [
        if (supabaseUrl.isEmpty) 'SUPABASE_URL',
        if (supabaseAnonKey.isEmpty) 'SUPABASE_ANON_KEY',
      ];

  static String get missingConfigMessage =>
      'Missing build-time config: ${missingDefines.join(', ')}. '
      'Pass them with --dart-define or --dart-define-from-file=.env '
      '(copy .env.example to .env).';

  /// Throws a [StateError] with a clear message when the build lacks the
  /// required Supabase defines.
  static void ensureConfigured() {
    if (isConfigured) return;
    throw StateError(missingConfigMessage);
  }

  // Legal URLs (hosted on GitHub Pages)
  static const String privacyPolicyUrl =
      'https://bluzername.github.io/ReadZero/privacy-policy';
  static const String termsOfServiceUrl =
      'https://bluzername.github.io/ReadZero/terms-of-service';
}
