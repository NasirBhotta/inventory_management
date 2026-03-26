import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repos/debt_repo.dart';
import '../../data/repos/providers.dart';

final debtCustomersProvider = FutureProvider<List<DebtCustomerSummary>>((ref) {
  return ref.watch(debtRepoProvider).getCustomerSummaries();
});

final debtCustomerDetailsProvider =
    FutureProvider.family<DebtCustomerDetails?, int>((ref, customerId) {
      return ref.watch(debtRepoProvider).getCustomerDetails(customerId);
    });
