# UI Fix Plan — Apple Review Rejection

**Date:** 2026-02-15
**Rejection Reason:** "Sign In" button doesn't do anything
**Goal:** Fix all dead/broken buttons and misleading UI before resubmission

---

## Test Results Summary

Full simulator UI test conducted on iPhone 16e (iOS 26.2). Every interactive element was tapped and verified.

| Element | Location | Status | Issue |
|---------|----------|--------|-------|
| Digest Time | Settings > Daily Digest | PASS | Opens time picker |
| Push Notifications toggle | Settings > Daily Digest | PASS | Toggles correctly |
| Analyze Images toggle | Settings > Content | PASS | Toggles correctly |
| Include Comments toggle | Settings > Content | PASS | Toggles correctly |
| Podcast Feed (no podcast) | Settings > Podcast | **FAIL** | No onTap handler when feedUrl is null — looks tappable but does nothing |
| **Sign In** | Settings > Account | **FAIL** | `// TODO: Auth flow` — completely dead button, has chevron suggesting navigation |
| Sync Status | Settings > Account | **FAIL** | Static "Last synced: Just now" text — misleading, no real sync exists |
| Archived Articles | Settings > Data | PASS | Navigates to archive screen |
| Export Data | Settings > Data | PASS | Opens share sheet with JSON export |
| Clear All Data | Settings > Data | PASS | Shows confirmation dialog |
| Privacy Policy | Settings > About | **WARN** | May fail silently on some devices — `launchUrl` without explicit `LaunchMode` |
| Terms of Service | Settings > About | PASS | Opens in-app browser to GitHub Pages |
| "View all N articles" | Digest card | **FAIL** | `// TODO: Show full digest view` — dead button |
| Library tab (empty) | Bottom nav | PASS | Shows empty state |
| Daily Digest tab (empty) | Bottom nav | PASS | Shows empty state |
| Settings tab | Bottom nav | PASS | Shows settings |

---

## Fixes Required

### FIX 1: Remove or replace "Sign In" button [CRITICAL — Apple rejection cause]

**File:** `lib/features/settings/screens/settings_screen.dart` lines 187-195

**Problem:** Button has `onTap: () { // TODO: Auth flow }` — does literally nothing. Apple explicitly rejected for this.

**Option A (Recommended): Remove the entire ACCOUNT section**
The app uses anonymous auth. There is no account system, no email/password, no OAuth. The "Sign In" and "Sync Status" rows are both fiction. Remove the entire section:

```dart
// DELETE these lines (187-200):
const _SectionHeader(title: 'Account'),
_SettingsTile(
  icon: Icons.person_outline,
  title: 'Sign In',
  subtitle: 'Sync your library across devices',
  onTap: () {
    // TODO: Auth flow
  },
),
_SettingsTile(
  icon: Icons.cloud_sync_outlined,
  title: 'Sync Status',
  subtitle: 'Last synced: Just now',
),
```

**Option B: Implement real Sign In with Apple**
If you want account sync in V1, implement Sign In with Apple (required by Apple if you offer any social login). This is significantly more work:
- Add `sign_in_with_apple` package
- Configure Supabase Apple OAuth provider
- Create auth state management
- Link anonymous data to Apple ID
- Build actual sync logic

**Recommendation:** Go with Option A. Remove the dead UI now, ship the fix, implement real auth in a future version.

---

### FIX 2: Remove "Sync Status" row [CRITICAL — misleading UI]

**File:** `lib/features/settings/screens/settings_screen.dart` lines 196-200

**Problem:** Shows "Last synced: Just now" but there is no sync functionality. This is misleading to both users and Apple reviewers.

**Fix:** Remove along with the Sign In button (see Fix 1, Option A).

---

### FIX 3: Fix "View all N articles" dead button in Digest [MODERATE]

**File:** `lib/features/digest/screens/digest_screen.dart` lines 307-319

**Problem:** When a digest has >3 articles, a "View all N articles" TextButton appears with `// TODO: Show full digest view` — it does nothing on tap.

**Fix:** Remove the article limit and show all articles inline, removing the dead button:

