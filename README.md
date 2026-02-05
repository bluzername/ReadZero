# ReadZero - Intelligent Reading List

A cross-platform mobile app that serves as a smart reading list destination. Share any article, blog post, or web page, and get AI-powered daily digests with intelligent summaries.

![Flutter](https://img.shields.io/badge/Flutter-3.19+-blue)
![Supabase](https://img.shields.io/badge/Supabase-Backend-green)
![Claude AI](https://img.shields.io/badge/Claude-Haiku%203.5-orange)

## Features

- **📱 Share Extension** - Share from any app on iOS
- **📄 Full Content Extraction** - Extracts article text, images, and comments
- **🐦 X/Twitter Support** - Native X post extraction via Grok API
- **🤖 AI Analysis** - Multi-level summaries using Claude via OpenRouter
- **📊 Daily Digest** - Intelligent summaries with theme detection
- **🌙 Dark Mode Icons** - iOS 18+ dark mode app icon support
- **🎨 Beautiful Reader UI** - Clean, modern interface

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Flutter App                          │
│  Share Extension → App Group → Main App → Supabase Sync    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Supabase Backend                       │
│  PostgreSQL │ Edge Functions │ Realtime │ Auth             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    External Services                        │
│  Jina Reader │ Claude (OpenRouter) │ Grok API (xAI)        │
└─────────────────────────────────────────────────────────────┘
```

## Setup

### Prerequisites

- Flutter SDK 3.19+
- Supabase account
- OpenRouter API key (for Claude)
- Jina AI API key (for article extraction)
- xAI API key (for X/Twitter extraction)

### 1. Clone & Install Dependencies

```bash
git clone https://github.com/bluzername/ReadZero.git
cd ReadZero
flutter pub get
```

### 2. Supabase Setup

1. Create a new Supabase project at [supabase.com](https://supabase.com)

2. Run the database migrations:
   ```bash
   # Copy the SQL from supabase/migrations/
   # Paste and run in Supabase SQL Editor
   ```

3. Deploy Edge Functions:
   ```bash
   # Install Supabase CLI
   npm install -g supabase

   # Login and link
   supabase login
   supabase link --project-ref YOUR_PROJECT_REF

   # Set secrets
   supabase secrets set OPENROUTER_API_KEY=your_key
   supabase secrets set JINA_API_KEY=your_key
   supabase secrets set XAI_API_KEY=your_key

   # Deploy functions
   supabase functions deploy extract-article --no-verify-jwt
   supabase functions deploy generate-digest --no-verify-jwt
   ```

### 3. Configure the App

Edit `lib/core/config/env.dart`:

```dart
class Env {
  static const String supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
  static const String supabaseAnonKey = 'YOUR_ANON_KEY';
}
```

### 4. iOS Setup

The iOS project is pre-configured with:
- Share Extension for saving URLs
- App Groups for extension communication
- Dark mode app icons

Bundle ID: `live.bluzername.readzero.app`

### 5. Run the App

```bash
# iOS
flutter run -d ios --release
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
│   ├── articles/                # Article display
│   ├── digest/                  # Daily digest
│   ├── home/                    # Library view
│   └── settings/                # Settings

supabase/
├── migrations/                  # Database schema
└── functions/
    ├── extract-article/         # Content extraction + Grok
    └── generate-digest/         # AI digest generation

ios/
├── Runner/                      # Main app
└── ShareExtension/              # iOS share extension

docs/
├── privacy-policy.md            # Privacy Policy
└── terms-of-service.md          # Terms of Service
```

## License

MIT
