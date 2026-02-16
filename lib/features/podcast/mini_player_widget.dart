import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/theme/app_theme.dart';
import 'podcast_player_provider.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(podcastPlayerProvider);

    if (playerState.episode == null) return const SizedBox.shrink();

    final player = ref.read(podcastPlayerProvider.notifier).player;

    return GestureDetector(
      onTap: () => context.go('/digest'),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: context.isDark ? const Color(0xFF1A1A2E) : Colors.white,
          border: Border(
            top: BorderSide(
              color: Colors.purple.withOpacity(0.2),
              width: 0.5,
            ),
          ),
        ),
        child: Column(
          children: [
            // Progress bar at top
            StreamBuilder<Duration>(
              stream: player.positionStream,
              builder: (context, posSnapshot) {
                final position = posSnapshot.data ?? Duration.zero;
                final duration = player.duration ?? Duration.zero;
                final progress = duration.inMilliseconds > 0
                    ? (position.inMilliseconds / duration.inMilliseconds)
                        .clamp(0.0, 1.0)
                    : 0.0;

                return LinearProgressIndicator(
                  value: progress,
                  minHeight: 2,
                  backgroundColor: Colors.purple.withOpacity(0.1),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.purple),
                );
              },
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Podcast icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.podcasts,
                        color: Colors.purple,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Title
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playerState.episode!.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (playerState.isLoading)
                            Text(
                              'Loading...',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: context.mutedTextColor),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Play/Pause button
                    if (playerState.isLoading)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      StreamBuilder<PlayerState>(
                        stream: player.playerStateStream,
                        builder: (context, snapshot) {
                          final playing = snapshot.data?.playing ?? false;
                          final processingState =
                              snapshot.data?.processingState;

                          if (processingState == ProcessingState.loading ||
                              processingState == ProcessingState.buffering) {
                            return const SizedBox(
                              width: 24,
                              height: 24,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            );
                          }

                          return IconButton(
                            icon: Icon(
                              playing ? Icons.pause : Icons.play_arrow,
                              color: Colors.purple,
                            ),
                            onPressed: () => ref
                                .read(podcastPlayerProvider.notifier)
                                .togglePlayPause(),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
