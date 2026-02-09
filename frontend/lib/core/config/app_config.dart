/// Application configuration loaded from build-time environment variables.
///
/// For GCP deployment, build with:
/// ```bash
/// flutter build web --release \
///   --dart-define=API_BASE_URL=https://api.yourdomain.com \
///   --dart-define=STRIPE_PUBLISHABLE_KEY=pk_live_xxxxx \
///   --dart-define=ENVIRONMENT=production
/// ```
class AppConfig {
  /// Backend API base URL
  /// Default: http://localhost:8000 (development)
  /// Production: Set via --dart-define=API_BASE_URL=https://api.yourdomain.com
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  /// Stripe publishable key for payment integration
  /// Production: Set via --dart-define=STRIPE_PUBLISHABLE_KEY=pk_live_xxxxx
  static const String stripePublishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  /// Current environment (development, staging, production)
  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  /// Application name
  static const String appName = 'WhyTheyBuy';

  /// Application version
  static const String appVersion = '1.0.0';

  // Feature flags
  static const bool enableAIRationale = true;
  static const bool enablePayments = true;

  /// Check if running in production
  static bool get isProduction => environment == 'production';

  /// Check if running in development
  static bool get isDevelopment => environment == 'development';
}
