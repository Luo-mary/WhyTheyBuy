import 'package:flutter/material.dart';

/// The 6 analysis perspectives for sequential multi-agent reasoning.
///
/// SEQUENTIAL ORDER (each builds on previous):
/// 1. Fundamental Analysis - Foundation metrics
/// 2. News & Sentiment - Recent news context
/// 3. Market Context - Sector/macro (references 1,2)
/// 4. Technical Analysis - Price patterns (references 1,2,3)
/// 5. Investment Debate - Bull vs Bear (references ALL above)
/// 6. Risk Assessment - Overall risk synthesis (NOT investment advice)
enum ReasoningPerspective {
  fundamental,     // 1st: Foundation
  newsSentiment,   // 2nd: News context
  marketContext,   // 3rd: References 1,2
  technical,       // 4th: References 1,2,3
  bullVsBear,      // 5th: References ALL above
  riskAssessment;  // 6th: Synthesizes ALL (NOT advice)

  /// Parse from JSON string value.
  static ReasoningPerspective fromJson(String value) {
    switch (value.toLowerCase()) {
      case 'fundamental':
        return ReasoningPerspective.fundamental;
      case 'news_sentiment':
        return ReasoningPerspective.newsSentiment;
      case 'market_context':
        return ReasoningPerspective.marketContext;
      case 'technical':
        return ReasoningPerspective.technical;
      case 'bull_vs_bear':
        return ReasoningPerspective.bullVsBear;
      case 'risk_assessment':
        return ReasoningPerspective.riskAssessment;
      default:
        return ReasoningPerspective.fundamental;
    }
  }

  /// Convert to JSON string value.
  String toJson() {
    switch (this) {
      case ReasoningPerspective.newsSentiment:
        return 'news_sentiment';
      case ReasoningPerspective.marketContext:
        return 'market_context';
      case ReasoningPerspective.bullVsBear:
        return 'bull_vs_bear';
      case ReasoningPerspective.riskAssessment:
        return 'risk_assessment';
      default:
        return name;
    }
  }
}

/// Metadata for each perspective including icon and color.
class PerspectiveMetadata {
  static IconData getIcon(ReasoningPerspective perspective) {
    switch (perspective) {
      case ReasoningPerspective.fundamental:
        return Icons.bar_chart;
      case ReasoningPerspective.newsSentiment:
        return Icons.newspaper;
      case ReasoningPerspective.marketContext:
        return Icons.public;
      case ReasoningPerspective.technical:
        return Icons.show_chart;
      case ReasoningPerspective.bullVsBear:
        return Icons.gavel;
      case ReasoningPerspective.riskAssessment:
        return Icons.shield;
    }
  }

  static Color getColor(ReasoningPerspective perspective) {
    switch (perspective) {
      case ReasoningPerspective.fundamental:
        return const Color(0xFF3B82F6); // Blue
      case ReasoningPerspective.newsSentiment:
        return const Color(0xFFEC4899); // Pink
      case ReasoningPerspective.marketContext:
        return const Color(0xFF06B6D4); // Cyan
      case ReasoningPerspective.technical:
        return const Color(0xFF8B5CF6); // Purple
      case ReasoningPerspective.bullVsBear:
        return const Color(0xFFF59E0B); // Amber
      case ReasoningPerspective.riskAssessment:
        return const Color(0xFFEF4444); // Red
    }
  }

  static String getTitle(ReasoningPerspective perspective) {
    switch (perspective) {
      case ReasoningPerspective.fundamental:
        return 'Fundamental Analysis';
      case ReasoningPerspective.newsSentiment:
        return 'News & Sentiment';
      case ReasoningPerspective.marketContext:
        return 'Market Context';
      case ReasoningPerspective.technical:
        return 'Technical Analysis';
      case ReasoningPerspective.bullVsBear:
        return 'Investment Debate & Verdict';
      case ReasoningPerspective.riskAssessment:
        return 'Risk Assessment';
    }
  }

