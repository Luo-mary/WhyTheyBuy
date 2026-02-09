import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/reasoning_card.dart';
import 'investor_detail_provider.dart';

// ============================================================================
// COMBINED TRANSACTION REPORT PROVIDERS
// ============================================================================

/// Parameters for fetching combined report data.
/// Keys are in format "TICKER_CHANGETYPE" e.g. "OXY_ADDED", "OXY_SOLD_OUT"
typedef CombinedReportParams = ({
  String investorId,
  String investorName,
  List<String> keys,  // Format: "TICKER_CHANGETYPE"
});

/// Parse a unique key to extract ticker and changeType.
/// Key format: "TICKER_CHANGETYPE" e.g. "OXY_ADDED", "OXY_SOLD_OUT"
(String ticker, String changeType) _parseKey(String key) {
  // Find the last underscore to split (in case ticker has underscore)
  final lastUnderscoreIndex = key.lastIndexOf('_');
  if (lastUnderscoreIndex == -1) {
    return (key, '');
  }
  final ticker = key.substring(0, lastUnderscoreIndex);
  final changeType = key.substring(lastUnderscoreIndex + 1);
  return (ticker, changeType);
}

/// State class for tracking combined report loading progress.
class CombinedReportState {
  final List<MultiAgentReasoningResponse> results;
  final int totalCount;
  final int loadedCount;
  final String? currentTicker;
  final String? error;
  final bool isComplete;

  const CombinedReportState({
    this.results = const [],
    this.totalCount = 0,
    this.loadedCount = 0,
    this.currentTicker,
    this.error,
    this.isComplete = false,
  });

  CombinedReportState copyWith({
    List<MultiAgentReasoningResponse>? results,
    int? totalCount,
    int? loadedCount,
    String? currentTicker,
    String? error,
    bool? isComplete,
  }) {
    return CombinedReportState(
      results: results ?? this.results,
      totalCount: totalCount ?? this.totalCount,
      loadedCount: loadedCount ?? this.loadedCount,
      currentTicker: currentTicker ?? this.currentTicker,
      error: error,
      isComplete: isComplete ?? this.isComplete,
    );
  }

  double get progress => totalCount > 0 ? loadedCount / totalCount : 0;
}

/// Notifier that manages loading combined report data with progress tracking.
class CombinedReportNotifier extends StateNotifier<CombinedReportState> {
  final Ref ref;

  CombinedReportNotifier(this.ref) : super(const CombinedReportState());

  /// Fetch AI reasoning for all selected transactions.
  /// Keys are in format "TICKER_CHANGETYPE" e.g. "OXY_ADDED", "OXY_SOLD_OUT"
  /// Updates state incrementally as each transaction's data is loaded.
  Future<void> loadReport(CombinedReportParams params) async {
    if (params.keys.isEmpty) {
      state = const CombinedReportState(isComplete: true);
      return;
    }

    // Parse keys to get ticker and changeType
    final parsedKeys = params.keys.map((key) {
      final parsed = _parseKey(key);
      return (key: key, ticker: parsed.$1, changeType: parsed.$2);
    }).toList();

    state = CombinedReportState(
      totalCount: parsedKeys.length,
      loadedCount: 0,
      currentTicker: parsedKeys.first.ticker,
    );

    final results = <MultiAgentReasoningResponse>[];

    for (int i = 0; i < parsedKeys.length; i++) {
      final entry = parsedKeys[i];

      state = state.copyWith(
        currentTicker: '${entry.ticker} (${entry.changeType})',
        loadedCount: i,
      );

      try {
        debugPrint('CombinedReport: Loading reasoning for ${entry.ticker} (${entry.changeType})');

        // Use the existing multiAgentReasoningProvider with changeType parameter
        final response = await ref.read(
          multiAgentReasoningProvider(
            (
              investorId: params.investorId,
              ticker: entry.ticker,
              changeType: entry.changeType,
            ),
          ).future,
        );

        if (response != null) {
          // Always add the result - the backend already tried to find the best match
          results.add(response);
          if (response.changeType.toUpperCase() != entry.changeType.toUpperCase()) {
            debugPrint('CombinedReport: Note - expected ${entry.changeType} but got ${response.changeType} for ${entry.ticker}');
          }
          debugPrint('CombinedReport: Loaded ${response.cards.length} cards for ${entry.ticker} (${response.changeType})');
        } else {
          debugPrint('CombinedReport: No response for ${entry.ticker}');
        }
      } catch (e) {
        debugPrint('CombinedReport: Error loading ${entry.ticker} - $e');
        // Continue loading other transactions even if one fails
      }

      state = state.copyWith(
        results: List.from(results),
        loadedCount: i + 1,
      );
    }

    state = state.copyWith(
      isComplete: true,
      currentTicker: null,
    );

    debugPrint('CombinedReport: Complete - loaded ${results.length}/${parsedKeys.length} transactions');
  }

  /// Reset the state for a new report.
  void reset() {
    state = const CombinedReportState();
  }
}

/// Provider for the combined report notifier.
final combinedReportNotifierProvider =
    StateNotifierProvider<CombinedReportNotifier, CombinedReportState>((ref) {
  return CombinedReportNotifier(ref);
});

/// Simple provider that fetches all reasoning data at once (without progress).
/// Use this for simple cases; use combinedReportNotifierProvider for progress tracking.
final combinedReportProvider = FutureProvider.family<
    List<MultiAgentReasoningResponse>, CombinedReportParams>(
  (ref, params) async {
    final results = <MultiAgentReasoningResponse>[];

    for (final key in params.keys) {
      final parsed = _parseKey(key);
      final ticker = parsed.$1;
      final changeType = parsed.$2;

      try {
        final response = await ref.read(
          multiAgentReasoningProvider(
            (investorId: params.investorId, ticker: ticker, changeType: changeType),
          ).future,
        );

        if (response != null) {
          results.add(response);
        }
      } catch (e) {
        debugPrint('CombinedReport: Error loading $ticker ($changeType) - $e');
      }
    }

    return results;
  },
);
