import 'package:cloud_firestore/cloud_firestore.dart';

enum MovementType { receipt, issue, transferIn, transferOut, adjustment }

String movementTypeLabel(MovementType t) {
  switch (t) {
    case MovementType.receipt: return 'Receipt';
    case MovementType.issue: return 'Issue';
    case MovementType.transferIn: return 'Transfer In';
    case MovementType.transferOut: return 'Transfer Out';
    case MovementType.adjustment: return 'Adjustment';
  }
}

class InventoryMovement {
  final String id;
  final String productId;
  final String productName;
  final String sku;
  final String warehouseId;
  final String warehouseName;
  final MovementType type;
  final num quantity;     // positive or negative (net change)
  final num unitCost;     // cost per unit at the time
  final num totalValue;   // quantity * unitCost (absolute)
  final String reason;    // mandatory for adjustments
  final String? reference; // e.g. invoice no, transfer id
  final String createdBy;  // user uid
  final DateTime? createdAt;

  InventoryMovement({
    required this.id,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.warehouseId,
    required this.warehouseName,
    required this.type,
    required this.quantity,
    required this.unitCost,
    required this.totalValue,
    required this.reason,
    this.reference,
    required this.createdBy,
    this.createdAt,
  });

  factory InventoryMovement.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return InventoryMovement(
      id: doc.id,
      productId: d['productId'] ?? '',
      productName: d['productName'] ?? '',
      sku: d['sku'] ?? '',
      warehouseId: d['warehouseId'] ?? '',
      warehouseName: d['warehouseName'] ?? '',
      type: MovementType.values.firstWhere(
        (t) => t.name == d['type'],
        orElse: () => MovementType.adjustment,
      ),
      quantity: (d['quantity'] ?? 0) as num,
      unitCost: (d['unitCost'] ?? 0) as num,
      totalValue: (d['totalValue'] ?? 0) as num,
      reason: d['reason'] ?? '',
      reference: d['reference'],
      createdBy: d['createdBy'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'sku': sku,
        'warehouseId': warehouseId,
        'warehouseName': warehouseName,
        'type': type.name,
        'quantity': quantity,
        'unitCost': unitCost,
        'totalValue': totalValue,
        'reason': reason,
        'reference': reference,
        'createdBy': createdBy,
      };
}

class StockBalance {
  final String id;          // "${productId}_${warehouseId}"
  final String productId;
  final String productName;
  final String sku;
  final String baseUnit;
  final String warehouseId;
  final String warehouseName;
  final num quantity;
  final num avgCost;
  final num totalValue;
  final num reorderLevel;
  final DateTime? updatedAt;

  StockBalance({
    required this.id,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.baseUnit,
    required this.warehouseId,
    required this.warehouseName,
    required this.quantity,
    required this.avgCost,
    required this.totalValue,
    required this.reorderLevel,
    this.updatedAt,
  });

  factory StockBalance.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return StockBalance(
      id: doc.id,
      productId: d['productId'] ?? '',
      productName: d['productName'] ?? '',
      sku: d['sku'] ?? '',
      baseUnit: d['baseUnit'] ?? 'kg',
      warehouseId: d['warehouseId'] ?? '',
      warehouseName: d['warehouseName'] ?? '',
      quantity: (d['quantity'] ?? 0) as num,
      avgCost: (d['avgCost'] ?? 0) as num,
      totalValue: (d['totalValue'] ?? 0) as num,
      reorderLevel: (d['reorderLevel'] ?? 0) as num,
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  bool get isLowStock => quantity <= reorderLevel && reorderLevel > 0;
}

class InventoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String _balanceId(String productId, String warehouseId) =>
      '${productId}_$warehouseId';

  /// Watch all stock balances across warehouses
  Stream<List<StockBalance>> watchBalances({
    String? warehouseId,
    String? search,
  }) {
    Query q = _db.collection('stockBalances').orderBy('productName');
    if (warehouseId != null && warehouseId.isNotEmpty) {
      q = q.where('warehouseId', isEqualTo: warehouseId);
    }
    return q.snapshots().map((s) {
      var list = s.docs.map(StockBalance.fromDoc).toList();
      if (search != null && search.trim().isNotEmpty) {
        final q2 = search.toLowerCase();
        list = list
            .where((b) =>
                b.productName.toLowerCase().contains(q2) ||
                b.sku.toLowerCase().contains(q2))
            .toList();
      }
      return list;
    });
  }

  /// Watch movements for a specific product (optionally for one warehouse)
  Stream<List<InventoryMovement>> watchMovements({
    String? productId,
    String? warehouseId,
    int limit = 100,
  }) {
    Query q = _db.collection('inventoryMovements');
    if (productId != null) q = q.where('productId', isEqualTo: productId);
    if (warehouseId != null) q = q.where('warehouseId', isEqualTo: warehouseId);
    // Note: composite index may be required. If Firestore complains,
    // create the index from the error message link.
    q = q.orderBy('createdAt', descending: true).limit(limit);
    return q.snapshots().map((s) =>
        s.docs.map(InventoryMovement.fromDoc).toList());
  }

