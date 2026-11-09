import 'package:flutter_test/flutter_test.dart';
import 'package:readzero/core/models/models.dart';

void main() {
  group('DailyDigest', () {
    final json = {
      'id': 'd1',
      'user_id': 'u1',
      'date': '2026-02-05',
      'overall_summary': 'Three articles about AI.',
      'top_themes': ['ai', 'tooling'],
      'articles': <Map<String, dynamic>>[],
      'ai_insights': 'They all mention agents.',
      'created_at': '2026-02-05T08:00:00Z',
    };

    test('fromJson parses fields and defaults is_read to false', () {
      final digest = DailyDigest.fromJson(json);

      expect(digest.id, 'd1');
      expect(digest.date, DateTime(2026, 2, 5));
      expect(digest.topThemes, ['ai', 'tooling']);
      expect(digest.articles, isEmpty);
      expect(digest.aiInsights, 'They all mention agents.');
      expect(digest.isRead, isFalse);
    });

    test('toJson round-trips', () {
      final digest = DailyDigest.fromJson({...json, 'is_read': true});
      final copy = DailyDigest.fromJson(digest.toJson());

      expect(copy.overallSummary, digest.overallSummary);
      expect(copy.topThemes, digest.topThemes);
      expect(copy.createdAt, digest.createdAt);
      expect(copy.isRead, isTrue);
    });
  });
}
