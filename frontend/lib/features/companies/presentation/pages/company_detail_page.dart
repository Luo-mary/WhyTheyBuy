import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/stock_websocket_service.dart';
import '../../models/company_model.dart';
import '../../providers/company_provider.dart';

/// Company Detail Page - Shows real stock data from Alpha Vantage
class CompanyDetailPage extends ConsumerStatefulWidget {
  final String ticker;
  final String? investorId;

  const CompanyDetailPage({
    super.key,
    required this.ticker,
    this.investorId,
  });

  @override
  ConsumerState<CompanyDetailPage> createState() => _CompanyDetailPageState();
}

class _CompanyDetailPageState extends ConsumerState<CompanyDetailPage> {
  String _selectedRange = '1m';

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    // Watch live quote data
    final quoteAsync = ref.watch(liveQuoteProvider(widget.ticker));

    // Watch price history data
    final historyAsync =
        ref.watch(priceHistoryProvider((widget.ticker, _selectedRange)));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header with back button and ticker
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.all(isDesktop ? 32 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/dashboard');
                      }
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surface,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Company header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            widget.ticker[0],
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.ticker.toUpperCase(),
                              style: Theme.of(context).textTheme.displaySmall,
                            ),
                            const SizedBox(height: 4),
                            // Real-time price display below ticker
                            _HeaderRealtimePrice(ticker: widget.ticker),
                            const SizedBox(height: 8),
                            const Row(
                              children: [
                                _InfoChip(label: 'NASDAQ'),
                                SizedBox(width: 8),
                                _InfoChip(label: 'Live'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Price chart section with real data
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 20),
              child: Container(
                height: 280,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Price header with real-time updates
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: _RealtimePriceHeader(
                            ticker: widget.ticker,
                            quoteAsync: quoteAsync,
                          ),
                        ),
                        // Range selector with extended options
                        Flexible(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                '1d',
                                '1w',
                                '1m',
                                '3m',
                                '6m',
                                '1y',
                                '5y',
                                'all'
                              ].map((range) {
                                final isSelected = range == _selectedRange;
                                return Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _selectedRange = range;
                                      });
                                    },
                                    style: TextButton.styleFrom(
                                      backgroundColor: isSelected
                                          ? AppColors.primary.withAlpha(26)
                                          : null,
                                      foregroundColor: isSelected
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                      minimumSize: const Size(36, 28),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                    ),
                                    child: Text(
                                      range.toUpperCase(),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Chart
                    Expanded(
                      child: historyAsync.when(
                        data: (history) => _RealPriceChart(history: history),
                        loading: () => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        error: (error, _) => Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppColors.error,
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Unable to load chart data',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              TextButton(
                                onPressed: () {
                                  ref.invalidate(priceHistoryProvider(
                                      (widget.ticker, _selectedRange)));
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // Daily stats section
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 20),
              child: quoteAsync.when(
                data: (quote) => _DailyStatsCard(quote: quote),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // Investor activity (keeping mock for now)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Investor Activity (Disclosed)',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Recent publicly disclosed positions and changes',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: EdgeInsets.all(isDesktop ? 32 : 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const _ActivityCard(
                  investorName: 'ARK Innovation ETF',
                  action: 'BUY',
                  date: 'Dec 15, 2024',
                  shares: '+15,000',
                  priceRange: '\$180 - \$195',
                  note: 'Market price range (not execution price)',
                ),
                const _ActivityCard(
                  investorName: 'ARK Next Gen Internet',
                  action: 'BUY',
                  date: 'Dec 14, 2024',
                  shares: '+5,000',
                  priceRange: '\$178 - \$185',
                  note: 'Market price range (not execution price)',
                ),
                const _ActivityCard(
                  investorName: 'Berkshire Hathaway',
                  action: 'HOLD',
                  date: 'Q3 2024 13F Filing',
                  shares: '2.5M shares (no change)',
                  priceRange: '\$150 - \$280 (quarter)',
                  note: '13F data - exact trade dates unknown',
                ),
              ]),
            ),
          ),

          // AI Rationale
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 20),
              child: _AIRationaleCard(ticker: widget.ticker),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

/// Real-time price display in the header with live updates
class _HeaderRealtimePrice extends ConsumerStatefulWidget {
  final String ticker;

  const _HeaderRealtimePrice({required this.ticker});

  @override
  ConsumerState<_HeaderRealtimePrice> createState() =>
      _HeaderRealtimePriceState();
}

