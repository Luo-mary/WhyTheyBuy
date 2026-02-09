import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/subscription_model.dart';

final subscriptionProvider = FutureProvider<SubscriptionModel?>((ref) async {
  final apiClient = ref.watch(apiClientProvider);

  try {
    final response = await apiClient.getSubscription();
    if (response.statusCode == 200) {
      return SubscriptionModel.fromJson(response.data);
    }
  } catch (e) {
    // Return null if not authenticated or error
  }
  return null;
});

/// Refresh subscription data
void refreshSubscription(WidgetRef ref) {
  ref.invalidate(subscriptionProvider);
}
