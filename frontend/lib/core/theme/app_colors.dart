import 'package:flutter/material.dart';

/// WhyTheyBuy Design System - Editorial Finance
///
/// Aesthetic: Premium dark theme with sharp data presentation
/// Bloomberg Terminal meets modern luxury editorial
class AppColors {
  // ═══════════════════════════════════════════════════════════════════════════
  // BRAND - Emerald primary for trust & growth
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color primary = Color(0xFF10B981); // Emerald 500
  static const Color primaryLight = Color(0xFF34D399); // Emerald 400
  static const Color primaryDark = Color(0xFF059669); // Emerald 600
  static const Color primaryMuted = Color(0xFF10B981); // With opacity in use

  // ═══════════════════════════════════════════════════════════════════════════
  // BACKGROUNDS - Deep, layered surfaces
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color background = Color(0xFF0C1222); // Deep navy
  static const Color backgroundAlt = Color(0xFF111827); // Slightly lighter
  static const Color surface = Color(0xFF1A2332); // Card surface
  static const Color surfaceAlt = Color(0xFF222F43); // Elevated surface
  static const Color surfaceLight = Color(0xFF2A3A52); // Hover state
  static const Color surfaceElevated = Color(0xFF1E293B);

  // ═══════════════════════════════════════════════════════════════════════════
  // TEXT - Clear hierarchy
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color textPrimary = Color(0xFFF8FAFC); // Almost white
  static const Color textSecondary = Color(0xFF94A3B8); // Muted
  static const Color textTertiary = Color(0xFF64748B); // Very muted
  static const Color textMuted = Color(0xFF475569); // Disabled

  // ═══════════════════════════════════════════════════════════════════════════
  // BORDERS - Subtle definition
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color border = Color(0xFF2A3A52); // Subtle
  static const Color borderLight = Color(0xFF1E293B); // Very subtle
  static const Color borderDark = Color(0xFF334155); // More visible
  static const Color borderFocus = Color(0xFF10B981); // Primary
  static const Color borderSubtle = Color(0xFF1E293B);

  // ═══════════════════════════════════════════════════════════════════════════
  // TRADING SIGNALS - Sharp & clear
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color positive = Color(0xFF10B981); // Emerald - Buy/Gain
  static const Color negative = Color(0xFFF43F5E); // Rose - Sell/Loss
  static const Color neutral = Color(0xFF64748B); // Gray - Unchanged

  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFF10B981);
  static const Color successBackground = Color(0x1A10B981); // 10% opacity

  static const Color error = Color(0xFFF43F5E);
  static const Color errorLight = Color(0xFFF43F5E);
  static const Color errorBackground = Color(0x1AF43F5E);

  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color warningLight = Color(0xFFFBBF24);
  static const Color warningBackground = Color(0x1AF59E0B);

  static const Color info = Color(0xFF3B82F6); // Blue
  static const Color infoLight = Color(0xFF60A5FA);
  static const Color infoBackground = Color(0x1A3B82F6);

  // ═══════════════════════════════════════════════════════════════════════════
  // PREMIUM ACCENTS
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color gold = Color(0xFFFFD700); // Premium tier
  static const Color goldMuted = Color(0xFFB8860B);
  static const Color accent = Color(0xFFFFD700);
  static const Color secondary = Color(0xFF6366F1); // Indigo
  static const Color secondaryLight = Color(0xFF818CF8);

  // ═══════════════════════════════════════════════════════════════════════════
  // CHART PALETTE
  // ═══════════════════════════════════════════════════════════════════════════
  static const List<Color> chartPalette = [
    Color(0xFF10B981), // Emerald
    Color(0xFF3B82F6), // Blue
    Color(0xFFF59E0B), // Amber
    Color(0xFF8B5CF6), // Violet
    Color(0xFFF43F5E), // Rose
    Color(0xFF06B6D4), // Cyan
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // GRADIENTS
  // ═══════════════════════════════════════════════════════════════════════════
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF059669)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0C1222), Color(0xFF111827)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A2332), Color(0xFF151D2B)],
  );

  static const LinearGradient premiumGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFD700), Color(0xFFB8860B)],
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // GLOW EFFECTS
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color glowPrimary = Color(0x4010B981);
  static const Color glowPositive = Color(0x4010B981);
  static const Color glowNegative = Color(0x40F43F5E);

  // ═══════════════════════════════════════════════════════════════════════════
  // LEGACY - For compatibility
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color inputBackground = Color(0xFF1A2332);
  static const Color darkBackground = Color(0xFF0C1222);
  static const Color darkBackgroundAlt = Color(0xFF111827);
  static const Color darkSurface = Color(0xFF1A2332);
  static const Color darkSurfaceAlt = Color(0xFF222F43);
  static const Color darkBorder = Color(0xFF2A3A52);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
}
