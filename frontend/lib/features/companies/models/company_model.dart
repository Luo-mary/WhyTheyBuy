/// Company data models for WhyTheyBuy.
library;

class LiveQuoteModel {
  final String ticker;
  final double price;
  final double change;
  final double changePercent;
  final int volume;
  final double high;
  final double low;
  final double open;
  final double previousClose;
  final String? latestTradingDay;

  const LiveQuoteModel({
    required this.ticker,
    required this.price,
    required this.change,
    required this.changePercent,
    required this.volume,
    required this.high,
    required this.low,
    required this.open,
    required this.previousClose,
    this.latestTradingDay,
  });

  factory LiveQuoteModel.fromJson(Map<String, dynamic> json) {
    return LiveQuoteModel(
      ticker: json['ticker'] as String? ?? '',
      price: _parseDouble(json['price']),
      change: _parseDouble(json['change']),
      changePercent: _parseDouble(json['change_percent']),
      volume: (json['volume'] as num?)?.toInt() ?? 0,
      high: _parseDouble(json['high']),
      low: _parseDouble(json['low']),
      open: _parseDouble(json['open']),
      previousClose: _parseDouble(json['previous_close']),
      latestTradingDay: json['latest_trading_day'] as String?,
    );
  }

  bool get isPositive => change >= 0;

  String get formattedPrice => '\$${price.toStringAsFixed(2)}';

  String get formattedChange =>
      '${isPositive ? '+' : ''}${change.toStringAsFixed(2)}';

  String get formattedChangePercent =>
      '${isPositive ? '+' : ''}${changePercent.toStringAsFixed(2)}%';
}

class PricePointModel {
  final DateTime date;
  final double open;
  final double high;
  final double low;
  final double close;
  final int volume;

  const PricePointModel({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  factory PricePointModel.fromJson(Map<String, dynamic> json) {
    return PricePointModel(
      date: DateTime.parse(json['date'] as String),
      open: _parseDouble(json['open']),
      high: _parseDouble(json['high']),
      low: _parseDouble(json['low']),
      close: _parseDouble(json['close']),
      volume: (json['volume'] as num?)?.toInt() ?? 0,
    );
  }
}

class PriceHistoryModel {
  final String ticker;
  final String range;
  final List<PricePointModel> prices;

  const PriceHistoryModel({
    required this.ticker,
    required this.range,
    required this.prices,
  });

  factory PriceHistoryModel.fromJson(Map<String, dynamic> json) {
    final pricesList = (json['prices'] as List<dynamic>?)
            ?.map((p) => PricePointModel.fromJson(p as Map<String, dynamic>))
            .toList() ??
        [];

    return PriceHistoryModel(
      ticker: json['ticker'] as String? ?? '',
      range: json['range'] as String? ?? '1m',
      prices: pricesList,
    );
  }

  double? get latestClose => prices.isNotEmpty ? prices.last.close : null;

  double? get earliestClose => prices.isNotEmpty ? prices.first.close : null;

  double? get periodChange {
    if (earliestClose == null || latestClose == null) return null;
    return latestClose! - earliestClose!;
  }

  double? get periodChangePercent {
    if (earliestClose == null || earliestClose == 0 || periodChange == null) {
      return null;
    }
    return (periodChange! / earliestClose!) * 100;
  }
}

/// Helper function to parse various number formats
double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    return double.tryParse(value.replaceAll('%', '')) ?? 0.0;
  }
  return 0.0;
}
