# Readwise App - Development Notes (Jan 29, 2026)

## Project Status Assessment

### What's Complete
- Share extension URL capture (Android/iOS intent handling)
- Article library view with date-based grouping
- Article detail screen with markdown rendering, progress tracking
- AI summary cards (key points, topics, image analysis)
- Daily digest generation with cross-article insights
- Supabase backend (PostgreSQL, Edge Functions, RLS policies)
- Real-time sync via Riverpod streams
- Processing queue with retry logic

### What's Missing
- Settings screen (10 TODOs - all toggles are placeholders)
- User authentication (currently anonymous only)
- Search functionality
- Archive view
- Data export
- Push notifications (Firebase setup incomplete)

### Testing Status
- **No automated tests exist** - no `test/` directory
- Manual testing possible once Supabase is configured

---

## Settings Screen Implementation Plan

### Database Schema (Already Exists)

The `user_settings` table in Supabase already has all required fields:

```sql
CREATE TABLE public.user_settings (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id),
    digest_time TIME DEFAULT '08:00:00',
    timezone TEXT DEFAULT 'America/Los_Angeles',
    analyze_images BOOLEAN DEFAULT true,
    include_comments BOOLEAN DEFAULT true,
    push_notifications BOOLEAN DEFAULT true,
    fcm_token TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
);
```

### Step 1: Add UserSettings Model

**File:** `lib/core/models/models.dart`

Add at the end of the file:

```dart
/// User preferences and settings
class UserSettings {
  final String userId;
  final TimeOfDay digestTime;
  final String timezone;
  final bool analyzeImages;
  final bool includeComments;
  final bool pushNotifications;
  final String? fcmToken;

  UserSettings({
    required this.userId,
    this.digestTime = const TimeOfDay(hour: 8, minute: 0),
    this.timezone = 'America/Los_Angeles',
    this.analyzeImages = true,
    this.includeComments = true,
    this.pushNotifications = true,
    this.fcmToken,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    // Parse TIME string "08:00:00" to TimeOfDay
    TimeOfDay parseTime(String? timeStr) {
      if (timeStr == null) return const TimeOfDay(hour: 8, minute: 0);
      final parts = timeStr.split(':');
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    return UserSettings(
      userId: json['user_id'] as String,
      digestTime: parseTime(json['digest_time'] as String?),
      timezone: json['timezone'] as String? ?? 'America/Los_Angeles',
      analyzeImages: json['analyze_images'] as bool? ?? true,
      includeComments: json['include_comments'] as bool? ?? true,
      pushNotifications: json['push_notifications'] as bool? ?? true,
      fcmToken: json['fcm_token'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'digest_time': '${digestTime.hour.toString().padLeft(2, '0')}:${digestTime.minute.toString().padLeft(2, '0')}:00',
    'timezone': timezone,
    'analyze_images': analyzeImages,
    'include_comments': includeComments,
    'push_notifications': pushNotifications,
    'fcm_token': fcmToken,
  };

  UserSettings copyWith({
    String? userId,
    TimeOfDay? digestTime,
    String? timezone,
    bool? analyzeImages,
    bool? includeComments,
    bool? pushNotifications,
    String? fcmToken,
  }) {
    return UserSettings(
      userId: userId ?? this.userId,
      digestTime: digestTime ?? this.digestTime,
      timezone: timezone ?? this.timezone,
      analyzeImages: analyzeImages ?? this.analyzeImages,
      includeComments: includeComments ?? this.includeComments,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }
}
```

Don't forget to add `import 'package:flutter/material.dart';` at the top for `TimeOfDay`.

---

### Step 2: Add Service Methods

**File:** `lib/core/services/supabase_service.dart`

Add these methods to the `SupabaseService` class:

