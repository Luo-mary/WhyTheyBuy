import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';

/// Pricing page for WhyTheyBuy with distinct Web and Mobile versions.
///
/// IMPORTANT PRINCIPLES:
/// - Tone: Calm, professional, trust-focused, institutional
/// - Do NOT promise returns or performance
/// - Do NOT use trading or speculative language
/// - Avoid urgency tactics
/// - Emphasize transparency, evidence-based explanations, understanding limitations
/// - Sell understanding, clarity, and transparency — not results
///
/// MICRO-INTERACTION PRINCIPLES:
/// - Calm and minimal
/// - No urgency or promotional effects
/// - Designed to explain, not persuade
/// - Focused on transparency and limitations
///
/// WEB VERSION: Supports careful comparison, rational decision-making
/// MOBILE VERSION: Reduces cognitive load, enables fast low-friction decisions
class PricingPage extends StatefulWidget {
  const PricingPage({super.key});

  @override
  State<PricingPage> createState() => _PricingPageState();
}

class _PricingPageState extends State<PricingPage> {
  bool _isYearly = false;
  bool _showMobileDisclaimer = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.show_chart_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            const Text('WhyTheyBuy'),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.heroGradient,
        ),
        child: isMobile ? _buildMobileLayout() : _buildWebLayout(),
      ),
    );
  }

  // ===========================================================================
  // WEB LAYOUT - Full descriptions, detailed explanations, comparison table
  // ===========================================================================

  Widget _buildWebLayout() {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 80 : 40,
        vertical: 48,
      ),
      child: Column(
        children: [
          // Web Hero Section
          _buildWebHeroSection(),
          const SizedBox(height: 40),

          // Billing toggle
          _buildBillingToggle(),
          const SizedBox(height: 48),

          // Plans - Row layout for web
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWebFreePlan(),
              const SizedBox(width: 24),
              _buildWebProPlan(),
              const SizedBox(width: 24),
              _buildWebProPlusPlan(),
            ],
          ),

          const SizedBox(height: 64),

          // Feature Comparison Table (Web only)
          _buildFeatureComparison(),

          const SizedBox(height: 64),

          // Web Disclaimer (visible, soft)
          _buildWebDisclaimer(),

          const SizedBox(height: 48),

          // Footer Trust Badges
          _buildFooterTrust(),
        ],
      ),
    );
  }

  Widget _buildWebHeroSection() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Column(
        children: [
          // Headline
          Text(
            'Pay for clarity, not predictions.',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Subheadline
          Text(
            'Understand what major investors disclosed — and what remains unknown.',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Supporting text - explains the product philosophy
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              'WhyTheyBuy provides structured access to publicly disclosed investor holdings, '
              'with transparency indicators, evidence-based AI summaries, and clearly stated limitations. '
              'Higher tiers offer deeper insight into data quality and confidence levels — not trading advantages.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.7,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebFreePlan() {
    return _WebPlanCard(
      name: 'Free',
      tagline: 'See what changed',
      description: 'For getting oriented with disclosure monitoring.',
      price: '€0',
      period: '/month',
      features: const [
        _FeatureItem(text: 'Track 2 investors (includes Berkshire Hathaway)'),
        _FeatureItem(
            text:
                'View basic holdings changes (new, increased, reduced, sold)'),
        _FeatureItem(
          text: 'Disclosure transparency label (High / Medium / Low)',
          hasTooltip: true,
          tooltipText: _TooltipTexts.transparencyScore,
        ),
        _FeatureItem(text: 'AI reasoning for Top 5 Buys + Top 5 Sells'),
        _FeatureItem(text: 'Weekly email digest'),
      ],
      lockedFeatures: [
        _LockedFeatureItem(
          text: 'Evidence Panel',
          tooltipText: _TooltipTexts.evidencePanel,
          onViewPlans: () => _scrollToPlans(),
        ),
        _LockedFeatureItem(
          text: 'Company-level explanations',
          onViewPlans: () => _scrollToPlans(),
        ),
        _LockedFeatureItem(
          text: 'Data export',
          onViewPlans: () => _scrollToPlans(),
        ),
      ],
      limitationNote:
          'Free summaries are descriptive and do not include detailed evidence panels.',
      ctaLabel: 'Start free',
      onTap: () => context.go('/register'),
    );
  }

  Widget _buildWebProPlan() {
    return _WebPlanCard(
      name: 'Pro',
      tagline: 'Understand the context',
      description:
          'For serious individual investors who want to understand data reliability.',
      price: _isYearly ? '€10' : '€12',
      period: '/month',
      yearlyNote: _isYearly ? '€120 billed annually' : null,
      isHighlighted: true,
      features: const [
        _FeatureItem(text: 'Track up to 10 investors'),
        _FeatureItem(
          text: 'Full Disclosure Transparency Score',
          hasTooltip: true,
          tooltipText: _TooltipTexts.transparencyScore,
          suffix: '(frequency, delay, granularity)',
        ),
        _FeatureItem(text: 'Unlimited AI reasoning for all transactions'),
        _FeatureItem(
          text: 'Evidence Panel',
          hasTooltip: true,
          tooltipText: _TooltipTexts.evidencePanel,
          suffix: '— see what signals were used and what is unknown',
        ),
        _FeatureItem(text: 'Company-level explanations of investor activity'),
        _FeatureItem(text: 'Daily digest and important change alerts'),
        _FeatureItem(text: 'Access to recent historical data'),
      ],
      lockedFeatures: [
        _LockedFeatureItem(
          text: 'Cross-investor activity analysis',
          onViewPlans: () => _scrollToPlans(),
        ),
        _LockedFeatureItem(
          text: 'Data export (CSV / PDF)',
          onViewPlans: () => _scrollToPlans(),
        ),
      ],
      valueStatement:
          'Know not only what changed, but how confident you should be in the information.',
      ctaLabel: 'Upgrade to Pro',
      onTap: () => context.go('/register?plan=pro'),
    );
  }

  Widget _buildWebProPlusPlan() {
    return _WebPlanCard(
      name: 'Pro+ Research',
      tagline: 'See the full picture',
      description: 'For deep research and professional use cases.',
      price: _isYearly ? '€32.50' : '€39',
      period: '/month',
      yearlyNote: _isYearly ? '€390 billed annually' : null,
      badge: 'RESEARCH',
      badgeColor: AppColors.info,
      features: const [
        _FeatureItem(text: 'Unlimited investors'),
        _FeatureItem(
          text: 'Full transparency breakdown by dimension',
          hasTooltip: true,
          tooltipText: _TooltipTexts.transparencyScore,
          suffix: '(frequency, delay, granularity, source reliability)',
        ),
        _FeatureItem(
          text: 'Evidence Panel expanded by default',
          hasTooltip: true,
          tooltipText: _TooltipTexts.evidencePanel,
        ),
        _FeatureItem(
            text: 'Cross-investor activity analysis on the same company'),
        _FeatureItem(text: 'Full historical access'),
        _FeatureItem(text: 'Data export (CSV / PDF)'),
        _FeatureItem(text: 'Real-time alerts where disclosures allow'),
      ],
      valueStatement:
          'Built for users who care about data limitations as much as data itself.',
      ctaLabel: 'Start Research plan',
      onTap: () => context.go('/register?plan=pro_plus'),
    );
  }

  void _scrollToPlans() {
    // In a real implementation, this would scroll to the Pro plan
    // For now, it's a no-op since plans are visible
  }

  Widget _buildFeatureComparison() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 900),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            'Feature Comparison',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2.5),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1),
            },
            children: [
              _buildTableHeader(),
              _buildTableRow('Investors tracked', '2', 'Up to 10', 'Unlimited'),
              _buildTableRowWithTooltip(
                'Transparency visibility',
                _TooltipTexts.transparencyScore,
                'Label only',
                'Full score',
                'Full breakdown',
              ),
              _buildTableRow('AI reasoning access', 'Top 5 only',
                  'Unlimited', 'Unlimited'),
              _buildTableRowWithTooltip(
                'Evidence Panel',
                _TooltipTexts.evidencePanel,
                '—',
                'Expandable',
                'Expanded',
              ),
              _buildTableRow('Company-level analysis', '—', '✓', '✓'),
              _buildTableRow('Cross-investor analysis', '—', '—', '✓'),
              _buildTableRow('Historical access', 'Limited', 'Recent', 'Full'),
              _buildTableRow('Export capability', '—', '—', 'CSV / PDF'),
              _buildTableRow(
                  'Notification frequency', 'Weekly', 'Daily', 'Real-time*'),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '* Real-time alerts available for daily disclosure sources (e.g., ARK ETFs)',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebDisclaimer() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 800),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'Disclaimer',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'WhyTheyBuy provides financial information and analytical tools only. '
            'It does not provide investment advice, financial recommendations, or portfolio management. '
            'AI-generated content represents hypothetical interpretations based on publicly available data '
            'and may be incomplete or inaccurate. '
            'Investing involves risk, including the possible loss of principal.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                  height: 1.6,
                ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MOBILE LAYOUT - Concise, scannable, fast decisions
  // ===========================================================================

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        children: [
          // Mobile Hero Section - Shorter, more direct
          _buildMobileHeroSection(),
          const SizedBox(height: 28),

          // Billing toggle
          _buildBillingToggle(),
          const SizedBox(height: 32),

          // Plans - Column layout, Pro first (highlighted)
          _buildMobileProPlan(),
          const SizedBox(height: 16),
          _buildMobileFreePlan(),
          const SizedBox(height: 16),
          _buildMobileProPlusPlan(),

          const SizedBox(height: 32),

          // Mobile Disclaimer - Collapsible
          _buildMobileDisclaimer(),

          const SizedBox(height: 24),

          // Minimal footer
          _buildMobileFooter(),
        ],
      ),
    );
  }

  Widget _buildMobileHeroSection() {
    return Column(
      children: [
        // Shorter headline for mobile
        Text(
          'Clarity over predictions.',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),

        // Concise subtext
        Text(
          'See what investors disclosed — with transparency and evidence.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildMobileFreePlan() {
    return _MobilePlanCard(
      name: 'Free',
      tagline: 'See what changed',
      price: '€0',
      period: '/month',
      bulletPoints: const [
        _MobileBulletPoint(text: '2 investors (incl. Berkshire)'),
        _MobileBulletPoint(text: 'Basic holdings changes'),
        _MobileBulletPoint(
          text: 'AI reasoning (Top 5 only)',
          hasInfoIcon: true,
          infoText: 'Free users can access AI reasoning for Top 5 Buys and Top 5 Sells only.',
        ),
        _MobileBulletPoint(text: 'Weekly summary'),
      ],
      ctaLabel: 'Start free',
      onTap: () => context.go('/register'),
    );
  }

  Widget _buildMobileProPlan() {
    return _MobilePlanCard(
      name: 'Pro',
      tagline: 'Understand the context',
      price: _isYearly ? '€10' : '€12',
      period: '/month',
      yearlyNote: _isYearly ? '€120/year' : null,
      isHighlighted: true,
      bulletPoints: const [
        _MobileBulletPoint(text: 'Up to 10 investors'),
        _MobileBulletPoint(
          text: 'Unlimited AI reasoning',
          hasInfoIcon: true,
          infoText: 'Access AI reasoning for all transactions, not just Top 5.',
        ),
        _MobileBulletPoint(
          text: 'Evidence Panel',
          hasInfoIcon: true,
          infoText: _TooltipTexts.evidencePanelMobile,
        ),
        _MobileBulletPoint(text: 'Company-level insights'),
      ],
      valueLine:
          'See not just what changed — but how reliable the information is.',
      ctaLabel: 'Upgrade to Pro',
      onTap: () => context.go('/register?plan=pro'),
    );
  }

  Widget _buildMobileProPlusPlan() {
    return _MobilePlanCard(
      name: 'Pro+ Research',
      tagline: 'For deep analysis',
      price: _isYearly ? '€32.50' : '€39',
      period: '/month',
      yearlyNote: _isYearly ? '€390/year' : null,
      bulletPoints: const [
        _MobileBulletPoint(text: 'Unlimited investors'),
        _MobileBulletPoint(
          text: 'Full transparency breakdown',
          hasInfoIcon: true,
          infoText: _TooltipTexts.transparencyScoreMobile,
        ),
        _MobileBulletPoint(
          text: 'Evidence shown by default',
          hasInfoIcon: true,
          infoText: _TooltipTexts.evidencePanelMobile,
        ),
        _MobileBulletPoint(text: 'Exports & full history'),
      ],
      ctaLabel: 'Start Research plan',
      onTap: () => context.go('/register?plan=pro_plus'),
    );
  }

  Widget _buildMobileDisclaimer() {
    return GestureDetector(
      onTap: () =>
          setState(() => _showMobileDisclaimer = !_showMobileDisclaimer),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppColors.textTertiary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _showMobileDisclaimer
                        ? 'Disclaimer'
                        : 'Informational only. No investment advice.',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                  ),
                ),
                Icon(
                  _showMobileDisclaimer
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppColors.textTertiary,
                  size: 20,
                ),
              ],
            ),
            if (_showMobileDisclaimer) ...[
              const SizedBox(height: 12),
              Text(
                'WhyTheyBuy provides financial information only. '
                'AI analysis may be incomplete or inaccurate. '
                'Investing involves risk, including loss of principal.',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textTertiary,
                      height: 1.5,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMobileFooter() {
    return Column(
      children: [
        Text(
          'Based on public disclosures',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textTertiary,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'No investment advice',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textTertiary,
              ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ===========================================================================
  // SHARED COMPONENTS
  // ===========================================================================

  Widget _buildBillingToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BillingToggle(
            label: 'Monthly',
            isSelected: !_isYearly,
            onTap: () => setState(() => _isYearly = false),
          ),
          _BillingToggle(
            label: 'Yearly',
            badge: 'Save ~17%',
            isSelected: _isYearly,
            onTap: () => setState(() => _isYearly = true),
          ),
        ],
      ),
    );
  }

  TableRow _buildTableHeader() {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      children: [
        _tableCell('Feature', isHeader: true),
        _tableCell('Free', isHeader: true),
        _tableCell('Pro', isHeader: true, highlight: true),
        _tableCell('Pro+', isHeader: true),
      ],
    );
  }

  TableRow _buildTableRow(
      String feature, String free, String pro, String proPlus) {
    return TableRow(
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: AppColors.border.withOpacity(0.3))),
      ),
      children: [
        _tableCell(feature),
        _tableCell(free),
        _tableCell(pro, highlight: true),
        _tableCell(proPlus),
      ],
    );
  }

  TableRow _buildTableRowWithTooltip(
    String feature,
    String tooltipText,
    String free,
    String pro,
    String proPlus,
  ) {
    return TableRow(
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: AppColors.border.withOpacity(0.3))),
      ),
      children: [
        _tableCellWithTooltip(feature, tooltipText),
        _tableCell(free),
        _tableCell(pro, highlight: true),
        _tableCell(proPlus),
      ],
    );
  }

  Widget _tableCell(String text,
      {bool isHeader = false, bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: isHeader ? FontWeight.w600 : FontWeight.w400,
              color: highlight ? AppColors.primary : AppColors.textPrimary,
            ),
        textAlign: isHeader ? TextAlign.center : TextAlign.left,
      ),
    );
  }

  Widget _tableCellWithTooltip(String text, String tooltipText) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: _WebFeatureTooltip(
        tooltipText: tooltipText,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.help_outline,
              size: 14,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterTrust() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 700),
      child: const Column(
        children: [
          Divider(color: AppColors.border),
          SizedBox(height: 24),
          Wrap(
            spacing: 32,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              _TrustBadge(
                icon: Icons.public,
                text: 'Based on publicly available disclosures',
              ),
              _TrustBadge(
                icon: Icons.block,
                text: 'No investment advice or recommendations',
              ),
              _TrustBadge(
                icon: Icons.visibility_outlined,
                text: 'Designed with transparency and limitations in mind',
              ),
            ],
          ),
          SizedBox(height: 32),
        ],
      ),
    );
  }
}

