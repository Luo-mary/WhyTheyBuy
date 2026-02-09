import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers/cache_provider.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/evidence_panel.dart';
import '../models/reasoning_card.dart';

// ============================================================================
// DATA MODELS
// ============================================================================

class StockTradeData {
  final String action; // 'BUY' or 'SELL'
  final String shares;
  final String value;
  final String date;
  final String fund;

  const StockTradeData({
    required this.action,
    required this.shares,
    required this.value,
    required this.date,
    required this.fund,
  });
}

class StockChangeItem {
  final String ticker;
  final String name;
  final String changeType; // 'NEW', 'ADDED', 'REDUCED', 'SOLD_OUT'
  final String sharesDelta; // Formatted shares change (e.g., "+1,000,000 shares")
  final String sharesDisplay; // Display value - for NEW shows total, for others shows delta
  final String weightDelta;
  final String date;
  final String rawDate; // ISO date string for sorting (e.g., "2026-02-06")
  final String dateRange; // "Jan 6 - Feb 5" (from_date to to_date)
  final String? priceRange; // "$45.20 - $52.80" estimated price range
  final String? estimatedValue; // Estimated transaction value
  final List<StockTradeData> trades;
  // Evidence is nullable — real evidence is fetched lazily per-stock
  // via companyRationaleProvider when the user flips a card
  final EvidencePanelData? evidence;
  // Rank within the buy/sell list (1-indexed). Used for AI reasoning access control.
  final int? rank;

  const StockChangeItem({
    required this.ticker,
    required this.name,
    required this.changeType,
    required this.sharesDelta,
    required this.sharesDisplay,
    required this.weightDelta,
    required this.date,
    required this.rawDate,
    required this.dateRange,
    this.priceRange,
    this.estimatedValue,
    required this.trades,
    this.evidence,
    this.rank,
  });

  /// Create a copy with an updated rank.
  StockChangeItem copyWithRank(int newRank) {
    return StockChangeItem(
      ticker: ticker,
      name: name,
      changeType: changeType,
      sharesDelta: sharesDelta,
      sharesDisplay: sharesDisplay,
      weightDelta: weightDelta,
      date: date,
      rawDate: rawDate,
      dateRange: dateRange,
      priceRange: priceRange,
      estimatedValue: estimatedValue,
      trades: trades,
      evidence: evidence,
      rank: newRank,
    );
  }