```dart
// ============ Settings ============

/// Get user settings
Future<UserSettings> getUserSettings() async {
  final response = await _client
      .from('user_settings')
      .select()
      .eq('user_id', userId!)
      .maybeSingle();

  if (response == null) {
    // Settings should be auto-created by DB trigger, but handle edge case
    final created = await _client.from('user_settings').insert({
      'user_id': userId,
    }).select().single();
    return UserSettings.fromJson(created);
  }
  return UserSettings.fromJson(response);
}

/// Update a single setting
Future<void> updateSetting(String key, dynamic value) async {
  await _client.from('user_settings').update({
    key: value,
    'updated_at': DateTime.now().toIso8601String(),
  }).eq('user_id', userId!);
}

/// Update digest time
Future<void> updateDigestTime(TimeOfDay time) async {
  final timeString = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
  await updateSetting('digest_time', timeString);
}

/// Update FCM token for push notifications
Future<void> updateFcmToken(String? token) async {
  await updateSetting('fcm_token', token);
}

/// Get all articles for export (including archived)
Future<List<Article>> getAllArticlesForExport() async {
  final response = await _client
      .from('articles')
      .select()
      .eq('user_id', userId!)
      .order('created_at', ascending: false);
  return (response as List).map((e) => Article.fromJson(e)).toList();
}

/// Get all digests for export
Future<List<DailyDigest>> getAllDigestsForExport() async {
  final response = await _client
      .from('digests')
      .select()
      .eq('user_id', userId!)
      .order('date', ascending: false);
  return (response as List).map((e) => DailyDigest.fromJson(e)).toList();
}

/// Delete all user data (articles and digests)
Future<void> clearAllData() async {
  await _client.from('articles').delete().eq('user_id', userId!);
  await _client.from('digests').delete().eq('user_id', userId!);
}

/// Stream of archived articles
Stream<List<Article>> watchArchivedArticles() {
  return _client
      .from('articles')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId!)
      .order('created_at', ascending: false)
      .map((data) => data
          .map((e) => Article.fromJson(e))
          .where((a) => a.isArchived)
          .toList());
}

/// Restore archived article
Future<void> restoreArticle(String id) async {
  await _client.from('articles').update({
    'is_archived': false,
  }).eq('id', id);
}
```

---

### Step 3: Create Settings Providers

**New File:** `lib/features/settings/providers/settings_providers.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/models/models.dart';
import '../../articles/providers/article_providers.dart';

/// User settings provider
final userSettingsProvider = AsyncNotifierProvider<UserSettingsNotifier, UserSettings>(() {
  return UserSettingsNotifier();
});

class UserSettingsNotifier extends AsyncNotifier<UserSettings> {
  @override
  Future<UserSettings> build() async {
    return ref.read(supabaseServiceProvider).getUserSettings();
  }

  Future<void> updateDigestTime(TimeOfDay time) async {
    final oldState = state.value!;
    state = AsyncData(oldState.copyWith(digestTime: time));
    try {
      await ref.read(supabaseServiceProvider).updateDigestTime(time);
    } catch (e) {
      state = AsyncData(oldState);
      rethrow;
    }
  }

  Future<void> togglePushNotifications(bool value) async {
    final oldState = state.value!;
    state = AsyncData(oldState.copyWith(pushNotifications: value));
    try {
      await ref.read(supabaseServiceProvider).updateSetting('push_notifications', value);
    } catch (e) {
      state = AsyncData(oldState);
      rethrow;
    }
  }

  Future<void> toggleAnalyzeImages(bool value) async {
    final oldState = state.value!;
    state = AsyncData(oldState.copyWith(analyzeImages: value));
    try {
      await ref.read(supabaseServiceProvider).updateSetting('analyze_images', value);
    } catch (e) {
      state = AsyncData(oldState);
      rethrow;
    }
  }

  Future<void> toggleIncludeComments(bool value) async {
    final oldState = state.value!;
    state = AsyncData(oldState.copyWith(includeComments: value));
    try {
      await ref.read(supabaseServiceProvider).updateSetting('include_comments', value);
    } catch (e) {
      state = AsyncData(oldState);
      rethrow;
    }
  }
}

/// Provider for archived articles stream
final archivedArticlesProvider = StreamProvider<List<Article>>((ref) {
  return ref.read(supabaseServiceProvider).watchArchivedArticles();
});
```

---

### Step 4: Update Configuration

**File:** `lib/core/config/env.dart`

Add these constants:

```dart
// Legal URLs (update with your actual URLs)
static const String privacyPolicyUrl = 'https://yourapp.com/privacy';
static const String termsOfServiceUrl = 'https://yourapp.com/terms';
```

---

### Step 5: Create Archive Screen

