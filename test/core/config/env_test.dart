import 'package:flutter_test/flutter_test.dart';
import 'package:readzero/core/config/env.dart';

// `flutter test` runs without --dart-define, so both Supabase values are
// empty here. The tests pin down the behaviour of an unconfigured build.
void main() {
  test('an unconfigured build reports both missing defines', () {
    expect(Env.isConfigured, isFalse);
    expect(Env.missingDefines, ['SUPABASE_URL', 'SUPABASE_ANON_KEY']);
    expect(Env.missingConfigMessage, contains('--dart-define-from-file=.env'));
  });

  test('ensureConfigured throws a StateError naming the defines', () {
    expect(
      Env.ensureConfigured,
      throwsA(isA<StateError>().having(
        (e) => e.message,
        'message',
        allOf(contains('SUPABASE_URL'), contains('SUPABASE_ANON_KEY')),
      )),
    );
  });

  test('legal URLs point at the GitHub Pages site', () {
    expect(Env.privacyPolicyUrl, startsWith('https://bluzername.github.io/ReadZero/'));
    expect(Env.termsOfServiceUrl, startsWith('https://bluzername.github.io/ReadZero/'));
  });
}
