// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'WhyTheyBuy';

  @override
  String get home => 'Home';

  @override
  String get settings => 'Settings';

  @override
  String get addInvestorToTrack => 'Add an investor to track';

  @override
  String get recommendedInvestors => 'Recommended Investors';

  @override
  String get shuffle => 'Shuffle';

  @override
  String get featuredInvestor => 'Featured Investor';

  @override
  String get disclaimer =>
      'For educational purposes only. Not investment advice.';

  @override
  String get manageAccountPreferences => 'Manage your account and preferences';

  @override
  String get freePlan => 'FREE PLAN';

  @override
  String get upgradeToPro => 'Upgrade to Pro';

  @override
  String get upgradeDescription =>
      'Monitor up to 10 investors, instant alerts, advanced AI summaries';

  @override
  String perMonth(String price) {
    return '$price/month';
  }

  @override
  String perYear(String price) {
    return '$price/year';
  }

  @override
  String get account => 'Account';

  @override
  String get profile => 'Profile';

  @override
  String get notificationEmails => 'Notification Emails';

  @override
  String get changePassword => 'Change Password';

  @override
  String get preferences => 'Preferences';

  @override
  String get language => 'Language';

  @override
  String get timezone => 'Timezone';

  @override
  String get support => 'Support';

  @override
  String get helpCenter => 'Help Center';

  @override
  String get sendFeedback => 'Send Feedback';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get signOut => 'Sign Out';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get selectTimezone => 'Select Timezone';

  @override
  String get searchTimezones => 'Search timezones...';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get name => 'Name';

  @override
  String get email => 'Email';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get currentPassword => 'Current Password';

  @override
  String get newPassword => 'New Password';

  @override
  String get confirmNewPassword => 'Confirm New Password';

  @override
  String get updatePassword => 'Update Password';

  @override
  String get atLeast8Characters => 'At least 8 characters';

  @override
  String get addInvestor => 'Add Investor';

  @override
  String get searchByInvestorName => 'Search by investor name...';

  @override
  String get searchForInvestors => 'Search for investors';

  @override
  String get trySearching => 'Try \"ARK\", \"Berkshire\", or \"Bridgewater\"';

  @override
  String noInvestorsFound(String query) {
    return 'No investors found for \"$query\"';
  }

  @override
  String get somethingWentWrong => 'Something went wrong';

  @override
  String get trackingLimitReached => 'Tracking Limit Reached';

  @override
  String get upgrade => 'Upgrade';

  @override
  String get login => 'Login';

  @override
  String get register => 'Register';

  @override
  String get forgotPassword => 'Forgot Password';

  @override
  String get password => 'Password';

  @override
  String get dontHaveAccount => 'Don\'t have an account?';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get etfManager => 'ETF Manager';

  @override
  String get hedgeFund => 'Hedge Fund';

  @override
  String get individual => 'Individual';

  @override
  String get unknown => 'Unknown';

  @override
  String get featured => 'Featured';

  @override
  String get institutional => 'Institutional';

  @override
  String get insider => 'Insider';

  @override
  String get dailyEtf => 'Daily ETF';

  @override
  String get sec13f => 'SEC 13F';

  @override
  String get nPort => 'N-PORT';

  @override
  String get form4 => 'Form 4';

  @override
  String get transparencyHigh => 'High Transparency';

  @override
  String get transparencyMedium => 'Medium Transparency';

  @override
  String get transparencyLow => 'Low Transparency';

  @override
  String get unlockAiInsights => 'Unlock AI insights';

  @override
  String get getAiPoweredAnalysis => 'Get AI-powered analysis and alerts';

  @override
  String get pro => 'PRO';

  @override
  String get navigation => 'NAVIGATION';

  @override
  String get liveTracking => 'LIVE TRACKING';

  @override
  String get landingHeadline => 'Track What Top Investors Are Buying';

  @override
  String get landingSubheadline =>
      'Monitor institutional holdings in real-time. ARK ETFs, 13F filings, and AI-powered insights delivered to your inbox.';

  @override
  String get startFreeTrial => 'Start Free Trial';

  @override
  String get viewDemo => 'View Demo';

  @override
  String get realTimeUpdates => 'Real-Time Updates';

  @override
  String get realTimeUpdatesDesc =>
      'Daily ARK ETF trades and quarterly 13F filings';

  @override
  String get aiPoweredInsights => 'AI-Powered Insights';

  @override
  String get aiPoweredInsightsDesc =>
      'Understand why top investors are making moves';

  @override
  String get smartAlerts => 'Smart Alerts';

  @override
  String get smartAlertsDesc => 'Get notified when your watchlist moves';

  @override
  String get trustedByInvestors => 'Trusted by 10,000+ investors';

  @override
  String get bankGradeSecurity => 'Bank-grade security';

  @override
  String get realTimeData => 'Real-time data';

  @override
  String get notFinancialAdvice =>
      'Not financial advice. Data provided for informational purposes only.';

  @override
  String get signIn => 'Sign In';

  @override
  String get portfolioOverview => 'Portfolio Overview';

  @override
  String get sectorBreakdownActivity => 'Sector breakdown & recent activity';

  @override
  String get totalHoldings => 'Total Holdings';

  @override
  String get changes30d => 'Changes (30d)';

  @override
  String get lastUpdate => 'Last Update';

  @override
  String get latestSnapshot => 'Latest snapshot';

  @override
  String get positions => 'positions';

  @override
  String get sectorAllocation => 'Sector Allocation';

  @override
  String get recentActivity => 'Recent Activity';

  @override
  String get noHoldingsDataYet =>
      'No holdings data available yet. Data will appear after the next ingestion cycle.';

  @override
  String moreSectors(int count) {
    return '+$count more sectors';
  }

  @override
  String get holdingsSnapshot => 'Holdings Snapshot';

  @override
  String get noHoldingsData => 'No holdings data available';

  @override
  String get ticker => 'Ticker';

  @override
  String get weight => 'Weight';

  @override
  String get value => 'Value';

  @override
  String get showTop10 => 'Show top 10';

  @override
  String viewAllHoldings(int count) {
    return 'View all $count holdings';
  }

  @override
  String get basedOnPublicDisclosures =>
      'Based on publicly disclosed holdings. This is not investment advice.';

  @override
  String get portfolioOverviewUnavailable =>
      'Portfolio overview unavailable. Connect to backend to see sector breakdown and recent activity.';

  @override
  String get holdingsChanges => 'Holdings Changes';

  @override
  String get last30Days => 'Last 30 days';

  @override
  String get cancel => 'Cancel';

  @override
  String get selectForReport => 'Select for Report';

  @override
  String nChanges(int count) {
    return '$count changes';
  }

  @override
  String get noChangesLast30Days => 'No changes in the last 30 days';

  @override
  String get topBuys => 'Top Buys';

  @override
  String get topSells => 'Top Sells';

  @override
  String hideMoreChanges(int count) {
    return 'Hide $count more changes';
  }

  @override
  String showMoreChanges(int count) {
    return 'Show $count more changes';
  }

  @override
  String nSelected(int count) {
    return '$count selected';
  }

  @override
  String get clear => 'Clear';

  @override
  String get generateReport => 'Generate Report';

  @override
  String get shares => 'shares';

  @override
  String get estimated => 'Est.';

  @override
  String get aiReasoningLimit => 'AI Reasoning Limit';

  @override
  String get freeUserReasoningLimit =>
      'Free users can access AI reasoning for the Top 5 Buys and Top 5 Sells. Upgrade to Pro for unlimited AI analysis on all transactions.';

  @override
  String get evidence => 'Evidence';

  @override
  String get possibleRationales => 'Possible Rationales';

  @override
  String get hypothesis => 'Hypothesis';

  @override
  String get aiReasoningUnavailable => 'AI reasoning unavailable';

  @override
  String get connectBackendForAi =>
      'Connect to backend with AI keys configured to see LLM-generated evidence and hypotheses for this stock.';

  @override
  String get failedToLoadInvestor => 'Failed to load investor';

  @override
  String get generatingAnalysis => 'Generating Sequential Analysis';

  @override
  String get fundamental => 'Fundamental';

  @override
  String get news => 'News';

  @override
  String get market => 'Market';

  @override
  String get technical => 'Technical';

  @override
  String get debate => 'Debate';

  @override
  String get risk => 'Risk';

  @override
  String get analysisUnavailable => 'Analysis Unavailable';

  @override
  String get retry => 'Retry';

  @override
  String get disclaimersLimitations => 'Disclaimers & Limitations';

  @override
  String get whatWeDontKnow => 'What We Don\'t Know';

  @override
  String get myInvestors => 'My Investors';

  @override
  String nTracked(int count) {
    return '$count tracked';
  }

  @override
  String get defaultLabel => 'DEFAULT';

  @override
  String get noInvestorsTrackedYet => 'No investors tracked yet';

  @override
  String get addInvestorsToTrack =>
      'Add investors to track their holdings and get AI-powered insights.';

  @override
  String get addYourFirstInvestor => 'Add Your First Investor';

  @override
  String get addToWatchlist => 'Add to Watchlist';

  @override
  String get addToWatchlistQuestion => 'Add to Watchlist?';

  @override
  String addToWatchlistDescription(String name) {
    return 'Add \"$name\" to your watchlist to view their transactions and AI reasoning.';
  }

  @override
  String get onlyWatchlistedInvestors =>
      'Only watchlisted investors show transactions & AI insights.';

  @override
  String addedToWatchlist(String name) {
    return '$name added to your watchlist';
  }

  @override
  String get failedToAddInvestor => 'Failed to add investor';

  @override
  String get investorLimitReached => 'Investor Limit Reached';

  @override
  String freeUserLimit(int count) {
    return 'Free users can track up to $count investors. Upgrade to Pro to track up to 10 investors.';
  }

  @override
  String proUserLimit(int count) {
    return 'Pro users can track up to $count investors. Upgrade to Pro+ for unlimited tracking.';
  }

  @override
  String trackingLimitMessage(int count) {
    return 'You\'ve reached your tracking limit of $count investors.';
  }

  @override
  String get viewPlans => 'View Plans';

  @override
  String get forEducationalPurposes =>
      'For educational purposes only. Not investment advice.';

  @override
  String get changeTypeNew => 'NEW';

  @override
  String get changeTypeAdded => 'ADDED';

  @override
  String get changeTypeReduced => 'REDUCED';

  @override
  String get changeTypeSold => 'SOLD';
}
