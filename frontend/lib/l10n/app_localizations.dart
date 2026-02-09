import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ja'),
    Locale('ko'),
    Locale('zh')
  ];

  /// The name of the application
  ///
  /// In en, this message translates to:
  /// **'WhyTheyBuy'**
  String get appName;

  /// Home navigation label
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Settings navigation label
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// CTA button label on home page
  ///
  /// In en, this message translates to:
  /// **'Add an investor to track'**
  String get addInvestorToTrack;

  /// Section title for recommended investors
  ///
  /// In en, this message translates to:
  /// **'Recommended Investors'**
  String get recommendedInvestors;

  /// Shuffle button label
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get shuffle;

  /// Featured investor section title
  ///
  /// In en, this message translates to:
  /// **'Featured Investor'**
  String get featuredInvestor;

  /// Footer disclaimer text
  ///
  /// In en, this message translates to:
  /// **'For educational purposes only. Not investment advice.'**
  String get disclaimer;

  /// Settings page subtitle
  ///
  /// In en, this message translates to:
  /// **'Manage your account and preferences'**
  String get manageAccountPreferences;

  /// Free plan badge
  ///
  /// In en, this message translates to:
  /// **'FREE PLAN'**
  String get freePlan;

  /// Upgrade to pro title
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro'**
  String get upgradeToPro;

  /// Upgrade benefits description
  ///
  /// In en, this message translates to:
  /// **'Monitor up to 10 investors, instant alerts, advanced AI summaries'**
  String get upgradeDescription;

  /// Price per month
  ///
  /// In en, this message translates to:
  /// **'{price}/month'**
  String perMonth(String price);

  /// Price per year
  ///
  /// In en, this message translates to:
  /// **'{price}/year'**
  String perYear(String price);

  /// Account section title
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// Profile menu item
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// Notification emails menu item
  ///
  /// In en, this message translates to:
  /// **'Notification Emails'**
  String get notificationEmails;

  /// Change password menu item
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// Preferences section title
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// Language menu item
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Timezone menu item
  ///
  /// In en, this message translates to:
  /// **'Timezone'**
  String get timezone;

  /// Support section title
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// Help center menu item
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get helpCenter;

  /// Send feedback menu item
  ///
  /// In en, this message translates to:
  /// **'Send Feedback'**
  String get sendFeedback;

  /// Terms of service menu item
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// Privacy policy menu item
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// Sign out button
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// Language selector title
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// Timezone selector title
  ///
  /// In en, this message translates to:
  /// **'Select Timezone'**
  String get selectTimezone;

  /// Timezone search placeholder
  ///
  /// In en, this message translates to:
  /// **'Search timezones...'**
  String get searchTimezones;

  /// Edit profile sheet title
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// Name field label
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// Email field label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Save changes button
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// Current password field label
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get currentPassword;

  /// New password field label
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPassword;

  /// Confirm password field label
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get confirmNewPassword;

  /// Update password button
  ///
  /// In en, this message translates to:
  /// **'Update Password'**
  String get updatePassword;

  /// Password hint
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get atLeast8Characters;

  /// Add investor modal title
  ///
  /// In en, this message translates to:
  /// **'Add Investor'**
  String get addInvestor;

  /// Investor search placeholder
  ///
  /// In en, this message translates to:
  /// **'Search by investor name...'**
  String get searchByInvestorName;

  /// Empty search state message
  ///
  /// In en, this message translates to:
  /// **'Search for investors'**
  String get searchForInvestors;

  /// Search suggestion hint
  ///
  /// In en, this message translates to:
  /// **'Try \"ARK\", \"Berkshire\", or \"Bridgewater\"'**
  String get trySearching;

  /// No results message
  ///
  /// In en, this message translates to:
  /// **'No investors found for \"{query}\"'**
  String noInvestorsFound(String query);

  /// Generic error message
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// Limit reached dialog title
  ///
  /// In en, this message translates to:
  /// **'Tracking Limit Reached'**
  String get trackingLimitReached;

  /// Upgrade button
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get upgrade;

  /// Login button/title
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// Register button/title
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// Forgot password link
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get forgotPassword;

  /// Password field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Register prompt
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// Login prompt
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// ETF manager investor type
  ///
  /// In en, this message translates to:
  /// **'ETF Manager'**
  String get etfManager;

  /// Hedge fund investor type
  ///
  /// In en, this message translates to:
  /// **'Hedge Fund'**
  String get hedgeFund;

  /// Individual investor type
  ///
  /// In en, this message translates to:
  /// **'Individual'**
  String get individual;

  /// Unknown type
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @featured.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get featured;

  /// No description provided for @institutional.
  ///
  /// In en, this message translates to:
  /// **'Institutional'**
  String get institutional;

  /// No description provided for @insider.
  ///
  /// In en, this message translates to:
  /// **'Insider'**
  String get insider;

  /// No description provided for @dailyEtf.
  ///
  /// In en, this message translates to:
  /// **'Daily ETF'**
  String get dailyEtf;

  /// No description provided for @sec13f.
  ///
  /// In en, this message translates to:
  /// **'SEC 13F'**
  String get sec13f;

  /// No description provided for @nPort.
  ///
  /// In en, this message translates to:
  /// **'N-PORT'**
  String get nPort;

  /// No description provided for @form4.
  ///
  /// In en, this message translates to:
  /// **'Form 4'**
  String get form4;

  /// High transparency label
  ///
  /// In en, this message translates to:
  /// **'High Transparency'**
  String get transparencyHigh;

  /// Medium transparency label
  ///
  /// In en, this message translates to:
  /// **'Medium Transparency'**
  String get transparencyMedium;

  /// Low transparency label
  ///
  /// In en, this message translates to:
  /// **'Low Transparency'**
  String get transparencyLow;

  /// Pro upgrade card title
  ///
  /// In en, this message translates to:
  /// **'Unlock AI insights'**
  String get unlockAiInsights;

  /// Pro upgrade card description
  ///
  /// In en, this message translates to:
  /// **'Get AI-powered analysis and alerts'**
  String get getAiPoweredAnalysis;

  /// Pro badge
  ///
  /// In en, this message translates to:
  /// **'PRO'**
  String get pro;

  /// Navigation section header
  ///
  /// In en, this message translates to:
  /// **'NAVIGATION'**
  String get navigation;

  /// No description provided for @liveTracking.
  ///
  /// In en, this message translates to:
  /// **'LIVE TRACKING'**
  String get liveTracking;

  /// No description provided for @landingHeadline.
  ///
  /// In en, this message translates to:
  /// **'Track What Top Investors Are Buying'**
  String get landingHeadline;

  /// No description provided for @landingSubheadline.
  ///
  /// In en, this message translates to:
  /// **'Monitor institutional holdings in real-time. ARK ETFs, 13F filings, and AI-powered insights delivered to your inbox.'**
  String get landingSubheadline;

  /// No description provided for @startFreeTrial.
  ///
  /// In en, this message translates to:
  /// **'Start Free Trial'**
  String get startFreeTrial;

  /// No description provided for @viewDemo.
  ///
  /// In en, this message translates to:
  /// **'View Demo'**
  String get viewDemo;

  /// No description provided for @realTimeUpdates.
  ///
  /// In en, this message translates to:
  /// **'Real-Time Updates'**
  String get realTimeUpdates;

  /// No description provided for @realTimeUpdatesDesc.
  ///
  /// In en, this message translates to:
  /// **'Daily ARK ETF trades and quarterly 13F filings'**
  String get realTimeUpdatesDesc;

  /// No description provided for @aiPoweredInsights.
  ///
  /// In en, this message translates to:
  /// **'AI-Powered Insights'**
  String get aiPoweredInsights;

  /// No description provided for @aiPoweredInsightsDesc.
  ///
  /// In en, this message translates to:
  /// **'Understand why top investors are making moves'**
  String get aiPoweredInsightsDesc;

  /// No description provided for @smartAlerts.
  ///
  /// In en, this message translates to:
  /// **'Smart Alerts'**
  String get smartAlerts;

  /// No description provided for @smartAlertsDesc.
  ///
  /// In en, this message translates to:
  /// **'Get notified when your watchlist moves'**
  String get smartAlertsDesc;

  /// No description provided for @trustedByInvestors.
  ///
  /// In en, this message translates to:
  /// **'Trusted by 10,000+ investors'**
  String get trustedByInvestors;

  /// No description provided for @bankGradeSecurity.
  ///
  /// In en, this message translates to:
  /// **'Bank-grade security'**
  String get bankGradeSecurity;

  /// No description provided for @realTimeData.
  ///
  /// In en, this message translates to:
  /// **'Real-time data'**
  String get realTimeData;

  /// No description provided for @notFinancialAdvice.
  ///
  /// In en, this message translates to:
  /// **'Not financial advice. Data provided for informational purposes only.'**
  String get notFinancialAdvice;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @portfolioOverview.
  ///
  /// In en, this message translates to:
  /// **'Portfolio Overview'**
  String get portfolioOverview;

  /// No description provided for @sectorBreakdownActivity.
  ///
  /// In en, this message translates to:
  /// **'Sector breakdown & recent activity'**
  String get sectorBreakdownActivity;

  /// No description provided for @totalHoldings.
  ///
  /// In en, this message translates to:
  /// **'Total Holdings'**
  String get totalHoldings;

  /// No description provided for @changes30d.
  ///
  /// In en, this message translates to:
  /// **'Changes (30d)'**
  String get changes30d;

  /// No description provided for @lastUpdate.
  ///
  /// In en, this message translates to:
  /// **'Last Update'**
  String get lastUpdate;

  /// No description provided for @latestSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Latest snapshot'**
  String get latestSnapshot;

  /// No description provided for @positions.
  ///
  /// In en, this message translates to:
  /// **'positions'**
  String get positions;

  /// No description provided for @sectorAllocation.
  ///
  /// In en, this message translates to:
  /// **'Sector Allocation'**
  String get sectorAllocation;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get recentActivity;

  /// No description provided for @noHoldingsDataYet.
  ///
  /// In en, this message translates to:
  /// **'No holdings data available yet. Data will appear after the next ingestion cycle.'**
  String get noHoldingsDataYet;

  /// No description provided for @moreSectors.
  ///
  /// In en, this message translates to:
  /// **'+{count} more sectors'**
  String moreSectors(int count);

  /// No description provided for @holdingsSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Holdings Snapshot'**
  String get holdingsSnapshot;

  /// No description provided for @noHoldingsData.
  ///
  /// In en, this message translates to:
  /// **'No holdings data available'**
  String get noHoldingsData;

  /// No description provided for @ticker.
  ///
  /// In en, this message translates to:
  /// **'Ticker'**
  String get ticker;

  /// No description provided for @weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// No description provided for @value.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get value;

  /// No description provided for @showTop10.
  ///
  /// In en, this message translates to:
  /// **'Show top 10'**
  String get showTop10;

  /// No description provided for @viewAllHoldings.
  ///
  /// In en, this message translates to:
  /// **'View all {count} holdings'**
  String viewAllHoldings(int count);

  /// No description provided for @basedOnPublicDisclosures.
  ///
  /// In en, this message translates to:
  /// **'Based on publicly disclosed holdings. This is not investment advice.'**
  String get basedOnPublicDisclosures;

  /// No description provided for @portfolioOverviewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Portfolio overview unavailable. Connect to backend to see sector breakdown and recent activity.'**
  String get portfolioOverviewUnavailable;

  /// No description provided for @holdingsChanges.
  ///
  /// In en, this message translates to:
  /// **'Holdings Changes'**
  String get holdingsChanges;

  /// No description provided for @last30Days.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get last30Days;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @selectForReport.
  ///
  /// In en, this message translates to:
  /// **'Select for Report'**
  String get selectForReport;

  /// No description provided for @nChanges.
  ///
  /// In en, this message translates to:
  /// **'{count} changes'**
  String nChanges(int count);

  /// No description provided for @noChangesLast30Days.
  ///
  /// In en, this message translates to:
  /// **'No changes in the last 30 days'**
  String get noChangesLast30Days;

  /// No description provided for @topBuys.
  ///
  /// In en, this message translates to:
  /// **'Top Buys'**
  String get topBuys;

  /// No description provided for @topSells.
  ///
  /// In en, this message translates to:
  /// **'Top Sells'**
  String get topSells;

  /// No description provided for @hideMoreChanges.
  ///
  /// In en, this message translates to:
  /// **'Hide {count} more changes'**
  String hideMoreChanges(int count);

  /// No description provided for @showMoreChanges.
  ///
  /// In en, this message translates to:
  /// **'Show {count} more changes'**
  String showMoreChanges(int count);

  /// No description provided for @nSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String nSelected(int count);

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @generateReport.
  ///
  /// In en, this message translates to:
  /// **'Generate Report'**
  String get generateReport;

  /// No description provided for @shares.
  ///
  /// In en, this message translates to:
  /// **'shares'**
  String get shares;

  /// No description provided for @estimated.
  ///
  /// In en, this message translates to:
  /// **'Est.'**
  String get estimated;

  /// No description provided for @aiReasoningLimit.
  ///
  /// In en, this message translates to:
  /// **'AI Reasoning Limit'**
  String get aiReasoningLimit;

  /// No description provided for @freeUserReasoningLimit.
  ///
  /// In en, this message translates to:
  /// **'Free users can access AI reasoning for the Top 5 Buys and Top 5 Sells. Upgrade to Pro for unlimited AI analysis on all transactions.'**
  String get freeUserReasoningLimit;

  /// No description provided for @evidence.
  ///
  /// In en, this message translates to:
  /// **'Evidence'**
  String get evidence;

  /// No description provided for @possibleRationales.
  ///
  /// In en, this message translates to:
  /// **'Possible Rationales'**
  String get possibleRationales;

  /// No description provided for @hypothesis.
  ///
  /// In en, this message translates to:
  /// **'Hypothesis'**
  String get hypothesis;

  /// No description provided for @aiReasoningUnavailable.
  ///
  /// In en, this message translates to:
  /// **'AI reasoning unavailable'**
  String get aiReasoningUnavailable;

  /// No description provided for @connectBackendForAi.
  ///
  /// In en, this message translates to:
  /// **'Connect to backend with AI keys configured to see LLM-generated evidence and hypotheses for this stock.'**
  String get connectBackendForAi;

  /// No description provided for @failedToLoadInvestor.
  ///
  /// In en, this message translates to:
  /// **'Failed to load investor'**
  String get failedToLoadInvestor;

  /// No description provided for @generatingAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Generating Sequential Analysis'**
  String get generatingAnalysis;

  /// No description provided for @fundamental.
  ///
  /// In en, this message translates to:
  /// **'Fundamental'**
  String get fundamental;

  /// No description provided for @news.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get news;

  /// No description provided for @market.
  ///
  /// In en, this message translates to:
  /// **'Market'**
  String get market;

  /// No description provided for @technical.
  ///
  /// In en, this message translates to:
  /// **'Technical'**
  String get technical;

  /// No description provided for @debate.
  ///
  /// In en, this message translates to:
  /// **'Debate'**
  String get debate;

  /// No description provided for @risk.
  ///
  /// In en, this message translates to:
  /// **'Risk'**
  String get risk;

  /// No description provided for @analysisUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Analysis Unavailable'**
  String get analysisUnavailable;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @disclaimersLimitations.
  ///
  /// In en, this message translates to:
  /// **'Disclaimers & Limitations'**
  String get disclaimersLimitations;

  /// No description provided for @whatWeDontKnow.
  ///
  /// In en, this message translates to:
  /// **'What We Don\'t Know'**
  String get whatWeDontKnow;

  /// No description provided for @myInvestors.
  ///
  /// In en, this message translates to:
  /// **'My Investors'**
  String get myInvestors;

  /// No description provided for @nTracked.
  ///
  /// In en, this message translates to:
  /// **'{count} tracked'**
  String nTracked(int count);

  /// No description provided for @defaultLabel.
  ///
  /// In en, this message translates to:
  /// **'DEFAULT'**
  String get defaultLabel;

  /// No description provided for @noInvestorsTrackedYet.
  ///
  /// In en, this message translates to:
  /// **'No investors tracked yet'**
  String get noInvestorsTrackedYet;

  /// No description provided for @addInvestorsToTrack.
  ///
  /// In en, this message translates to:
  /// **'Add investors to track their holdings and get AI-powered insights.'**
  String get addInvestorsToTrack;

  /// No description provided for @addYourFirstInvestor.
  ///
  /// In en, this message translates to:
  /// **'Add Your First Investor'**
  String get addYourFirstInvestor;

  /// No description provided for @addToWatchlist.
  ///
  /// In en, this message translates to:
  /// **'Add to Watchlist'**
  String get addToWatchlist;

  /// No description provided for @addToWatchlistQuestion.
  ///
  /// In en, this message translates to:
  /// **'Add to Watchlist?'**
  String get addToWatchlistQuestion;

  /// No description provided for @addToWatchlistDescription.
  ///
  /// In en, this message translates to:
  /// **'Add \"{name}\" to your watchlist to view their transactions and AI reasoning.'**
  String addToWatchlistDescription(String name);

  /// No description provided for @onlyWatchlistedInvestors.
  ///
  /// In en, this message translates to:
  /// **'Only watchlisted investors show transactions & AI insights.'**
  String get onlyWatchlistedInvestors;

  /// No description provided for @addedToWatchlist.
  ///
  /// In en, this message translates to:
  /// **'{name} added to your watchlist'**
  String addedToWatchlist(String name);

  /// No description provided for @failedToAddInvestor.
  ///
  /// In en, this message translates to:
  /// **'Failed to add investor'**
  String get failedToAddInvestor;

  /// No description provided for @investorLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Investor Limit Reached'**
  String get investorLimitReached;

  /// No description provided for @freeUserLimit.
  ///
  /// In en, this message translates to:
  /// **'Free users can track up to {count} investors. Upgrade to Pro to track up to 10 investors.'**
  String freeUserLimit(int count);

  /// No description provided for @proUserLimit.
  ///
  /// In en, this message translates to:
  /// **'Pro users can track up to {count} investors. Upgrade to Pro+ for unlimited tracking.'**
  String proUserLimit(int count);

  /// No description provided for @trackingLimitMessage.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached your tracking limit of {count} investors.'**
  String trackingLimitMessage(int count);

  /// No description provided for @viewPlans.
  ///
  /// In en, this message translates to:
  /// **'View Plans'**
  String get viewPlans;

  /// No description provided for @forEducationalPurposes.
  ///
  /// In en, this message translates to:
  /// **'For educational purposes only. Not investment advice.'**
  String get forEducationalPurposes;

  /// No description provided for @changeTypeNew.
  ///
  /// In en, this message translates to:
  /// **'NEW'**
  String get changeTypeNew;

  /// No description provided for @changeTypeAdded.
  ///
  /// In en, this message translates to:
  /// **'ADDED'**
  String get changeTypeAdded;

  /// No description provided for @changeTypeReduced.
  ///
  /// In en, this message translates to:
  /// **'REDUCED'**
  String get changeTypeReduced;

  /// No description provided for @changeTypeSold.
  ///
  /// In en, this message translates to:
  /// **'SOLD'**
  String get changeTypeSold;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'ar',
        'de',
        'en',
        'es',
        'fr',
        'ja',
        'ko',
        'zh'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
