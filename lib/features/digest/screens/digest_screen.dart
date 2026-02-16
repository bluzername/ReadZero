import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../articles/providers/article_providers.dart';
import '../../articles/widgets/source_placeholder.dart';

class DigestScreen extends ConsumerWidget {
  const DigestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final digestsAsync = ref.watch(digestsStreamProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(
            floating: true,
            title: Text('Daily Digest'),
          ),
          digestsAsync.when(
            data: (digests) {
              if (digests.isEmpty) {
                return SliverFillRemaining(child: _EmptyDigest());
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final digest = digests[index];
                    final isLatest = index == 0;

                    return _DigestCard(
                      digest: digest,
                      isLatest: isLatest,
                    ).animate().fadeIn(
                          duration: 300.ms,
                          delay: (50 * index).ms,
                        );
                  },
                  childCount: digests.length,
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: context.mutedTextColor),
                    const SizedBox(height: 16),
                    Text('Failed to load digests'),
                    TextButton(
                      onPressed: () => ref.invalidate(digestsStreamProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDigest extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: context.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.auto_awesome_outlined,
                size: 40,
                color: context.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No digests yet',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Save some articles to your library and your first daily digest will be generated at 8 AM tomorrow.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.mutedTextColor,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _DigestCard extends ConsumerWidget {
  final DailyDigest digest;
  final bool isLatest;

  const _DigestCard({
    required this.digest,
    required this.isLatest,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: isLatest
                    ? LinearGradient(
                        colors: [
                          context.primaryColor.withOpacity(0.1),
                          context.primaryColor.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isLatest && !digest.isRead) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: context.primaryColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'NEW',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Text(
                        _formatDate(digest.date),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: context.mutedTextColor,
                            ),
                      ),
                      const Spacer(),
                      Text(
                        '${digest.articles.length} articles',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Themes
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: digest.topThemes
                        .take(4)
                        .map((theme) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: context.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                theme,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: context.primaryColor,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),

            // Overall Summary
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 18,
                        color: context.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Summary',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    digest.overallSummary,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),

                  // AI Insights
                  if (digest.aiInsights != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.isDark
                            ? Colors.amber.withOpacity(0.1)
                            : Colors.amber.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.amber.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            size: 18,
                            color: Colors.amber[700],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              digest.aiInsights!,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Podcast Player
            _PodcastPlayerSection(digestId: digest.id),

            // Articles preview
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...digest.articles.map((article) => _DigestArticleTile(
                        article: article,
                        onTap: () => context.push('/article/${article.articleId}'),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final digestDate = DateTime(date.year, date.month, date.day);

    if (digestDate == today) {
      return 'Today\'s Digest';
    } else if (digestDate == yesterday) {
      return 'Yesterday\'s Digest';
    } else {
      return DateFormat.MMMEd().format(date);
    }
  }
}

class _PodcastPlayerSection extends ConsumerWidget {
  final String digestId;

  const _PodcastPlayerSection({required this.digestId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodeAsync = ref.watch(podcastEpisodeForDigestProvider(digestId));

    return episodeAsync.when(
      data: (episode) {
        if (episode == null) return const SizedBox.shrink();

        if (episode.isGenerating) {
          return _PodcastStatusCard(
            icon: Icons.podcasts,
            message: 'Generating your podcast...',
            showProgress: true,
          );
        }

        if (episode.isFailed) {
          return _PodcastStatusCard(
            icon: Icons.error_outline,
            message: 'Podcast generation failed',
            action: TextButton(
              onPressed: () {
                ref.read(supabaseServiceProvider).generatePodcast(digestId);
                ref.invalidate(podcastEpisodeForDigestProvider(digestId));
              },
              child: const Text('Retry'),
            ),
          );
        }

        if (episode.isReady) {
          return _PodcastPlayer(episode: episode);
        }

        return const SizedBox.shrink();
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _PodcastStatusCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool showProgress;
  final Widget? action;

  const _PodcastStatusCard({
    required this.icon,
    required this.message,
    this.showProgress = false,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.isDark
              ? Colors.purple.withOpacity(0.1)
              : Colors.purple.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.purple.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.purple),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (showProgress)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            if (action != null) action!,
          ],
        ),
      ),
    );
  }
}

class _PodcastPlayer extends StatefulWidget {
  final PodcastEpisode episode;

  const _PodcastPlayer({required this.episode});

  @override
  State<_PodcastPlayer> createState() => _PodcastPlayerState();
}

class _PodcastPlayerState extends State<_PodcastPlayer> {
  late AudioPlayer _player;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      await _player.setUrl(widget.episode.audioUrl!);
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load audio';
      });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _PodcastStatusCard(
        icon: Icons.error_outline,
        message: _error!,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.isDark
              ? Colors.purple.withOpacity(0.1)
              : Colors.purple.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.purple.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Icon(Icons.podcasts, size: 18, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  'Podcast',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                if (widget.episode.durationSeconds != null)
                  Text(
                    widget.episode.formattedDuration,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.mutedTextColor,
                        ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Play button + seek bar
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              Row(
                children: [
                  // Play/Pause button
                  StreamBuilder<PlayerState>(
                    stream: _player.playerStateStream,
                    builder: (context, snapshot) {
                      final playerState = snapshot.data;
                      final playing = playerState?.playing ?? false;
                      final processingState = playerState?.processingState;

                      if (processingState == ProcessingState.loading ||
                          processingState == ProcessingState.buffering) {
                        return const SizedBox(
                          width: 40,
                          height: 40,
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }

                      return GestureDetector(
                        onTap: () {
                          if (processingState == ProcessingState.completed) {
                            _player.seek(Duration.zero);
                            _player.play();
                          } else if (playing) {
                            _player.pause();
                          } else {
                            _player.play();
                          }
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.purple,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            processingState == ProcessingState.completed
                                ? Icons.replay
                                : playing
                                    ? Icons.pause
                                    : Icons.play_arrow,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),

                  // Seek bar
                  Expanded(
                    child: StreamBuilder<Duration>(
                      stream: _player.positionStream,
                      builder: (context, posSnapshot) {
                        final position = posSnapshot.data ?? Duration.zero;
                        final duration = _player.duration ?? Duration.zero;

                        return Column(
                          children: [
                            SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 12,
                                ),
                                activeTrackColor: Colors.purple,
                                inactiveTrackColor:
                                    Colors.purple.withOpacity(0.2),
                                thumbColor: Colors.purple,
                              ),
                              child: Slider(
                                value: duration.inMilliseconds > 0
                                    ? position.inMilliseconds
                                        .clamp(0, duration.inMilliseconds)
                                        .toDouble()
                                    : 0,
                                max: duration.inMilliseconds > 0
                                    ? duration.inMilliseconds.toDouble()
                                    : 1,
                                onChanged: (value) {
                                  _player.seek(
                                    Duration(milliseconds: value.toInt()),
                                  );
                                },
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(position),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          fontSize: 11,
                                          color: context.mutedTextColor,
                                        ),
                                  ),
                                  Text(
                                    _formatDuration(duration),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          fontSize: 11,
                                          color: context.mutedTextColor,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }
}

class _DigestArticleTile extends StatelessWidget {
  final DigestArticle article;
  final VoidCallback onTap;

  const _DigestArticleTile({
    required this.article,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: article.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: article.imageUrl!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => SourcePlaceholder(
                        url: article.url,
                        width: 60,
                        height: 60,
                      ),
                    )
                  : SourcePlaceholder(
                      url: article.url,
                      width: 60,
                      height: 60,
                    ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    article.summary,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.mutedTextColor,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: context.mutedTextColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