```dart
// REPLACE lines 303-319:
// OLD:
...digest.articles.take(3).map((article) => _DigestArticleTile(
      article: article,
      onTap: () => context.push('/article/${article.articleId}'),
    )),
if (digest.articles.length > 3)
  Padding(
    padding: const EdgeInsets.only(top: 8),
    child: TextButton(
      onPressed: () {
        // TODO: Show full digest view
      },
      child: Text(
        'View all ${digest.articles.length} articles',
        style: TextStyle(color: context.primaryColor),
      ),
    ),
  ),

// NEW:
...digest.articles.map((article) => _DigestArticleTile(
      article: article,
      onTap: () => context.push('/article/${article.articleId}'),
    )),
```

---

### FIX 4: Fix Podcast Feed tile when no podcast exists [LOW]

**File:** `lib/features/settings/screens/settings_screen.dart` lines 139-148

**Problem:** When `feedUrl == null`, the tile renders without an `onTap` handler. Visually looks the same as other tiles (same font, same layout). No chevron though, so it's less deceptive than Sign In.

**Fix:** Make it visually clear this is informational, not tappable. Either:
- Add a muted/disabled style, OR
- Remove the tile entirely when no podcast exists and only show the explanatory text

```dart
// REPLACE lines 142-148:
if (feedUrl == null) {
  return _SettingsTile(
    icon: Icons.podcasts_outlined,
    title: 'Podcast Feed',
    subtitle: 'Save articles to generate your first podcast',
    // No onTap — already has no chevron since onTap is null
    // The _SettingsTile only shows chevron when onTap != null, so this is OK
  );
}
```

**Verdict:** This is actually fine as-is — no chevron is shown when `onTap` is null (the `_SettingsTile` widget only adds a chevron when `onTap != null`). However, Apple might still tap it and notice nothing happens. Safest fix: add an `onTap` that shows a SnackBar saying "Save articles to generate your first podcast episode."

```dart
if (feedUrl == null) {
  return _SettingsTile(
    icon: Icons.podcasts_outlined,
    title: 'Podcast Feed',
    subtitle: 'Save articles to generate your first podcast',
    onTap: () {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Save some articles first — your podcast feed will appear here.'),
          duration: Duration(seconds: 2),
        ),
      );
    },
  );
}
```

---

### FIX 5: Ensure Privacy Policy opens reliably [LOW]

**File:** `lib/features/settings/screens/settings_screen.dart` line 249

**Problem:** `launchUrl` without explicit `LaunchMode` may fail silently on some devices/simulators. Terms of Service works but Privacy Policy was inconsistent in testing.

**Fix:** Add explicit launch mode matching Terms of Service behavior:

```dart
// OLD:
onTap: () => launchUrl(Uri.parse(Env.privacyPolicyUrl)),

// NEW:
onTap: () => launchUrl(
  Uri.parse(Env.privacyPolicyUrl),
  mode: LaunchMode.inAppBrowserView,
),
```

Apply the same to Terms of Service for consistency:

```dart
onTap: () => launchUrl(
  Uri.parse(Env.termsOfServiceUrl),
  mode: LaunchMode.inAppBrowserView,
),
```

---

## Implementation Order

1. **FIX 1 + FIX 2:** Remove ACCOUNT section (Sign In + Sync Status) — **this alone should pass Apple review**
2. **FIX 3:** Remove dead "View all" button in digest
3. **FIX 4:** Add feedback to Podcast Feed tile
4. **FIX 5:** Add explicit LaunchMode to Privacy Policy / ToS

## Files Changed

| File | Changes |
|------|---------|
| `lib/features/settings/screens/settings_screen.dart` | Remove ACCOUNT section, fix Podcast Feed tile, fix Privacy Policy launch mode |
| `lib/features/digest/screens/digest_screen.dart` | Remove dead "View all" button, show all articles |

## Post-Fix Verification

1. Build to simulator
2. Tap every Settings tile — verify none are dead
3. Navigate to each tab — verify no dead buttons
4. Check Privacy Policy and Terms of Service both open
5. If you have digests with >3 articles, verify they all show without a dead "View all" button

## Resubmission Notes

- Bump version/build number in `ios/Runner.xcodeproj/project.pbxproj` (both Runner AND ShareExtension targets)
- Push to main branch for Xcode Cloud to pick up
- In App Store Connect review notes, mention: "Fixed: Removed placeholder Sign In button that was non-functional. The app uses anonymous authentication and does not require user accounts."
