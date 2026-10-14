import 'package:cloud_firestore/cloud_firestore.dart';

/// A Role bundles a set of permissions. Custom roles can be created by
/// the Super Admin. Default roles come pre-seeded.
class Role {
  final String id;
  final String name;            // e.g. "Karachi Sales Manager"
  final String description;
  final List<String> permissions;  // permission keys
  final bool isSystem;          // true for default roles — can't be deleted
  final DateTime? createdAt;

  Role({
    required this.id,
    required this.name,
    required this.description,
    required this.permissions,
    this.isSystem = false,
    this.createdAt,
  });

  bool hasPermission(String key) => permissions.contains(key);

  factory Role.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Role(
      id: doc.id,
      name: d['name'] ?? '',
      description: d['description'] ?? '',
      permissions: List<String>.from(d['permissions'] ?? const []),
      isSystem: d['isSystem'] ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'permissions': permissions,
        'isSystem': isSystem,
      };
}

/// Default roles that are seeded on first run.
/// These match the roles from the master prompt.
class DefaultRoles {
  static const superAdmin = 'super_admin';
  static const director = 'director';
  static const financeManager = 'finance_manager';
  static const accountant = 'accountant';
  static const inventoryManager = 'inventory_manager';
  static const purchaseOfficer = 'purchase_officer';
  static const salesOfficer = 'sales_officer';
  static const readOnly = 'read_only';

  static List<Role> seed() => [
        Role(
          id: superAdmin,
          name: 'Super Admin',
          description: 'Full access to everything',
          permissions: _allPermissionKeys(),
          isSystem: true,
        ),
        Role(
          id: director,
          name: 'Director / Management',
          description: 'Full visibility, most actions',
          permissions: _allPermissionKeys()
              .where((p) => !p.startsWith('users.roles'))
              .toList(),
          isSystem: true,
        ),
        Role(
          id: financeManager,
          name: 'Finance Manager',
          description: 'Accounting, invoices, payments, reports',
          permissions: const [
            'products.view', 'inventory.view',
            'purchasing.view', 'purchasing.bills.view',
            'purchasing.bills.post', 'purchasing.payments.view',
            'purchasing.payments.create',
            'sales.view', 'sales.invoices.view',
            'sales.invoices.post', 'sales.payments.record',
            'accounting.view', 'accounting.coa.manage',
            'accounting.journal.create', 'accounting.journal.post',
            'accounting.journal.reverse', 'accounting.reports.view',
            'suppliers.view', 'customers.view',
            'settings.view',
          ],
          isSystem: true,
        ),
        Role(
          id: accountant,
          name: 'Accountant',
          description: 'Accounting entries and reports',
          permissions: const [
            'products.view', 'inventory.view',
            'accounting.view', 'accounting.journal.create',
            'accounting.journal.post', 'accounting.reports.view',
            'suppliers.view', 'customers.view',
            'purchasing.bills.view', 'sales.invoices.view',
          ],
          isSystem: true,
        ),
        Role(
          id: inventoryManager,
          name: 'Inventory Manager',
          description: 'Manage stock across warehouses',
          permissions: const [
            'products.view', 'products.edit',
            'inventory.view', 'inventory.receive',
            'inventory.adjust', 'inventory.transfer',
            'warehouses.manage', 'categories.manage',
            'purchasing.receive',
          ],
          isSystem: true,
        ),
        Role(
          id: purchaseOfficer,
          name: 'Purchase Officer',
          description: 'Purchase orders and goods receipts',
          permissions: const [
            'products.view',
            'purchasing.view', 'purchasing.create', 'purchasing.receive',
            'purchasing.bills.view', 'purchasing.bills.create',
            'suppliers.view', 'suppliers.manage',
            'inventory.view',
          ],
          isSystem: true,
        ),
        Role(
          id: salesOfficer,
          name: 'Sales Officer',
          description: 'Sales orders and invoices',
          permissions: const [
            'products.view', 'inventory.view',
            'sales.view', 'sales.create', 'sales.confirm',
            'sales.invoices.view', 'sales.invoices.create',
            'sales.payments.record',
            'customers.view', 'customers.manage',
          ],
          isSystem: true,
        ),
        Role(
          id: readOnly,
          name: 'Read-Only Auditor',
          description: 'Can view everything, cannot modify',
          permissions: _allPermissionKeys()
              .where((p) => p.endsWith('.view') ||
                  p.endsWith('.reports.view'))
              .toList(),
          isSystem: true,
        ),
      ];

  static List<String> _allPermissionKeys() {
    // Import from permission.dart
    // (kept as method so we can call at runtime)
    return const [
      'products.view', 'products.create', 'products.edit', 'products.delete',
      'inventory.view', 'inventory.receive', 'inventory.adjust', 'inventory.transfer',
      'purchasing.view', 'purchasing.create', 'purchasing.approve', 'purchasing.receive',
      'purchasing.bills.view', 'purchasing.bills.create', 'purchasing.bills.post',
      'purchasing.payments.view', 'purchasing.payments.create',
      'sales.view', 'sales.create', 'sales.confirm',
      'sales.invoices.view', 'sales.invoices.create', 'sales.invoices.post',
      'sales.payments.record',
      'accounting.view', 'accounting.coa.manage',
      'accounting.journal.create', 'accounting.journal.post',
      'accounting.journal.reverse', 'accounting.reports.view',
      'users.view', 'users.invite', 'users.roles.manage',
      'settings.view', 'settings.edit',
      'suppliers.view', 'suppliers.manage',
      'customers.view', 'customers.manage',
      'warehouses.manage', 'categories.manage',
    ];
  }
}