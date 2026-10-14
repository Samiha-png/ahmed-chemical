import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/account.dart';
import '../models/journal_entry.dart';

/// Computes Trial Balance, P&L, Balance Sheet, and General Ledger
/// from posted journal entries.
class ReportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─────────────────────────────────────────────
  // CORE: Aggregate all posted entries
  // ─────────────────────────────────────────────
  Future<Map<String, _AccountBalance>> _computeBalances({
    DateTime? from,
    DateTime? to,
  }) async {
    final snap = await _db
        .collection('journalEntries')
        .where('status', isEqualTo: JournalEntryStatus.posted.name)
        .get();

    final balances = <String, _AccountBalance>{};

    for (final doc in snap.docs) {
      final entry = JournalEntry.fromDoc(doc);
      final d = entry.entryDate;
      if (from != null && d.isBefore(from)) continue;
      if (to != null && d.isAfter(to.add(const Duration(days: 1)))) {
        continue;
      }
      for (final line in entry.lines) {
        final cur = balances.putIfAbsent(
          line.accountId,
          () => _AccountBalance(
            accountId: line.accountId,
            accountCode: line.accountCode,
            accountName: line.accountName,
            totalDebit: 0,
            totalCredit: 0,
          ),
        );
        cur.totalDebit += line.debit;
        cur.totalCredit += line.credit;
      }
    }
    return balances;
  }

  Future<Map<String, Account>> _loadAccounts() async {
    final snap = await _db.collection('chartOfAccounts').get();
    return {
      for (final d in snap.docs) d.id: Account.fromDoc(d),
    };
  }

  // ─────────────────────────────────────────────
  // TRIAL BALANCE
  // ─────────────────────────────────────────────
  Future<TrialBalance> trialBalance({
    DateTime? from,
    DateTime? to,
  }) async {
    final balances = await _computeBalances(from: from, to: to);
    final accounts = await _loadAccounts();

    final rows = <TrialBalanceRow>[];
    num totalDebit = 0;
    num totalCredit = 0;

    for (final entry in balances.entries) {
      final account = accounts[entry.key];
      if (account == null) continue;
      final bal = entry.value;
      final net = bal.totalDebit - bal.totalCredit;
      final dr = net > 0 ? net : 0;
      final cr = net < 0 ? -net : 0;
      if (dr == 0 && cr == 0) continue;
      rows.add(TrialBalanceRow(
        accountId: account.id,
        accountCode: account.code,
        accountName: account.name,
        type: account.type,
        debit: dr,
        credit: cr,
      ));
      totalDebit += dr;
      totalCredit += cr;
    }

    rows.sort((a, b) => a.accountCode.compareTo(b.accountCode));

    return TrialBalance(
      asOf: to ?? DateTime.now(),
      from: from,
      rows: rows,
      totalDebit: totalDebit,
      totalCredit: totalCredit,
    );
  }

  // ─────────────────────────────────────────────
  // PROFIT & LOSS
  // ─────────────────────────────────────────────
  Future<ProfitAndLoss> profitAndLoss({
    required DateTime from,
    required DateTime to,
  }) async {
    final balances = await _computeBalances(from: from, to: to);
    final accounts = await _loadAccounts();

    final revenues = <PLRow>[];
    final expenses = <PLRow>[];
    num totalRevenue = 0;
    num totalExpense = 0;

    for (final entry in balances.entries) {
      final account = accounts[entry.key];
      if (account == null) continue;
      final bal = entry.value;

      if (account.type == AccountType.revenue) {
        final amount = bal.totalCredit - bal.totalDebit;
        if (amount == 0) continue;
        revenues.add(PLRow(
          accountCode: account.code,
          accountName: account.name,
          amount: amount,
        ));
        totalRevenue += amount;
      } else if (account.type == AccountType.expense) {
        final amount = bal.totalDebit - bal.totalCredit;
        if (amount == 0) continue;
        expenses.add(PLRow(
          accountCode: account.code,
          accountName: account.name,
          amount: amount,
        ));
        totalExpense += amount;
      }
    }

    revenues.sort((a, b) => a.accountCode.compareTo(b.accountCode));
    expenses.sort((a, b) => a.accountCode.compareTo(b.accountCode));

    return ProfitAndLoss(
      from: from,
      to: to,
      revenues: revenues,
      expenses: expenses,
      totalRevenue: totalRevenue,
      totalExpense: totalExpense,
      netProfit: totalRevenue - totalExpense,
    );
  }

  // ─────────────────────────────────────────────
  // BALANCE SHEET
  // ─────────────────────────────────────────────
  Future<BalanceSheet> balanceSheet({
    required DateTime asOf,
  }) async {
    final balances = await _computeBalances(to: asOf);
    final accounts = await _loadAccounts();

    final assets = <PLRow>[];
    final liabilities = <PLRow>[];
    final equity = <PLRow>[];
    num totalAssets = 0;
    num totalLiabilities = 0;
    num totalEquity = 0;

    for (final entry in balances.entries) {
      final account = accounts[entry.key];
      if (account == null) continue;
      final bal = entry.value;

      if (account.type == AccountType.asset) {
        final amount = bal.totalDebit - bal.totalCredit;
        if (amount == 0) continue;
        assets.add(PLRow(
          accountCode: account.code,
          accountName: account.name,
          amount: amount,
        ));
        totalAssets += amount;
      } else if (account.type == AccountType.liability) {
        final amount = bal.totalCredit - bal.totalDebit;
        if (amount == 0) continue;
        liabilities.add(PLRow(
          accountCode: account.code,
          accountName: account.name,
          amount: amount,
        ));
        totalLiabilities += amount;
      } else if (account.type == AccountType.equity) {
        final amount = bal.totalCredit - bal.totalDebit;
        if (amount == 0) continue;
        equity.add(PLRow(
          accountCode: account.code,
          accountName: account.name,
          amount: amount,
        ));
        totalEquity += amount;
      }
    }

    // Include net profit in equity
    final pl = await profitAndLoss(
      from: DateTime(asOf.year, 1, 1),
      to: asOf,
    );
    if (pl.netProfit != 0) {
      equity.add(PLRow(
        accountCode: '3999',
        accountName: 'Net Profit (Current Period)',
        amount: pl.netProfit,
      ));
      totalEquity += pl.netProfit;
    }

    assets.sort((a, b) => a.accountCode.compareTo(b.accountCode));
    liabilities.sort((a, b) => a.accountCode.compareTo(b.accountCode));
    equity.sort((a, b) => a.accountCode.compareTo(b.accountCode));

    return BalanceSheet(
      asOf: asOf,
      assets: assets,
      liabilities: liabilities,
      equity: equity,
      totalAssets: totalAssets,
      totalLiabilities: totalLiabilities,
      totalEquity: totalEquity,
    );
  }

  // ─────────────────────────────────────────────
  // GENERAL LEDGER
  // ─────────────────────────────────────────────
  Future<LedgerReport> generalLedger({
    required String accountId,
    DateTime? from,
    DateTime? to,
  }) async {
    final account = await _db
        .collection('chartOfAccounts')
        .doc(accountId)
        .get();
    if (!account.exists) throw Exception('Account not found');
    final acc = Account.fromDoc(account);

    final snap = await _db
        .collection('journalEntries')
        .where('status', isEqualTo: JournalEntryStatus.posted.name)
        .get();

    final isDebitNormal = acc.normalBalance == NormalBalance.debit;

    final lines = <LedgerLine>[];
    for (final doc in snap.docs) {
      final entry = JournalEntry.fromDoc(doc);
      final d = entry.entryDate;
      if (from != null && d.isBefore(from)) continue;
      if (to != null && d.isAfter(to.add(const Duration(days: 1)))) {
        continue;
      }
      for (final line in entry.lines) {
        if (line.accountId != accountId) continue;
        lines.add(LedgerLine(
          date: d,
          entryNumber: entry.number,
          narration: entry.narration,
          reference: entry.reference,
          debit: line.debit,
          credit: line.credit,
          balance: 0,
        ));
      }
    }

    lines.sort((a, b) => a.date.compareTo(b.date));

    num bal = 0;
    final sorted = <LedgerLine>[];
    for (final l in lines) {
      final delta = isDebitNormal
          ? (l.debit - l.credit)
          : (l.credit - l.debit);
      bal += delta;
      sorted.add(LedgerLine(
        date: l.date,
        entryNumber: l.entryNumber,
        narration: l.narration,
        reference: l.reference,
        debit: l.debit,
        credit: l.credit,
        balance: bal,
      ));
    }

    return LedgerReport(
      account: acc,
      lines: sorted,
      closingBalance: bal,
    );
  }
}