  Color get changeColor {
    switch (changeType) {
      case 'NEW':
      case 'ADDED':
        return AppColors.success;
      case 'REDUCED':
        return AppColors.warning;
      case 'SOLD_OUT':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  /// Unique key for this transaction (ticker + changeType).
  /// This distinguishes between buy and sell of the same stock.
  String get uniqueKey => '${ticker}_$changeType';

  /// Check if this is a buy transaction.
  bool get isBuy => changeType == 'NEW' || changeType == 'ADDED';
}

// ============================================================================
// FORMATTING HELPERS
// ============================================================================

String _formatShares(dynamic value) {
  if (value == null) return '0';
  final num n = value is num ? value : num.tryParse(value.toString()) ?? 0;
  final formatter = NumberFormat('#,###');
  final prefix = n > 0 ? '+' : '';
  return '$prefix${formatter.format(n.toInt())}';
}

String _formatSharesAbs(dynamic value) {
  if (value == null) return '0';
  final num n = (value is num ? value : num.tryParse(value.toString()) ?? 0).abs();
  return NumberFormat('#,###').format(n.toInt());
}

String _formatWeight(dynamic value) {
  if (value == null) return '0%';
  final num n = value is num ? value : num.tryParse(value.toString()) ?? 0;
  final prefix = n > 0 ? '+' : '';
  return '$prefix${n.toStringAsFixed(1)}%';
}

String _formatValue(dynamic value) {
  if (value == null) return '\$0';
  final num n = (value is num ? value : num.tryParse(value.toString()) ?? 0).abs();
  if (n >= 1e9) return '\$${(n / 1e9).toStringAsFixed(1)}B';
  if (n >= 1e6) return '\$${(n / 1e6).toStringAsFixed(1)}M';
  if (n >= 1e3) return '\$${(n / 1e3).toStringAsFixed(0)}K';
  return '\$${n.toStringAsFixed(0)}';
}

String _formatDate(String? dateStr) {
  if (dateStr == null) return '';
  try {
    final date = DateTime.parse(dateStr);
    return DateFormat('MMM d').format(date);
  } catch (_) {
    return dateStr;
  }
}

String _formatFullDate(String? dateStr) {
  if (dateStr == null) return '';
  try {
    final date = DateTime.parse(dateStr);
    return DateFormat('MMM d, yyyy').format(date);
  } catch (_) {
    return dateStr;
  }
}

String _formatDateRange(String? fromDate, String? toDate) {
  if (fromDate == null || toDate == null) return '';
  try {
    final from = DateTime.parse(fromDate);
    final to = DateTime.parse(toDate);
    // Always include year to avoid confusion (e.g., "Aug 14, 2024 - Nov 14, 2024")
    // If same year, show year only once at the end
    if (from.year == to.year) {
      final fromStr = DateFormat('MMM d').format(from);
      final toStr = DateFormat('MMM d, yyyy').format(to);
      return '$fromStr - $toStr';
    } else {
      final fromStr = DateFormat('MMM d, yyyy').format(from);
      final toStr = DateFormat('MMM d, yyyy').format(to);
      return '$fromStr - $toStr';
    }
  } catch (_) {
    return '';
  }
}

String _formatPriceRange(dynamic low, dynamic high) {
  if (low == null && high == null) return '';
  final lowVal = low != null ? (low is num ? low : num.tryParse(low.toString())) : null;
  final highVal = high != null ? (high is num ? high : num.tryParse(high.toString())) : null;
  if (lowVal == null && highVal == null) return '';
  if (lowVal != null && highVal != null) {
    return '\$${lowVal.toStringAsFixed(2)} - \$${highVal.toStringAsFixed(2)}';
  }
  if (lowVal != null) return '~\$${lowVal.toStringAsFixed(2)}';
  if (highVal != null) return '~\$${highVal.toStringAsFixed(2)}';
  return '';
}

String _computeSharesDisplay(String changeType, dynamic sharesDelta, dynamic sharesAfter) {
  // For NEW positions, show total shares acquired (sharesAfter)
  // For SOLD_OUT positions, show shares sold (use sharesDelta, not sharesAfter which is 0)
  // For other positions, show the delta
  if (changeType == 'NEW') {
    final shares = sharesAfter ?? sharesDelta;
    if (shares == null) return '0';
    final num n = (shares is num ? shares : num.tryParse(shares.toString()) ?? 0).abs();
    final formatted = NumberFormat('#,###').format(n.toInt());
    return '+$formatted';
  }
  if (changeType == 'SOLD_OUT') {
    // Use sharesDelta (negative) for SOLD_OUT, not sharesAfter (which is 0)
    final shares = sharesDelta;
    if (shares == null) return '0';
    final num n = (shares is num ? shares : num.tryParse(shares.toString()) ?? 0).abs();
    final formatted = NumberFormat('#,###').format(n.toInt());
    return '-$formatted';
  }
  return _formatShares(sharesDelta);
}

String _investorTypeDisplay(String type) {
  switch (type.toLowerCase()) {
    case 'etf_manager':
      return 'ETF Manager';
    case 'hedge_fund':
      return 'Hedge Fund';
    case 'public_institution':
      return 'Public Institution';
    case 'individual_investor':
      return 'Individual';
    case 'family_office':
      return 'Family Office';
    case 'mutual_fund':
      return 'Mutual Fund';
    case 'sovereign_wealth':
      return 'Sovereign Wealth';
    default:
      return type;
  }
}

String _frequencyDisplay(String freq) {
  switch (freq.toLowerCase()) {
    case 'daily':
      return 'Daily';
    case 'weekly':
      return 'Weekly';
    case 'monthly':
      return 'Monthly';
    case 'quarterly':
      return 'Quarterly';
    case 'semi_annual':
      return 'Semi-Annual';
    case 'annual':
      return 'Annual';
    case 'event_driven':
      return 'Event-Driven';
    default:
      return freq;
  }
}

String _timeAgo(String? dateStr) {
  if (dateStr == null) return 'Unknown';
  try {
    final date = DateTime.parse(dateStr);
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(date);
  } catch (_) {
    return dateStr;
  }
}

// ============================================================================
// PROVIDERS
// ============================================================================

/// Provider for investor detail data.
/// Falls back to mock data if the API call fails.
/// Uses TTL-based caching (6 hours for investor profiles).
final investorDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, investorId) async {
  final apiClient = ref.watch(apiClientProvider);
  final cache = ref.watch(investorDetailCacheProvider);

  // Check cache first
  final cached = cache[investorId];
  if (cached != null && !cached.isExpired) {
    return cached.data;
  }

  try {
    final response = await apiClient.getInvestor(investorId);
    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;

      // Extract disclosure type from sources or primary_disclosure_type
      String disclosureType = 'Unknown';
      if (data['primary_disclosure_type'] != null) {
        disclosureType = data['primary_disclosure_type'].toString();
      } else if (data['disclosure_sources'] is List &&
          (data['disclosure_sources'] as List).isNotEmpty) {
        disclosureType =
            (data['disclosure_sources'] as List).first['source_type'] ?? 'Unknown';
      }

      // Build limitations list
      List<String> limitations = [];
      if (data['data_limitations_summary'] != null) {
        limitations = (data['data_limitations_summary'] as String)
            .split(';')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }

      // Format the latest filing period for quarterly filers (13F)
      String? latestFilingPeriod;
      int? latestFilingChanges;
      final filingFrom = data['latest_filing_from']?.toString();
      final filingTo = data['latest_filing_to']?.toString();
      if (filingFrom != null && filingTo != null) {
        latestFilingPeriod = _formatDateRange(filingFrom, filingTo);
        latestFilingChanges = data['latest_filing_changes_count'] as int?;
      }

      final result = {
        'id': data['id']?.toString() ?? investorId,
        'name': data['name'] ?? 'Unknown Investor',
        'investorType': _investorTypeDisplay(
            data['investor_type']?.toString() ?? 'Unknown'),
        'disclosureType': disclosureType,
        'updateFrequency': _frequencyDisplay(
            data['expected_update_frequency']?.toString() ?? 'Unknown'),
        'typicalDelay':
            '${data['typical_reporting_delay_days'] ?? 0} days',
        'transparencyScore': data['transparency_score'] ?? 50,
        'aum': data['aum_billions'] ?? 'N/A',
        'description': data['description'] ?? '',
        'totalHoldings': data['total_holdings'] ?? 0,
        'changes30d': data['changes_count_30d'] ?? 0,
        'lastUpdate': _timeAgo(
            data['last_data_fetch']?.toString() ??
                data['last_change_detected']?.toString()),
        'limitations': limitations,
        // For quarterly filers: latest filing info
        'latestFilingPeriod': latestFilingPeriod,
        'latestFilingChanges': latestFilingChanges,
        'latestSnapshotDate': data['latest_snapshot_date']?.toString(),
      };

      // Cache the result with 6-hour TTL
      ref.read(investorDetailCacheProvider.notifier).set(
        investorId,
        result,
        CacheTTL.investorProfile,
      );

      return result;
    }
  } catch (e) {
    // Fall through to mock data
  }

