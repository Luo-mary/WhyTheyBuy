// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appName => 'WhyTheyBuy';

  @override
  String get home => 'Startseite';

  @override
  String get settings => 'Einstellungen';

  @override
  String get addInvestorToTrack => 'Investor zum Verfolgen hinzufügen';

  @override
  String get recommendedInvestors => 'Empfohlene Investoren';

  @override
  String get shuffle => 'Mischen';

  @override
  String get featuredInvestor => 'Vorgestellter Investor';

  @override
  String get disclaimer => 'Nur zu Bildungszwecken. Keine Anlageberatung.';

  @override
  String get manageAccountPreferences => 'Konto und Einstellungen verwalten';

  @override
  String get freePlan => 'KOSTENLOS';

  @override
  String get upgradeToPro => 'Auf Pro upgraden';

  @override
  String get upgradeDescription =>
      'Bis zu 10 Investoren überwachen, sofortige Benachrichtigungen, erweiterte KI-Zusammenfassungen';

  @override
  String perMonth(String price) {
    return '$price/Monat';
  }

  @override
  String perYear(String price) {
    return '$price/Jahr';
  }

  @override
  String get account => 'Konto';

  @override
  String get profile => 'Profil';

  @override
  String get notificationEmails => 'Benachrichtigungs-E-Mails';

  @override
  String get changePassword => 'Passwort ändern';

  @override
  String get preferences => 'Einstellungen';

  @override
  String get language => 'Sprache';

  @override
  String get timezone => 'Zeitzone';

  @override
  String get support => 'Support';

  @override
  String get helpCenter => 'Hilfecenter';

  @override
  String get sendFeedback => 'Feedback senden';

  @override
  String get termsOfService => 'Nutzungsbedingungen';

  @override
  String get privacyPolicy => 'Datenschutzrichtlinie';

  @override
  String get signOut => 'Abmelden';

  @override
  String get selectLanguage => 'Sprache auswählen';

  @override
  String get selectTimezone => 'Zeitzone auswählen';

  @override
  String get searchTimezones => 'Zeitzonen suchen...';

  @override
  String get editProfile => 'Profil bearbeiten';

  @override
  String get name => 'Name';

  @override
  String get email => 'E-Mail';

  @override
  String get saveChanges => 'Änderungen speichern';

  @override
  String get currentPassword => 'Aktuelles Passwort';

  @override
  String get newPassword => 'Neues Passwort';

  @override
  String get confirmNewPassword => 'Neues Passwort bestätigen';

  @override
  String get updatePassword => 'Passwort aktualisieren';

  @override
  String get atLeast8Characters => 'Mindestens 8 Zeichen';

  @override
  String get addInvestor => 'Investor hinzufügen';

  @override
  String get searchByInvestorName => 'Nach Investorname suchen...';

  @override
  String get searchForInvestors => 'Investoren suchen';

  @override
  String get trySearching =>
      'Versuchen Sie \"ARK\", \"Berkshire\" oder \"Bridgewater\"';

  @override
  String noInvestorsFound(String query) {
    return 'Keine Investoren für \"$query\" gefunden';
  }

  @override
  String get somethingWentWrong => 'Etwas ist schiefgelaufen';

  @override
  String get trackingLimitReached => 'Verfolgungslimit erreicht';

  @override
  String get upgrade => 'Upgraden';

  @override
  String get login => 'Anmelden';

  @override
  String get register => 'Registrieren';

  @override
  String get forgotPassword => 'Passwort vergessen';

  @override
  String get password => 'Passwort';

  @override
  String get dontHaveAccount => 'Noch kein Konto?';

  @override
  String get alreadyHaveAccount => 'Bereits ein Konto?';

  @override
  String get etfManager => 'ETF-Manager';

  @override
  String get hedgeFund => 'Hedgefonds';

  @override
  String get individual => 'Privatanleger';

  @override
  String get unknown => 'Unbekannt';

  @override
  String get featured => 'Vorgestellt';

  @override
  String get institutional => 'Institutionell';

  @override
  String get insider => 'Insider';

  @override
  String get dailyEtf => 'Täglicher ETF';

  @override
  String get sec13f => 'SEC 13F';

  @override
  String get nPort => 'N-PORT';

  @override
  String get form4 => 'Form 4';

  @override
  String get transparencyHigh => 'Hohe Transparenz';

  @override
  String get transparencyMedium => 'Mittlere Transparenz';

  @override
  String get transparencyLow => 'Niedrige Transparenz';

  @override
  String get unlockAiInsights => 'KI-Einblicke freischalten';

  @override
  String get getAiPoweredAnalysis =>
      'KI-gestützte Analysen und Benachrichtigungen erhalten';

  @override
  String get pro => 'PRO';

  @override
  String get navigation => 'NAVIGATION';

  @override
  String get liveTracking => 'LIVE-TRACKING';

  @override
  String get landingHeadline => 'Verfolgen Sie, was Top-Investoren kaufen';

  @override
  String get landingSubheadline =>
      'Überwachen Sie institutionelle Bestände in Echtzeit. ARK ETFs, 13F-Einreichungen und KI-gestützte Einblicke direkt in Ihren Posteingang.';

  @override
  String get startFreeTrial => 'Kostenlos testen';

  @override
  String get viewDemo => 'Demo ansehen';

  @override
  String get realTimeUpdates => 'Echtzeit-Updates';

  @override
  String get realTimeUpdatesDesc =>
      'Tägliche ARK ETF-Trades und vierteljährliche 13F-Einreichungen';

  @override
  String get aiPoweredInsights => 'KI-gestützte Einblicke';

  @override
  String get aiPoweredInsightsDesc =>
      'Verstehen Sie, warum Top-Investoren Entscheidungen treffen';

  @override
  String get smartAlerts => 'Intelligente Benachrichtigungen';

  @override
  String get smartAlertsDesc =>
      'Werden Sie benachrichtigt, wenn sich Ihre Watchlist ändert';

  @override
  String get trustedByInvestors => 'Vertraut von über 10.000 Investoren';

  @override
  String get bankGradeSecurity => 'Banksicherheit';

  @override
  String get realTimeData => 'Echtzeit-Daten';

  @override
  String get notFinancialAdvice =>
      'Keine Finanzberatung. Daten dienen nur zu Informationszwecken.';

  @override
  String get signIn => 'Anmelden';

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
