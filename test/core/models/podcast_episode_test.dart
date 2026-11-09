import 'package:flutter_test/flutter_test.dart';
import 'package:readzero/core/models/models.dart';

PodcastEpisode _episode({
  String status = 'pending',
  String? audioUrl,
  int? durationSeconds,
}) {
  return PodcastEpisode(
    id: 'p1',
    userId: 'u1',
    title: 'Digest for Feb 5',
    status: status,
    audioUrl: audioUrl,
    durationSeconds: durationSeconds,
    publishedAt: DateTime.utc(2026, 2, 5),
    createdAt: DateTime.utc(2026, 2, 5),
  );
}

void main() {
  group('PodcastEpisode.formattedDuration', () {
    test('is empty when duration is unknown', () {
      expect(_episode().formattedDuration, '');
    });

    test('formats minutes and zero-padded seconds', () {
      expect(_episode(durationSeconds: 65).formattedDuration, '1:05');
      expect(_episode(durationSeconds: 600).formattedDuration, '10:00');
      expect(_episode(durationSeconds: 7).formattedDuration, '0:07');
    });
  });

  group('PodcastEpisode status flags', () {
    test('isReady requires ready status and an audio url', () {
      expect(_episode(status: 'ready').isReady, isFalse);
      expect(
        _episode(status: 'ready', audioUrl: 'https://cdn/x.mp3').isReady,
        isTrue,
      );
    });

    test('isGenerating covers pending and generating', () {
      expect(_episode(status: 'pending').isGenerating, isTrue);
      expect(_episode(status: 'generating').isGenerating, isTrue);
      expect(_episode(status: 'failed').isGenerating, isFalse);
      expect(_episode(status: 'failed').isFailed, isTrue);
    });
  });

  test('fromJson defaults status to pending', () {
    final episode = PodcastEpisode.fromJson({
      'id': 'p1',
      'user_id': 'u1',
      'title': 'T',
      'published_at': '2026-02-05T00:00:00Z',
      'created_at': '2026-02-05T00:00:00Z',
    });

    expect(episode.status, 'pending');
    expect(episode.durationSeconds, isNull);
  });
}