**New File:** `lib/features/settings/screens/archive_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../articles/providers/article_providers.dart';
import '../providers/settings_providers.dart';

class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archivedArticles = ref.watch(archivedArticlesProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            title: const Text('Archived Articles'),
          ),
          archivedArticles.when(
            data: (articles) {
              if (articles.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.archive_outlined,
                          size: 64,
                          color: context.mutedTextColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No archived articles',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: context.mutedTextColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Archived articles will appear here',
                          style: TextStyle(color: context.mutedTextColor),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final article = articles[index];
                    return ListTile(
                      leading: article.imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                article.imageUrl!,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: context.surfaceColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.article_outlined,
                                color: context.mutedTextColor,
                              ),
                            ),
                      title: Text(
                        article.title ?? 'Untitled',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        article.siteName ?? Uri.parse(article.url).host,
                        style: TextStyle(color: context.mutedTextColor),
                      ),
                      trailing: PopupMenuButton(
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'restore',
                            child: ListTile(
                              leading: Icon(Icons.unarchive_outlined),
                              title: Text('Restore'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              leading: Icon(Icons.delete_outline, color: Colors.red),
                              title: Text('Delete', style: TextStyle(color: Colors.red)),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                        onSelected: (value) async {
                          final service = ref.read(supabaseServiceProvider);
                          if (value == 'restore') {
                            await service.restoreArticle(article.id);
                          } else if (value == 'delete') {
                            await service.deleteArticle(article.id);
                          }
                        },
                      ),
                      onTap: () => context.push('/article/${article.id}'),
                    );
                  },
                  childCount: articles.length,
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SliverFillRemaining(
              child: Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
  }
}
```

---

### Step 6: Update Router

**File:** `lib/core/router/app_router.dart`

Add the archive route. First import:
```dart
import '../../features/settings/screens/archive_screen.dart';
```

Then add this route alongside your other routes:
```dart
GoRoute(
  path: '/archive',
  name: 'archive',
  builder: (context, state) => const ArchiveScreen(),
),
```

---

### Step 7: Update Settings Screen

**File:** `lib/features/settings/screens/settings_screen.dart`

Replace the entire file with the updated implementation (see below for key changes):

**Add imports at the top:**
```dart
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';  // Add to pubspec if needed
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../../core/config/env.dart';
import '../providers/settings_providers.dart';
```

**Key changes to the widget:**

1. Watch settings provider at the start of build:
```dart
final settingsAsync = ref.watch(userSettingsProvider);
```

2. **Digest Time (line 30):**
```dart
_SettingsTile(
  icon: Icons.schedule_outlined,
  title: 'Digest Time',
  subtitle: settingsAsync.when(
    data: (s) => '${s.digestTime.hourOfPeriod}:${s.digestTime.minute.toString().padLeft(2, '0')} ${s.digestTime.period == DayPeriod.am ? 'AM' : 'PM'}',
    loading: () => 'Loading...',
    error: (_, __) => '8:00 AM',
  ),
  onTap: () async {
    final settings = ref.read(userSettingsProvider).value;
    if (settings == null) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: settings.digestTime,
    );
    if (picked != null) {
      ref.read(userSettingsProvider.notifier).updateDigestTime(picked);
    }
  },
),
```

3. **Push Notifications (line 40):**
```dart
trailing: settingsAsync.when(
  data: (s) => Switch(
    value: s.pushNotifications,
    onChanged: (value) {
      ref.read(userSettingsProvider.notifier).togglePushNotifications(value);
    },
  ),
  loading: () => const SizedBox(width: 48, height: 24, child: LinearProgressIndicator()),
  error: (_, __) => Switch(value: false, onChanged: null),
),
```

4. **Analyze Images (line 54):**
```dart
trailing: settingsAsync.when(
  data: (s) => Switch(
    value: s.analyzeImages,
    onChanged: (value) {
      ref.read(userSettingsProvider.notifier).toggleAnalyzeImages(value);
    },
  ),
  loading: () => const SizedBox(width: 48, height: 24, child: LinearProgressIndicator()),
  error: (_, __) => Switch(value: true, onChanged: null),
),
```