  return _getMockInvestor(investorId);
});

/// Provider for investor holdings changes, mapped to StockChangeItems.
/// Evidence is NOT included here — it is fetched lazily per-stock
/// via companyRationaleProvider when the user flips a card.
/// Falls back to mock data if the API call fails.
final investorChangesProvider =
    FutureProvider.family<List<StockChangeItem>, String>((ref, investorId) async {
  final apiClient = ref.watch(apiClientProvider);

  try {
    // Fetch changes and trades in parallel
    // Explicitly set latestOnly=false to get multiple days of data for grouping
    final results = await Future.wait([
      apiClient.getInvestorChanges(investorId, latestOnly: false, limit: 300),
      apiClient.getInvestorTrades(investorId),
    ]);

    final changesResponse = results[0];
    final tradesResponse = results[1];

    if (changesResponse.statusCode == 200) {
      final changesData = changesResponse.data as Map<String, dynamic>;
      final changesList = (changesData['changes'] as List?) ?? [];

      // Parse trades into a map by ticker
      Map<String, List<StockTradeData>> tradesByTicker = {};
      if (tradesResponse.statusCode == 200) {
        final tradesData = tradesResponse.data as Map<String, dynamic>;
        final actionsList = (tradesData['actions'] as List?) ?? [];
        for (final action in actionsList) {
          final ticker = action['ticker']?.toString() ?? '';
          final trade = StockTradeData(
            action: (action['action_type']?.toString() ?? 'BUY').toUpperCase(),
            shares: NumberFormat('#,###')
                .format((num.tryParse(action['shares']?.toString() ?? '0') ?? 0).toInt()),
            value: _formatValue(action['estimated_value']),
            date: _formatFullDate(action['trade_date']?.toString()),
            fund: action['fund_name']?.toString() ?? '',
          );
          tradesByTicker.putIfAbsent(ticker, () => []);
          tradesByTicker[ticker]!.add(trade);
        }
      }

      // Map changes to StockChangeItems (no evidence — loaded lazily)
      return changesList.map<StockChangeItem>((change) {
        final ticker = change['ticker']?.toString() ?? '';
        final changeType =
            (change['change_type']?.toString() ?? 'added').toUpperCase();
        final trades = tradesByTicker[ticker] ?? [];

        // Compute shares display - for NEW positions show total, others show delta
        String sharesDisplay;
        try {
          sharesDisplay = _computeSharesDisplay(
            changeType,
            change['shares_delta'],
            change['shares_after'],
          );
        } catch (_) {
          sharesDisplay = _formatShares(change['shares_delta']);
        }

        // Format price range if available
        String priceRange = '';
        try {
          priceRange = _formatPriceRange(
            change['price_range_low'],
            change['price_range_high'],
          );
        } catch (_) {
          // Ignore price range errors
        }

        // Format date range
        String dateRange = '';
        try {
          dateRange = _formatDateRange(
            change['from_date']?.toString(),
            change['to_date']?.toString(),
          );
        } catch (_) {
          // Ignore date range errors
        }

        // Estimate transaction value from shares and price
        // NOTE: We do NOT use value_delta as fallback because it represents
        // total position value change (shares traded + price movements on remaining shares),
        // not the actual transaction value.
        String? estimatedValue;
        final sharesNum = change['shares_delta'] ?? change['shares_after'];
        final priceLow = change['price_range_low'];
        final priceHigh = change['price_range_high'];
        if (sharesNum != null && (priceLow != null || priceHigh != null)) {
          final shares = (sharesNum is num ? sharesNum : num.tryParse(sharesNum.toString()) ?? 0).abs();
          final lowPrice = priceLow != null
              ? (priceLow is num ? priceLow : num.tryParse(priceLow.toString()) ?? 0)
              : 0;
          final highPrice = priceHigh != null
              ? (priceHigh is num ? priceHigh : num.tryParse(priceHigh.toString()) ?? 0)
              : 0;
          final avgPrice = (lowPrice > 0 && highPrice > 0)
              ? (lowPrice + highPrice) / 2
              : (lowPrice > 0 ? lowPrice : highPrice);
          if (avgPrice > 0) {
            estimatedValue = _formatValue(shares * avgPrice);
          }
        }
        // If no price range available, don't show estimated value
        // (value_delta includes price movements on all shares, not just traded shares)

        return StockChangeItem(
          ticker: ticker,
          name: change['company_name']?.toString() ?? ticker,
          changeType: changeType,
          sharesDelta: _formatShares(change['shares_delta']),
          sharesDisplay: sharesDisplay,
          weightDelta: _formatWeight(change['weight_delta']),
          date: _formatDate(change['to_date']?.toString()),
          rawDate: change['to_date']?.toString() ?? '',  // ISO date for sorting
          dateRange: dateRange,
          priceRange: priceRange.isNotEmpty ? priceRange : null,
          estimatedValue: estimatedValue,
          trades: trades,
          // evidence: null — fetched on demand when card is flipped
        );
      }).toList();
    }
  } catch (e) {
    // Fall through to mock data only on network/parse errors
  }

  return _getMockStockChanges();
});

