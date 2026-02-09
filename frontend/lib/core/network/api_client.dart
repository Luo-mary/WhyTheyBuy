import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';
import '../providers/locale_provider.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final locale = ref.watch(localeProvider);
  return ApiClient(languageCode: locale?.languageCode ?? 'en');
});

class ApiClient {
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final String languageCode;

  ApiClient({this.languageCode = 'en'}) {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Accept-Language': languageCode,
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Add auth token if available
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        // Handle 401 - refresh token
        // Skip refresh for the refresh endpoint itself to avoid infinite loop
        if (error.response?.statusCode == 401 &&
            !error.requestOptions.path.contains('/auth/refresh')) {
          final refreshToken = await _storage.read(key: 'refresh_token');
          if (refreshToken != null) {
            try {
              final response = await _dio.post('/api/auth/refresh', data: {
                'refresh_token': refreshToken,
              });

              if (response.statusCode == 200) {
                await _storage.write(
                  key: 'access_token',
                  value: response.data['access_token'],
                );
                await _storage.write(
                  key: 'refresh_token',
                  value: response.data['refresh_token'],
                );

                // Retry the original request
                final opts = error.requestOptions;
                opts.headers['Authorization'] =
                    'Bearer ${response.data['access_token']}';
                final cloneReq = await _dio.fetch(opts);
                return handler.resolve(cloneReq);
              }
            } catch (e) {
              // Refresh failed, clear tokens
              await _storage.delete(key: 'access_token');
              await _storage.delete(key: 'refresh_token');
            }
          }
        }
        return handler.next(error);
      },
    ));
  }

  // Auth
  Future<Response> login(String email, String password) async {
    return _dio.post('/api/auth/login', data: {
      'email': email,
      'password': password,
    });
  }

  Future<Response> register(String email, String password, String name) async {
    return _dio.post('/api/auth/register', data: {
      'email': email,
      'password': password,
      'name': name,
    });
  }

  Future<Response> requestPasswordReset(String email) async {
    return _dio.post('/api/auth/password-reset/request', data: {
      'email': email,
    });
  }

  Future<Response> getCurrentUser() async {
    return _dio.get('/api/auth/me');
  }

  // Users
  Future<Response> updateProfile(Map<String, dynamic> data) async {
    return _dio.patch('/api/users/profile', data: data);
  }

  Future<Response> uploadAvatar(List<int> bytes, String filename, String mimeType) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename, contentType: DioMediaType.parse(mimeType)),
    });
    return _dio.post('/api/users/avatar', data: formData);
  }

  Future<Response> removeAvatar() async {
    return _dio.delete('/api/users/avatar');
  }

  Future<Response> changePassword(String currentPassword, String newPassword) async {
    return _dio.post('/api/users/change-password', data: {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  // Investors
  Future<Response> getInvestors({
    String? category,
    String? search,
    int skip = 0,
    int limit = 50,
  }) async {
    return _dio.get('/api/investors', queryParameters: {
      if (category != null) 'category': category,
      if (search != null) 'search': search,
      'skip': skip,
      'limit': limit,
    });
  }

  Future<Response> getFeaturedInvestors() async {
    return _dio.get('/api/investors/featured');
  }

  Future<Response> getInvestor(String id) async {
    return _dio.get('/api/investors/$id');
  }

  Future<Response> getInvestorHoldings(String id, {String? date}) async {
    return _dio.get('/api/investors/$id/holdings', queryParameters: {
      if (date != null) 'snapshot_date': date,
    });
  }

  Future<Response> getPortfolioOverview(String id, {int days = 30}) async {
    return _dio.get('/api/investors/$id/portfolio-overview', queryParameters: {
      'days': days,
    });
  }

  Future<Response> getInvestorChanges(
    String id, {
    String? fromDate,
    String? toDate,
    String? changeType,
    int skip = 0,
    int limit = 100,
    bool latestOnly = false,  // Get all days by default for grouped display
  }) async {
    return _dio.get('/api/investors/$id/changes', queryParameters: {
      if (fromDate != null) 'from_date': fromDate,
      if (toDate != null) 'to_date': toDate,
      if (changeType != null) 'change_type': changeType,
      'skip': skip,
      'limit': limit,
      'latest_only': latestOnly,
    });
  }

  Future<Response> getInvestorTrades(
    String id, {
    String? fromDate,
    String? toDate,
    int skip = 0,
    int limit = 50,
  }) async {
    return _dio.get('/api/investors/$id/trades', queryParameters: {
      if (fromDate != null) 'from_date': fromDate,
      if (toDate != null) 'to_date': toDate,
      'skip': skip,
      'limit': limit,
    });
  }

  Future<Response> getInvestorSummary(String id, {int days = 30}) async {
    return _dio.get('/api/investors/$id/summary', queryParameters: {
      'days': days,
    });
  }

  // Companies
  Future<Response> getCompany(String ticker) async {
    return _dio.get('/api/companies/$ticker');
  }

  Future<Response> getCompanyPriceHistory(String ticker, {String range = '1m'}) async {
    return _dio.get('/api/companies/$ticker/price', queryParameters: {
      'range': range,
    });
  }

  Future<Response> getCompanyInvestorActivity(
    String ticker, {
    String? investorId,
  }) async {
    return _dio.get('/api/companies/$ticker/investor-activity', queryParameters: {
      if (investorId != null) 'investor_id': investorId,
    });
  }

  Future<Response> getCompanyLiveQuote(String ticker) async {
    return _dio.get('/api/companies/$ticker/live');
  }

  Future<Response> getCompanyLiveHistory(String ticker, {String range = '1m'}) async {
    return _dio.get('/api/companies/$ticker/live-history', queryParameters: {
      'range': range,
    });
  }

  // Watchlist
  Future<Response> getWatchlist() async {
    return _dio.get('/api/watchlist');
  }

  Future<Response> addToWatchlist(
    String investorId, {
    String frequency = 'daily',
    bool emailEnabled = true,
  }) async {
    return _dio.post('/api/watchlist/items', data: {
      'investor_id': investorId,
      'notification_frequency': frequency,
      'email_enabled': emailEnabled,
    });
  }

  Future<Response> removeFromWatchlist(String itemId) async {
    return _dio.delete('/api/watchlist/items/$itemId');
  }

  Future<Response> updateWatchlistItem(
    String itemId,
    Map<String, dynamic> data,
  ) async {
    return _dio.patch('/api/watchlist/items/$itemId', data: data);
  }

  // Reports
  Future<Response> getReports({
    String? reportType,
    bool unreadOnly = false,
    int skip = 0,
    int limit = 20,
    String? language,
  }) async {
    return _dio.get('/api/reports', queryParameters: {
      if (reportType != null) 'report_type': reportType,
      'unread_only': unreadOnly,
      'skip': skip,
      'limit': limit,
      'language': language ?? languageCode,
    });
  }

  Future<Response> getReport(String id, {String? language}) async {
    return _dio.get('/api/reports/$id', queryParameters: {
      'language': language ?? languageCode,
    });
  }

  Future<Response> getUnreadCount() async {
    return _dio.get('/api/reports/unread-count');
  }

  // AI
  Future<Response> getInvestorAISummary(String investorId, {int days = 30, String? language}) async {
    return _dio.get('/api/ai/investor-summary/$investorId', queryParameters: {
      'days': days,
      'language': language ?? languageCode,
    });
  }

  Future<Response> generateCompanyRationale(
    String investorId,
    String ticker, {
    String? language,
  }) async {
    return _dio.post('/api/ai/company-rationale', data: {
      'investor_id': investorId,
      'ticker': ticker,
      'language': language ?? languageCode,
    });
  }

  /// Generate multi-agent reasoning analysis (6 perspectives)
  /// changeType is optional - if provided, fetches reasoning for specific transaction (NEW, ADDED, REDUCED, SOLD_OUT)
  Future<Response> generateMultiAgentReasoning(
    String investorId,
    String ticker, {
    String? changeType,
  }) async {
    return _dio.post('/api/ai/multi-agent-reasoning', data: {
      'investor_id': investorId,
      'ticker': ticker,
      if (changeType != null) 'change_type': changeType,
    });
  }

  /// Generate a full investor report in the specified language
  Future<Response> generateInvestorReport(
    String investorId, {
    String? language,
    String format = 'pdf',
  }) async {
    return _dio.post('/api/ai/investor-report/$investorId', data: {
      'language': language ?? languageCode,
      'format': format,
    });
  }

  /// Send combined transaction report to email
  Future<Response> sendCombinedTransactionReport(
    String investorId,
    String investorName,
    List<String> tickers,
    List<Map<String, dynamic>> transactions, {
    String? language,
  }) async {
    return _dio.post('/api/reports/combined-transaction-report', data: {
      'investor_id': investorId,
      'investor_name': investorName,
      'tickers': tickers,
      'transactions': transactions,
      'language': language ?? languageCode,
    });
  }

  // Payments
  Future<Response> getSubscription() async {
    return _dio.get('/api/payments/subscription');
  }

  Future<Response> getPricing() async {
    return _dio.get('/api/payments/pricing');
  }

  Future<Response> createCheckoutSession({String plan = 'pro_monthly'}) async {
    return _dio.post('/api/payments/checkout', queryParameters: {
      'plan': plan,
    });
  }

  Future<Response> createBillingPortal() async {
    return _dio.post('/api/payments/billing-portal');
  }

  // Token management
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: 'access_token', value: accessToken);
    await _storage.write(key: 'refresh_token', value: refreshToken);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  Future<bool> hasValidToken() async {
    final token = await _storage.read(key: 'access_token');
    return token != null;
  }
}