5. **Include Comments (line 65):**
```dart
trailing: settingsAsync.when(
  data: (s) => Switch(
    value: s.includeComments,
    onChanged: (value) {
      ref.read(userSettingsProvider.notifier).toggleIncludeComments(value);
    },
  ),
  loading: () => const SizedBox(width: 48, height: 24, child: LinearProgressIndicator()),
  error: (_, __) => Switch(value: true, onChanged: null),
),
```

6. **Auth Flow (line 77):**
```dart
onTap: () {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sign In'),
      content: const Text('Account sign-in is coming soon! Your data is currently synced anonymously.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
},
```

7. **Archive View (line 93):**
```dart
onTap: () => context.push('/archive'),
```

8. **Export Data (line 101):**
```dart
onTap: () => _showExportDialog(context, ref),
```

Add this method to the class:
```dart
void _showExportDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Export Data'),
      content: const Text('Export all your articles and digests as a JSON file?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await _performExport(context, ref);
          },
          child: const Text('Export'),
        ),
      ],
    ),
  );
}

Future<void> _performExport(BuildContext context, WidgetRef ref) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final service = ref.read(supabaseServiceProvider);
    final articles = await service.getAllArticlesForExport();
    final digests = await service.getAllDigestsForExport();

    final exportData = {
      'exportedAt': DateTime.now().toIso8601String(),
      'articles': articles.map((a) => a.toJson()).toList(),
      'digests': digests.map((d) => d.toJson()).toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

    // Save to temp file and share
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/readwise_export_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(jsonString);

    Navigator.pop(context);

    await Share.shareXFiles([XFile(file.path)], subject: 'Readwise Data Export');
  } catch (e) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Export failed: $e')),
    );
  }
}
```

9. **Privacy Policy (line 125):**
```dart
onTap: () async {
  final url = Uri.parse(Env.privacyPolicyUrl);
  if (await canLaunchUrl(url)) {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
},
```

10. **Terms of Service (line 132):**
```dart
onTap: () async {
  final url = Uri.parse(Env.termsOfServiceUrl);
  if (await canLaunchUrl(url)) {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
},
```

11. **Clear All Data (line 183):**
```dart
onPressed: () async {
  Navigator.pop(context);

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(child: CircularProgressIndicator()),
  );

  try {
    await ref.read(supabaseServiceProvider).clearAllData();
    Navigator.pop(context);

    ref.invalidate(articlesStreamProvider);
    ref.invalidate(digestsStreamProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All data cleared')),
    );
  } catch (e) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to clear data: $e')),
    );
  }
},
```

---

### Step 8: Add share_plus (if needed)

**File:** `pubspec.yaml`

Add under dependencies:
```yaml
share_plus: ^7.2.1
```

Then run `flutter pub get`.

---

## Summary of Files to Change

| File | Action |
|------|--------|
| `lib/core/models/models.dart` | Add `UserSettings` class |
| `lib/core/services/supabase_service.dart` | Add 8 new methods |
| `lib/core/config/env.dart` | Add URL constants |
| `lib/core/router/app_router.dart` | Add `/archive` route |
| `lib/features/settings/screens/settings_screen.dart` | Implement all TODOs |
| `lib/features/settings/providers/settings_providers.dart` | **CREATE NEW** |
| `lib/features/settings/screens/archive_screen.dart` | **CREATE NEW** |
| `pubspec.yaml` | Add `share_plus` if not present |

---

## Testing Checklist

- [ ] Open Settings screen - settings load without error
- [ ] Tap Digest Time - time picker appears, selection saves
- [ ] Toggle Push Notifications - switch works, persists on restart
- [ ] Toggle Analyze Images - switch works, persists on restart
- [ ] Toggle Include Comments - switch works, persists on restart
- [ ] Tap Sign In - "Coming Soon" dialog appears
- [ ] Tap Archived Articles - archive screen opens
- [ ] Archive an article, verify it appears in archive
- [ ] Restore archived article, verify it returns to library
- [ ] Tap Export Data - JSON file generated and share sheet opens
- [ ] Tap Privacy Policy - opens URL in browser
- [ ] Tap Terms of Service - opens URL in browser
- [ ] Tap Clear All Data - confirmation dialog appears
- [ ] Confirm Clear All Data - articles and digests are deleted