/// Provider for portfolio overview (sector breakdown + recent changes summary).
/// Uses TTL-based caching (1 hour for holdings data).
final portfolioOverviewProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, investorId) async {
  final apiClient = ref.watch(apiClientProvider);
  final cache = ref.watch(portfolioOverviewCacheProvider);

  // Check cache first
  final cached = cache[investorId];
  if (cached != null && !cached.isExpired) {
    return cached.data;
  }

  try {
    final response = await apiClient.getPortfolioOverview(investorId);
    if (response.statusCode == 200) {
      final result = response.data as Map<String, dynamic>;

      // Cache the result with 1-hour TTL
      ref.read(portfolioOverviewCacheProvider.notifier).set(
        investorId,
        result,
        CacheTTL.holdings,
      );

      return result;
    }
  } catch (_) {}
  return null;
});

/// Provider for AI-generated investor summary.
/// Returns the full AISummaryResponse shape from the backend including:
/// headline, what_changed, top_buys, top_sells, observations,
/// interpretation_notes, evidence_panel, limitations, disclaimer.
/// Returns null if the API call fails (section will show fallback content).
final investorAISummaryProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, investorId) async {
  final apiClient = ref.watch(apiClientProvider);

  try {
    final response = await apiClient.getInvestorAISummary(investorId);
    if (response.statusCode == 200) {
      return response.data as Map<String, dynamic>;
    }
  } catch (e) {
    // Return null — section will use fallback content
  }

  return null;
});

