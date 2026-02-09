import 'package:flutter/material.dart';

/// Subscription tier for feature gating
enum SubscriptionTier {
  free,
  pro,
  proPlus,
}

/// Signal category types from backend
enum SignalCategory {
  holdingsData,
  priceData,
  companyProfile,
  investorStrategy,
  disclosureMetadata,
  historicalPattern,
}

/// Single evidence signal
class EvidenceSignal {
  final String signalId;
  final SignalCategory category;
  final String description;
  final String source;
  final String? value;

  const EvidenceSignal({
    required this.signalId,
    required this.category,
    required this.description,
    required this.source,
    this.value,
  });

  factory EvidenceSignal.fromJson(Map<String, dynamic> json) {
    return EvidenceSignal(
      signalId: json['signal_id'] ?? '',
      category: _parseCategory(json['category']),
      description: json['description'] ?? '',
      source: json['source'] ?? '',
      value: json['value'],
    );
  }

  static SignalCategory _parseCategory(String? category) {
    switch (category) {
      case 'holdings_data':
        return SignalCategory.holdingsData;
      case 'price_data':
        return SignalCategory.priceData;
      case 'company_profile':
        return SignalCategory.companyProfile;
      case 'investor_strategy':
        return SignalCategory.investorStrategy;
      case 'disclosure_metadata':
        return SignalCategory.disclosureMetadata;
      case 'historical_pattern':
        return SignalCategory.historicalPattern;
      default:
        return SignalCategory.holdingsData;
    }
  }
}

/// Unknown factor
class UnknownFactor {
  final String unknownId;
  final String description;
  final bool isStandard;
  final String? impact;

  const UnknownFactor({
    required this.unknownId,
    required this.description,
    this.isStandard = false,
    this.impact,
  });

  factory UnknownFactor.fromJson(Map<String, dynamic> json) {
    return UnknownFactor(
      unknownId: json['unknown_id'] ?? '',
      description: json['description'] ?? '',
      isStandard: json['is_standard'] ?? false,
      impact: json['impact'],
    );
  }
}

/// Evidence panel data from AI response
class EvidencePanelData {
  final List<EvidenceSignal> signalsUsed;
  final List<UnknownFactor> unknowns;
  final String evidenceCompleteness;
  final String evidenceCompletenessNote;
  final List<String> signalsUnavailable;
  final String? transparencyContext;
  final bool shouldAutoExpand;

  const EvidencePanelData({
    required this.signalsUsed,
    required this.unknowns,
    this.evidenceCompleteness = 'limited',
    this.evidenceCompletenessNote = '',
    this.signalsUnavailable = const [],
    this.transparencyContext,
    this.shouldAutoExpand = false,
  });

  factory EvidencePanelData.fromJson(Map<String, dynamic> json) {
    return EvidencePanelData(
      signalsUsed: (json['signals_used'] as List<dynamic>?)
              ?.map((e) => EvidenceSignal.fromJson(e))
              .toList() ??
          [],
      unknowns: (json['unknowns'] as List<dynamic>?)
              ?.map((e) => UnknownFactor.fromJson(e))
              .toList() ??
          [],
      evidenceCompleteness: json['evidence_completeness'] ?? 'limited',
      evidenceCompletenessNote: json['evidence_completeness_note'] ?? '',
      signalsUnavailable:
          List<String>.from(json['signals_unavailable'] ?? []),
      transparencyContext: json['transparency_context'],
      shouldAutoExpand: json['should_auto_expand'] ?? false,
    );
  }

  /// Get standard unknowns
  List<UnknownFactor> get standardUnknowns =>
      unknowns.where((u) => u.isStandard).toList();

  /// Get additional unknowns
  List<UnknownFactor> get additionalUnknowns =>
      unknowns.where((u) => !u.isStandard).toList();
}

/// Evidence Panel Widget
/// 
/// Displays what information the AI used and what is unknown.
/// Designed to be honest, cautious, and institutional-grade.
class EvidencePanel extends StatefulWidget {
  final EvidencePanelData data;
  final bool initiallyExpanded;
  final Color? backgroundColor;
  final Color? borderColor;

