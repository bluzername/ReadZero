import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/models/models.dart';

class PodcastPlayerState {
  final PodcastEpisode? episode;
  final bool isLoading;
  final String? error;

  const PodcastPlayerState({
    this.episode,
    this.isLoading = false,
    this.error,
  });

  PodcastPlayerState copyWith({
    PodcastEpisode? episode,
    bool? isLoading,
    String? error,
    bool clearEpisode = false,
    bool clearError = false,
  }) {
    return PodcastPlayerState(
      episode: clearEpisode ? null : (episode ?? this.episode),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PodcastPlayerNotifier extends StateNotifier<PodcastPlayerState> {
  AudioPlayer? _player;

  AudioPlayer get player {
    _player ??= AudioPlayer();
    return _player!;
  }

  PodcastPlayerNotifier() : super(const PodcastPlayerState());

  Future<void> play(PodcastEpisode episode) async {
    if (state.episode?.id == episode.id) {
      // Same episode — just resume
      player.play();
      return;
    }

    state = PodcastPlayerState(episode: episode, isLoading: true);
    try {
      await player.setUrl(episode.audioUrl!);
      state = state.copyWith(isLoading: false, clearError: true);
      player.play();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load audio');
    }
  }

  void pause() => player.pause();

  void resume() => player.play();

  void togglePlayPause() {
    if (player.playing) {
      player.pause();
    } else {
      player.play();
    }
  }

  void seek(Duration position) => player.seek(position);

  void stop() {
    player.stop();
    state = const PodcastPlayerState();
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }
}

final podcastPlayerProvider =
    StateNotifierProvider<PodcastPlayerNotifier, PodcastPlayerState>((ref) {
  return PodcastPlayerNotifier();
});
