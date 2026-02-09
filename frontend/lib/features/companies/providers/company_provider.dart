import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/company_model.dart';

/// Provider for fetching live stock quotes.
/// Usage: ref.watch(liveQuoteProvider('AAPL'))
final liveQuoteProvider =
    FutureProvider.family<LiveQuoteModel, String>((ref, ticker) async {
  final apiClient = ref.watch(apiClientProvider);

  final response = await apiClient.getCompanyLiveQuote(ticker);

  if (response.statusCode == 200) {
    return LiveQuoteModel.fromJson(response.data as Map<String, dynamic>);
  }

  throw Exception('Failed to fetch live quote for $ticker');
});

/// Provider for fetching price history for charts.
/// Usage: ref.watch(priceHistoryProvider(('AAPL', '1m')))
final priceHistoryProvider =
    FutureProvider.family<PriceHistoryModel, (String, String)>(
        (ref, params) async {
  final (ticker, range) = params;
  final apiClient = ref.watch(apiClientProvider);

  final response = await apiClient.getCompanyLiveHistory(ticker, range: range);

  if (response.statusCode == 200) {
    return PriceHistoryModel.fromJson(response.data as Map<String, dynamic>);
  }

  throw Exception('Failed to fetch price history for $ticker');
});

/// Provider to invalidate and refresh quote data.
/// Usage: ref.invalidate(liveQuoteProvider('AAPL'))
final refreshQuoteProvider =
    Provider.family<void Function(), String>((ref, ticker) {
  return () {
    ref.invalidate(liveQuoteProvider(ticker));
  };
});

/// Provider to invalidate and refresh price history.
final refreshHistoryProvider =
    Provider.family<void Function(), (String, String)>((ref, params) {
  return () {
    ref.invalidate(priceHistoryProvider(params));
  };
});
