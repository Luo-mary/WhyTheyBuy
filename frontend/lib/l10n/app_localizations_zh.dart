// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'WhyTheyBuy';

  @override
  String get home => '首页';

  @override
  String get settings => '设置';

  @override
  String get addInvestorToTrack => '添加投资者进行跟踪';

  @override
  String get recommendedInvestors => '推荐投资者';

  @override
  String get shuffle => '换一批';

  @override
  String get featuredInvestor => '精选投资者';

  @override
  String get disclaimer => '仅供教育目的。不构成投资建议。';

  @override
  String get manageAccountPreferences => '管理您的账户和偏好设置';

  @override
  String get freePlan => '免费版';

  @override
  String get upgradeToPro => '升级到专业版';

  @override
  String get upgradeDescription => '监控多达10位投资者，即时提醒，高级AI摘要';

  @override
  String perMonth(String price) {
    return '$price/月';
  }

  @override
  String perYear(String price) {
    return '$price/年';
  }

  @override
  String get account => '账户';

  @override
  String get profile => '个人资料';

  @override
  String get notificationEmails => '通知邮件';

  @override
  String get changePassword => '修改密码';

  @override
  String get preferences => '偏好设置';

  @override
  String get language => '语言';

  @override
  String get timezone => '时区';

  @override
  String get support => '支持';

  @override
  String get helpCenter => '帮助中心';

  @override
  String get sendFeedback => '发送反馈';

  @override
  String get termsOfService => '服务条款';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get signOut => '退出登录';

  @override
  String get selectLanguage => '选择语言';

  @override
  String get selectTimezone => '选择时区';

  @override
  String get searchTimezones => '搜索时区...';

  @override
  String get editProfile => '编辑资料';

  @override
  String get name => '姓名';

  @override
  String get email => '邮箱';

  @override
  String get saveChanges => '保存更改';

  @override
  String get currentPassword => '当前密码';

  @override
  String get newPassword => '新密码';

  @override
  String get confirmNewPassword => '确认新密码';

  @override
  String get updatePassword => '更新密码';

  @override
  String get atLeast8Characters => '至少8个字符';

  @override
  String get addInvestor => '添加投资者';

  @override
  String get searchByInvestorName => '按投资者名称搜索...';

  @override
  String get searchForInvestors => '搜索投资者';

  @override
  String get trySearching => '试试 \"ARK\"、\"Berkshire\" 或 \"Bridgewater\"';

  @override
  String noInvestorsFound(String query) {
    return '未找到 \"$query\" 相关的投资者';
  }

  @override
  String get somethingWentWrong => '出错了';

  @override
  String get trackingLimitReached => '已达跟踪上限';

  @override
  String get upgrade => '升级';

  @override
  String get login => '登录';

  @override
  String get register => '注册';

  @override
  String get forgotPassword => '忘记密码';

  @override
  String get password => '密码';

  @override
  String get dontHaveAccount => '没有账户？';

  @override
  String get alreadyHaveAccount => '已有账户？';

  @override
  String get etfManager => 'ETF管理人';

  @override
  String get hedgeFund => '对冲基金';

  @override
  String get individual => '个人投资者';

  @override
  String get unknown => '未知';

  @override
  String get featured => '精选';

  @override
  String get institutional => '机构投资者';

  @override
  String get insider => '内部人士';

  @override
  String get dailyEtf => '每日ETF';

  @override
  String get sec13f => 'SEC 13F';

  @override
  String get nPort => 'N-PORT';

  @override
  String get form4 => 'Form 4';

  @override
  String get transparencyHigh => '高透明度';

  @override
  String get transparencyMedium => '中等透明度';

  @override
  String get transparencyLow => '低透明度';

  @override
  String get unlockAiInsights => '解锁AI洞察';

  @override
  String get getAiPoweredAnalysis => '获取AI驱动的分析和提醒';

  @override
  String get pro => '专业版';

  @override
  String get navigation => '导航';

  @override
  String get liveTracking => '实时追踪';

  @override
  String get landingHeadline => '追踪顶级投资者的投资动向';

  @override
  String get landingSubheadline => '实时监控机构持仓。ARK ETF、13F文件和AI驱动的洞察直达您的收件箱。';

  @override
  String get startFreeTrial => '开始免费试用';

  @override
  String get viewDemo => '查看演示';

  @override
  String get realTimeUpdates => '实时更新';

  @override
  String get realTimeUpdatesDesc => '每日ARK ETF交易和季度13F文件';

  @override
  String get aiPoweredInsights => 'AI驱动洞察';

  @override
  String get aiPoweredInsightsDesc => '了解顶级投资者的投资动机';

  @override
  String get smartAlerts => '智能提醒';

  @override
  String get smartAlertsDesc => '关注列表有变动时及时通知您';

  @override
  String get trustedByInvestors => '受到10,000+投资者信赖';

  @override
  String get bankGradeSecurity => '银行级安全';

  @override
  String get realTimeData => '实时数据';

  @override
  String get notFinancialAdvice => '非投资建议。数据仅供参考。';

  @override
  String get signIn => '登录';

  @override
  String get portfolioOverview => '投资组合概览';

  @override
  String get sectorBreakdownActivity => '行业分布与近期活动';

  @override
  String get totalHoldings => '总持仓';

  @override
  String get changes30d => '近30天变化';

  @override
  String get lastUpdate => '最后更新';

  @override
  String get latestSnapshot => '最新快照';

  @override
  String get positions => '个持仓';

  @override
  String get sectorAllocation => '行业配置';

  @override
  String get recentActivity => '近期活动';

  @override
  String get noHoldingsDataYet => '暂无持仓数据。数据将在下次数据更新后显示。';

  @override
  String moreSectors(int count) {
    return '还有$count个行业';
  }

  @override
  String get holdingsSnapshot => '持仓快照';

  @override
  String get noHoldingsData => '暂无持仓数据';

  @override
  String get ticker => '代码';

  @override
  String get weight => '权重';

  @override
  String get value => '市值';

  @override
  String get showTop10 => '显示前10';

  @override
  String viewAllHoldings(int count) {
    return '查看全部$count个持仓';
  }

  @override
  String get basedOnPublicDisclosures => '基于公开披露的持仓数据。此内容不构成投资建议。';

  @override
  String get portfolioOverviewUnavailable => '投资组合概览不可用。请连接后端以查看行业分布和近期活动。';

  @override
  String get holdingsChanges => '持仓变动';

  @override
  String get last30Days => '近30天';

  @override
  String get cancel => '取消';

  @override
  String get selectForReport => '选择生成报告';

  @override
  String nChanges(int count) {
    return '$count项变动';
  }

  @override
  String get noChangesLast30Days => '近30天无持仓变动';

  @override
  String get topBuys => '主要买入';

  @override
  String get topSells => '主要卖出';

  @override
  String hideMoreChanges(int count) {
    return '收起$count项变动';
  }

  @override
  String showMoreChanges(int count) {
    return '展开$count项变动';
  }

  @override
  String nSelected(int count) {
    return '已选$count项';
  }

  @override
  String get clear => '清除';

  @override
  String get generateReport => '生成报告';

  @override
  String get shares => '股';

  @override
  String get estimated => '估值';

  @override
  String get aiReasoningLimit => 'AI分析限制';

  @override
  String get freeUserReasoningLimit =>
      '免费用户可查看前5笔买入和前5笔卖出的AI分析。升级至专业版可解锁所有交易的AI分析。';

  @override
  String get evidence => '证据';

  @override
  String get possibleRationales => '可能的投资逻辑';

  @override
  String get hypothesis => '假设';

  @override
  String get aiReasoningUnavailable => 'AI分析不可用';

  @override
  String get connectBackendForAi => '请连接配置了AI密钥的后端服务，以查看由AI生成的证据和投资假设。';

  @override
  String get failedToLoadInvestor => '加载投资者信息失败';

  @override
  String get generatingAnalysis => '正在生成多维分析';

  @override
  String get fundamental => '基本面';

  @override
  String get news => '资讯';

  @override
  String get market => '市场';

  @override
  String get technical => '技术面';

  @override
  String get debate => '观点碰撞';

  @override
  String get risk => '风险';

  @override
  String get analysisUnavailable => '分析不可用';

  @override
  String get retry => '重试';

  @override
  String get disclaimersLimitations => '免责声明与局限性';

  @override
  String get whatWeDontKnow => '未知因素';

  @override
  String get myInvestors => '我的投资者';

  @override
  String nTracked(int count) {
    return '已跟踪$count位';
  }

  @override
  String get defaultLabel => '默认';

  @override
  String get noInvestorsTrackedYet => '暂无跟踪的投资者';

  @override
  String get addInvestorsToTrack => '添加投资者以跟踪其持仓并获取AI洞察。';

  @override
  String get addYourFirstInvestor => '添加您的第一位投资者';

  @override
  String get addToWatchlist => '添加到关注列表';

  @override
  String get addToWatchlistQuestion => '添加到关注列表？';

  @override
  String addToWatchlistDescription(String name) {
    return '将\"$name\"添加到您的关注列表，以查看其交易记录和AI分析。';
  }

  @override
  String get onlyWatchlistedInvestors => '只有关注列表中的投资者才能查看交易和AI洞察。';

  @override
  String addedToWatchlist(String name) {
    return '$name已添加到您的关注列表';
  }

  @override
  String get failedToAddInvestor => '添加投资者失败';

  @override
  String get investorLimitReached => '已达投资者上限';

  @override
  String freeUserLimit(int count) {
    return '免费用户最多可跟踪$count位投资者。升级至专业版可跟踪最多10位投资者。';
  }

  @override
  String proUserLimit(int count) {
    return '专业版用户最多可跟踪$count位投资者。升级至Pro+可无限跟踪。';
  }

  @override
  String trackingLimitMessage(int count) {
    return '您已达到$count位投资者的跟踪上限。';
  }

  @override
  String get viewPlans => '查看套餐';

  @override
  String get forEducationalPurposes => '仅供教育目的。不构成投资建议。';

  @override
  String get changeTypeNew => '新建仓';

  @override
  String get changeTypeAdded => '加仓';

  @override
  String get changeTypeReduced => '减仓';

  @override
  String get changeTypeSold => '清仓';
}
