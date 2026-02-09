class SubscriptionModel {
  final String id;
  final String userId;
  final String tier; // 'free', 'pro', 'pro_plus'
  final String? billingCycle;
  final String status;
  final bool isActive;
  final bool isPaid;
  final bool isPro;
  final bool isProPlus;
  final int maxMonitoredInvestors;
  final int monitoredInvestorsCount;
  final bool canAddInvestor;
  final bool canInstantAlerts;
  final bool canDailyDigest;
  final bool evidencePanelEnabled;
  final bool transparencyScoreVisible;
  final int historyDays;
  final bool exportEnabled;
  final int aiReasoningLimit; // -1 for unlimited, or max rank
  final String defaultInvestorSlug;

  const SubscriptionModel({
    required this.id,
    required this.userId,
    required this.tier,
    this.billingCycle,
    required this.status,
    required this.isActive,
    required this.isPaid,
    required this.isPro,
    required this.isProPlus,
    required this.maxMonitoredInvestors,
    required this.monitoredInvestorsCount,
    required this.canAddInvestor,
    required this.canInstantAlerts,
    required this.canDailyDigest,
    required this.evidencePanelEnabled,
    required this.transparencyScoreVisible,
    required this.historyDays,
    required this.exportEnabled,
    required this.aiReasoningLimit,
    required this.defaultInvestorSlug,
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      tier: json['tier'] as String,
      billingCycle: json['billing_cycle'] as String?,
      status: json['status'] as String,
      isActive: json['is_active'] as bool? ?? false,
      isPaid: json['is_paid'] as bool? ?? false,
      isPro: json['is_pro'] as bool? ?? false,
      isProPlus: json['is_pro_plus'] as bool? ?? false,
      maxMonitoredInvestors: json['max_monitored_investors'] as int? ?? 1,
      monitoredInvestorsCount: json['monitored_investors_count'] as int? ?? 0,
      canAddInvestor: json['can_add_investor'] as bool? ?? true,
      canInstantAlerts: json['can_instant_alerts'] as bool? ?? false,
      canDailyDigest: json['can_daily_digest'] as bool? ?? false,
      evidencePanelEnabled: json['evidence_panel_enabled'] as bool? ?? false,
      transparencyScoreVisible: json['transparency_score_visible'] as bool? ?? false,
      historyDays: json['history_days'] as int? ?? 7,
      exportEnabled: json['export_enabled'] as bool? ?? false,
      aiReasoningLimit: json['ai_reasoning_limit'] as int? ?? 5,
      defaultInvestorSlug: json['default_investor_slug'] as String? ?? 'berkshire-hathaway',
    );
  }

  String get tierDisplayName {
    switch (tier) {
      case 'pro':
        return 'Pro';
      case 'pro_plus':
        return 'Pro+';
      default:
        return 'Free';
    }
  }

  bool get isFree => tier == 'free';

  /// Whether user has unlimited investor tracking.
  bool get hasUnlimitedInvestors => maxMonitoredInvestors == -1;

  /// Check if user can access AI reasoning for a transaction at given rank.
  /// Rank is 1-indexed (1 = top buy/sell).
  bool canAccessAiReasoning(int rank) {
    if (aiReasoningLimit == -1) return true;
    return rank <= aiReasoningLimit;
  }

  /// Whether user has unlimited AI reasoning access.
  bool get hasUnlimitedAiReasoning => aiReasoningLimit == -1;
}