/// Provider for per-stock AI company rationale.
/// Calls POST /api/ai/company-rationale with investor_id and ticker.
/// Returns AICompanyRationaleResponse shape including:
/// company_overview, investor_activity_summary, possible_rationales[],
/// evidence_panel, what_is_unknown, disclaimer.
/// Returns null if the API call fails.
typedef CompanyRationaleParams = ({String investorId, String ticker});

final companyRationaleProvider =
    FutureProvider.family<Map<String, dynamic>?, CompanyRationaleParams>(
        (ref, params) async {
  final apiClient = ref.watch(apiClientProvider);

  try {
    final response = await apiClient.generateCompanyRationale(
      params.investorId,
      params.ticker,
    );
    if (response.statusCode == 200) {
      return response.data as Map<String, dynamic>;
    }
  } catch (e) {
    // Return null — card back will show fallback
  }

  return null;
});

/// Provider for multi-agent reasoning analysis.
/// Calls POST /api/ai/multi-agent-reasoning with investor_id and ticker.
/// Returns MultiAgentReasoningResponse with 6 perspective cards.
/// Returns null if the API call fails.
/// changeType is optional - if provided, fetches reasoning for specific transaction type
/// Note: This provider watches the locale and will refresh when language changes
typedef MultiAgentParams = ({String investorId, String ticker, String? changeType});

