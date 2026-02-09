import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';

/// Real-time stock price model
class RealtimePrice {
  final String symbol;
  final double price;
  final int volume;
  final int timestamp;

  const RealtimePrice({
    required this.symbol,
    required this.price,
    required this.volume,
    required this.timestamp,
  });

  factory RealtimePrice.fromJson(Map<String, dynamic> json) {
    return RealtimePrice(
      symbol: json['symbol'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      volume: (json['volume'] as num?)?.toInt() ?? 0,
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
    );
  }
}

/// WebSocket connection state
enum WebSocketState { disconnected, connecting, connected, error }

/// Stock WebSocket service for real-time price updates
class StockWebSocketService {
  WebSocketChannel? _channel;
  final _priceController = StreamController<RealtimePrice>.broadcast();
  final _stateController = StreamController<WebSocketState>.broadcast();
  final Set<String> _subscriptions = {};
  Timer? _reconnectTimer;
  bool _shouldReconnect = true;

  /// Stream of real-time price updates
  Stream<RealtimePrice> get priceStream => _priceController.stream;

  /// Stream of connection state changes
  Stream<WebSocketState> get stateStream => _stateController.stream;

  /// Current subscriptions
  Set<String> get subscriptions => Set.unmodifiable(_subscriptions);

  /// Connect to the WebSocket server
  Future<void> connect() async {
    if (_channel != null) return;

    _stateController.add(WebSocketState.connecting);

    try {
      // Build WebSocket URL from API base URL
      final wsUrl = AppConfig.apiBaseUrl
          .replaceFirst('http://', 'ws://')
          .replaceFirst('https://', 'wss://');

      _channel = WebSocketChannel.connect(Uri.parse('$wsUrl/ws/stocks'));

      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDone,
      );

      _stateController.add(WebSocketState.connected);

      // Resubscribe to previous symbols
      for (final symbol in _subscriptions) {
        _sendSubscribe(symbol);
      }
    } catch (e) {
      _stateController.add(WebSocketState.error);
      _scheduleReconnect();
    }
  }

  /// Disconnect from the WebSocket server
  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _stateController.add(WebSocketState.disconnected);
  }

  /// Subscribe to real-time updates for a symbol
  void subscribe(String symbol) {
    final upperSymbol = symbol.toUpperCase();
    _subscriptions.add(upperSymbol);

    if (_channel != null) {
      _sendSubscribe(upperSymbol);
    }
  }

  /// Unsubscribe from a symbol
  void unsubscribe(String symbol) {
    final upperSymbol = symbol.toUpperCase();
    _subscriptions.remove(upperSymbol);

    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'action': 'unsubscribe',
        'symbol': upperSymbol,
      }));
    }
  }

  void _sendSubscribe(String symbol) {
    _channel?.sink.add(jsonEncode({
      'action': 'subscribe',
      'symbol': symbol,
    }));
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == 'trade') {
        final price = RealtimePrice.fromJson(data);
        _priceController.add(price);
      } else if (type == 'connected') {
        _stateController.add(WebSocketState.connected);
      } else if (type == 'error') {
        // Handle error message from server
      }
    } catch (e) {
      // Ignore parse errors
    }
  }

  void _handleError(dynamic error) {
    _stateController.add(WebSocketState.error);
    _scheduleReconnect();
  }

  void _handleDone() {
    _channel = null;
    _stateController.add(WebSocketState.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      connect();
    });
  }

  void dispose() {
    disconnect();
    _priceController.close();
    _stateController.close();
  }
}

/// Provider for the stock WebSocket service
final stockWebSocketServiceProvider = Provider<StockWebSocketService>((ref) {
  final service = StockWebSocketService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for WebSocket connection state
final webSocketStateProvider = StreamProvider<WebSocketState>((ref) {
  final service = ref.watch(stockWebSocketServiceProvider);
  return service.stateStream;
});

/// Provider for real-time price of a specific symbol
final realtimePriceProvider =
    StreamProvider.family<RealtimePrice?, String>((ref, symbol) {
  final service = ref.watch(stockWebSocketServiceProvider);

  // Ensure connected and subscribed
  service.connect();
  service.subscribe(symbol);

  // Clean up subscription when provider is disposed
  ref.onDispose(() {
    service.unsubscribe(symbol);
  });

  // Filter stream for this symbol only
  return service.priceStream.where((price) => price.symbol == symbol.toUpperCase());
});