  /// Receipt — increase stock. Recomputes weighted average cost.
  Future<void> receiveStock({
    required String productId,
    required String productName,
    required String sku,
    required String baseUnit,
    required String warehouseId,
    required String warehouseName,
    required num quantity,
    required num unitCost,
    required num reorderLevel,
    required String userId,
    String? reference,
  }) async {
    if (quantity <= 0) {
      throw Exception('Quantity must be greater than zero');
    }
    if (unitCost < 0) {
      throw Exception('Unit cost cannot be negative');
    }

    final balRef =
        _db.collection('stockBalances').doc(_balanceId(productId, warehouseId));

    await _db.runTransaction((tx) async {
      final balSnap = await tx.get(balRef);
      num oldQty = 0;
      num oldAvg = 0;
      if (balSnap.exists) {
        final d = balSnap.data() as Map<String, dynamic>;
        oldQty = (d['quantity'] ?? 0) as num;
        oldAvg = (d['avgCost'] ?? 0) as num;
      }
      final newQty = oldQty + quantity;
      final newAvg = newQty == 0
          ? 0.0
          : ((oldQty * oldAvg) + (quantity * unitCost)) / newQty;
      final newTotal = newQty * newAvg;

      tx.set(balRef, {
        'productId': productId,
        'productName': productName,
        'sku': sku,
        'baseUnit': baseUnit,
        'warehouseId': warehouseId,
        'warehouseName': warehouseName,
        'quantity': newQty,
        'avgCost': newAvg,
        'totalValue': newTotal,
        'reorderLevel': reorderLevel,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final movRef = _db.collection('inventoryMovements').doc();
      tx.set(movRef, {
        'productId': productId,
        'productName': productName,
        'sku': sku,
        'warehouseId': warehouseId,
        'warehouseName': warehouseName,
        'type': MovementType.receipt.name,
        'quantity': quantity,
        'unitCost': unitCost,
        'totalValue': quantity * unitCost,
        'reason': '',
        'reference': reference,
        'createdBy': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Adjust — set stock to a specific number or add/subtract with reason.
  /// Uses `delta` (can be positive or negative). Reason is mandatory.
  Future<void> adjustStock({
    required String productId,
    required String productName,
    required String sku,
    required String baseUnit,
    required String warehouseId,
    required String warehouseName,
    required num delta,
    required String reason,
    required num reorderLevel,
    required String userId,
  }) async {
    if (delta == 0) throw Exception('Adjustment cannot be zero');
    if (reason.trim().isEmpty) {
      throw Exception('Reason is required for adjustments');
    }

    final balRef =
        _db.collection('stockBalances').doc(_balanceId(productId, warehouseId));

    await _db.runTransaction((tx) async {
      final balSnap = await tx.get(balRef);
      num oldQty = 0;
      num oldAvg = 0;
      if (balSnap.exists) {
        final d = balSnap.data() as Map<String, dynamic>;
        oldQty = (d['quantity'] ?? 0) as num;
        oldAvg = (d['avgCost'] ?? 0) as num;
      }
      final newQty = oldQty + delta;
      if (newQty < 0) {
        throw Exception('Insufficient stock. Available: $oldQty');
      }
      final newTotal = newQty * oldAvg;

      tx.set(balRef, {
        'productId': productId,
        'productName': productName,
        'sku': sku,
        'baseUnit': baseUnit,
        'warehouseId': warehouseId,
        'warehouseName': warehouseName,
        'quantity': newQty,
        'avgCost': oldAvg,
        'totalValue': newTotal,
        'reorderLevel': reorderLevel,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final movRef = _db.collection('inventoryMovements').doc();
      tx.set(movRef, {
        'productId': productId,
        'productName': productName,
        'sku': sku,
        'warehouseId': warehouseId,
        'warehouseName': warehouseName,
        'type': MovementType.adjustment.name,
        'quantity': delta,
        'unitCost': oldAvg,
        'totalValue': (delta.abs()) * oldAvg,
        'reason': reason.trim(),
        'reference': null,
        'createdBy': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Transfer — move stock between warehouses.
  Future<void> transferStock({
    required String productId,
    required String productName,
    required String sku,
    required String baseUnit,
    required String fromWarehouseId,
    required String fromWarehouseName,
    required String toWarehouseId,
    required String toWarehouseName,
    required num quantity,
    required String userId,
  }) async {
    if (quantity <= 0) throw Exception('Quantity must be greater than zero');
    if (fromWarehouseId == toWarehouseId) {
      throw Exception('Source and destination warehouses must differ');
    }

    final fromRef = _db
        .collection('stockBalances')
        .doc(_balanceId(productId, fromWarehouseId));
    final toRef = _db
        .collection('stockBalances')
        .doc(_balanceId(productId, toWarehouseId));

    await _db.runTransaction((tx) async {
      final fromSnap = await tx.get(fromRef);
      if (!fromSnap.exists) {
        throw Exception('No stock in source warehouse');
      }
      final fd = fromSnap.data() as Map<String, dynamic>;
      final fromQty = (fd['quantity'] ?? 0) as num;
      final avgCost = (fd['avgCost'] ?? 0) as num;
      final reorder = (fd['reorderLevel'] ?? 0) as num;
      if (fromQty < quantity) {
        throw Exception(
            'Insufficient stock in source. Available: $fromQty');
      }

      final toSnap = await tx.get(toRef);
      num toQty = 0;
      num toAvg = 0;
      if (toSnap.exists) {
        final td = toSnap.data() as Map<String, dynamic>;
        toQty = (td['quantity'] ?? 0) as num;
        toAvg = (td['avgCost'] ?? 0) as num;
      }
      final newFromQty = fromQty - quantity;
      final newToQty = toQty + quantity;
      final newToAvg = newToQty == 0
          ? 0.0
          : ((toQty * toAvg) + (quantity * avgCost)) / newToQty;

      tx.update(fromRef, {
        'quantity': newFromQty,
        'totalValue': newFromQty * avgCost,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.set(toRef, {
        'productId': productId,
        'productName': productName,
        'sku': sku,
        'baseUnit': baseUnit,
        'warehouseId': toWarehouseId,
        'warehouseName': toWarehouseName,
        'quantity': newToQty,
        'avgCost': newToAvg,
        'totalValue': newToQty * newToAvg,
        'reorderLevel': reorder,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final outRef = _db.collection('inventoryMovements').doc();
      final inRef = _db.collection('inventoryMovements').doc();
      tx.set(outRef, {
        'productId': productId,
        'productName': productName,
        'sku': sku,
        'warehouseId': fromWarehouseId,
        'warehouseName': fromWarehouseName,
        'type': MovementType.transferOut.name,
        'quantity': -quantity,
        'unitCost': avgCost,
        'totalValue': quantity * avgCost,
        'reason': '',
        'reference': toWarehouseName,
        'createdBy': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.set(inRef, {
        'productId': productId,
        'productName': productName,
        'sku': sku,
        'warehouseId': toWarehouseId,
        'warehouseName': toWarehouseName,
        'type': MovementType.transferIn.name,
        'quantity': quantity,
        'unitCost': avgCost,
        'totalValue': quantity * avgCost,
        'reason': '',
        'reference': fromWarehouseName,
        'createdBy': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

     /// Issue — decrease stock. Used by sales invoices.
  ///
  /// Uses Firestore transaction to prevent negative stock.
  /// Records an `issue` movement for audit.
  Future<void> issueStock({
    required String productId,
    required String productName,
    required String sku,
    required String baseUnit,
    required String warehouseId,
    required String warehouseName,
    required num quantity,
    required num reorderLevel,
    required String userId,
    String? reference,
  }) async {
    if (quantity <= 0) {
      throw Exception('Quantity must be greater than zero');
    }

    final balRef =
        _db.collection('stockBalances').doc(_balanceId(productId, warehouseId));

    await _db.runTransaction((tx) async {
      final balSnap = await tx.get(balRef);
      if (!balSnap.exists) {
        throw Exception('No stock found in $warehouseName');
      }
      final d = balSnap.data() as Map<String, dynamic>;
      final oldQty = (d['quantity'] ?? 0) as num;
      final avgCost = (d['avgCost'] ?? 0) as num;
      if (oldQty < quantity) {
        throw Exception(
            'Insufficient stock. Available: $oldQty $baseUnit');
      }
      final newQty = oldQty - quantity;

      tx.update(balRef, {
        'quantity': newQty,
        'totalValue': newQty * avgCost,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final movRef = _db.collection('inventoryMovements').doc();
      tx.set(movRef, {
        'productId': productId,
        'productName': productName,
        'sku': sku,
        'warehouseId': warehouseId,
        'warehouseName': warehouseName,
        'type': MovementType.issue.name,
        'quantity': -quantity,
        'unitCost': avgCost,
        'totalValue': quantity * avgCost,
        'reason': '',
        'reference': reference,
        'createdBy': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Get current stock balance for a product + warehouse.
  Future<StockBalance?> getBalance(
      String productId, String warehouseId) async {
    final doc = await _db
        .collection('stockBalances')
        .doc(_balanceId(productId, warehouseId))
        .get();
    if (!doc.exists) return null;
    return StockBalance.fromDoc(doc);
  }
}