final multiAgentReasoningProvider =
    FutureProvider.family<MultiAgentReasoningResponse?, MultiAgentParams>(
        (ref, params) async {
  // Watch the API client which includes the current locale's Accept-Language header
  // This ensures a new request is made when the locale changes
  final apiClient = ref.watch(apiClientProvider);
  // Also watch the locale directly to ensure we refresh when language changes
  ref.watch(localeProvider);

  try {
    debugPrint('MultiAgentReasoning: Calling API for ${params.ticker} (${params.changeType ?? "any"})');
    final response = await apiClient.generateMultiAgentReasoning(
      params.investorId,
      params.ticker,
      changeType: params.changeType,
    );
    debugPrint('MultiAgentReasoning: Response status ${response.statusCode}');
    if (response.statusCode == 200) {
      debugPrint('MultiAgentReasoning: Parsing response data');
      final result = MultiAgentReasoningResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
      debugPrint('MultiAgentReasoning: Parsed ${result.cards.length} cards');
      return result;
    } else {
      debugPrint('MultiAgentReasoning: Non-200 status: ${response.statusCode}');
    }
  } catch (e, stackTrace) {
    // Log the error for debugging
    debugPrint('MultiAgentReasoning: Error - $e');
    debugPrint('MultiAgentReasoning: Stack - $stackTrace');
  }

  return null;
});

// ============================================================================
// MULTI-SELECT TRANSACTION REPORT
// ============================================================================

/// Provider to track whether multi-select mode is active.
final transactionSelectModeProvider = StateProvider<bool>((ref) => false);

/// Provider to track selected transaction tickers.
/// Uses ticker as unique key since each investor has unique tickers per change.
final selectedTransactionsProvider = StateProvider<Set<String>>((ref) => {});

// ============================================================================
// CURRENT HOLDINGS
// ============================================================================

class HoldingItem {
  final String ticker;
  final String companyName;
  final String shares;
  final String marketValue;
  final String weightPercent;

  const HoldingItem({
    required this.ticker,
    required this.companyName,
    required this.shares,
    required this.marketValue,
    required this.weightPercent,
  });
}

/// Provider for the latest holdings snapshot.
/// Returns the list of current positions sorted by weight.
final investorHoldingsProvider =
    FutureProvider.family<List<HoldingItem>, String>((ref, investorId) async {
  final apiClient = ref.watch(apiClientProvider);

  try {
    final response = await apiClient.getInvestorHoldings(investorId);
    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      final records = (data['records'] as List?) ?? [];
      // 13F tickers are share classes like "COM", "CL A" — not real tickers.
      const shareClassLabels = {
        'COM', 'CL A', 'CL B', 'CL C', 'CLASS A', 'CLASS B', 'CLASS C',
        'SHS', 'ORD SHS', 'SHS CLASS A', 'CAP STK CL A', 'CAP STK CL B',
        'CAP STK CL C', 'COM NEW', 'SER A', 'SER B', 'SER C', 'NEW',
      };

      final items = records.map<HoldingItem>((r) {
        final rawTicker = (r['ticker']?.toString() ?? '').trim();
        final name = r['company_name']?.toString() ?? '';
        // Use company name as display ticker when ticker is a share class
        final displayTicker =
            shareClassLabels.contains(rawTicker.toUpperCase()) ? name : rawTicker;
        final subtitle =
            shareClassLabels.contains(rawTicker.toUpperCase()) ? '' : name;

        return HoldingItem(
          ticker: displayTicker,
          companyName: subtitle,
          shares: _formatSharesAbs(r['shares']),
          marketValue: _formatValue(r['market_value']),
          weightPercent:
              '${num.tryParse(r['weight_percent']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0'}%',
        );
      }).toList();
      // Already sorted by market_value desc from backend
      return items;
    }
  } catch (_) {}

  return [];
});

// ============================================================================
// MOCK DATA FALLBACKS
// ============================================================================

