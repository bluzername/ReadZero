import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'core/config/env.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/articles/providers/article_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase for push notifications
  await Firebase.initializeApp();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );
  
  runApp(const ProviderScope(child: ReadwiseApp()));
}

class ReadwiseApp extends ConsumerStatefulWidget {
  const ReadwiseApp({super.key});

  @override
  ConsumerState<ReadwiseApp> createState() => _ReadwiseAppState();
}

class _ReadwiseAppState extends ConsumerState<ReadwiseApp> {
  @override
  void initState() {
    super.initState();
    _initShareIntent();
  }

  void _initShareIntent() {
    // Handle shared content when app is opened via share
    ReceiveSharingIntent.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleSharedContent(value);
      }
    });

    // Handle shared content when app is already running
    ReceiveSharingIntent.getMediaStream().listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleSharedContent(value);
      }
    });

    // Handle shared text/URLs
    ReceiveSharingIntent.getInitialText().then((String? value) {
      if (value != null) {
        _handleSharedUrl(value);
      }
    });

    ReceiveSharingIntent.getTextStream().listen((String value) {
      _handleSharedUrl(value);
    });
  }

  void _handleSharedContent(List<SharedMediaFile> files) {
    // Handle media files if needed
    for (final file in files) {
      debugPrint('Shared file: ${file.path}');
    }
  }

  void _handleSharedUrl(String text) {
    // Extract URL from shared text
    final urlRegex = RegExp(
      r'https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
    );
    final match = urlRegex.firstMatch(text);
    
    if (match != null) {
      final url = match.group(0)!;
      ref.read(articleServiceProvider).saveArticle(url: url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Readwise',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
