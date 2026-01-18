import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../articles/providers/article_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articlesAsync = ref.watch(articlesStreamProvider);
    final pendingCount = ref.watch(pendingArticlesCountProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            floating: true,
            title: const Text('Library'),
            actions: [
              if (pendingCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Chip(
                    label: Text(
                      '$pendingCount processing',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.primaryColor,
                      ),
                    ),
                    backgroundColor: context.primaryColor.withOpacity(0.1),
                    side: BorderSide.none,
                    padding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),

          // Content
          articlesAsync.when(
            data: (articles) {
              if (articles.isEmpty) {
                return SliverFillRemaining(
                  child: _EmptyState(),
                );
              }

              // Group by date
              final grouped = <DateTime, List<Article>>{};
              for (final article in articles) {
                final date = DateTime(
                  article.createdAt.year,
                  article.createdAt.month,
                  article.createdAt.day,
                );
                grouped.putIfAbsent(date, () => []).add(article);
              }

              final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final date = dates[index];
                    final dayArticles = grouped[date]!;

                    return _DateSection(
                      date: date,
                      articles: dayArticles,
                    );
                  },
                  childCount: dates.length,
                ),
              );
            },
            loading: () => SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  color: context.primaryColor,
                ),
              ),
            ),
            error: (error, stack) => SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: context.mutedTextColor),
                    const SizedBox(height: 16),
                    Text('Failed to load articles', style: TextStyle(color: context.mutedTextColor)),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => ref.invalidate(articlesStreamProvider),
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

class _EmptyState extends StatelessWidget {
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
                Icons.bookmark_add_outlined,
                size: 40,
                color: context.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your reading list is empty',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Share articles, blog posts, or any web page to save them here. We\'ll extract the content and prepare your daily digest.',
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

class _DateSection extends StatelessWidget {
  final DateTime date;
  final List<Article> articles;

  const _DateSection({
    required this.date,
    required this.articles,
  });

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) {
      return 'Today';
    } else if (date == yesterday) {
      return 'Yesterday';
    } else if (date.isAfter(today.subtract(const Duration(days: 7)))) {
      return DateFormat.EEEE().format(date);
    } else {
      return DateFormat.yMMMd().format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            _formatDate(date),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: context.mutedTextColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        ...articles.map((article) => _ArticleCard(article: article)),
      ],
    );
  }
}

class _ArticleCard extends ConsumerWidget {
  final Article article;

  const _ArticleCard({required this.article});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isProcessing = article.status == ArticleStatus.pending ||
        article.status == ArticleStatus.extracting ||
        article.status == ArticleStatus.analyzing;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isProcessing
              ? null
              : () => context.push('/article/${article.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              if (article.imageUrl != null)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: isProcessing
                      ? Shimmer.fromColors(
                          baseColor: context.isDark
                              ? Colors.grey[800]!
                              : Colors.grey[300]!,
                          highlightColor: context.isDark
                              ? Colors.grey[700]!
                              : Colors.grey[100]!,
                          child: Container(color: Colors.white),
                        )
                      : CachedNetworkImage(
                          imageUrl: article.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: context.borderColor,
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: context.borderColor,
                            child: Icon(
                              Icons.image_outlined,
                              color: context.mutedTextColor,
                            ),
                          ),
                        ),
                ),

              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Site name & time
                    Row(
                      children: [
                        if (article.siteName != null) ...[
                          Text(
                            article.siteName!,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '•',
                            style: TextStyle(color: context.mutedTextColor),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          timeago.format(article.createdAt),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const Spacer(),
                        if (isProcessing)
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.primaryColor,
                            ),
                          )
                        else if (article.readAt == null)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: context.primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Title
                    if (isProcessing)
                      Shimmer.fromColors(
                        baseColor: context.isDark
                            ? Colors.grey[800]!
                            : Colors.grey[300]!,
                        highlightColor: context.isDark
                            ? Colors.grey[700]!
                            : Colors.grey[100]!,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 20,
                              width: double.infinity,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 20,
                              width: 200,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      )
                    else
                      Text(
                        article.title ?? _extractDomain(article.url),
                        style: Theme.of(context).textTheme.titleLarge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                    // Summary preview
                    if (!isProcessing && article.analysis?.summary != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        article.analysis!.summary,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: context.mutedTextColor,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    // Topics
                    if (!isProcessing &&
                        article.analysis?.topics.isNotEmpty == true) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: article.analysis!.topics
                            .take(3)
                            .map((topic) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        context.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    topic,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.primaryColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }
}
