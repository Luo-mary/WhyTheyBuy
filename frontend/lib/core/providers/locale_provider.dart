import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_ar.dart';
import '../../l10n/app_localizations_de.dart';
import '../../l10n/app_localizations_en.dart';
import '../../l10n/app_localizations_es.dart';
import '../../l10n/app_localizations_fr.dart';
import '../../l10n/app_localizations_ja.dart';
import '../../l10n/app_localizations_ko.dart';
import '../../l10n/app_localizations_zh.dart';

/// Key for storing the locale in shared preferences
const _localeKey = 'app_locale';

/// Supported locales in the app
const supportedLocales = [
  Locale('en'), // English
  Locale('es'), // Spanish
  Locale('zh'), // Chinese
  Locale('ja'), // Japanese
  Locale('ko'), // Korean
  Locale('de'), // German
  Locale('fr'), // French
  Locale('ar'), // Arabic
];

/// Provider for SharedPreferences instance
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in main.dart');
});

/// Provider for managing the app's locale
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocaleNotifier(prefs);
});

/// Notifier for managing locale state
class LocaleNotifier extends StateNotifier<Locale?> {
  final SharedPreferences _prefs;

  LocaleNotifier(this._prefs) : super(null) {
    _loadLocale();
  }

  /// Load saved locale from preferences
  void _loadLocale() {
    final savedLocale = _prefs.getString(_localeKey);
    if (savedLocale != null) {
      state = Locale(savedLocale);
    }
  }

  /// Set a new locale and persist it
  Future<void> setLocale(Locale locale) async {
    state = locale;
    await _prefs.setString(_localeKey, locale.languageCode);
  }

  /// Clear the locale (use system default)
  Future<void> clearLocale() async {
    state = null;
    await _prefs.remove(_localeKey);
  }
}

/// Get display name for a locale
String getLanguageDisplayName(String code) {
  const languages = {
    'en': 'English',
    'es': 'Español',
    'zh': '中文',
    'ja': '日本語',
    'ko': '한국어',
    'de': 'Deutsch',
    'fr': 'Français',
    'ar': 'العربية',
  };
  return languages[code] ?? 'English';
}

/// Get flag emoji for a locale
String getLanguageFlag(String code) {
  const flags = {
    'en': '🇺🇸',
    'es': '🇪🇸',
    'zh': '🇨🇳',
    'ja': '🇯🇵',
    'ko': '🇰🇷',
    'de': '🇩🇪',
    'fr': '🇫🇷',
    'ar': '🇸🇦',
  };
  return flags[code] ?? '🌐';
}

/// Provider for AppLocalizations that returns the correct localization
/// based on the current locale. Use this instead of AppLocalizations.of(context)
/// in ConsumerWidgets to ensure proper rebuilding when locale changes.
final appLocalizationsProvider = Provider<AppLocalizations>((ref) {
  final locale = ref.watch(localeProvider);
  final languageCode = locale?.languageCode ?? 'en';

  switch (languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'de':
      return AppLocalizationsDe();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'zh':
      return AppLocalizationsZh();
    case 'en':
    default:
      return AppLocalizationsEn();
  }
});