  static String getDescription(ReasoningPerspective perspective) {
    switch (perspective) {
      case ReasoningPerspective.fundamental:
        return 'Financial metrics, valuation, and company fundamentals';
      case ReasoningPerspective.newsSentiment:
        return 'Recent news coverage and market sentiment analysis';
      case ReasoningPerspective.marketContext:
        return 'Sector trends, macro factors, and peer comparison';
      case ReasoningPerspective.technical:
        return 'Price patterns, volume, and technical indicators';
      case ReasoningPerspective.bullVsBear:
        return 'Bull vs Bear debate referencing all previous analyses';
      case ReasoningPerspective.riskAssessment:
        return 'Overall risk factors - NOT investment advice';
    }
  }
}

/// A clickable evidence link with URL.
class EvidenceLink {
  final String title;
  final String url;
  final String sourceType;

  const EvidenceLink({
    required this.title,
    required this.url,
    this.sourceType = 'web',
  });

  factory EvidenceLink.fromJson(Map<String, dynamic> json) {
    return EvidenceLink(
      title: json['title'] as String? ?? 'Source',
      url: json['url'] as String? ?? '#',
      sourceType: json['source_type'] as String? ?? 'web',
    );
  }

  /// Check if this is a valid clickable URL
  bool get isClickable => url.startsWith('http://') || url.startsWith('https://');

  /// Get icon based on source type
  IconData get icon {
    switch (sourceType) {
      case 'sec_filing':
        return Icons.description;
      case 'news':
        return Icons.newspaper;
      case 'financial_data':
        return Icons.analytics;
      case 'research':
        return Icons.science;
      default:
        return Icons.link;
    }
  }
}

/// A single reasoning perspective card.
///
/// Each card represents one of the 6 sequential analysis perspectives with
/// key points, clickable evidence links, and a disclaimer.
///
/// COMPLIANCE: All content is hypothetical and for educational purposes only.
/// Risk Assessment explicitly states it is NOT investment advice.
class ReasoningCard {
  final ReasoningPerspective perspective;
  final String title;
  final IconData icon;
  final Color accentColor;
  final List<String> keyPoints;
  final List<EvidenceLink> evidence;
  final String confidence; // "low" or "medium" only
  final String disclaimer;

  // For Bull vs Bear card (includes verdict)
  final List<String>? bullPoints;
  final List<String>? bearPoints;

  // Verdict fields (part of Bull vs Bear card)
  final String? verdict; // BULLISH, BEARISH, or NEUTRAL
  final String? verdictReasoning;

  // For News Sentiment card
  final String? newsSentiment; // POSITIVE, NEGATIVE, MIXED, or NEUTRAL
  final String? newsSummary;
  final List<String>? newsSources;

  // For Risk Assessment card (NOT investment advice)
  final String? riskLevel; // LOW, MODERATE, HIGH, or VERY_HIGH
  final List<String>? riskFactors;
  final String? riskSummary;

  const ReasoningCard({
    required this.perspective,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.keyPoints,
    required this.evidence,
    required this.confidence,
    required this.disclaimer,
    this.bullPoints,
    this.bearPoints,
    this.verdict,
    this.verdictReasoning,
    this.newsSentiment,
    this.newsSummary,
    this.newsSources,
    this.riskLevel,
    this.riskFactors,
    this.riskSummary,
  });

