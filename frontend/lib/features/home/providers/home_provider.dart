import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/investor_card_model.dart';

/// Model for a watchlist item (tracked investor)
class TrackedInvestorModel {
  final String id; // watchlist item id
  final String investorId;
  final String investorSlug;
  final String name;
  final String investorType;
  final String? disclosureType;
  final int? transparencyScore;
  final String? description;
  final bool isDefault;

  const TrackedInvestorModel({
    required this.id,
    required this.investorId,
    required this.investorSlug,
    required this.name,
    required this.investorType,
    this.disclosureType,
    this.transparencyScore,
    this.description,
    this.isDefault = false,
  });

  factory TrackedInvestorModel.fromJson(Map<String, dynamic> json) {
    final investor = json['investor'] as Map<String, dynamic>?;
    return TrackedInvestorModel(
      id: json['id'] as String,
      investorId: json['investor_id'] as String,
      investorSlug: investor?['slug'] as String? ?? json['investor_id'] as String,
      name: investor?['name'] as String? ?? 'Unknown Investor',
      investorType: investor?['investor_type'] as String? ?? 'unknown',
      disclosureType: investor?['disclosure_type'] as String?,
      transparencyScore: investor?['transparency_score'] as int?,
      description: investor?['description'] as String?,
      isDefault: (investor?['slug'] as String?) == 'berkshire-hathaway',
    );
  }
}

/// Provider for user's tracked investors (from watchlist)
final trackedInvestorsProvider = FutureProvider<List<TrackedInvestorModel>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);

  try {
    final response = await apiClient.getWatchlist();
    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>? ?? [];
      return items
          .map((json) => TrackedInvestorModel.fromJson(json as Map<String, dynamic>))
          .toList();
    }
  } catch (e) {
    // Return empty list on error (user might not be logged in)
  }

  return [];
});

/// Provider for featured investor (shown prominently on home page)
final featuredInvestorProvider = FutureProvider<InvestorCardModel?>((ref) async {
  final apiClient = ref.watch(apiClientProvider);

  try {
    final response = await apiClient.getFeaturedInvestors();
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;
      if (data.isNotEmpty) {
        // Return the first featured investor (typically a well-known one like Berkshire)
        return InvestorCardModel.fromJson(data.first);
      }
    }
  } catch (e) {
    // Return mock data in case of error
  }

  // Return mock featured investor as fallback
  return const InvestorCardModel(
    id: 'berkshire-hathaway',
    name: 'Berkshire Hathaway',
    investorType: 'institutional',
    disclosureType: 'sec_13f',
    transparencyScore: 45,
    description: 'Warren Buffett\'s holding company',
    totalHoldings: 45,
    changesLast30Days: 3,
    lastUpdate: '2024-11-14',
    isFeatured: true,
  );
});

/// State notifier for recommended investors with shuffle functionality
class RecommendedInvestorsNotifier extends StateNotifier<AsyncValue<List<InvestorCardModel>>> {
  final ApiClient _apiClient;
  int _currentPage = 0;
  static const int _pageSize = 3;

  RecommendedInvestorsNotifier(this._apiClient) : super(const AsyncValue.loading()) {
    _loadRecommended();
  }

  Future<void> _loadRecommended() async {
    state = const AsyncValue.loading();

    try {
      final response = await _apiClient.getInvestors(
        skip: _currentPage * _pageSize,
        limit: _pageSize,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['investors'] ?? response.data;
        final investors = data
            .map((json) => InvestorCardModel.fromJson(json))
            .toList();
        state = AsyncValue.data(investors);
      } else {
        state = AsyncValue.data(_getMockInvestors());
      }
    } catch (e) {
      // Return mock data as fallback
      state = AsyncValue.data(_getMockInvestors());
    }
  }

  /// Shuffle to load next set of recommended investors
  Future<void> shuffle() async {
    _currentPage++;
    await _loadRecommended();
  }

  /// Reset to first page
  Future<void> reset() async {
    _currentPage = 0;
    await _loadRecommended();
  }

  List<InvestorCardModel> _getMockInvestors() {
    final allMocks = [
      const InvestorCardModel(
        id: 'ark-invest',
        name: 'ARK Invest',
        investorType: 'etf_manager',
        disclosureType: 'etf_holdings',
        transparencyScore: 95,
        description: 'Cathie Wood\'s innovation-focused ETFs',
        totalHoldings: 150,
        changesLast30Days: 25,
        lastUpdate: '2024-12-01',
      ),
      const InvestorCardModel(
        id: 'bridgewater',
        name: 'Bridgewater Associates',
        investorType: 'hedge_fund',
        disclosureType: 'sec_13f',
        transparencyScore: 40,
        description: 'Ray Dalio\'s hedge fund',
        totalHoldings: 800,
        changesLast30Days: 50,
        lastUpdate: '2024-11-14',
      ),
      const InvestorCardModel(
        id: 'renaissance',
        name: 'Renaissance Technologies',
        investorType: 'hedge_fund',
        disclosureType: 'sec_13f',
        transparencyScore: 35,
        description: 'Jim Simons\' quantitative fund',
        totalHoldings: 3500,
        changesLast30Days: 200,
        lastUpdate: '2024-11-14',
      ),
      const InvestorCardModel(
        id: 'soros',
        name: 'Soros Fund Management',
        investorType: 'hedge_fund',
        disclosureType: 'sec_13f',
        transparencyScore: 42,
        description: 'George Soros\' family office',
        totalHoldings: 120,
        changesLast30Days: 15,
        lastUpdate: '2024-11-14',
      ),
      const InvestorCardModel(
        id: 'druckenmiller',
        name: 'Duquesne Family Office',
        investorType: 'institutional',
        disclosureType: 'sec_13f',
        transparencyScore: 40,
        description: 'Stanley Druckenmiller\'s family office',
        totalHoldings: 50,
        changesLast30Days: 8,
        lastUpdate: '2024-11-14',
      ),
      const InvestorCardModel(
        id: 'pershing-square',
        name: 'Pershing Square',
        investorType: 'hedge_fund',
        disclosureType: 'sec_13f',
        transparencyScore: 55,
        description: 'Bill Ackman\'s hedge fund',
        totalHoldings: 10,
        changesLast30Days: 2,
        lastUpdate: '2024-11-14',
      ),
    ];

    // Return a subset based on current page (cycling through)
    final startIndex = (_currentPage * _pageSize) % allMocks.length;
    final result = <InvestorCardModel>[];
    for (int i = 0; i < _pageSize; i++) {
      result.add(allMocks[(startIndex + i) % allMocks.length]);
    }
    return result;
  }
}