// ─────────────────────────────────────────────
// Internal helper
// ─────────────────────────────────────────────
class _AccountBalance {
  final String accountId;
  final String accountCode;
  final String accountName;
  num totalDebit;
  num totalCredit;
  _AccountBalance({
    required this.accountId,
    required this.accountCode,
    required this.accountName,
    required this.totalDebit,
    required this.totalCredit,
  });
}

// ─────────────────────────────────────────────
// Public result types
// ─────────────────────────────────────────────

class TrialBalanceRow {
  final String accountId;
  final String accountCode;
  final String accountName;
  final AccountType type;
  final num debit;
  final num credit;
  TrialBalanceRow({
    required this.accountId,
    required this.accountCode,
    required this.accountName,
    required this.type,
    required this.debit,
    required this.credit,
  });
}

class TrialBalance {
  final DateTime asOf;
  final DateTime? from;
  final List<TrialBalanceRow> rows;
  final num totalDebit;
  final num totalCredit;
  TrialBalance({
    required this.asOf,
    this.from,
    required this.rows,
    required this.totalDebit,
    required this.totalCredit,
  });
  bool get isBalanced => (totalDebit - totalCredit).abs() < 0.01;
}

class PLRow {
  final String accountCode;
  final String accountName;
  final num amount;
  PLRow({
    required this.accountCode,
    required this.accountName,
    required this.amount,
  });
}

