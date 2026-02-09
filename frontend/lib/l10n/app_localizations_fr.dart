// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'WhyTheyBuy';

  @override
  String get home => 'Accueil';

  @override
  String get settings => 'Paramètres';

  @override
  String get addInvestorToTrack => 'Ajouter un investisseur à suivre';

  @override
  String get recommendedInvestors => 'Investisseurs Recommandés';

  @override
  String get shuffle => 'Mélanger';

  @override
  String get featuredInvestor => 'Investisseur en Vedette';

  @override
  String get disclaimer =>
      'À des fins éducatives uniquement. Pas de conseil en investissement.';

  @override
  String get manageAccountPreferences =>
      'Gérer votre compte et vos préférences';

  @override
  String get freePlan => 'GRATUIT';

  @override
  String get upgradeToPro => 'Passer à Pro';

  @override
  String get upgradeDescription =>
      'Surveillez jusqu\'à 10 investisseurs, alertes instantanées, résumés IA avancés';

  @override
  String perMonth(String price) {
    return '$price/mois';
  }

  @override
  String perYear(String price) {
    return '$price/an';
  }

  @override
  String get account => 'Compte';

  @override
  String get profile => 'Profil';

  @override
  String get notificationEmails => 'E-mails de Notification';

  @override
  String get changePassword => 'Changer le Mot de Passe';

  @override
  String get preferences => 'Préférences';

  @override
  String get language => 'Langue';

  @override
  String get timezone => 'Fuseau Horaire';

  @override
  String get support => 'Support';

  @override
  String get helpCenter => 'Centre d\'Aide';

  @override
  String get sendFeedback => 'Envoyer un Commentaire';

  @override
  String get termsOfService => 'Conditions d\'Utilisation';

  @override
  String get privacyPolicy => 'Politique de Confidentialité';

  @override
  String get signOut => 'Se Déconnecter';

  @override
  String get selectLanguage => 'Sélectionner la Langue';

  @override
  String get selectTimezone => 'Sélectionner le Fuseau Horaire';

  @override
  String get searchTimezones => 'Rechercher des fuseaux horaires...';

  @override
  String get editProfile => 'Modifier le Profil';

  @override
  String get name => 'Nom';

  @override
  String get email => 'E-mail';

  @override
  String get saveChanges => 'Enregistrer les Modifications';

  @override
  String get currentPassword => 'Mot de Passe Actuel';

  @override
  String get newPassword => 'Nouveau Mot de Passe';

  @override
  String get confirmNewPassword => 'Confirmer le Nouveau Mot de Passe';

  @override
  String get updatePassword => 'Mettre à Jour le Mot de Passe';

  @override
  String get atLeast8Characters => 'Au moins 8 caractères';

  @override
  String get addInvestor => 'Ajouter un Investisseur';

  @override
  String get searchByInvestorName => 'Rechercher par nom d\'investisseur...';

  @override
  String get searchForInvestors => 'Rechercher des investisseurs';

  @override
  String get trySearching =>
      'Essayez \"ARK\", \"Berkshire\" ou \"Bridgewater\"';

  @override
  String noInvestorsFound(String query) {
    return 'Aucun investisseur trouvé pour \"$query\"';
  }

  @override
  String get somethingWentWrong => 'Une erreur s\'est produite';

  @override
  String get trackingLimitReached => 'Limite de Suivi Atteinte';

  @override
  String get upgrade => 'Mettre à Niveau';

  @override
  String get login => 'Connexion';

  @override
  String get register => 'S\'inscrire';

  @override
  String get forgotPassword => 'Mot de Passe Oublié';

  @override
  String get password => 'Mot de Passe';

  @override
  String get dontHaveAccount => 'Vous n\'avez pas de compte ?';

  @override
  String get alreadyHaveAccount => 'Vous avez déjà un compte ?';

  @override
  String get etfManager => 'Gestionnaire ETF';

  @override
  String get hedgeFund => 'Fonds Spéculatif';

  @override
  String get individual => 'Investisseur Individuel';

  @override
  String get unknown => 'Inconnu';

  @override
  String get featured => 'En Vedette';

  @override
  String get institutional => 'Institutionnel';

  @override
  String get insider => 'Initié';

  @override
  String get dailyEtf => 'ETF Quotidien';

  @override
  String get sec13f => 'SEC 13F';

  @override
  String get nPort => 'N-PORT';

  @override
  String get form4 => 'Form 4';

  @override
  String get transparencyHigh => 'Haute Transparence';

  @override
  String get transparencyMedium => 'Transparence Moyenne';

  @override
  String get transparencyLow => 'Faible Transparence';

  @override
  String get unlockAiInsights => 'Débloquer les analyses IA';

  @override
  String get getAiPoweredAnalysis =>
      'Obtenez des analyses et alertes alimentées par l\'IA';

  @override
  String get pro => 'PRO';

  @override
  String get navigation => 'NAVIGATION';

  @override
  String get liveTracking => 'SUIVI EN DIRECT';

  @override
  String get landingHeadline =>
      'Suivez Ce Qu\'achètent Les Meilleurs Investisseurs';

  @override
  String get landingSubheadline =>
      'Surveillez les avoirs institutionnels en temps réel. ETFs ARK, documents 13F et analyses IA livrés dans votre boîte de réception.';

  @override
  String get startFreeTrial => 'Essai Gratuit';

  @override
  String get viewDemo => 'Voir la Démo';

  @override
  String get realTimeUpdates => 'Mises à Jour en Temps Réel';

  @override
  String get realTimeUpdatesDesc =>
      'Transactions quotidiennes ARK ETF et documents 13F trimestriels';

  @override
  String get aiPoweredInsights => 'Analyses IA';

  @override
  String get aiPoweredInsightsDesc =>
      'Comprenez pourquoi les meilleurs investisseurs prennent des décisions';

  @override
  String get smartAlerts => 'Alertes Intelligentes';

  @override
  String get smartAlertsDesc =>
      'Soyez notifié lorsque votre liste de suivi évolue';

  @override
  String get trustedByInvestors => 'Approuvé par plus de 10 000 investisseurs';

  @override
  String get bankGradeSecurity => 'Sécurité bancaire';

  @override
  String get realTimeData => 'Données en temps réel';

  @override
  String get notFinancialAdvice =>
      'Pas de conseil financier. Données fournies à titre informatif uniquement.';

  @override
  String get signIn => 'Se Connecter';

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