Map<String, dynamic> _getMockInvestor(String id) {
  return {
    'id': id,
    'name': 'ARK Innovation ETF (ARKK)',
    'investorType': 'ETF Manager',
    'disclosureType': 'ETF Holdings',
    'updateFrequency': 'Daily',
    'typicalDelay': '1 day',
    'transparencyScore': 88,
    'aum': '~\$8B',
    'description':
        'ARK Innovation ETF seeks long-term growth by investing in companies relevant to disruptive innovation.',
    'totalHoldings': 35,
    'changes30d': 47,
    'lastUpdate': '2h ago',
    'limitations': [
      'Execution prices not disclosed',
      'Market price ranges are for reference only',
    ],
  };
}

List<StockChangeItem> _getMockStockChanges() {
  return const [
    StockChangeItem(
      ticker: 'COIN',
      name: 'Coinbase Global',
      changeType: 'NEW',
      sharesDelta: '+8,500',
      sharesDisplay: '+8,500 shares',
      weightDelta: '+0.3%',
      date: 'Dec 15',
      rawDate: '2024-12-15',
      dateRange: 'Dec 1 - Dec 15',
      priceRange: '\$218.50 - \$245.20',
      estimatedValue: '\$1.9M',
      trades: [
        StockTradeData(
          action: 'BUY',
          shares: '8,500',
          value: '\$1.9M',
          date: 'Dec 15, 2024',
          fund: 'ARKK',
        ),
      ],
    ),
    StockChangeItem(
      ticker: 'TSLA',
      name: 'Tesla Inc.',
      changeType: 'ADDED',
      sharesDelta: '+15,000',
      sharesDisplay: '+15,000 shares',
      weightDelta: '+0.5%',
      date: 'Dec 15',
      rawDate: '2024-12-15',
      dateRange: 'Dec 1 - Dec 15',
      priceRange: '\$175.80 - \$192.40',
      estimatedValue: '\$2.7M',
      trades: [
        StockTradeData(
          action: 'BUY',
          shares: '15,000',
          value: '\$2.7M',
          date: 'Dec 15, 2024',
          fund: 'ARKK',
        ),
      ],
    ),
    StockChangeItem(
      ticker: 'PLTR',
      name: 'Palantir',
      changeType: 'ADDED',
      sharesDelta: '+5,000',
      sharesDisplay: '+5,000 shares',
      weightDelta: '+0.2%',
      date: 'Dec 14',
      rawDate: '2024-12-14',
      dateRange: 'Dec 1 - Dec 14',
      priceRange: '\$82.10 - \$86.50',
      estimatedValue: '\$420K',
      trades: [
        StockTradeData(
          action: 'BUY',
          shares: '5,000',
          value: '\$420K',
          date: 'Dec 14, 2024',
          fund: 'ARKK',
        ),
      ],
    ),
    StockChangeItem(
      ticker: 'ROKU',
      name: 'Roku Inc.',
      changeType: 'REDUCED',
      sharesDelta: '-12,000',
      sharesDisplay: '-12,000 shares',
      weightDelta: '-0.4%',
      date: 'Dec 14',
      rawDate: '2024-12-14',
      dateRange: 'Dec 1 - Dec 14',
      priceRange: '\$62.30 - \$68.90',
      estimatedValue: '\$780K',
      trades: [
        StockTradeData(
          action: 'SELL',
          shares: '12,000',
          value: '\$780K',
          date: 'Dec 14, 2024',
          fund: 'ARKW',
        ),
      ],
    ),
    StockChangeItem(
      ticker: 'SQ',
      name: 'Block Inc.',
      changeType: 'SOLD_OUT',
      sharesDelta: '-25,000',
      sharesDisplay: '-25,000 shares',
      weightDelta: '-0.8%',
      date: 'Dec 13',
      rawDate: '2024-12-13',
      dateRange: 'Dec 1 - Dec 13',
      priceRange: '\$58.20 - \$62.50',
      estimatedValue: '\$1.5M',
      trades: [
        StockTradeData(
          action: 'SELL',
          shares: '25,000',
          value: '\$1.5M',
          date: 'Dec 13, 2024',
          fund: 'ARKK',
        ),
      ],
    ),
  ];
}
