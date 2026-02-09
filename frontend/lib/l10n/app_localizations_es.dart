// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'WhyTheyBuy';

  @override
  String get home => 'Inicio';

  @override
  String get settings => 'Ajustes';

  @override
  String get addInvestorToTrack => 'Agregar un inversor para seguir';

  @override
  String get recommendedInvestors => 'Inversores Recomendados';

  @override
  String get shuffle => 'Mezclar';

  @override
  String get featuredInvestor => 'Inversor Destacado';

  @override
  String get disclaimer =>
      'Solo con fines educativos. No es asesoramiento de inversión.';

  @override
  String get manageAccountPreferences => 'Administra tu cuenta y preferencias';

  @override
  String get freePlan => 'PLAN GRATIS';

  @override
  String get upgradeToPro => 'Actualizar a Pro';

  @override
  String get upgradeDescription =>
      'Monitorea hasta 10 inversores, alertas instantáneas, resúmenes de IA avanzados';

  @override
  String perMonth(String price) {
    return '$price/mes';
  }

  @override
  String perYear(String price) {
    return '$price/año';
  }

  @override
  String get account => 'Cuenta';

  @override
  String get profile => 'Perfil';

  @override
  String get notificationEmails => 'Correos de Notificación';

  @override
  String get changePassword => 'Cambiar Contraseña';

  @override
  String get preferences => 'Preferencias';

  @override
  String get language => 'Idioma';

  @override
  String get timezone => 'Zona Horaria';

  @override
  String get support => 'Soporte';

  @override
  String get helpCenter => 'Centro de Ayuda';

  @override
  String get sendFeedback => 'Enviar Comentarios';

  @override
  String get termsOfService => 'Términos de Servicio';

  @override
  String get privacyPolicy => 'Política de Privacidad';

  @override
  String get signOut => 'Cerrar Sesión';

  @override
  String get selectLanguage => 'Seleccionar Idioma';

  @override
  String get selectTimezone => 'Seleccionar Zona Horaria';

  @override
  String get searchTimezones => 'Buscar zonas horarias...';

  @override
  String get editProfile => 'Editar Perfil';

  @override
  String get name => 'Nombre';

  @override
  String get email => 'Correo';

  @override
  String get saveChanges => 'Guardar Cambios';

  @override
  String get currentPassword => 'Contraseña Actual';

  @override
  String get newPassword => 'Nueva Contraseña';

  @override
  String get confirmNewPassword => 'Confirmar Nueva Contraseña';

  @override
  String get updatePassword => 'Actualizar Contraseña';

  @override
  String get atLeast8Characters => 'Al menos 8 caracteres';

  @override
  String get addInvestor => 'Agregar Inversor';

  @override
  String get searchByInvestorName => 'Buscar por nombre de inversor...';

  @override
  String get searchForInvestors => 'Buscar inversores';

  @override
  String get trySearching => 'Prueba \"ARK\", \"Berkshire\", o \"Bridgewater\"';

  @override
  String noInvestorsFound(String query) {
    return 'No se encontraron inversores para \"$query\"';
  }

  @override
  String get somethingWentWrong => 'Algo salió mal';

  @override
  String get trackingLimitReached => 'Límite de Seguimiento Alcanzado';

  @override
  String get upgrade => 'Actualizar';

  @override
  String get login => 'Iniciar Sesión';

  @override
  String get register => 'Registrarse';

  @override
  String get forgotPassword => 'Olvidé mi Contraseña';

  @override
  String get password => 'Contraseña';

  @override
  String get dontHaveAccount => '¿No tienes cuenta?';

  @override
  String get alreadyHaveAccount => '¿Ya tienes cuenta?';

  @override
  String get etfManager => 'Gestor de ETF';

  @override
  String get hedgeFund => 'Fondo de Cobertura';

  @override
  String get individual => 'Individual';

  @override
  String get unknown => 'Desconocido';

  @override
  String get featured => 'Destacado';

  @override
  String get institutional => 'Institucional';

  @override
  String get insider => 'Insider';

  @override
  String get dailyEtf => 'ETF Diario';

  @override
  String get sec13f => 'SEC 13F';

  @override
  String get nPort => 'N-PORT';

  @override
  String get form4 => 'Form 4';

  @override
  String get transparencyHigh => 'Alta Transparencia';

  @override
  String get transparencyMedium => 'Transparencia Media';

  @override
  String get transparencyLow => 'Baja Transparencia';

  @override
  String get unlockAiInsights => 'Desbloquea análisis de IA';

  @override
  String get getAiPoweredAnalysis => 'Obtén análisis y alertas con IA';

  @override
  String get pro => 'PRO';

  @override
  String get navigation => 'NAVEGACIÓN';

  @override
  String get liveTracking => 'SEGUIMIENTO EN VIVO';

  @override
  String get landingHeadline => 'Rastrea Lo Que Compran Los Mejores Inversores';

  @override
  String get landingSubheadline =>
      'Monitorea las tenencias institucionales en tiempo real. ETFs ARK, archivos 13F e información impulsada por IA en tu bandeja de entrada.';

  @override
  String get startFreeTrial => 'Iniciar Prueba Gratis';

  @override
  String get viewDemo => 'Ver Demo';

  @override
  String get realTimeUpdates => 'Actualizaciones en Tiempo Real';

  @override
  String get realTimeUpdatesDesc =>
      'Operaciones diarias de ETF ARK y archivos 13F trimestrales';

  @override
  String get aiPoweredInsights => 'Información con IA';

  @override
  String get aiPoweredInsightsDesc =>
      'Entiende por qué los mejores inversores toman decisiones';

  @override
  String get smartAlerts => 'Alertas Inteligentes';

  @override
  String get smartAlertsDesc =>
      'Recibe notificaciones cuando tu lista de seguimiento cambie';

  @override
  String get trustedByInvestors => 'Confiado por más de 10,000 inversores';

  @override
  String get bankGradeSecurity => 'Seguridad bancaria';

  @override
  String get realTimeData => 'Datos en tiempo real';

  @override
  String get notFinancialAdvice =>
      'No es asesoramiento financiero. Datos proporcionados solo con fines informativos.';

  @override
  String get signIn => 'Iniciar Sesión';

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
