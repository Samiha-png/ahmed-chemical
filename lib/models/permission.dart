/// Master list of all permissions in the system.
/// Add new permissions here; they'll automatically appear in the
/// role editor UI.
class AppPermission {
  final String key;         // e.g. "products.create"
  final String label;       // e.g. "Create Products"
  final String group;       // e.g. "Products & Inventory"

  const AppPermission(this.key, this.label, this.group);
}

/// The canonical list. DO NOT change keys — only add new ones.
const List<AppPermission> allPermissions = [
  // ─── Products & Inventory ───
  AppPermission('products.view', 'View Products', 'Products & Inventory'),
  AppPermission('products.create', 'Create Products', 'Products & Inventory'),
  AppPermission('products.edit', 'Edit Products', 'Products & Inventory'),
  AppPermission('products.delete', 'Delete Products', 'Products & Inventory'),
  AppPermission('inventory.view', 'View Inventory', 'Products & Inventory'),
  AppPermission('inventory.receive', 'Receive Stock', 'Products & Inventory'),
  AppPermission('inventory.adjust', 'Adjust Stock', 'Products & Inventory'),
  AppPermission('inventory.transfer', 'Transfer Stock', 'Products & Inventory'),

  // ─── Purchasing ───
  AppPermission('purchasing.view', 'View Purchase Orders', 'Purchasing'),
  AppPermission('purchasing.create', 'Create Purchase Orders', 'Purchasing'),
  AppPermission('purchasing.approve', 'Approve Purchase Orders', 'Purchasing'),
  AppPermission('purchasing.receive', 'Post Goods Receipts', 'Purchasing'),
  AppPermission('purchasing.bills.view', 'View Supplier Bills', 'Purchasing'),
  AppPermission('purchasing.bills.create', 'Create Supplier Bills', 'Purchasing'),
  AppPermission('purchasing.bills.post', 'Post Supplier Bills', 'Purchasing'),
  AppPermission('purchasing.payments.view', 'View Supplier Payments', 'Purchasing'),
  AppPermission('purchasing.payments.create', 'Record Supplier Payments', 'Purchasing'),

  // ─── Sales ───
  AppPermission('sales.view', 'View Sales Orders', 'Sales'),
  AppPermission('sales.create', 'Create Sales Orders', 'Sales'),
  AppPermission('sales.confirm', 'Confirm Sales Orders', 'Sales'),
  AppPermission('sales.invoices.view', 'View Sales Invoices', 'Sales'),
  AppPermission('sales.invoices.create', 'Create Invoices', 'Sales'),
  AppPermission('sales.invoices.post', 'Post Invoices', 'Sales'),
  AppPermission('sales.payments.record', 'Record Customer Receipts', 'Sales'),

  // ─── Finance & Accounting ───
  AppPermission('accounting.view', 'View Accounting', 'Finance & Accounting'),
  AppPermission('accounting.coa.manage', 'Manage Chart of Accounts', 'Finance & Accounting'),
  AppPermission('accounting.journal.create', 'Create Journal Entries', 'Finance & Accounting'),
  AppPermission('accounting.journal.post', 'Post Journal Entries', 'Finance & Accounting'),
  AppPermission('accounting.journal.reverse', 'Reverse Journal Entries', 'Finance & Accounting'),
  AppPermission('accounting.reports.view', 'View Financial Reports', 'Finance & Accounting'),

  // ─── Users & Settings ───
  AppPermission('users.view', 'View Users', 'Users & Settings'),
  AppPermission('users.invite', 'Invite Users', 'Users & Settings'),
  AppPermission('users.roles.manage', 'Manage Roles & Permissions', 'Users & Settings'),
  AppPermission('settings.view', 'View Settings', 'Users & Settings'),
  AppPermission('settings.edit', 'Edit Settings', 'Users & Settings'),

  // ─── Master Data ───
  AppPermission('suppliers.view', 'View Suppliers', 'Master Data'),
  AppPermission('suppliers.manage', 'Manage Suppliers', 'Master Data'),
  AppPermission('customers.view', 'View Customers', 'Master Data'),
  AppPermission('customers.manage', 'Manage Customers', 'Master Data'),
  AppPermission('warehouses.manage', 'Manage Warehouses', 'Master Data'),
  AppPermission('categories.manage', 'Manage Categories', 'Master Data'),
];

/// Group permissions by their `group` field for UI display.
Map<String, List<AppPermission>> groupPermissions() {
  final map = <String, List<AppPermission>>{};
  for (final p in allPermissions) {
    map.putIfAbsent(p.group, () => []).add(p);
  }
  return map;
}