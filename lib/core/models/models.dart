import 'dart:convert';

/// Represents a saved article/webpage
class Article {
  final String id;
  final String userId;
  final String url;
  final String? title;
  final String? description;
  final String? content; // Extracted markdown content
  final String? imageUrl;
  final String? siteName;
  final String? author;
  final List<ArticleImage> images;
  final List<Comment> comments;
  final ArticleAnalysis? analysis;
  final ArticleStatus status;
  final DateTime createdAt;
  final DateTime? readAt;
  final bool isArchived;

  Article({
    required this.id,
    required this.userId,
    required this.url,
    this.title,
    this.description,
    this.content,
    this.imageUrl,
    this.siteName,
    this.author,
    this.images = const [],
    this.comments = const [],
    this.analysis,
    this.status = ArticleStatus.pending,
    required this.createdAt,
    this.readAt,
    this.isArchived = false,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      url: json['url'] as String,
      title: json['title'] as String?,
      description: json['description'] as String?,
      content: json['content'] as String?,
      imageUrl: json['image_url'] as String?,
      siteName: json['site_name'] as String?,
      author: json['author'] as String?,
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => ArticleImage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      comments: (json['comments'] as List<dynamic>?)
              ?.map((e) => Comment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      analysis: json['analysis'] != null
          ? ArticleAnalysis.fromJson(json['analysis'] as Map<String, dynamic>)
          : null,
      status: ArticleStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ArticleStatus.pending,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      isArchived: json['is_archived'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'url': url,
        'title': title,
        'description': description,
        'content': content,
        'image_url': imageUrl,
        'site_name': siteName,
        'author': author,
        'images': images.map((e) => e.toJson()).toList(),
        'comments': comments.map((e) => e.toJson()).toList(),
        'analysis': analysis?.toJson(),
        'status': status.name,
        'created_at': createdAt.toIso8601String(),
        'read_at': readAt?.toIso8601String(),
        'is_archived': isArchived,
      };

  Article copyWith({
    String? id,
    String? userId,
    String? url,
    String? title,
    String? description,
    String? content,
    String? imageUrl,
    String? siteName,
    String? author,
    List<ArticleImage>? images,
    List<Comment>? comments,
    ArticleAnalysis? analysis,
    ArticleStatus? status,
    DateTime? createdAt,
    DateTime? readAt,
    bool? isArchived,
  }) {
    return Article(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      url: url ?? this.url,
      title: title ?? this.title,
      description: description ?? this.description,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      siteName: siteName ?? this.siteName,
      author: author ?? this.author,
      images: images ?? this.images,
      comments: comments ?? this.comments,
      analysis: analysis ?? this.analysis,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}

enum ArticleStatus {
  pending,    // Just saved, not yet processed
  extracting, // Content being extracted
  analyzing,  // AI analysis in progress
  ready,      // Fully processed
  failed,     // Processing failed
}

/// Image extracted from an article
class ArticleImage {
  final String url;
  final String? alt;
  final String? caption;
  final String? aiDescription; // Claude's description of the image

  ArticleImage({
    required this.url,
    this.alt,
    this.caption,
    this.aiDescription,
  });

  factory ArticleImage.fromJson(Map<String, dynamic> json) => ArticleImage(
        url: json['url'] as String,
        alt: json['alt'] as String?,
        caption: json['caption'] as String?,
        aiDescription: json['ai_description'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'url': url,
        'alt': alt,
        'caption': caption,
        'ai_description': aiDescription,
      };
}

/// Comment from the article (if from a forum/social site)
class Comment {
  final String author;
  final String content;
  final int? score;
  final DateTime? timestamp;
  final List<Comment> replies;

  Comment({
    required this.author,
    required this.content,
    this.score,
    this.timestamp,
    this.replies = const [],
  });

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        author: json['author'] as String,
        content: json['content'] as String,
        score: json['score'] as int?,
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : null,
        replies: (json['replies'] as List<dynamic>?)
                ?.map((e) => Comment.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        'author': author,
        'content': content,
        'score': score,
        'timestamp': timestamp?.toIso8601String(),
        'replies': replies.map((e) => e.toJson()).toList(),
      };
}

/// AI-generated analysis of the article
class ArticleAnalysis {
  final String summary;
  final List<String> keyPoints;
  final List<String> topics;
  final String? sentiment;
  final int? readingTimeMinutes;
  final double? relevanceScore; // How relevant to user's interests
  final String? commentsSummary; // Summary of discussion if comments exist
  final List<ImageAnalysis> imageAnalyses;

  ArticleAnalysis({
    required this.summary,
    required this.keyPoints,
    required this.topics,
    this.sentiment,
    this.readingTimeMinutes,
    this.relevanceScore,
    this.commentsSummary,
    this.imageAnalyses = const [],
  });

  factory ArticleAnalysis.fromJson(Map<String, dynamic> json) =>
      ArticleAnalysis(
        summary: json['summary'] as String,
        keyPoints: (json['key_points'] as List<dynamic>)
            .map((e) => e as String)
            .toList(),
        topics:
            (json['topics'] as List<dynamic>).map((e) => e as String).toList(),
        sentiment: json['sentiment'] as String?,
        readingTimeMinutes: json['reading_time_minutes'] as int?,
        relevanceScore: (json['relevance_score'] as num?)?.toDouble(),
        commentsSummary: json['comments_summary'] as String?,
        imageAnalyses: (json['image_analyses'] as List<dynamic>?)
                ?.map((e) => ImageAnalysis.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        'summary': summary,
        'key_points': keyPoints,
        'topics': topics,
        'sentiment': sentiment,
        'reading_time_minutes': readingTimeMinutes,
        'relevance_score': relevanceScore,
        'comments_summary': commentsSummary,
        'image_analyses': imageAnalyses.map((e) => e.toJson()).toList(),
      };
}

/// AI analysis of an image
class ImageAnalysis {
  final String imageUrl;
  final String description;
  final List<String> objects;
  final String? relevance; // How the image relates to the article

  ImageAnalysis({
    required this.imageUrl,
    required this.description,
    this.objects = const [],
    this.relevance,
  });

  factory ImageAnalysis.fromJson(Map<String, dynamic> json) => ImageAnalysis(
        imageUrl: json['image_url'] as String,
        description: json['description'] as String,
        objects: (json['objects'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        relevance: json['relevance'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'image_url': imageUrl,
        'description': description,
        'objects': objects,
        'relevance': relevance,
      };
}

/// Daily digest containing summarized articles
class DailyDigest {
  final String id;
  final String userId;
  final DateTime date;
  final String overallSummary;
  final List<String> topThemes;
  final List<DigestArticle> articles;
  final String? aiInsights; // Cross-article insights
  final DateTime createdAt;
  final bool isRead;

  DailyDigest({
    required this.id,
    required this.userId,
    required this.date,
    required this.overallSummary,
    required this.topThemes,
    required this.articles,
    this.aiInsights,
    required this.createdAt,
    this.isRead = false,
  });

  factory DailyDigest.fromJson(Map<String, dynamic> json) => DailyDigest(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        date: DateTime.parse(json['date'] as String),
        overallSummary: json['overall_summary'] as String,
        topThemes: (json['top_themes'] as List<dynamic>)
            .map((e) => e as String)
            .toList(),
        articles: (json['articles'] as List<dynamic>)
            .map((e) => DigestArticle.fromJson(e as Map<String, dynamic>))
            .toList(),
        aiInsights: json['ai_insights'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        isRead: json['is_read'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'date': date.toIso8601String(),
        'overall_summary': overallSummary,
        'top_themes': topThemes,
        'articles': articles.map((e) => e.toJson()).toList(),
        'ai_insights': aiInsights,
        'created_at': createdAt.toIso8601String(),
        'is_read': isRead,
      };
}

/// Article reference in a digest (condensed view)
class DigestArticle {
  final String articleId;
  final String title;
  final String? imageUrl;
  final String summary;
  final List<String> highlights;
  final String url;

  DigestArticle({
    required this.articleId,
    required this.title,
    this.imageUrl,
    required this.summary,
    required this.highlights,
    required this.url,
  });

  factory DigestArticle.fromJson(Map<String, dynamic> json) => DigestArticle(
        articleId: json['article_id'] as String,
        title: json['title'] as String,
        imageUrl: json['image_url'] as String?,
        summary: json['summary'] as String,
        highlights: (json['highlights'] as List<dynamic>)
            .map((e) => e as String)
            .toList(),
        url: json['url'] as String,
      );

  Map<String, dynamic> toJson() => {
        'article_id': articleId,
        'title': title,
        'image_url': imageUrl,
        'summary': summary,
        'highlights': highlights,
        'url': url,
      };
}
