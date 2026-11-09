import 'package:flutter_test/flutter_test.dart';
import 'package:readzero/core/services/auth_extraction_service.dart';

void main() {
  group('RestrictedDomains.getProvider', () {
    test('detects LinkedIn and X/Twitter hosts', () {
      expect(RestrictedDomains.getProvider('https://www.linkedin.com/in/x'), 'linkedin');
      expect(RestrictedDomains.getProvider('https://linkedin.com/posts/1'), 'linkedin');
      expect(RestrictedDomains.getProvider('https://x.com/user/status/1'), 'twitter');
      expect(RestrictedDomains.getProvider('https://twitter.com/user/status/1'), 'twitter');
    });

    test('is case-insensitive on the host', () {
      expect(RestrictedDomains.getProvider('https://X.com/a/status/2'), 'twitter');
    });

    test('returns null for other sites and unparseable input', () {
      expect(RestrictedDomains.getProvider('https://example.com/article'), isNull);
      expect(RestrictedDomains.getProvider('not a url'), isNull);
      expect(RestrictedDomains.getProvider(''), isNull);
    });
  });

  test('isRestricted mirrors getProvider', () {
    expect(RestrictedDomains.isRestricted('https://x.com/a/status/1'), isTrue);
    expect(RestrictedDomains.isRestricted('https://example.com'), isFalse);
  });

  group('RestrictedDomains.getLoginUrl', () {
    test('returns provider login pages', () {
      expect(RestrictedDomains.getLoginUrl('linkedin'), 'https://www.linkedin.com/login');
      expect(RestrictedDomains.getLoginUrl('twitter'), 'https://twitter.com/i/flow/login');
    });

    test('throws for unknown providers', () {
      expect(() => RestrictedDomains.getLoginUrl('mastodon'), throwsArgumentError);
    });
  });

  test('getProviderName returns display names and passes unknowns through', () {
    expect(RestrictedDomains.getProviderName('linkedin'), 'LinkedIn');
    expect(RestrictedDomains.getProviderName('twitter'), 'X (Twitter)');
    expect(RestrictedDomains.getProviderName('other'), 'other');
  });
}