  /// Parse from JSON response.
  factory ReasoningCard.fromJson(Map<String, dynamic> json) {
    final perspective = ReasoningPerspective.fromJson(
      json['perspective'] as String? ?? 'fundamental',
    );

    // Use metadata if title/icon/color not provided
    final title = json['title'] as String? ??
        PerspectiveMetadata.getTitle(perspective);

    final iconName = json['icon'] as String?;
    final icon = _parseIconName(iconName) ??
        PerspectiveMetadata.getIcon(perspective);

    final colorHex = json['accent_color'] as String?;
    final color = _parseHexColor(colorHex) ??
        PerspectiveMetadata.getColor(perspective);

    final keyPoints = (json['key_points'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    // Parse evidence as EvidenceLink objects
    final rawEvidence = json['evidence'] as List<dynamic>?;
    final evidence = <EvidenceLink>[];
    if (rawEvidence != null) {
      for (final e in rawEvidence) {
        if (e is Map<String, dynamic>) {
          evidence.add(EvidenceLink.fromJson(e));
        } else if (e is String) {
          // Legacy format - convert string to EvidenceLink
          evidence.add(EvidenceLink(title: e, url: '#'));
        }
      }
    }

    // Enforce confidence cap
    var confidence = (json['confidence'] as String?)?.toLowerCase() ?? 'low';
    if (confidence == 'high') {
      confidence = 'medium'; // Cap at medium
    }

    final disclaimer = json['disclaimer'] as String? ??
        'This analysis is hypothetical and for educational purposes only.';

    // Bull vs Bear specific fields (now includes verdict)
    final bullPoints = (json['bull_points'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList();
    final bearPoints = (json['bear_points'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList();

    // Verdict fields (now part of Bull vs Bear card)
    final verdict = json['verdict'] as String?;
    final verdictReasoning = json['verdict_reasoning'] as String?;

    // News Sentiment specific fields
    final newsSentiment = json['news_sentiment'] as String?;
    final newsSummary = json['news_summary'] as String?;
    final newsSources = (json['news_sources'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList();

    // Risk Assessment specific fields
    final riskLevel = json['risk_level'] as String?;
    final riskFactors = (json['risk_factors'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList();
    final riskSummary = json['risk_summary'] as String?;

    return ReasoningCard(
      perspective: perspective,
      title: title,
      icon: icon,
      accentColor: color,
      keyPoints: keyPoints,
      evidence: evidence,
      confidence: confidence,
      disclaimer: disclaimer,
      bullPoints: bullPoints,
      bearPoints: bearPoints,
      verdict: verdict,
      verdictReasoning: verdictReasoning,
      newsSentiment: newsSentiment,
      newsSummary: newsSummary,
      newsSources: newsSources,
      riskLevel: riskLevel,
      riskFactors: riskFactors,
      riskSummary: riskSummary,
    );
  }

  static IconData? _parseIconName(String? name) {
    if (name == null) return null;
    switch (name) {
      case 'bar_chart':
        return Icons.bar_chart;
      case 'public':
        return Icons.public;
      case 'show_chart':
        return Icons.show_chart;
      case 'swap_horiz':
        return Icons.swap_horiz;
      case 'gavel':
        return Icons.gavel;
      case 'newspaper':
        return Icons.newspaper;
      case 'trending_up':
        return Icons.trending_up;
      case 'trending_down':
        return Icons.trending_down;
      case 'balance':
        return Icons.balance;
      case 'shield':
        return Icons.shield;
      case 'warning':
        return Icons.warning;
      default:
        return null;
    }
  }

  static Color? _parseHexColor(String? hex) {
    if (hex == null || !hex.startsWith('#')) return null;
    try {
      final colorInt = int.parse(hex.substring(1), radix: 16);
      return Color(0xFF000000 | colorInt);
    } catch (_) {
      return null;
    }
  }

  /// Get verdict color for Bull vs Bear card
  Color get verdictColor {
    switch (verdict?.toUpperCase()) {
      case 'BULLISH':
        return const Color(0xFF10B981); // Green
      case 'BEARISH':
        return const Color(0xFFF43F5E); // Red
      case 'NEUTRAL':
      default:
        return const Color(0xFFF59E0B); // Amber
    }
  }

  /// Get verdict icon for Bull vs Bear card
  IconData get verdictIcon {
    switch (verdict?.toUpperCase()) {
      case 'BULLISH':
        return Icons.trending_up;
      case 'BEARISH':
        return Icons.trending_down;
      case 'NEUTRAL':
      default:
        return Icons.remove;
    }
  }

  /// Get news sentiment color
  Color get newsSentimentColor {
    switch (newsSentiment?.toUpperCase()) {
      case 'POSITIVE':
        return const Color(0xFF10B981); // Green
      case 'NEGATIVE':
        return const Color(0xFFF43F5E); // Red
      case 'MIXED':
        return const Color(0xFFF59E0B); // Amber
      case 'NEUTRAL':
      default:
        return const Color(0xFF6B7280); // Gray
    }
  }

  /// Get news sentiment icon
  IconData get newsSentimentIcon {
    switch (newsSentiment?.toUpperCase()) {
      case 'POSITIVE':
        return Icons.sentiment_satisfied;
      case 'NEGATIVE':
        return Icons.sentiment_dissatisfied;
      case 'MIXED':
        return Icons.sentiment_neutral;
      case 'NEUTRAL':
      default:
        return Icons.sentiment_neutral;
    }
  }

  /// Get risk level color
  Color get riskLevelColor {
    switch (riskLevel?.toUpperCase()) {
      case 'LOW':
        return const Color(0xFF10B981); // Green
      case 'MODERATE':
        return const Color(0xFFF59E0B); // Amber
      case 'HIGH':
        return const Color(0xFFF97316); // Orange
      case 'VERY_HIGH':
        return const Color(0xFFEF4444); // Red
      default:
        return const Color(0xFF6B7280); // Gray
    }
  }

  /// Get risk level icon
  IconData get riskLevelIcon {
    switch (riskLevel?.toUpperCase()) {
      case 'LOW':
        return Icons.check_circle;
      case 'MODERATE':
        return Icons.info;
      case 'HIGH':
        return Icons.warning;
      case 'VERY_HIGH':
        return Icons.error;
      default:
        return Icons.help;
    }
  }
}

/// Full multi-agent reasoning response with 6 sequential perspective cards.
///
/// COMPLIANCE: This is descriptive analysis of publicly disclosed activity.
/// It does NOT provide investment advice, predictions, or assume investor intent.
/// Risk Assessment explicitly states it is NOT investment advice.
class MultiAgentReasoningResponse {
  final String ticker;
  final String companyName;
  final String investorName;
  final String changeType;
  final String activitySummary;
  final List<ReasoningCard> cards;
  final List<String> unknowns;
  final String overallDisclaimer;
  final DateTime generatedAt;

  const MultiAgentReasoningResponse({
    required this.ticker,
    required this.companyName,
    required this.investorName,
    required this.changeType,
    required this.activitySummary,
    required this.cards,
    required this.unknowns,
    required this.overallDisclaimer,
    required this.generatedAt,
  });

  /// Parse from JSON response.
  factory MultiAgentReasoningResponse.fromJson(Map<String, dynamic> json) {
    final cards = (json['cards'] as List<dynamic>?)
            ?.map((e) => ReasoningCard.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final unknowns = (json['unknowns'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [
          "The exact execution prices at which trades were made",
          "The investor's private reasoning and decision-making process",
          "Whether the investor plans to increase, decrease, or maintain this position",
        ];

    // Parse generated_at timestamp
    DateTime generatedAt;
    try {
      generatedAt = DateTime.parse(json['generated_at'] as String);
    } catch (_) {
      generatedAt = DateTime.now();
    }

    return MultiAgentReasoningResponse(
      ticker: json['ticker'] as String? ?? '',
      companyName: json['company_name'] as String? ?? '',
      investorName: json['investor_name'] as String? ?? '',
      changeType: json['change_type'] as String? ?? 'CHANGED',
      activitySummary: json['activity_summary'] as String? ?? '',
      cards: cards,
      unknowns: unknowns,
      overallDisclaimer: json['overall_disclaimer'] as String? ??
          'This multi-perspective analysis is for educational purposes only. '
              'It does NOT constitute investment advice.',
      generatedAt: generatedAt,
    );
  }

  /// Get a card by perspective type.
  ReasoningCard? getCard(ReasoningPerspective perspective) {
    try {
      return cards.firstWhere((c) => c.perspective == perspective);
    } catch (_) {
      return null;
    }
  }
}
