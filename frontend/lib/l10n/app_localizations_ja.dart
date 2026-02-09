// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appName => 'WhyTheyBuy';

  @override
  String get home => 'ホーム';

  @override
  String get settings => '設定';

  @override
  String get addInvestorToTrack => '追跡する投資家を追加';

  @override
  String get recommendedInvestors => 'おすすめの投資家';

  @override
  String get shuffle => 'シャッフル';

  @override
  String get featuredInvestor => '注目の投資家';

  @override
  String get disclaimer => '教育目的のみ。投資アドバイスではありません。';

  @override
  String get manageAccountPreferences => 'アカウントと設定を管理';

  @override
  String get freePlan => '無料プラン';

  @override
  String get upgradeToPro => 'Proにアップグレード';

  @override
  String get upgradeDescription => '最大10人の投資家を監視、即時アラート、高度なAI要約';

  @override
  String perMonth(String price) {
    return '$price/月';
  }

  @override
  String perYear(String price) {
    return '$price/年';
  }

  @override
  String get account => 'アカウント';

  @override
  String get profile => 'プロフィール';

  @override
  String get notificationEmails => '通知メール';

  @override
  String get changePassword => 'パスワードを変更';

  @override
  String get preferences => '環境設定';

  @override
  String get language => '言語';

  @override
  String get timezone => 'タイムゾーン';

  @override
  String get support => 'サポート';

  @override
  String get helpCenter => 'ヘルプセンター';

  @override
  String get sendFeedback => 'フィードバックを送信';

  @override
  String get termsOfService => '利用規約';

  @override
  String get privacyPolicy => 'プライバシーポリシー';

  @override
  String get signOut => 'ログアウト';

  @override
  String get selectLanguage => '言語を選択';

  @override
  String get selectTimezone => 'タイムゾーンを選択';

  @override
  String get searchTimezones => 'タイムゾーンを検索...';

  @override
  String get editProfile => 'プロフィールを編集';

  @override
  String get name => '名前';

  @override
  String get email => 'メール';

  @override
  String get saveChanges => '変更を保存';

  @override
  String get currentPassword => '現在のパスワード';

  @override
  String get newPassword => '新しいパスワード';

  @override
  String get confirmNewPassword => '新しいパスワードを確認';

  @override
  String get updatePassword => 'パスワードを更新';

  @override
  String get atLeast8Characters => '8文字以上';

  @override
  String get addInvestor => '投資家を追加';

  @override
  String get searchByInvestorName => '投資家名で検索...';

  @override
  String get searchForInvestors => '投資家を検索';

  @override
  String get trySearching => '「ARK」「Berkshire」「Bridgewater」で検索';

  @override
  String noInvestorsFound(String query) {
    return '「$query」に一致する投資家が見つかりません';
  }

  @override
  String get somethingWentWrong => 'エラーが発生しました';

  @override
  String get trackingLimitReached => '追跡上限に達しました';

  @override
  String get upgrade => 'アップグレード';

  @override
  String get login => 'ログイン';

  @override
  String get register => '登録';

  @override
  String get forgotPassword => 'パスワードをお忘れですか';

  @override
  String get password => 'パスワード';

  @override
  String get dontHaveAccount => 'アカウントをお持ちでないですか？';

  @override
  String get alreadyHaveAccount => 'すでにアカウントをお持ちですか？';

  @override
  String get etfManager => 'ETFマネージャー';

  @override
  String get hedgeFund => 'ヘッジファンド';

  @override
  String get individual => '個人投資家';

  @override
  String get unknown => '不明';

  @override
  String get featured => '注目';

  @override
  String get institutional => '機関投資家';

  @override
  String get insider => 'インサイダー';

  @override
  String get dailyEtf => 'デイリーETF';

  @override
  String get sec13f => 'SEC 13F';

  @override
  String get nPort => 'N-PORT';

  @override
  String get form4 => 'Form 4';

  @override
  String get transparencyHigh => '高い透明性';

  @override
  String get transparencyMedium => '中程度の透明性';

  @override
  String get transparencyLow => '低い透明性';

  @override
  String get unlockAiInsights => 'AIインサイトを解放';

  @override
  String get getAiPoweredAnalysis => 'AI分析とアラートを取得';

  @override
  String get pro => 'PRO';

  @override
  String get navigation => 'ナビゲーション';

  @override
  String get liveTracking => 'リアルタイム追跡';

  @override
  String get landingHeadline => 'トップ投資家の動向を追跡';

  @override
  String get landingSubheadline =>
      '機関投資家のポートフォリオをリアルタイムで監視。ARK ETF、13Fファイリング、AI分析を受信箱にお届け。';

  @override
  String get startFreeTrial => '無料トライアル開始';

  @override
  String get viewDemo => 'デモを見る';

  @override
  String get realTimeUpdates => 'リアルタイム更新';

  @override
  String get realTimeUpdatesDesc => '毎日のARK ETF取引と四半期13Fファイリング';

  @override
  String get aiPoweredInsights => 'AI分析';

  @override
  String get aiPoweredInsightsDesc => 'トップ投資家の投資理由を理解';

  @override
  String get smartAlerts => 'スマートアラート';

  @override
  String get smartAlertsDesc => 'ウォッチリストに変動があった際に通知';

  @override
  String get trustedByInvestors => '10,000人以上の投資家に信頼されています';

  @override
  String get bankGradeSecurity => '銀行レベルのセキュリティ';

  @override
  String get realTimeData => 'リアルタイムデータ';

  @override
  String get notFinancialAdvice => '投資アドバイスではありません。情報提供のみを目的としています。';

  @override
  String get signIn => 'ログイン';

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
