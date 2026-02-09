import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Ultra-simple investors page
class InvestorsPage extends ConsumerWidget {
  const InvestorsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Investors',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.black),
            ),
            const SizedBox(height: 20),

            const Text('ETF Managers', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
            const SizedBox(height: 8),
            _Item(name: 'ARK Innovation (ARKK)', info: 'Daily updates', onTap: () => context.go('/investors/ark-arkk')),
            _Item(name: 'ARK Genomic (ARKG)', info: 'Daily updates', onTap: () => context.go('/investors/ark-arkg')),

            const SizedBox(height: 24),
            const Text('13F Filers', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
            const SizedBox(height: 8),
            _Item(name: 'Berkshire Hathaway', info: 'Quarterly', onTap: () => context.go('/investors/berkshire')),
            _Item(name: 'Bridgewater', info: 'Quarterly', onTap: () => context.go('/investors/bridgewater')),
            _Item(name: 'Soros Fund', info: 'Quarterly', onTap: () => context.go('/investors/soros')),
            _Item(name: 'Pershing Square', info: 'Quarterly', onTap: () => context.go('/investors/pershing')),
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final String name, info;
  final VoidCallback onTap;
  const _Item({required this.name, required this.info, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black12))),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black)),
                  Text(info, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}
