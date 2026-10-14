import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/journal_entry.dart';
import '../services/journal_service.dart';

final journalServiceProvider =
    Provider<JournalService>((ref) => JournalService());

final journalSearchProvider = StateProvider<String>((ref) => '');
final journalStatusFilterProvider =
    StateProvider<JournalEntryStatus?>((ref) => null);

final journalEntriesProvider = StreamProvider<List<JournalEntry>>((ref) {
  final search = ref.watch(journalSearchProvider);
  final status = ref.watch(journalStatusFilterProvider);
  return ref.watch(journalServiceProvider).watch(
        search: search,
        status: status,
      );
});