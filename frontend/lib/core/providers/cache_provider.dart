import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cached data with TTL (Time-To-Live) support
class CachedData<T> {
  final T data;
  final DateTime cachedAt;
  final Duration ttl;

  CachedData({
    required this.data,
    required this.cachedAt,
    required this.ttl,
  });

  bool get isExpired => DateTime.now().difference(cachedAt) > ttl;

  Duration get age => DateTime.now().difference(cachedAt);

  String get ageDisplay {
    final minutes = age.inMinutes;
    if (minutes < 1) return 'Just now';
    if (minutes < 60) return '$minutes min ago';
    final hours = age.inHours;
    if (hours < 24) return '$hours hr ago';
    return '${age.inDays} days ago';
  }
}

/// TTL durations for different data types
class CacheTTL {
  /// Live stock quotes - refresh frequently
  static const Duration liveQuotes = Duration(minutes: 5);

  /// Price history - moderate refresh
  static const Duration priceHistory = Duration(minutes: 30);

  /// Holdings and portfolio data - updated daily typically
  static const Duration holdings = Duration(hours: 1);

  /// Investor profile metadata - rarely changes
  static const Duration investorProfile = Duration(hours: 6);

  /// AI-generated content - expensive to generate
  static const Duration aiContent = Duration(hours: 12);

  /// User subscription - check periodically
  static const Duration subscription = Duration(hours: 1);

  /// Watchlist data - moderate refresh
  static const Duration watchlist = Duration(minutes: 10);

  /// Search results - lower priority
  static const Duration search = Duration(minutes: 30);
}

/// Generic cache store for any data type with TTL support
class CacheStore<K, V> extends StateNotifier<Map<K, CachedData<V>>> {
  CacheStore() : super({});

  /// Get cached data if not expired, null otherwise
  CachedData<V>? get(K key) {
    final cached = state[key];
    if (cached == null || cached.isExpired) {
      return null;
    }
    return cached;
  }

  /// Store data with TTL
  void set(K key, V data, Duration ttl) {
    state = {
      ...state,
      key: CachedData(
        data: data,
        cachedAt: DateTime.now(),
        ttl: ttl,
      ),
    };
  }

  /// Remove specific key
  void remove(K key) {
    final newState = Map<K, CachedData<V>>.from(state);
    newState.remove(key);
    state = newState;
  }

  /// Clear all cached data
  void clear() {
    state = {};
  }

  /// Remove all expired entries
  void purgeExpired() {
    state = Map.fromEntries(
      state.entries.where((e) => !e.value.isExpired),
    );
  }
}

/// Provider for investor detail cache
final investorDetailCacheProvider =
    StateNotifierProvider<CacheStore<String, Map<String, dynamic>>, Map<String, CachedData<Map<String, dynamic>>>>((ref) {
  return CacheStore();
});

/// Provider for investor changes cache
final investorChangesCacheProvider =
    StateNotifierProvider<CacheStore<String, List<dynamic>>, Map<String, CachedData<List<dynamic>>>>((ref) {
  return CacheStore();
});

/// Provider for portfolio overview cache
final portfolioOverviewCacheProvider =
    StateNotifierProvider<CacheStore<String, Map<String, dynamic>?>, Map<String, CachedData<Map<String, dynamic>?>>>((ref) {
  return CacheStore();
});

/// Provider for live quote cache
final liveQuoteCacheProvider =
    StateNotifierProvider<CacheStore<String, Map<String, dynamic>?>, Map<String, CachedData<Map<String, dynamic>?>>>((ref) {
  return CacheStore();
});

/// Helper to check if data is fresh or needs refresh
bool isCacheFresh<T>(CachedData<T>? cached) {
  return cached != null && !cached.isExpired;
}

/// Helper to clear all investor-related caches for a specific investor
void clearInvestorCache(WidgetRef ref, String investorId) {
  ref.read(investorDetailCacheProvider.notifier).remove(investorId);
  ref.read(investorChangesCacheProvider.notifier).remove(investorId);
  ref.read(portfolioOverviewCacheProvider.notifier).remove(investorId);
}

/// Helper to clear all caches (useful for logout or full refresh)
void clearAllCaches(WidgetRef ref) {
  ref.read(investorDetailCacheProvider.notifier).clear();
  ref.read(investorChangesCacheProvider.notifier).clear();
  ref.read(portfolioOverviewCacheProvider.notifier).clear();
  ref.read(liveQuoteCacheProvider.notifier).clear();
}
