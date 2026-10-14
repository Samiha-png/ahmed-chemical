import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../services/report_service.dart';

final reportServiceProvider =
    Provider<ReportService>((ref) => ReportService());

class DateRange {
  final DateTime from;
  final DateTime to;
  DateRange({required this.from, required this.to});
}

final trialBalanceFromProvider =
    StateProvider<DateTime?>((ref) => null);
final trialBalanceToProvider =
    StateProvider<DateTime>((ref) => DateTime.now());

final trialBalanceProvider = FutureProvider<TrialBalance>((ref) async {
  final from = ref.watch(trialBalanceFromProvider);
  final to = ref.watch(trialBalanceToProvider);
  return ref.read(reportServiceProvider).trialBalance(from: from, to: to);
});

final plRangeProvider = StateProvider<DateRange>((ref) {
  final now = DateTime.now();
  return DateRange(from: DateTime(now.year, 1, 1), to: now);
});

final profitAndLossProvider = FutureProvider<ProfitAndLoss>((ref) async {
  final range = ref.watch(plRangeProvider);
  return ref
      .read(reportServiceProvider)
      .profitAndLoss(from: range.from, to: range.to);
});

final balanceSheetAsOfProvider =
    StateProvider<DateTime>((ref) => DateTime.now());

final balanceSheetProvider = FutureProvider<BalanceSheet>((ref) async {
  final asOf = ref.watch(balanceSheetAsOfProvider);
  return ref.read(reportServiceProvider).balanceSheet(asOf: asOf);
});