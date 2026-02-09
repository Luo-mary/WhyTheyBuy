// Simple test to verify Chinese localization
import 'lib/l10n/app_localizations_zh.dart';

void main() {
  final zh = AppLocalizationsZh();

  print('=== Chinese Localization Test ===');
  print('home: ${zh.home}');
  print('settings: ${zh.settings}');
  print('navigation: ${zh.navigation}');
  print('---');
  print('portfolioOverview: ${zh.portfolioOverview}');
  print('totalHoldings: ${zh.totalHoldings}');
  print('sectorAllocation: ${zh.sectorAllocation}');
  print('holdingsChanges: ${zh.holdingsChanges}');
  print('---');
  print('unlockAiInsights: ${zh.unlockAiInsights}');
  print('getAiPoweredAnalysis: ${zh.getAiPoweredAnalysis}');
  print('upgrade: ${zh.upgrade}');
}
