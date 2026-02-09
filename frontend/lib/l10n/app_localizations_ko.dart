// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appName => 'WhyTheyBuy';

  @override
  String get home => '홈';

  @override
  String get settings => '설정';

  @override
  String get addInvestorToTrack => '추적할 투자자 추가';

  @override
  String get recommendedInvestors => '추천 투자자';

  @override
  String get shuffle => '섞기';

  @override
  String get featuredInvestor => '주목할 투자자';

  @override
  String get disclaimer => '교육 목적으로만 제공됩니다. 투자 조언이 아닙니다.';

  @override
  String get manageAccountPreferences => '계정 및 환경설정 관리';

  @override
  String get freePlan => '무료 플랜';

  @override
  String get upgradeToPro => 'Pro로 업그레이드';

  @override
  String get upgradeDescription => '최대 10명의 투자자 모니터링, 즉시 알림, 고급 AI 요약';

  @override
  String perMonth(String price) {
    return '$price/월';
  }

  @override
  String perYear(String price) {
    return '$price/년';
  }

  @override
  String get account => '계정';

  @override
  String get profile => '프로필';

  @override
  String get notificationEmails => '알림 이메일';

  @override
  String get changePassword => '비밀번호 변경';

  @override
  String get preferences => '환경설정';

  @override
  String get language => '언어';

  @override
  String get timezone => '시간대';

  @override
  String get support => '지원';

  @override
  String get helpCenter => '도움말 센터';

  @override
  String get sendFeedback => '피드백 보내기';

  @override
  String get termsOfService => '서비스 약관';

  @override
  String get privacyPolicy => '개인정보 처리방침';

  @override
  String get signOut => '로그아웃';

  @override
  String get selectLanguage => '언어 선택';

  @override
  String get selectTimezone => '시간대 선택';

  @override
  String get searchTimezones => '시간대 검색...';

  @override
  String get editProfile => '프로필 편집';

  @override
  String get name => '이름';

  @override
  String get email => '이메일';

  @override
  String get saveChanges => '변경사항 저장';

  @override
  String get currentPassword => '현재 비밀번호';

  @override
  String get newPassword => '새 비밀번호';

  @override
  String get confirmNewPassword => '새 비밀번호 확인';

  @override
  String get updatePassword => '비밀번호 업데이트';

  @override
  String get atLeast8Characters => '최소 8자 이상';

  @override
  String get addInvestor => '투자자 추가';

  @override
  String get searchByInvestorName => '투자자 이름으로 검색...';

  @override
  String get searchForInvestors => '투자자 검색';

  @override
  String get trySearching => '\"ARK\", \"Berkshire\", \"Bridgewater\" 검색해보세요';

  @override
  String noInvestorsFound(String query) {
    return '\"$query\"에 대한 투자자를 찾을 수 없습니다';
  }

  @override
  String get somethingWentWrong => '문제가 발생했습니다';

  @override
  String get trackingLimitReached => '추적 한도 도달';

  @override
  String get upgrade => '업그레이드';

  @override
  String get login => '로그인';

  @override
  String get register => '회원가입';

  @override
  String get forgotPassword => '비밀번호 찾기';

  @override
  String get password => '비밀번호';

  @override
  String get dontHaveAccount => '계정이 없으신가요?';

  @override
  String get alreadyHaveAccount => '이미 계정이 있으신가요?';

  @override
  String get etfManager => 'ETF 매니저';

  @override
  String get hedgeFund => '헤지펀드';

  @override
  String get individual => '개인 투자자';

  @override
  String get unknown => '알 수 없음';

  @override
  String get featured => '추천';

  @override
  String get institutional => '기관';

  @override
  String get insider => '내부자';

  @override
  String get dailyEtf => '일일 ETF';

  @override
  String get sec13f => 'SEC 13F';

  @override
  String get nPort => 'N-PORT';

  @override
  String get form4 => 'Form 4';

  @override
  String get transparencyHigh => '높은 투명성';

  @override
  String get transparencyMedium => '중간 투명성';

  @override
  String get transparencyLow => '낮은 투명성';

  @override
  String get unlockAiInsights => 'AI 인사이트 잠금 해제';

  @override
  String get getAiPoweredAnalysis => 'AI 기반 분석 및 알림 받기';

  @override
  String get pro => 'PRO';

  @override
  String get navigation => '탐색';

  @override
  String get liveTracking => '실시간 추적';

  @override
  String get landingHeadline => '최고 투자자들의 투자를 추적하세요';

  @override
  String get landingSubheadline =>
      '기관 보유 현황을 실시간으로 모니터링. ARK ETF, 13F 파일링, AI 기반 인사이트를 받아보세요.';

  @override
  String get startFreeTrial => '무료 체험 시작';

  @override
  String get viewDemo => '데모 보기';

  @override
  String get realTimeUpdates => '실시간 업데이트';

  @override
  String get realTimeUpdatesDesc => '일일 ARK ETF 거래 및 분기별 13F 파일링';

  @override
  String get aiPoweredInsights => 'AI 기반 인사이트';

  @override
  String get aiPoweredInsightsDesc => '최고 투자자들의 투자 이유를 이해하세요';

  @override
  String get smartAlerts => '스마트 알림';

  @override
  String get smartAlertsDesc => '관심 목록에 변동이 있을 때 알림 받기';

  @override
  String get trustedByInvestors => '10,000명 이상의 투자자가 신뢰';

  @override
  String get bankGradeSecurity => '은행급 보안';

  @override
  String get realTimeData => '실시간 데이터';

  @override
  String get notFinancialAdvice => '금융 조언이 아닙니다. 정보 제공 목적으로만 데이터가 제공됩니다.';

  @override
  String get signIn => '로그인';

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
