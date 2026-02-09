# WhyTheyBuy - Frontend

A cross-platform Flutter app (Web + iOS + Android) that tracks and summarizes portfolio/holdings changes of notable investors and institutions.

## Getting Started

### Prerequisites
- Flutter SDK 3.0+
- Dart SDK 3.0+

### Installation

```bash
# Get dependencies
flutter pub get

# Generate code (Riverpod providers, JSON serialization)
dart run build_runner build --delete-conflicting-outputs

# Run on web
flutter run -d chrome

# Run on iOS
flutter run -d ios

# Run on Android
flutter run -d android

# Run tests
flutter test
```

## Architecture

### Project Structure

```
lib/
├── core/                    # Shared infrastructure
│   ├── network/            # API client, interceptors
│   ├── providers/          # Global providers (locale, cache, auth)
│   ├── router/             # GoRouter configuration
│   ├── theme/              # Colors, typography, themes
│   └── widgets/            # Shared UI components
├── features/               # Feature modules
│   ├── auth/              # Authentication
│   ├── home/              # Home page, watchlist
│   ├── investors/         # Investor detail, AI reasoning
│   ├── landing/           # Landing page, pricing
│   ├── settings/          # User preferences
│   └── subscription/      # Subscription management
├── l10n/                   # Localization (8 languages)
└── main.dart              # App entry point
```

### State Management

We use **Riverpod** for state management with the following patterns:

- `FutureProvider.family` for API data with parameters
- `StateNotifierProvider` for complex state with mutations
- `Provider` for computed/derived state

---

## Caching Strategy

### Overview

The app implements a **TTL-based caching system** to balance data freshness with performance. Cache is managed at two levels:

1. **Riverpod Provider Cache** - In-memory cache with TTL
2. **Browser Cache** - Static assets with content-addressed filenames

### TTL Configuration

| Data Type | TTL Duration | Rationale |
|-----------|--------------|-----------|
| Live Stock Quotes | 5 minutes | Markets move frequently |
| Price History | 30 minutes | Moderate refresh needed |
| Holdings/Portfolio | 1 hour | Updated daily after market close |
| Investor Profile | 6 hours | Metadata rarely changes |
| AI Content | 12 hours | Expensive to generate |
| User Subscription | 1 hour | Periodic check sufficient |
| Watchlist | 10 minutes | Moderate change frequency |
| Search Results | 30 minutes | Query-specific, lower priority |

### Cache Implementation

Located in `lib/core/providers/cache_provider.dart`:

```dart
// TTL durations
class CacheTTL {
  static const Duration liveQuotes = Duration(minutes: 5);
  static const Duration holdings = Duration(hours: 1);
  static const Duration investorProfile = Duration(hours: 6);
  static const Duration aiContent = Duration(hours: 12);
  // ... more
}

// Cached data with expiration
class CachedData<T> {
  final T data;
  final DateTime cachedAt;
  final Duration ttl;

  bool get isExpired => DateTime.now().difference(cachedAt) > ttl;
}
```

### Cache Invalidation

Cache is invalidated in these scenarios:

| Trigger | What Happens |
|---------|--------------|
| **Pull-to-refresh** | Clears TTL cache + invalidates Riverpod providers |
| **TTL expiration** | Automatic refetch on next access |
| **Language change** | AI reasoning cache invalidated |
| **Watchlist update** | Related caches invalidated |
| **App restart** | In-memory cache cleared |

### User Experience

```
User Action              → Cache Behavior
─────────────────────────────────────────────────
Open app (first time)    → Fresh fetch from API
Navigate to investor     → Check cache → return if valid, else fetch
Pull down to refresh     → Clear cache → fresh fetch
Wait > TTL, navigate     → Cache expired → fresh fetch
Change language          → AI content refetched in new language
```

### Manual Cache Control

```dart
// Clear cache for specific investor
clearInvestorCache(ref, investorId);

// Clear all caches (e.g., on logout)
clearAllCaches(ref);
```

---

## Backend Data Refresh Schedule

The backend uses **Celery Beat** for scheduled data updates:

| Task | Schedule (UTC) | Description |
|------|----------------|-------------|
| ARK Daily Ingestion | 23:00 daily | ETF holdings after market close |
| 13F Filing Check | 08:00 daily | SEC quarterly filings |
| Company Profile Refresh | 06:00 Sunday | Company metadata |
| Daily Digest Email | 07:00 daily | User notifications |
| Weekly Digest Email | 08:00 Sunday | Weekly summary |

---

## Localization

The app supports 8 languages:
- English (en)
- Chinese (zh)
- Spanish (es)
- Japanese (ja)
- Korean (ko)
- German (de)
- French (fr)
- Arabic (ar)

### Adding Translations

1. Add keys to `lib/l10n/app_en.arb` (template)
2. Add translations to other `.arb` files
3. Run `flutter pub get` to regenerate

### Language Change Handling

Pages watch `localeProvider` to rebuild on language change:

```dart
Widget build(BuildContext context, WidgetRef ref) {
  ref.watch(localeProvider); // Rebuild on language change
  final l10n = AppLocalizations.of(context);
  // ...
}
```

---

## Production Deployment

### Web Deployment Cache Headers

Include `web/cache-headers.conf` in your nginx configuration:

```nginx
# Static assets - 1 year cache (content-hashed)
location ~* \.(js|css|woff|woff2|ttf|eot|ico|png|jpg|jpeg|gif|svg)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}

# HTML - no cache (always fresh)
location ~* \.html$ {
    expires -1;
    add_header Cache-Control "no-store, no-cache, must-revalidate";
}

# Service worker - no cache
location = /flutter_service_worker.js {
    expires -1;
    add_header Cache-Control "no-store, no-cache, must-revalidate";
}
```

### Build for Production

```bash
flutter build web --release
```

---

## Development

### Run with Hot Reload

```bash
flutter run -d chrome
```

### Code Generation

After modifying models or providers:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Localization Generation

After modifying `.arb` files:

```bash
flutter pub get
```