class _HeaderRealtimePriceState extends ConsumerState<_HeaderRealtimePrice>
    with SingleTickerProviderStateMixin {
  late AnimationController _flashController;
  late Animation<Color?> _flashAnimation;
  double? _lastPrice;
  bool _priceUp = true;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _flashAnimation = ColorTween(
      begin: Colors.transparent,
      end: AppColors.success.withAlpha(100),
    ).animate(CurvedAnimation(
      parent: _flashController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  void _onPriceUpdate(double newPrice) {
    if (_lastPrice != null && newPrice != _lastPrice) {
      setState(() {
        _priceUp = newPrice > _lastPrice!;
      });
      // Update flash color based on price direction
      _flashAnimation = ColorTween(
        begin: (_priceUp ? AppColors.success : AppColors.error).withAlpha(100),
        end: Colors.transparent,
      ).animate(CurvedAnimation(
        parent: _flashController,
        curve: Curves.easeOut,
      ));
      _flashController.forward(from: 0);
    }
    _lastPrice = newPrice;
  }

  @override
  Widget build(BuildContext context) {
    final realtimeAsync = ref.watch(realtimePriceProvider(widget.ticker));

    return realtimeAsync.when(
      data: (price) {
        if (price != null) {
          // Trigger flash animation on price change
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _onPriceUpdate(price.price);
          });

          return AnimatedBuilder(
            animation: _flashAnimation,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _flashAnimation.value,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Live indicator dot
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success.withAlpha(128),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Price
                    Text(
                      '\$${price.price.toStringAsFixed(2)}',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color:
                                _priceUp ? AppColors.success : AppColors.error,
                          ),
                    ),
                    const SizedBox(width: 8),
                    // Direction arrow
                    Icon(
                      _priceUp ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 16,
                      color: _priceUp ? AppColors.success : AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    // Timestamp
                    Text(
                      _formatTime(price.timestamp),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textTertiary,
                          ),
                    ),
                  ],
                ),
              );
            },
          );
        }
        // Waiting for first price
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Connecting to live feed...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        );
      },
      loading: () => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Connecting...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
      error: (_, __) => Text(
        'Live feed unavailable',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textTertiary,
            ),
      ),
    );
  }

  String _formatTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}

/// Real-time price header that shows live WebSocket updates
class _RealtimePriceHeader extends ConsumerWidget {
  final String ticker;
  final AsyncValue<LiveQuoteModel> quoteAsync;

  const _RealtimePriceHeader({
    required this.ticker,
    required this.quoteAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the real-time price stream
    final realtimeAsync = ref.watch(realtimePriceProvider(ticker));

    return realtimeAsync.when(
      data: (realtimePrice) {
        if (realtimePrice != null) {
          // Show real-time price
          return _LivePriceDisplay(price: realtimePrice);
        }
        // Fall back to quote data while waiting for first real-time update
        return quoteAsync.when(
          data: (quote) => _PriceHeader(quote: quote),
          loading: () => _PriceHeaderLoading(),
          error: (error, _) => _PriceHeaderError(error: error),
        );
      },
      loading: () => quoteAsync.when(
        data: (quote) => _PriceHeader(quote: quote),
        loading: () => _PriceHeaderLoading(),
        error: (error, _) => _PriceHeaderError(error: error),
      ),
      error: (_, __) => quoteAsync.when(
        data: (quote) => _PriceHeader(quote: quote),
        loading: () => _PriceHeaderLoading(),
        error: (error, _) => _PriceHeaderError(error: error),
      ),
    );
  }
}

/// Display for live price from WebSocket
class _LivePriceDisplay extends StatelessWidget {
  final RealtimePrice price;

  const _LivePriceDisplay({required this.price});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '\$${price.price.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(26),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'LIVE',
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Row(
          children: [
            Text(
              'Vol: ${_formatVolume(price.volume)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(width: 8),
            Text(
              'Updated: ${_formatTime(price.timestamp)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatVolume(int volume) {
    if (volume >= 1000000) {
      return '${(volume / 1000000).toStringAsFixed(1)}M';
    } else if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(0)}K';
    }
    return volume.toString();
  }

  String _formatTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}

class _PriceHeader extends StatelessWidget {
  final LiveQuoteModel quote;