// =============================================================================
// TOOLTIP TEXTS - Centralized copy for consistency
// =============================================================================

class _TooltipTexts {
  static const String transparencyScore =
      'Reflects how frequently and precisely an investor discloses holdings — not performance or quality.';

  static const String evidencePanel =
      'Shows what data the AI used — and what information is missing or unknown.';

  static const String lockedFeatureTitle = 'Why this is locked';

  static const String lockedFeatureBody =
      'This feature reveals additional context, evidence, and limitations. It does not provide investment advice.';

  // Shorter versions for mobile
  static const String transparencyScoreMobile =
      'Shows disclosure frequency and precision — not performance.';

  static const String evidencePanelMobile =
      'Shows what data AI used and what is unknown.';
}

// =============================================================================
// WEB FEATURE TOOLTIP - Hover with 300-500ms delay, soft fade-in
// =============================================================================

class _WebFeatureTooltip extends StatefulWidget {
  final Widget child;
  final String tooltipText;

  const _WebFeatureTooltip({
    required this.child,
    required this.tooltipText,
  });

  @override
  State<_WebFeatureTooltip> createState() => _WebFeatureTooltipState();
}

class _WebFeatureTooltipState extends State<_WebFeatureTooltip> {
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isHovering = false;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _showTooltip() async {
    _isHovering = true;
    // Delay 400ms before showing (within 300-500ms range)
    await Future.delayed(const Duration(milliseconds: 400));
    if (_isHovering && mounted) {
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
    }
  }