/// Provider for recommended investors with shuffle capability
final recommendedInvestorsProvider =
    StateNotifierProvider<RecommendedInvestorsNotifier, AsyncValue<List<InvestorCardModel>>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return RecommendedInvestorsNotifier(apiClient);
});

/// Provider for ALL available investors (for add investor modal)
final allInvestorsProvider = FutureProvider<List<InvestorCardModel>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);

  try {
    final response = await apiClient.getInvestors(
      limit: 50, // Get all available investors
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = response.data['investors'] ?? response.data;
      return data.map((json) => InvestorCardModel.fromJson(json)).toList();
    }
  } catch (e) {
    // Return mock data as fallback
  }

  // Return all mock investors as fallback
  return const [
    InvestorCardModel(
      id: 'berkshire-hathaway',
      name: 'Berkshire Hathaway',
      investorType: 'individual_investor',
      disclosureType: 'sec_13f',
      transparencyScore: 45,
      description: 'Warren Buffett\'s holding company',
    ),
    InvestorCardModel(
      id: 'ark-arkk',
      name: 'ARK Innovation ETF (ARKK)',
      investorType: 'etf_manager',
      disclosureType: 'etf_holdings',
      transparencyScore: 95,
      description: 'Cathie Wood\'s innovation-focused ETF',
    ),
    InvestorCardModel(
      id: 'ark-arkg',
      name: 'ARK Genomic Revolution ETF (ARKG)',
      investorType: 'etf_manager',
      disclosureType: 'etf_holdings',
      transparencyScore: 90,
      description: 'ARK\'s genomics-focused ETF',
    ),
    InvestorCardModel(
      id: 'bridgewater-associates',
      name: 'Bridgewater Associates',
      investorType: 'hedge_fund',
      disclosureType: 'sec_13f',
      transparencyScore: 40,
      description: 'Ray Dalio\'s hedge fund',
    ),
    InvestorCardModel(
      id: 'renaissance-technologies',
      name: 'Renaissance Technologies',
      investorType: 'hedge_fund',
      disclosureType: 'sec_13f',
      transparencyScore: 35,
      description: 'Jim Simons\' quantitative fund',
    ),
    InvestorCardModel(
      id: 'soros-fund-management',
      name: 'Soros Fund Management',
      investorType: 'family_office',
      disclosureType: 'sec_13f',
      transparencyScore: 42,
      description: 'George Soros\' family office',
    ),
    InvestorCardModel(
      id: 'duquesne-family-office',
      name: 'Duquesne Family Office',
      investorType: 'family_office',
      disclosureType: 'sec_13f',
      transparencyScore: 40,
      description: 'Stanley Druckenmiller\'s family office',
    ),
    InvestorCardModel(
      id: 'pershing-square',
      name: 'Pershing Square Capital',
      investorType: 'hedge_fund',
      disclosureType: 'sec_13f',
      transparencyScore: 55,
      description: 'Bill Ackman\'s hedge fund',
    ),
    InvestorCardModel(
      id: 'fidelity-contrafund',
      name: 'Fidelity Contrafund',
      investorType: 'mutual_fund',
      disclosureType: 'nport',
      transparencyScore: 55,
      description: 'Large actively managed mutual fund',
    ),
    InvestorCardModel(
      id: 'calpers',
      name: 'CalPERS',
      investorType: 'public_institution',
      disclosureType: 'sec_13f',
      transparencyScore: 45,
      description: 'California public pension fund',
    ),
  ];
});

/// Provider for searching investors
final investorSearchProvider = FutureProvider.family<List<InvestorCardModel>, String>((ref, query) async {
  if (query.isEmpty) {
    return [];
  }

  final apiClient = ref.watch(apiClientProvider);

  try {
    final response = await apiClient.getInvestors(
      search: query,
      limit: 10,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = response.data['investors'] ?? response.data;
      return data.map((json) => InvestorCardModel.fromJson(json)).toList();
    }
  } catch (e) {
    // Return empty on error
  }

  // Mock search results
  final mockResults = [
    const InvestorCardModel(
      id: 'ark-invest',
      name: 'ARK Invest',
      investorType: 'etf_manager',
      disclosureType: 'etf_holdings',
      transparencyScore: 95,
    ),
    const InvestorCardModel(
      id: 'berkshire-hathaway',
      name: 'Berkshire Hathaway',
      investorType: 'institutional',
      disclosureType: 'sec_13f',
      transparencyScore: 45,
    ),
    const InvestorCardModel(
      id: 'bridgewater',
      name: 'Bridgewater Associates',
      investorType: 'hedge_fund',
      disclosureType: 'sec_13f',
      transparencyScore: 40,
    ),
  ];

  return mockResults
      .where((i) => i.name.toLowerCase().contains(query.toLowerCase()))
      .toList();
});
