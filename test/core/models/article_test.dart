import 'package:flutter_test/flutter_test.dart';
import 'package:readzero/core/models/models.dart';

void main() {
  const minimalJson = {
    'id': 'a1',
    'user_id': 'u1',
    'url': 'https://example.com/post',
    'created_at': '2026-01-29T10:00:00Z',
  };

  group('Article.fromJson', () {
    test('applies defaults for optional fields', () {
      final article = Article.fromJson(Map<String, dynamic>.from(minimalJson));

      expect(article.id, 'a1');
      expect(article.userId, 'u1');
      expect(article.url, 'https://example.com/post');
      expect(article.status, ArticleStatus.pending);
      expect(article.images, isEmpty);
      expect(article.comments, isEmpty);
      expect(article.analysis, isNull);
      expect(article.readAt, isNull);
      expect(article.isArchived, isFalse);
      expect(article.createdAt, DateTime.utc(2026, 1, 29, 10));
    });

    test('maps known status names and falls back to pending', () {
      final ready = Article.fromJson({...minimalJson, 'status': 'ready'});
      final bogus = Article.fromJson({...minimalJson, 'status': 'nope'});

      expect(ready.status, ArticleStatus.ready);
      expect(bogus.status, ArticleStatus.pending);
    });

    test('parses nested analysis and image credit', () {
      final article = Article.fromJson({
        ...minimalJson,
        'status': 'ready',
        'image_credit': {
          'name': 'Annie',
          'username': 'annie',
          'profile_url': 'https://unsplash.com/@annie',
          'photo_url': 'https://unsplash.com/photos/abc',
        },
        'analysis': {
          'summary': 'Short summary',
          'key_points': ['one', 'two'],
          'topics': ['tech'],
          'reading_time_minutes': 4,
          'relevance_score': 1,
        },
      });

      expect(article.imageCredit?.name, 'Annie');
      expect(article.analysis?.keyPoints, ['one', 'two']);
      expect(article.analysis?.readingTimeMinutes, 4);
      expect(article.analysis?.relevanceScore, 1.0);
    });

    test('toJson round-trips through fromJson', () {
      final original = Article.fromJson({
        ...minimalJson,
        'title': 'Hello',
        'status': 'analyzing',
        'read_at': '2026-02-01T08:30:00Z',
        'is_archived': true,
      });

      final copy = Article.fromJson(original.toJson());

      expect(copy.title, 'Hello');
      expect(copy.status, ArticleStatus.analyzing);
      expect(copy.readAt, original.readAt);
      expect(copy.isArchived, isTrue);
    });
  });

  group('ArticleAnalysis.fromJson', () {
    test('substitutes a placeholder when summary is missing', () {
      final analysis = ArticleAnalysis.fromJson(const {});

      expect(analysis.summary, 'Summary unavailable');
      expect(analysis.keyPoints, isEmpty);
      expect(analysis.detailedPoints, isEmpty);
      expect(analysis.topics, isEmpty);
      expect(analysis.imageAnalyses, isEmpty);
    });
  });
}
