import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../subscription/providers/subscription_provider.dart';
import 'home_provider.dart';

/// Result of attempting to add an investor
class AddInvestorResult {
  final bool success;
  final String? investorId;
  final String? message;
  final bool limitReached;

  const AddInvestorResult({
    required this.success,
    this.investorId,
    this.message,
    this.limitReached = false,
  });

  factory AddInvestorResult.success(String investorId) {
    return AddInvestorResult(
      success: true,
      investorId: investorId,
    );
  }

  factory AddInvestorResult.limitReached({String? message}) {
    return AddInvestorResult(
      success: false,
      message: message ?? 'You\'ve reached your tracking limit.',
      limitReached: true,
    );
  }

  factory AddInvestorResult.error(String message) {
    return AddInvestorResult(
      success: false,
      message: message,
    );
  }
}

/// Provider to check if user can add more investors
final canAddInvestorProvider = Provider<bool>((ref) {
  final subscriptionAsync = ref.watch(subscriptionProvider);

  return subscriptionAsync.when(
    data: (subscription) => subscription?.canAddInvestor ?? true,
    loading: () => false, // Be conservative while loading
    error: (_, __) => true, // Allow on error (will fail at API level if needed)
  );
});

/// Provider for current tracking count
final trackingCountProvider = Provider<int>((ref) {
  final subscriptionAsync = ref.watch(subscriptionProvider);

  return subscriptionAsync.when(
    data: (subscription) => subscription?.monitoredInvestorsCount ?? 0,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Provider for tracking limit
final trackingLimitProvider = Provider<int>((ref) {
  final subscriptionAsync = ref.watch(subscriptionProvider);

  return subscriptionAsync.when(
    data: (subscription) => subscription?.maxMonitoredInvestors ?? 1,
    loading: () => 1,
    error: (_, __) => 1,
  );
});

/// Notifier for managing investor tracking
class InvestorTrackingNotifier extends StateNotifier<AsyncValue<void>> {
  final ApiClient _apiClient;
  final Ref _ref;

  InvestorTrackingNotifier(this._apiClient, this._ref) : super(const AsyncValue.data(null));

  /// Add an investor to tracking watchlist
  /// Returns AddInvestorResult with success status and details
  Future<AddInvestorResult> addInvestor(String investorId) async {
    // Check subscription limits first
    final canAdd = _ref.read(canAddInvestorProvider);

    if (!canAdd) {
      final limit = _ref.read(trackingLimitProvider);
      return AddInvestorResult.limitReached(
        message: 'You\'re tracking $limit investor${limit == 1 ? '' : 's'}, '
            'the maximum for your plan.',
      );
    }

    state = const AsyncValue.loading();

    try {
      final response = await _apiClient.addToWatchlist(investorId);

      if (response.statusCode == 201 || response.statusCode == 200) {
        state = const AsyncValue.data(null);
        // Refresh subscription to update counts and tracked investors list
        _ref.invalidate(subscriptionProvider);
        _ref.invalidate(trackedInvestorsProvider);
        return AddInvestorResult.success(investorId);
      } else if (response.statusCode == 403) {
        state = const AsyncValue.data(null);
        final detail = response.data?['detail'] ?? 'Tracking limit reached';
        return AddInvestorResult.limitReached(message: detail);
      } else if (response.statusCode == 400) {
        state = const AsyncValue.data(null);
        final detail = response.data?['detail'] ?? 'Invalid request';
        return AddInvestorResult.error(detail);
      } else {
        state = const AsyncValue.data(null);
        final detail = response.data?['detail'] ?? 'Failed to add investor';
        return AddInvestorResult.error(detail);
      }
    } on DioException catch (e) {
      state = const AsyncValue.data(null);
      // Extract error message from DioException response
      final statusCode = e.response?.statusCode;
      final detail = e.response?.data?['detail'];

      if (statusCode == 403) {
        return AddInvestorResult.limitReached(
          message: detail ?? 'Tracking limit reached',
        );
      } else if (statusCode == 400) {
        return AddInvestorResult.error(detail ?? 'Investor already in watchlist');
      } else if (statusCode == 404) {
        return AddInvestorResult.error(detail ?? 'Investor not found');
      } else {
        return AddInvestorResult.error(detail ?? 'Failed to add investor');
      }
    } catch (e) {
      state = const AsyncValue.data(null);
      return AddInvestorResult.error('Network error. Please try again.');
    }
  }

  /// Remove an investor from tracking
  Future<bool> removeInvestor(String watchlistItemId) async {
    state = const AsyncValue.loading();

    try {
      final response = await _apiClient.removeFromWatchlist(watchlistItemId);

      if (response.statusCode == 200 || response.statusCode == 204) {
        state = const AsyncValue.data(null);
        // Refresh subscription to update counts and tracked investors list
        _ref.invalidate(subscriptionProvider);
        _ref.invalidate(trackedInvestorsProvider);
        return true;
      }
    } catch (e) {
      // Error removing
    }

    state = const AsyncValue.data(null);
    return false;
  }
}

/// Provider for investor tracking operations
final investorTrackingProvider =
    StateNotifierProvider<InvestorTrackingNotifier, AsyncValue<void>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return InvestorTrackingNotifier(apiClient, ref);
});