  const EvidencePanel({
    super.key,
    required this.data,
    this.initiallyExpanded = false,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  State<EvidencePanel> createState() => _EvidencePanelState();
}

class _EvidencePanelState extends State<EvidencePanel>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _animationController;
  late Animation<double> _heightFactor;

  @override
  void initState() {
    super.initState();
    // Auto-expand if transparency is low or evidence is insufficient
    _isExpanded = widget.initiallyExpanded || widget.data.shouldAutoExpand;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _heightFactor = _animationController.drive(CurveTween(curve: Curves.easeInOut));
    if (_isExpanded) {
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  Color _getCompletenessColor() {
    switch (widget.data.evidenceCompleteness) {
      case 'sufficient':
        return const Color(0xFF22C55E); // Green
      case 'limited':
        return const Color(0xFFF59E0B); // Amber
      case 'insufficient':
        return const Color(0xFFEF4444); // Red
      default:
        return const Color(0xFF64748B); // Slate
    }
  }

  String _getCompletenessLabel() {
    switch (widget.data.evidenceCompleteness) {
      case 'sufficient':
        return 'Sufficient Evidence';
      case 'limited':
        return 'Limited Evidence';
      case 'insufficient':
        return 'Insufficient Evidence';
      default:
        return 'Unknown';
    }
  }

  IconData _getCategoryIcon(SignalCategory category) {
    switch (category) {
      case SignalCategory.holdingsData:
        return Icons.pie_chart_outline;
      case SignalCategory.priceData:
        return Icons.trending_up;
      case SignalCategory.companyProfile:
        return Icons.business;
      case SignalCategory.investorStrategy:
        return Icons.psychology;
      case SignalCategory.disclosureMetadata:
        return Icons.description;
      case SignalCategory.historicalPattern:
        return Icons.timeline;
    }
  }

  String _getCategoryLabel(SignalCategory category) {
    switch (category) {
      case SignalCategory.holdingsData:
        return 'Holdings Data';
      case SignalCategory.priceData:
        return 'Price Data';
      case SignalCategory.companyProfile:
        return 'Company Profile';
      case SignalCategory.investorStrategy:
        return 'Investor Strategy';
      case SignalCategory.disclosureMetadata:
        return 'Disclosure Info';
      case SignalCategory.historicalPattern:
        return 'Historical Pattern';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final bgColor = widget.backgroundColor ?? 
        (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC));
    final borderColor = widget.borderColor ?? 
        (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));
    
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header (always visible)
          InkWell(
            onTap: _toggleExpanded,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Evidence icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getCompletenessColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.fact_check_outlined,
                      color: _getCompletenessColor(),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Title and status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Evidence Panel',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getCompletenessColor().withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _getCompletenessLabel(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: _getCompletenessColor(),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '${widget.data.signalsUsed.length} signals used',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Expand/collapse icon
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Expandable content
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: _heightFactor.value,
                  child: child,
                ),
              );
            },
            child: _buildExpandedContent(theme, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Transparency context (if low)
            if (widget.data.transparencyContext != null) ...[
              _buildInfoBanner(
                theme,
                Icons.info_outline,
                widget.data.transparencyContext!,
                isWarning: widget.data.shouldAutoExpand,
              ),
              const SizedBox(height: 16),
            ],
            
            // Evidence completeness note
            if (widget.data.evidenceCompletenessNote.isNotEmpty) ...[
              Text(
                widget.data.evidenceCompletenessNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Signals Used section
            _buildSectionHeader(theme, 'Signals Used', Icons.check_circle_outline),
            const SizedBox(height: 8),
            _buildSignalsList(theme, isDark),
            
            const SizedBox(height: 20),
            
            // What We Don't Know section
            _buildSectionHeader(theme, 'What We Don\'t Know', Icons.help_outline),
            const SizedBox(height: 8),
            _buildUnknownsList(theme, isDark),
            
            // Unavailable signals
            if (widget.data.signalsUnavailable.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildSectionHeader(theme, 'Not Available', Icons.block_outlined),
              const SizedBox(height: 8),
              _buildUnavailableList(theme, isDark),
            ],
            
            // Disclaimer
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI analysis is based only on the signals listed above. '
                      'Any interpretation is hypothetical. This is not investment advice.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner(ThemeData theme, IconData icon, String text, {bool isWarning = false}) {
    final color = isWarning ? const Color(0xFFF59E0B) : const Color(0xFF3B82F6);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: theme.colorScheme.onSurface.withOpacity(0.7),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withOpacity(0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildSignalsList(ThemeData theme, bool isDark) {
    if (widget.data.signalsUsed.isEmpty) {
      return _buildEmptyState(theme, 'No signals available');
    }

    // Group signals by category
    final grouped = <SignalCategory, List<EvidenceSignal>>{};
    for (final signal in widget.data.signalsUsed) {
      grouped.putIfAbsent(signal.category, () => []).add(signal);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category header
            Padding(
              padding: const EdgeInsets.only(bottom: 6, top: 8),
              child: Row(
                children: [
                  Icon(
                    _getCategoryIcon(entry.key),
                    size: 14,
                    color: theme.colorScheme.primary.withOpacity(0.7),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getCategoryLabel(entry.key),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Signals
            ...entry.value.take(5).map((signal) => _buildSignalItem(theme, isDark, signal)),
            if (entry.value.length > 5)
              Padding(
                padding: const EdgeInsets.only(left: 20, top: 4),
                child: Text(
                  '+ ${entry.value.length - 5} more',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildSignalItem(ThemeData theme, bool isDark, EvidenceSignal signal) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  signal.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
                if (signal.value != null)
                  Text(
                    signal.value!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                      fontFamily: 'monospace',
                    ),
                  ),
                Text(
                  'Source: ${signal.source}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnknownsList(ThemeData theme, bool isDark) {
    if (widget.data.unknowns.isEmpty) {
      return _buildEmptyState(theme, 'No unknowns listed');
    }

    // Show standard unknowns first
    final standardUnknowns = widget.data.standardUnknowns;
    final additionalUnknowns = widget.data.additionalUnknowns;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Standard unknowns (always present)
        if (standardUnknowns.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Always Unknown:',
              style: theme.textTheme.labelSmall?.copyWith(
                color: const Color(0xFFEF4444).withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ...standardUnknowns.map((u) => _buildUnknownItem(theme, isDark, u)),
        ],
        
        // Additional unknowns
        if (additionalUnknowns.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Additional Unknowns:',
              style: theme.textTheme.labelSmall?.copyWith(
                color: const Color(0xFFF59E0B).withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ...additionalUnknowns.map((u) => _buildUnknownItem(theme, isDark, u)),
        ],
      ],
    );
  }

  Widget _buildUnknownItem(ThemeData theme, bool isDark, UnknownFactor unknown) {
    final color = unknown.isStandard ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
    
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.7),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unknown.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
                if (unknown.impact != null)
                  Text(
                    'Impact: ${unknown.impact}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnavailableList(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.data.signalsUnavailable.map((item) {
        return Padding(
          padding: const EdgeInsets.only(left: 20, bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState(ThemeData theme, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.5),
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

/// Compact version of the evidence panel for cards/lists
class EvidencePanelCompact extends StatelessWidget {
  final EvidencePanelData data;
  final VoidCallback? onTap;

  const EvidencePanelCompact({
    super.key,
    required this.data,
    this.onTap,
  });

  Color _getCompletenessColor() {
    switch (data.evidenceCompleteness) {
      case 'sufficient':
        return const Color(0xFF22C55E);
      case 'limited':
        return const Color(0xFFF59E0B);
      case 'insufficient':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _getCompletenessColor().withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _getCompletenessColor().withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fact_check_outlined,
              size: 14,
              color: _getCompletenessColor(),
            ),
            const SizedBox(width: 6),
            Text(
              '${data.signalsUsed.length} signals',
              style: theme.textTheme.labelSmall?.copyWith(
                color: _getCompletenessColor(),
                fontWeight: FontWeight.w500,
              ),
            ),
            if (data.shouldAutoExpand) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.warning_amber_rounded,
                size: 12,
                color: _getCompletenessColor(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


// =============================================================================
// TIER-GATED EVIDENCE PANEL
// =============================================================================

/// Evidence Panel with subscription tier gating.
/// 
/// FREE: Shows "Upgrade to Pro" message
/// PRO: Shows evidence panel (collapsed by default)
/// PRO+: Shows evidence panel (expanded by default)
class TierGatedEvidencePanel extends StatelessWidget {
  final EvidencePanelData? data;
  final SubscriptionTier tier;
  final VoidCallback? onUpgradeTap;

  const TierGatedEvidencePanel({
    super.key,
    this.data,
    required this.tier,
    this.onUpgradeTap,
  });

  @override
  Widget build(BuildContext context) {
    // FREE tier: Show upgrade prompt
    if (tier == SubscriptionTier.free) {
      return _buildUpgradePrompt(context);
    }
    
    // PRO/PRO+: Show evidence panel
    if (data == null) {
      return const SizedBox.shrink();
    }
    
    return EvidencePanel(
      data: data!,
      // PRO+ auto-expands, PRO doesn't
      initiallyExpanded: tier == SubscriptionTier.proPlus,
    );
  }

  Widget _buildUpgradePrompt(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.fact_check_outlined,
                  color: Color(0xFF3B82F6),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Evidence Panel',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'See exactly what evidence AI used for this analysis',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Teaser content
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.visibility_off_outlined,
                      size: 16,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'What\'s included:',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildTeaserItem(context, 'Signals used by AI', true),
                _buildTeaserItem(context, 'What\'s unknown (always)', true),
                _buildTeaserItem(context, 'Evidence completeness', true),
                _buildTeaserItem(context, 'Signal sources', true),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Upgrade CTA
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onUpgradeTap,
              icon: const Icon(Icons.lock_open, size: 18),
              label: const Text('Upgrade to Pro to unlock'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: Color(0xFF3B82F6)),
                foregroundColor: const Color(0xFF3B82F6),
              ),
            ),
          ),
          const SizedBox(height: 8),
          
          // Note about what Pro provides
          Text(
            'Pro helps you understand what the AI knows and doesn\'t know',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTeaserItem(BuildContext context, String text, bool included) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            included ? Icons.check : Icons.close,
            size: 14,
            color: included
                ? const Color(0xFF22C55E).withOpacity(0.5)
                : theme.colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}


/// Compact tier-gated evidence indicator
class TierGatedEvidenceCompact extends StatelessWidget {
  final EvidencePanelData? data;
  final SubscriptionTier tier;
  final VoidCallback? onTap;

  const TierGatedEvidenceCompact({
    super.key,
    this.data,
    required this.tier,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // FREE tier: Show locked badge
    if (tier == SubscriptionTier.free) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF64748B).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF64748B).withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 14,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                'Evidence',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // PRO/PRO+: Show actual evidence panel compact
    if (data == null) {
      return const SizedBox.shrink();
    }
    
    return EvidencePanelCompact(
      data: data!,
      onTap: onTap,
    );
  }
}
