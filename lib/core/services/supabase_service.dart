import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

class SupabaseService {
  final SupabaseClient _client;

  SupabaseService() : _client = Supabase.instance.client;

  SupabaseClient get client => _client;
  String? get userId => _client.auth.currentUser?.id;

  // ============ Articles ============

  /// Save a new article URL (processing happens via Edge Function)
  Future<Article> saveArticle(String url) async {
    final response = await _client.from('articles').insert({
      'user_id': userId,
      'url': url,
      'status': ArticleStatus.pending.name,
      'created_at': DateTime.now().toIso8601String(),
    }).select().single();

    // Trigger extraction via Edge Function
    await _client.functions.invoke('extract-article', body: {
      'article_id': response['id'],
      'url': url,
    });

    return Article.fromJson(response);
  }

  /// Get all articles for current user
  Stream<List<Article>> watchArticles({bool includeArchived = false}) {
    var query = _client
        .from('articles')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId!)
        .order('created_at', ascending: false);

    return query.map((data) {
      final articles = data.map((e) => Article.fromJson(e)).toList();
      if (!includeArchived) {
        return articles.where((a) => !a.isArchived).toList();
      }
      return articles;
    });
  }

  /// Get single article by ID
  Future<Article> getArticle(String id) async {
    final response = await _client
        .from('articles')
        .select()
        .eq('id', id)
        .single();
    return Article.fromJson(response);
  }

  /// Mark article as read
  Future<void> markAsRead(String id) async {
    await _client.from('articles').update({
      'read_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Archive article
  Future<void> archiveArticle(String id) async {
    await _client.from('articles').update({
      'is_archived': true,
    }).eq('id', id);
  }

  /// Delete article
  Future<void> deleteArticle(String id) async {
    await _client.from('articles').delete().eq('id', id);
  }

  /// Get articles from a specific date (for digest)
  Future<List<Article>> getArticlesForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final response = await _client
        .from('articles')
        .select()
        .eq('user_id', userId!)
        .gte('created_at', startOfDay.toIso8601String())
        .lt('created_at', endOfDay.toIso8601String())
        .order('created_at', ascending: false);

    return (response as List).map((e) => Article.fromJson(e)).toList();
  }

  // ============ Digests ============

  /// Get all digests for current user
  Stream<List<DailyDigest>> watchDigests() {
    return _client
        .from('digests')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId!)
        .order('date', ascending: false)
        .map((data) => data.map((e) => DailyDigest.fromJson(e)).toList());
  }

  /// Get digest for a specific date
  Future<DailyDigest?> getDigestForDate(DateTime date) async {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    
    final response = await _client
        .from('digests')
        .select()
        .eq('user_id', userId!)
        .eq('date', dateStr)
        .maybeSingle();

    if (response == null) return null;
    return DailyDigest.fromJson(response);
  }

  /// Get latest digest
  Future<DailyDigest?> getLatestDigest() async {
    final response = await _client
        .from('digests')
        .select()
        .eq('user_id', userId!)
        .order('date', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return DailyDigest.fromJson(response);
  }

  /// Mark digest as read
  Future<void> markDigestAsRead(String id) async {
    await _client.from('digests').update({
      'is_read': true,
    }).eq('id', id);
  }

  /// Manually trigger digest generation (for testing/on-demand)
  Future<DailyDigest> generateDigest({DateTime? date}) async {
    final response = await _client.functions.invoke('generate-digest', body: {
      'user_id': userId,
      'date': (date ?? DateTime.now()).toIso8601String(),
    });

    return DailyDigest.fromJson(response.data);
  }

  // ============ Auth ============

  Future<void> signInAnonymously() async {
    await _client.auth.signInAnonymously();
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}
