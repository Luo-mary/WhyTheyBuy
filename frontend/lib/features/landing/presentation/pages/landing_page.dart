import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/providers/locale_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/providers/auth_provider.dart';

/// Premium Editorial Finance Landing Page
class LandingPage extends ConsumerWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch locale to rebuild when language changes
    ref.watch(localeProvider);

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 768;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background gradient overlay
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0C1222),
                    Color(0xFF111827),
                    Color(0xFF0C1222),
                  ],
                ),
              ),
            ),
          ),

          // Subtle grid pattern overlay
          Positioned.fill(
            child: CustomPaint(
              painter: _GridPainter(),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Header
                _Header(isDesktop: isDesktop),

                // Hero Section
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 80 : (isTablet ? 48 : 24),
                        vertical: 40,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: isDesktop ? 80 : 40),

                          // Premium badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: AppColors.primary.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            AppColors.primary.withOpacity(0.5),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  AppLocalizations.of(context)?.liveTracking ??
                                      'LIVE TRACKING',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: isDesktop ? 32 : 24),

                          // Hero headline
                          Text(
                            AppLocalizations.of(context)?.landingHeadline ??
                                'Track What Top\nInvestors Are Buying',
                            style: GoogleFonts.dmSans(
                              fontSize: isDesktop ? 64 : (isTablet ? 48 : 36),
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: -2,
                              height: 1.1,
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Subheadline
                          SizedBox(
                            width: isDesktop ? 560 : double.infinity,
                            child: Text(
                              AppLocalizations.of(context)
                                      ?.landingSubheadline ??
                                  'Monitor institutional holdings in real-time. ARK ETFs, 13F filings, and AI-powered insights delivered to your inbox.',
                              style: GoogleFonts.dmSans(
                                fontSize: isDesktop ? 18 : 16,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textSecondary,
                                height: 1.6,
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),

                          // CTA button
                          _PrimaryButton(
                            label: AppLocalizations.of(context)
                                    ?.startFreeTrial ??
                                'Start Free Trial',
                            onTap: () {
                              debugPrint('>>> Start Free Trial clicked!');
                              context.go('/register');
                            },
                          ),

                          const SizedBox(height: 64),

                          // Feature highlights
                          if (isDesktop)
                            Row(
                              children: [
                                _FeatureCard(
                                  icon: Icons.trending_up_rounded,
                                  title: AppLocalizations.of(context)
                                          ?.realTimeUpdates ??
                                      'Real-Time Updates',
                                  description: AppLocalizations.of(context)
                                          ?.realTimeUpdatesDesc ??
                                      'Daily ARK ETF trades and quarterly 13F filings',
                                  useExpanded: true,
                                ),
                                const SizedBox(width: 24),
                                _FeatureCard(
                                  icon: Icons.auto_awesome_rounded,
                                  title: AppLocalizations.of(context)
                                          ?.aiPoweredInsights ??
                                      'AI Summaries',
                                  description: AppLocalizations.of(context)
                                          ?.aiPoweredInsightsDesc ??
                                      'Intelligent analysis of portfolio changes',
                                  useExpanded: true,
                                ),
                                const SizedBox(width: 24),
                                _FeatureCard(
                                  icon: Icons.notifications_active_rounded,
                                  title: AppLocalizations.of(context)
                                          ?.smartAlerts ??
                                      'Smart Alerts',
                                  description: AppLocalizations.of(context)
                                          ?.smartAlertsDesc ??
                                      'Get notified when your watchlist moves',
                                  useExpanded: true,
                                ),
                              ],
                            )
                          else
                            Column(
                              children: [
                                _FeatureCard(
                                  icon: Icons.trending_up_rounded,
                                  title: AppLocalizations.of(context)
                                          ?.realTimeUpdates ??
                                      'Real-Time Updates',
                                  description: AppLocalizations.of(context)
                                          ?.realTimeUpdatesDesc ??
                                      'Daily ARK ETF trades and quarterly 13F filings',
                                ),
                                const SizedBox(height: 16),
                                _FeatureCard(
                                  icon: Icons.auto_awesome_rounded,
                                  title: AppLocalizations.of(context)
                                          ?.aiPoweredInsights ??
                                      'AI Summaries',
                                  description: AppLocalizations.of(context)
                                          ?.aiPoweredInsightsDesc ??
                                      'Intelligent analysis of portfolio changes',
                                ),
                                const SizedBox(height: 16),
                                _FeatureCard(
                                  icon: Icons.notifications_active_rounded,
                                  title: AppLocalizations.of(context)
                                          ?.smartAlerts ??
                                      'Smart Alerts',
                                  description: AppLocalizations.of(context)
                                          ?.smartAlertsDesc ??
                                      'Get notified when your watchlist moves',
                                ),
                              ],
                            ),

                          const SizedBox(height: 80),

                          // Trust indicators
                          _TrustSection(isDesktop: isDesktop),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),

                // Footer
                _Footer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  final bool isDesktop;
  const _Header({required this.isDesktop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final isAuthenticated = authState.isAuthenticated;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 80 : 24,
        vertical: 20,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border.withOpacity(0.5)),
        ),
      ),
      child: Row(
        children: [
          // Logo
          Row(
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
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'WhyTheyBuy',
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Show different button based on auth state
          if (isAuthenticated)
            TextButton(
              onPressed: () => context.go('/home'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Dashboard',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward, size: 16),
                ],
              ),
            )
          else
            TextButton(
              onPressed: () {
                debugPrint('>>> Sign In clicked!');
                context.go('/login');
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
              child: Text(
                AppLocalizations.of(context)?.signIn ?? 'Sign In',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.onTap});

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(_isHovered ? 0.4 : 0.2),
                blurRadius: _isHovered ? 20 : 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool useExpanded;
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    this.useExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );

    return useExpanded ? Expanded(child: card) : card;
  }
}

class _TrustSection extends StatelessWidget {
  final bool isDesktop;
  const _TrustSection({required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified_user_rounded,
              color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Text(
            AppLocalizations.of(context)?.trustedByInvestors ??
                'Trusted by 10,000+ investors',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          if (isDesktop) ...[
            const SizedBox(width: 32),
            Container(width: 1, height: 20, color: AppColors.border),
            const SizedBox(width: 32),
            const Icon(Icons.lock_rounded,
                color: AppColors.textTertiary, size: 18),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context)?.bankGradeSecurity ??
                  'Bank-grade security',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 32),
            Container(width: 1, height: 20, color: AppColors.border),
            const SizedBox(width: 32),
            const Icon(Icons.speed_rounded,
                color: AppColors.textTertiary, size: 18),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context)?.realTimeData ?? 'Real-time data',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.border.withOpacity(0.5)),
        ),
      ),
      child: Text(
        AppLocalizations.of(context)?.notFinancialAdvice ??
            'Not financial advice. Data provided for informational purposes only.',
        textAlign: TextAlign.center,
        style: GoogleFonts.dmSans(
          fontSize: 12,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}

/// Subtle grid pattern for background depth
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border.withOpacity(0.03)
      ..strokeWidth = 1;

    const spacing = 60.0;

    // Vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
