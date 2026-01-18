# Readwise - Intelligent Reading List

A cross-platform mobile app that serves as a smart reading list destination. Share any article, blog post, or web page, and get AI-powered daily digests with intelligent summaries.

![Flutter](https://img.shields.io/badge/Flutter-3.19+-blue)
![Supabase](https://img.shields.io/badge/Supabase-Backend-green)
![Claude AI](https://img.shields.io/badge/Claude-Haiku%204.5-orange)

## Features

- **📱 Share Extension** - Share from any app on iOS or Android
- **📄 Full Content Extraction** - Extracts article text, images, and comments
- **🤖 AI Analysis** - Multi-modal analysis of text and images using Claude
- **📊 Daily Digest** - Intelligent summaries every day at 8 AM
- **🎨 Beautiful Reader UI** - Clean, Perplexity-inspired interface
- **🔄 Cross-Platform** - Single Flutter codebase for iOS and Android

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Flutter App                          │
│  Share Extension → Local Storage → Supabase Sync           │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Supabase Backend                       │
│  PostgreSQL │ Edge Functions │ Realtime │ Auth │ pg_cron   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    External Services                        │
│  Jina Reader API │ Claude API (Haiku 4.5) │ FCM            │
└─────────────────────────────────────────────────────────────┘
```

## Setup

### Prerequisites

- Flutter SDK 3.19+
- Supabase account
- Anthropic API key (for Claude)
- Jina AI API key (optional, for enhanced extraction)

### 1. Clone & Install Dependencies

```bash
git clone <repo>
cd readwise-app
flutter pub get
```

### 2. Supabase Setup

1. Create a new Supabase project at [supabase.com](https://supabase.com)

2. Run the database migration:
   ```bash
   # Copy the SQL from supabase/migrations/001_initial_schema.sql
   # Paste and run in Supabase SQL Editor
   ```

3. Enable the `pg_cron` extension (for scheduled digests):
   - Go to Database → Extensions
   - Enable `pg_cron`

4. Deploy Edge Functions:
   ```bash
   # Install Supabase CLI
   npm install -g supabase
   
   # Login
   supabase login
   
   # Link to your project
   supabase link --project-ref YOUR_PROJECT_REF
   
   # Set secrets
   supabase secrets set ANTHROPIC_API_KEY=your_anthropic_key
   supabase secrets set JINA_API_KEY=your_jina_key  # Optional
   
   # Deploy functions
   supabase functions deploy extract-article
   supabase functions deploy generate-digest
   ```

5. Update the cron job URLs in the migration file with your actual Supabase URL and service role key.

### 3. Configure the App

Edit `lib/core/config/env.dart`:

```dart
class Env {
  static const String supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
  static const String supabaseAnonKey = 'YOUR_ANON_KEY';
  static const String jinaApiKey = 'YOUR_JINA_KEY'; // Optional
}
```

### 4. iOS Setup

1. Open `ios/Runner.xcworkspace` in Xcode

2. Add Share Extension target:
   - File → New → Target → Share Extension
   - Name it "ShareExtension"
   - Copy `ShareViewController.swift` to the extension

3. Configure App Groups:
   - Select main target → Signing & Capabilities
   - Add "App Groups" capability
   - Create group: `group.com.readwise.app`
   - Add same group to Share Extension target

4. Update `ios/Runner/Info.plist`:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLSchemes</key>
       <array>
         <string>readwise</string>
       </array>
     </dict>
   </array>
   ```

### 5. Android Setup

1. Update `android/app/src/main/AndroidManifest.xml`:

```xml
<activity
    android:name=".ShareActivity"
    android:exported="true"
    android:theme="@style/Theme.AppCompat.Light">
    <intent-filter>
        <action android:name="android.intent.action.SEND" />
        <category android:name="android.intent.category.DEFAULT" />
        <data android:mimeType="text/plain" />
    </intent-filter>
</activity>
```

2. Add to `android/app/build.gradle`:
```gradle
android {
    defaultConfig {
        // ...
        manifestPlaceholders = [
            'appAuthRedirectScheme': 'com.readwise.app'
        ]
    }
}
```

### 6. Firebase Setup (Push Notifications)

1. Create Firebase project at [console.firebase.google.com](https://console.firebase.google.com)

2. Add iOS and Android apps

3. Download config files:
   - `GoogleService-Info.plist` → `ios/Runner/`
   - `google-services.json` → `android/app/`

4. Follow FlutterFire setup:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

### 7. Run the App

```bash
# iOS
flutter run -d ios

# Android
flutter run -d android
```

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── core/
│   ├── config/env.dart          # Environment configuration
│   ├── models/models.dart       # Data models
│   ├── router/app_router.dart   # Navigation
│   ├── services/supabase_service.dart
│   └── theme/app_theme.dart     # Design system
├── features/
│   ├── articles/
│   │   ├── providers/           # Riverpod providers
│   │   └── screens/             # Article views
│   ├── digest/
│   │   └── screens/             # Daily digest view
│   ├── home/
│   │   └── screens/             # Library view
│   └── settings/
│       └── screens/             # Settings
└── shared/
    └── widgets/                 # Reusable widgets

supabase/
├── migrations/
│   └── 001_initial_schema.sql   # Database schema
└── functions/
    ├── extract-article/         # Content extraction
    └── generate-digest/         # Digest generation

ios/
└── ShareExtension/              # iOS share extension

android/
└── app/src/main/kotlin/
    └── com/readwise/share/      # Android share handling
```

## API Costs Estimate

| Service | Usage | Cost |
|---------|-------|------|
| Supabase | Free tier | $0 |
| Claude Haiku 4.5 | ~$0.00025/article | ~$0.25/1000 articles |
| Jina Reader | Free tier (1000/day) | $0 |
| Firebase | Free tier | $0 |

**Estimated monthly cost for 100 articles/day: ~$0.75**

## Roadmap

- [ ] Manual digest trigger
- [ ] Custom digest schedule
- [ ] Tags/folders organization
- [ ] Search across articles
- [ ] Export to Notion/Obsidian
- [ ] Web app version
- [ ] Offline reading
- [ ] Podcast/video support

## Contributing

PRs welcome! Please follow the existing code style and add tests for new features.

## License

MIT