class ProfitAndLoss {
  final DateTime from;
  final DateTime to;
  final List<PLRow> revenues;
  final List<PLRow> expenses;
  final num totalRevenue;
  final num totalExpense;
  final num netProfit;
  ProfitAndLoss({
    required this.from,
    required this.to,
    required this.revenues,
    required this.expenses,
    required this.totalRevenue,
    required this.totalExpense,
    required this.netProfit,
  });
}

class BalanceSheet {
  final DateTime asOf;
  final List<PLRow> assets;
  final List<PLRow> liabilities;
  final List<PLRow> equity;
  final num totalAssets;
  final num totalLiabilities;
  final num totalEquity;
  BalanceSheet({
    required this.asOf,
    required this.assets,
    required this.liabilities,
    required this.equity,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.totalEquity,
  });
  bool get isBalanced =>
      (totalAssets - (totalLiabilities + totalEquity)).abs() < 0.01;
}

class LedgerLine {
  final DateTime date;
  final String entryNumber;
  final String narration;
  final String reference;
  final num debit;
  final num credit;
  final num balance;
  LedgerLine({
    required this.date,
    required this.entryNumber,
    required this.narration,
    required this.reference,
    required this.debit,
    required this.credit,
    required this.balance,
  });
}

class LedgerReport {
  final Account account;
  final List<LedgerLine> lines;
  final num closingBalance;
  LedgerReport({
    required this.account,
    required this.lines,
    required this.closingBalance,
  });
}