  const _PriceHeader({required this.quote});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          quote.formattedPrice,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        Row(
          children: [
            Icon(
              quote.isPositive ? Icons.trending_up : Icons.trending_down,
              size: 16,
              color: quote.isPositive ? AppColors.success : AppColors.error,
            ),
            const SizedBox(width: 4),
            Text(
              '${quote.formattedChange} (${quote.formattedChangePercent})',
              style: TextStyle(
                color: quote.isPositive ? AppColors.success : AppColors.error,
              ),
            ),
            Text(
              ' today',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _PriceHeaderLoading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 100,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 150,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}

class _PriceHeaderError extends StatelessWidget {
  final Object error;

  const _PriceHeaderError({required this.error});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Price unavailable',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        Text(
          'API may be rate limited',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
              ),
        ),
      ],
    );
  }
}

class _RealPriceChart extends StatelessWidget {
  final PriceHistoryModel history;

  const _RealPriceChart({required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.prices.isEmpty) {
      return const Center(
        child: Text('No price data available'),
      );
    }

    // Convert price data to chart spots
    final spots = <FlSpot>[];
    for (int i = 0; i < history.prices.length; i++) {
      spots.add(FlSpot(i.toDouble(), history.prices[i].close));
    }

    // Determine if overall trend is positive
    final isPositive = (history.periodChange ?? 0) >= 0;
    final lineColor = isPositive ? AppColors.success : AppColors.error;

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: lineColor,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  lineColor.withAlpha(51),
                  lineColor.withAlpha(0),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: AppColors.surface,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                if (index < history.prices.length) {
                  final price = history.prices[index];
                  return LineTooltipItem(
                    '\$${price.close.toStringAsFixed(2)}\n${price.date.toString().substring(0, 10)}',
                    const TextStyle(color: Colors.white, fontSize: 12),
                  );
                }
                return null;
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}

class _DailyStatsCard extends StatelessWidget {
  final LiveQuoteModel quote;

  const _DailyStatsCard({required this.quote});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Statistics',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 32,
            runSpacing: 16,
            children: [
              _StatItem(
                  label: 'Open', value: '\$${quote.open.toStringAsFixed(2)}'),
              _StatItem(
                  label: 'High', value: '\$${quote.high.toStringAsFixed(2)}'),
              _StatItem(
                  label: 'Low', value: '\$${quote.low.toStringAsFixed(2)}'),
              _StatItem(
                label: 'Prev Close',
                value: '\$${quote.previousClose.toStringAsFixed(2)}',
              ),
              _StatItem(
                label: 'Volume',
                value: _formatVolume(quote.volume),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatVolume(int volume) {
    if (volume >= 1000000000) {
      return '${(volume / 1000000000).toStringAsFixed(2)}B';
    } else if (volume >= 1000000) {
      return '${(volume / 1000000).toStringAsFixed(2)}M';
    } else if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(1)}K';
    }
    return volume.toString();
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final String investorName;
  final String action;
  final String date;
  final String shares;
  final String priceRange;
  final String? note;

  const _ActivityCard({
    required this.investorName,
    required this.action,
    required this.date,
    required this.shares,
    required this.priceRange,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    final isBuy = action == 'BUY';
    final isHold = action == 'HOLD';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
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
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isBuy
                        ? AppColors.successBackground
                        : isHold
                            ? AppColors.surfaceLight
                            : AppColors.errorBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      investorName[0],
                      style: TextStyle(
                        color: isBuy
                            ? AppColors.success
                            : isHold
                                ? AppColors.textSecondary
                                : AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        investorName,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        date,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isBuy
                                ? AppColors.successBackground
                                : isHold
                                    ? AppColors.surfaceLight
                                    : AppColors.errorBackground,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            action,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isBuy
                                  ? AppColors.success
                                  : isHold
                                      ? AppColors.textSecondary
                                      : AppColors.error,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          shares,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: isBuy ? AppColors.success : null,
                                  ),
                        ),
                      ],
                    ),
                    Text(
                      'Market: $priceRange',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textTertiary,
                          ),
                    ),
                  ],
                ),
              ],
            ),
            if (note != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 14,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        note!,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.textTertiary,
                              fontStyle: FontStyle.italic,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AIRationaleCard extends StatelessWidget {
  final String ticker;

  const _AIRationaleCard({required this.ticker});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Rationale',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      'Hypothetical analysis (not advice)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textTertiary,
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(26),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'PRO',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Disclaimer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warningBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.warning.withAlpha(77)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.warning,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Disclaimer',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.warning,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Informational only, not investment advice. This analysis presents '
                  'hypotheses based on publicly disclosed information and does not reflect '
                  "the investor's actual reasoning. Do not make investment decisions based "
                  'on this analysis. Past holdings changes do not indicate future actions.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.warningLight,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