  void _hideTooltip() {
    _isHovering = false;
    _removeOverlay();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) => Positioned(
        width: 280,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 28),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 200),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: child,
              );
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  widget.tooltipText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) => _showTooltip(),
        onExit: (_) => _hideTooltip(),
        cursor: SystemMouseCursors.help,
        child: widget.child,
      ),
    );
  }
}

// =============================================================================
// FEATURE ITEM - For web plan cards with optional tooltip
// =============================================================================

class _FeatureItem {
  final String text;
  final bool hasTooltip;
  final String? tooltipText;
  final String? suffix;

  const _FeatureItem({
    required this.text,
    this.hasTooltip = false,
    this.tooltipText,
    this.suffix,
  });
}

// =============================================================================
// LOCKED FEATURE ITEM - With popover explanation
// =============================================================================

class _LockedFeatureItem {
  final String text;
  final String? tooltipText;
  final VoidCallback onViewPlans;

  const _LockedFeatureItem({
    required this.text,
    this.tooltipText,
    required this.onViewPlans,
  });
}

// =============================================================================
// LOCKED FEATURE POPOVER - Explains "Why this is locked"
// =============================================================================

class _LockedFeaturePopover extends StatefulWidget {
  final String featureName;
  final String? additionalText;
  final VoidCallback onViewPlans;

