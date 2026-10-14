import 'package:cloud_firestore/cloud_firestore.dart';

/// Account types in double-entry accounting.
enum AccountType {
  asset,       // Cash, Bank, Receivables, Inventory, Fixed Assets
  liability,   // Payables, Loans, Taxes
  equity,      // Capital, Retained Earnings
  revenue,     // Sales, Other Income
  expense,     // COGS, Salaries, Rent, Utilities
}

/// Normal balance side — how the account increases.
/// Assets & Expenses → Debit
/// Liabilities, Equity, Revenue → Credit
enum NormalBalance { debit, credit }

String accountTypeLabel(AccountType t) {
  switch (t) {
    case AccountType.asset:
      return 'Asset';
    case AccountType.liability:
      return 'Liability';
    case AccountType.equity:
      return 'Equity';
    case AccountType.revenue:
      return 'Revenue';
    case AccountType.expense:
      return 'Expense';
  }
}

String normalBalanceLabel(NormalBalance n) {
  return n == NormalBalance.debit ? 'Debit' : 'Credit';
}

NormalBalance normalBalanceFor(AccountType type) {
  switch (type) {
    case AccountType.asset:
    case AccountType.expense:
      return NormalBalance.debit;
    case AccountType.liability:
    case AccountType.equity:
    case AccountType.revenue:
      return NormalBalance.credit;
  }
}

class Account {
  final String id;
  final String code;         // e.g. "1001", "2001"
  final String name;         // e.g. "Cash in Hand"
  final AccountType type;
  final String? parentId;    // for sub-accounts
  final String description;
  final bool isSystem;       // system accounts (can't be deleted)
  final bool active;
  final DateTime? createdAt;

  Account({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    this.parentId,
    this.description = '',
    this.isSystem = false,
    this.active = true,
    this.createdAt,
  });

  NormalBalance get normalBalance => normalBalanceFor(type);

  factory Account.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Account(
      id: doc.id,
      code: d['code'] ?? '',
      name: d['name'] ?? '',
      type: AccountType.values.firstWhere(
        (t) => t.name == d['type'],
        orElse: () => AccountType.asset,
      ),
      parentId: d['parentId'],
      description: d['description'] ?? '',
      isSystem: d['isSystem'] ?? false,
      active: d['active'] ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'code': code,
        'name': name,
        'type': type.name,
        'parentId': parentId,
        'description': description,
        'isSystem': isSystem,
        'active': active,
      };
}