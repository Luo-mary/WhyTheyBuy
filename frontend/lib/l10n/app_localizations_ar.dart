// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'WhyTheyBuy';

  @override
  String get home => 'الرئيسية';

  @override
  String get settings => 'الإعدادات';

  @override
  String get addInvestorToTrack => 'أضف مستثمراً للمتابعة';

  @override
  String get recommendedInvestors => 'مستثمرون موصى بهم';

  @override
  String get shuffle => 'خلط';

  @override
  String get featuredInvestor => 'مستثمر مميز';

  @override
  String get disclaimer => 'للأغراض التعليمية فقط. ليست نصيحة استثمارية.';

  @override
  String get manageAccountPreferences => 'إدارة حسابك وتفضيلاتك';

  @override
  String get freePlan => 'مجاني';

  @override
  String get upgradeToPro => 'الترقية إلى Pro';

  @override
  String get upgradeDescription =>
      'راقب حتى 10 مستثمرين، تنبيهات فورية، ملخصات ذكاء اصطناعي متقدمة';

  @override
  String perMonth(String price) {
    return '$price/شهر';
  }

  @override
  String perYear(String price) {
    return '$price/سنة';
  }

  @override
  String get account => 'الحساب';

  @override
  String get profile => 'الملف الشخصي';

  @override
  String get notificationEmails => 'رسائل الإشعارات';

  @override
  String get changePassword => 'تغيير كلمة المرور';

  @override
  String get preferences => 'التفضيلات';

  @override
  String get language => 'اللغة';

  @override
  String get timezone => 'المنطقة الزمنية';

  @override
  String get support => 'الدعم';

  @override
  String get helpCenter => 'مركز المساعدة';

  @override
  String get sendFeedback => 'إرسال ملاحظات';

  @override
  String get termsOfService => 'شروط الخدمة';

  @override
  String get privacyPolicy => 'سياسة الخصوصية';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get selectLanguage => 'اختر اللغة';

  @override
  String get selectTimezone => 'اختر المنطقة الزمنية';

  @override
  String get searchTimezones => 'البحث عن المناطق الزمنية...';

  @override
  String get editProfile => 'تعديل الملف الشخصي';

  @override
  String get name => 'الاسم';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get saveChanges => 'حفظ التغييرات';

  @override
  String get currentPassword => 'كلمة المرور الحالية';

  @override
  String get newPassword => 'كلمة المرور الجديدة';

  @override
  String get confirmNewPassword => 'تأكيد كلمة المرور الجديدة';

  @override
  String get updatePassword => 'تحديث كلمة المرور';

  @override
  String get atLeast8Characters => '8 أحرف على الأقل';

  @override
  String get addInvestor => 'إضافة مستثمر';

  @override
  String get searchByInvestorName => 'البحث باسم المستثمر...';

  @override
  String get searchForInvestors => 'البحث عن مستثمرين';

  @override
  String get trySearching => 'جرب \"ARK\" أو \"Berkshire\" أو \"Bridgewater\"';

  @override
  String noInvestorsFound(String query) {
    return 'لم يتم العثور على مستثمرين لـ \"$query\"';
  }

  @override
  String get somethingWentWrong => 'حدث خطأ ما';

  @override
  String get trackingLimitReached => 'تم الوصول إلى حد المتابعة';

  @override
  String get upgrade => 'ترقية';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get register => 'التسجيل';

  @override
  String get forgotPassword => 'نسيت كلمة المرور';

  @override
  String get password => 'كلمة المرور';

  @override
  String get dontHaveAccount => 'ليس لديك حساب؟';

  @override
  String get alreadyHaveAccount => 'لديك حساب بالفعل؟';

  @override
  String get etfManager => 'مدير ETF';

  @override
  String get hedgeFund => 'صندوق تحوط';

  @override
  String get individual => 'مستثمر فردي';

  @override
  String get unknown => 'غير معروف';

  @override
  String get featured => 'مميز';

  @override
  String get institutional => 'مؤسسي';

  @override
  String get insider => 'من الداخل';

  @override
  String get dailyEtf => 'ETF يومي';

  @override
  String get sec13f => 'SEC 13F';

  @override
  String get nPort => 'N-PORT';

  @override
  String get form4 => 'Form 4';

  @override
  String get transparencyHigh => 'شفافية عالية';

  @override
  String get transparencyMedium => 'شفافية متوسطة';

  @override
  String get transparencyLow => 'شفافية منخفضة';

  @override
  String get unlockAiInsights => 'افتح رؤى الذكاء الاصطناعي';

  @override
  String get getAiPoweredAnalysis =>
      'احصل على تحليلات وتنبيهات مدعومة بالذكاء الاصطناعي';

  @override
  String get pro => 'PRO';

  @override
  String get navigation => 'التنقل';

  @override
  String get liveTracking => 'تتبع مباشر';

  @override
  String get landingHeadline => 'تتبع ما يشتريه كبار المستثمرين';

  @override
  String get landingSubheadline =>
      'راقب حيازات المؤسسات في الوقت الفعلي. صناديق ARK ETF، ملفات 13F، ورؤى مدعومة بالذكاء الاصطناعي مباشرة إلى بريدك.';

  @override
  String get startFreeTrial => 'ابدأ التجربة المجانية';

  @override
  String get viewDemo => 'عرض التجريبي';

  @override
  String get realTimeUpdates => 'تحديثات فورية';

  @override
  String get realTimeUpdatesDesc => 'صفقات ARK ETF اليومية وملفات 13F الفصلية';

  @override
  String get aiPoweredInsights => 'رؤى الذكاء الاصطناعي';

  @override
  String get aiPoweredInsightsDesc =>
      'افهم لماذا يتخذ كبار المستثمرين قراراتهم';

  @override
  String get smartAlerts => 'تنبيهات ذكية';

  @override
  String get smartAlertsDesc => 'احصل على إشعارات عند تغير قائمة المتابعة';

  @override
  String get trustedByInvestors => 'موثوق من قبل أكثر من 10,000 مستثمر';

  @override
  String get bankGradeSecurity => 'أمان بمستوى البنوك';

  @override
  String get realTimeData => 'بيانات فورية';

  @override
  String get notFinancialAdvice =>
      'ليست نصيحة مالية. البيانات مقدمة لأغراض إعلامية فقط.';

  @override
  String get signIn => 'تسجيل الدخول';

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