  const _LockedFeaturePopover({
    required this.featureName,
    this.additionalText,
    required this.onViewPlans,
  });

  @override
  State<_LockedFeaturePopover> createState() => _LockedFeaturePopoverState();
}

class _LockedFeaturePopoverState extends State<_LockedFeaturePopover> {
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  void _togglePopover() {
    if (_overlayEntry != null) {
      _removeOverlay();
    } else {
      _showPopover();
    }
  }

  void _showPopover() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Dismiss on tap outside
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeOverlay,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            width: 300,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 32),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 200),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 4 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title
                        const Row(
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            SizedBox(width: 8),
                            Text(
                              _TooltipTexts.lockedFeatureTitle,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Body
                        const Text(
                          _TooltipTexts.lockedFeatureBody,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),

                        // Additional context if provided
                        if (widget.additionalText != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            widget.additionalText!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Actions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                _removeOverlay();
                                widget.onViewPlans();
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              child: const Text('View plans'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _removeOverlay,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.surfaceLight,
                                foregroundColor: AppColors.textPrimary,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _togglePopover,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 16,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.featureName,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// MOBILE BULLET POINT - With optional tap-based info icon
// =============================================================================

class _MobileBulletPoint {
  final String text;
  final bool hasInfoIcon;
  final String? infoText;

  const _MobileBulletPoint({
    required this.text,
    this.hasInfoIcon = false,
    this.infoText,
  });
}

// =============================================================================
// MOBILE INFO ICON - Tap to expand explanation
// =============================================================================

class _MobileInfoIcon extends StatefulWidget {
  final String text;
  final String infoText;
  final bool isHighlighted;

  const _MobileInfoIcon({
    required this.text,
    required this.infoText,
    this.isHighlighted = false,
  });

  @override
  State<_MobileInfoIcon> createState() => _MobileInfoIconState();
}

class _MobileInfoIconState extends State<_MobileInfoIcon>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Row(
            children: [
              Icon(
                Icons.check,
                size: 16,
                color: widget.isHighlighted
                    ? AppColors.primary
                    : AppColors.success,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.text,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                ),
              ),
              Icon(
                _isExpanded ? Icons.info : Icons.info_outline,
                size: 16,
                color: _isExpanded ? AppColors.primary : AppColors.textTertiary,
              ),
            ],
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(left: 24, top: 6, bottom: 4),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight.withOpacity(0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                widget.infoText,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
              ),
            ),
          ),
          crossFadeState: _isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}

// =============================================================================
// WEB PLAN CARD - Full descriptions, multiple features
// =============================================================================

class _WebPlanCard extends StatelessWidget {
  final String name;
  final String tagline;
  final String description;
  final String price;
  final String period;
  final String? yearlyNote;
  final String? badge;
  final Color? badgeColor;
  final bool isHighlighted;
  final List<_FeatureItem> features;
  final List<_LockedFeatureItem>? lockedFeatures;
  final String? limitationNote;
  final String? valueStatement;
  final String ctaLabel;
  final VoidCallback onTap;

  const _WebPlanCard({
    required this.name,
    required this.tagline,
    required this.description,
    required this.price,
    required this.period,
    this.yearlyNote,
    this.badge,
    this.badgeColor,
    this.isHighlighted = false,
    required this.features,
    this.lockedFeatures,
    this.limitationNote,
    this.valueStatement,
    required this.ctaLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighlighted ? AppColors.primary : AppColors.border,
          width: isHighlighted ? 2 : 1,
        ),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge
          if (badge != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor ?? AppColors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badge!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Tagline
          Text(
            tagline,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 4),

          // Name
          Text(
            name,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),

          // Description
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 20),

          // Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                price,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                period,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
          if (yearlyNote != null) ...[
            const SizedBox(height: 4),
            Text(
              yearlyNote!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
            ),
          ],
          const SizedBox(height: 24),

          // Included Features
          ...features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildFeatureRow(context, feature),
              )),

          // Locked Features
          if (lockedFeatures != null && lockedFeatures!.isNotEmpty) ...[
            const SizedBox(height: 4),
            ...lockedFeatures!.map((locked) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _LockedFeaturePopover(
                    featureName: locked.text,
                    additionalText: locked.tooltipText,
                    onViewPlans: locked.onViewPlans,
                  ),
                )),
          ],

          // Limitation note (for Free tier)
          if (limitationNote != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                limitationNote!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textTertiary,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
              ),
            ),
          ],

          // Value statement (for paid tiers)
          if (valueStatement != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                ),
              ),
              child: Text(
                valueStatement!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.primaryLight,
                      height: 1.4,
                    ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // CTA
          SizedBox(
            width: double.infinity,
            height: 48,
            child: isHighlighted
                ? ElevatedButton(
                    onPressed: onTap,
                    child: Text(ctaLabel),
                  )
                : OutlinedButton(
                    onPressed: onTap,
                    child: Text(ctaLabel),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(BuildContext context, _FeatureItem feature) {
    Widget content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check,
          size: 18,
          color: AppColors.success,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
              children: [
                TextSpan(text: feature.text),
                if (feature.suffix != null)
                  TextSpan(
                    text: ' ${feature.suffix}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
        ),
        if (feature.hasTooltip) ...[
          const SizedBox(width: 4),
          const Icon(
            Icons.help_outline,
            size: 14,
            color: AppColors.textTertiary,
          ),
        ],
      ],
    );

    if (feature.hasTooltip && feature.tooltipText != null) {
      return _WebFeatureTooltip(
        tooltipText: feature.tooltipText!,
        child: content,
      );
    }

    return content;
  }
}

// =============================================================================
// MOBILE PLAN CARD - Concise, max 4 bullet points
// =============================================================================

class _MobilePlanCard extends StatelessWidget {
  final String name;
  final String tagline;
  final String price;
  final String period;
  final String? yearlyNote;
  final bool isHighlighted;
  final List<_MobileBulletPoint> bulletPoints; // Max 4
  final String? valueLine;
  final String ctaLabel;
  final VoidCallback onTap;

  const _MobilePlanCard({
    required this.name,
    required this.tagline,
    required this.price,
    required this.period,
    this.yearlyNote,
    this.isHighlighted = false,
    required this.bulletPoints,
    this.valueLine,
    required this.ctaLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted ? AppColors.primary : AppColors.border,
          width: isHighlighted ? 2 : 1,
        ),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: Name + Price
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tagline,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        price,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      Text(
                        period,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                  if (yearlyNote != null)
                    Text(
                      yearlyNote!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textTertiary,
                          ),
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Bullet points (max 4) with optional info icons
          ...bulletPoints.take(4).map((point) {
            if (point.hasInfoIcon && point.infoText != null) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _MobileInfoIcon(
                  text: point.text,
                  infoText: point.infoText!,
                  isHighlighted: isHighlighted,
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.check,
                    size: 16,
                    color:
                        isHighlighted ? AppColors.primary : AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      point.text,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Value line (for Pro)
          if (valueLine != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                valueLine!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.primaryLight,
                    ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // CTA
          SizedBox(
            width: double.infinity,
            height: 44,
            child: isHighlighted
                ? ElevatedButton(
                    onPressed: onTap,
                    child: Text(ctaLabel),
                  )
                : OutlinedButton(
                    onPressed: onTap,
                    child: Text(ctaLabel),
                  ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SHARED HELPER WIDGETS
// =============================================================================

class _BillingToggle extends StatelessWidget {
  final String label;
  final String? badge;
  final bool isSelected;
  final VoidCallback onTap;

  const _BillingToggle({
    required this.label,
    this.badge,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.2)
                      : AppColors.success.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.success,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TrustBadge({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.textTertiary,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textTertiary,
              ),
        ),
      ],
    );
  }
}
