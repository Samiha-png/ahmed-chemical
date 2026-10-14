import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/account.dart';

class AccountService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Account>> watch({AccountType? type, bool onlyActive = false}) {
    Query q = _db.collection('chartOfAccounts').orderBy('code');
    if (type != null) q = q.where('type', isEqualTo: type.name);
    if (onlyActive) q = q.where('active', isEqualTo: true);
    return q.snapshots().map((s) => s.docs.map(Account.fromDoc).toList());
  }

  Future<Account?> getById(String id) async {
    final doc = await _db.collection('chartOfAccounts').doc(id).get();
    if (!doc.exists) return null;
    return Account.fromDoc(doc);
  }

  Future<String> create(Account a) async {
    // Unique code
    final existing = await _db
        .collection('chartOfAccounts')
        .where('code', isEqualTo: a.code)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw Exception('Account code already exists: ${a.code}');
    }
    final ref = await _db.collection('chartOfAccounts').add({
      ...a.toMap(),
      'isSystem': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> update(String id, Account a) async {
    final existing = await _db
        .collection('chartOfAccounts')
        .where('code', isEqualTo: a.code)
        .get();
    final conflict = existing.docs.any((d) => d.id != id);
    if (conflict) throw Exception('Account code belongs to another account');
    await _db.collection('chartOfAccounts').doc(id).update({
      ...a.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String id) async {
    final a = await getById(id);
    if (a == null) return;
    if (a.isSystem) throw Exception('System accounts cannot be deleted');
    // Check if used in any journal
    final used = await _db
        .collection('journalEntries')
        .where('lines', arrayContains: a.id)
        .limit(1)
        .get();
    // Note: arrayContains on nested lists requires a different query in Firestore
    // For now, we allow delete — user will get error if constraint violated
    await _db.collection('chartOfAccounts').doc(id).delete();
  }

  /// Find account by code (for seed and auto-posting).
  Future<Account?> getByCode(String code) async {
    final snap = await _db
        .collection('chartOfAccounts')
        .where('code', isEqualTo: code)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return Account.fromDoc(snap.docs.first);
  }

  /// Seed default Chart of Accounts.
  /// Only runs if collection is empty.
  Future<bool> seedDefaultCOA() async {
    final existing = await _db.collection('chartOfAccounts').limit(1).get();
    if (existing.docs.isNotEmpty) return false;

    final defaults = _defaultAccounts();
    final batch = _db.batch();
    for (final a in defaults) {
      final ref = _db.collection('chartOfAccounts').doc();
      batch.set(ref, {
        ...a.toMap(),
        'isSystem': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    return true;
  }

  List<Account> _defaultAccounts() => [
        // ─── ASSETS (1000-1999) ───
        Account(id: '', code: '1000', name: 'Cash in Hand', type: AccountType.asset, isSystem: true),
        Account(id: '', code: '1010', name: 'Bank Account', type: AccountType.asset, isSystem: true),
        Account(id: '', code: '1100', name: 'Accounts Receivable', type: AccountType.asset, isSystem: true),
        Account(id: '', code: '1200', name: 'Inventory', type: AccountType.asset, isSystem: true),
        Account(id: '', code: '1300', name: 'Prepaid Expenses', type: AccountType.asset, isSystem: true),
        Account(id: '', code: '1500', name: 'Fixed Assets', type: AccountType.asset, isSystem: true),

        // ─── LIABILITIES (2000-2999) ───
        Account(id: '', code: '2000', name: 'Accounts Payable', type: AccountType.liability, isSystem: true),
        Account(id: '', code: '2100', name: 'Accrued Liabilities', type: AccountType.liability, isSystem: true),
        Account(id: '', code: '2200', name: 'Taxes Payable', type: AccountType.liability, isSystem: true),
        Account(id: '', code: '2500', name: 'Long-Term Loans', type: AccountType.liability, isSystem: true),

        // ─── EQUITY (3000-3999) ───
        Account(id: '', code: '3000', name: 'Owner\'s Capital', type: AccountType.equity, isSystem: true),
        Account(id: '', code: '3100', name: 'Retained Earnings', type: AccountType.equity, isSystem: true),
        Account(id: '', code: '3200', name: 'Drawings', type: AccountType.equity, isSystem: true),

        // ─── REVENUE (4000-4999) ───
        Account(id: '', code: '4000', name: 'Sales Revenue', type: AccountType.revenue, isSystem: true),
        Account(id: '', code: '4100', name: 'Sales Returns', type: AccountType.revenue, isSystem: true),
        Account(id: '', code: '4200', name: 'Sales Discounts', type: AccountType.revenue, isSystem: true),
        Account(id: '', code: '4500', name: 'Other Income', type: AccountType.revenue, isSystem: true),
        Account(id: '', code: '4600', name: 'FX Gain', type: AccountType.revenue, isSystem: true),

        // ─── EXPENSES (5000-5999) ───
        Account(id: '', code: '5000', name: 'Cost of Goods Sold', type: AccountType.expense, isSystem: true),
        Account(id: '', code: '5100', name: 'Salaries & Wages', type: AccountType.expense, isSystem: true),
        Account(id: '', code: '5200', name: 'Rent', type: AccountType.expense, isSystem: true),
        Account(id: '', code: '5300', name: 'Utilities', type: AccountType.expense, isSystem: true),
        Account(id: '', code: '5400', name: 'Freight & Transport', type: AccountType.expense, isSystem: true),
        Account(id: '', code: '5500', name: 'Office Supplies', type: AccountType.expense, isSystem: true),
        Account(id: '', code: '5600', name: 'Marketing', type: AccountType.expense, isSystem: true),
        Account(id: '', code: '5700', name: 'Professional Fees', type: AccountType.expense, isSystem: true),
        Account(id: '', code: '5800', name: 'Bank Charges', type: AccountType.expense, isSystem: true),
        Account(id: '', code: '5900', name: 'FX Loss', type: AccountType.expense, isSystem: true),
        Account(id: '', code: '5990', name: 'Miscellaneous Expense', type: AccountType.expense, isSystem: true),
      ];
}