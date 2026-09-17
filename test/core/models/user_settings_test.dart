import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readzero/core/models/models.dart';

void main() {
  const base = {'id': 's1', 'user_id': 'u1'};

  group('UserSettings.fromJson', () {
    test('parses digest_time and applies defaults', () {
      final settings = UserSettings.fromJson({...base, 'digest_time': '07:45:00'});

      expect(settings.digestTime, const TimeOfDay(hour: 7, minute: 45));
      expect(settings.timezone, 'America/Los_Angeles');
      expect(settings.analyzeImages, isTrue);
      expect(settings.includeComments, isTrue);
      expect(settings.pushNotifications, isTrue);
      expect(settings.podcastToken, isNull);
    });

    test('defaults digest_time to 08:00 when absent', () {
      final settings = UserSettings.fromJson(Map<String, dynamic>.from(base));

      expect(settings.digestTime, const TimeOfDay(hour: 8, minute: 0));
    });
  });

  group('UserSettings.toJson', () {
    test('zero-pads digest_time as HH:MM:00', () {
      final settings = UserSettings.fromJson({...base, 'digest_time': '06:05:00'});

      expect(settings.toJson()['digest_time'], '06:05:00');
    });
  });

  group('UserSettings.podcastFeedUrl', () {
    test('is null without a podcast token', () {
      expect(UserSettings.fromJson(Map<String, dynamic>.from(base)).podcastFeedUrl, isNull);
    });

    test('points at the podcast-feed function with the token', () {
      final settings = UserSettings.fromJson({...base, 'podcast_token': 'tok123'});

      expect(
        settings.podcastFeedUrl,
        endsWith('/functions/v1/podcast-feed?token=tok123'),
      );
    });
  });
}
