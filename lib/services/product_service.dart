import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final String sku;
  final String categoryId;
  final String? categoryName;
  final String grade;
  final String description;
  final String specifications;
  final num purchasePrice;
  final num sellingPrice;
  final String baseUnit;        // kg, L, ton, drum, bag, bottle
  final String purchaseCurrency; // PKR, USD
  final num reorderLevel;
  final String storageRequirements;
  final String hazardInfo;
  final String sdsUrl;          // Safety Data Sheet (Cloudinary)
  final String packagingType;
  final String packageSize;
  final num? density;           // kg/L — agar mass-volume conversion chahiye
  final bool batchTracking;
  final bool active;
  final DateTime? createdAt;

  Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.categoryId,
    this.categoryName,
    required this.grade,
    required this.description,
    required this.specifications,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.baseUnit,
    required this.purchaseCurrency,
    required this.reorderLevel,
    required this.storageRequirements,
    required this.hazardInfo,
    required this.sdsUrl,
    required this.packagingType,
    required this.packageSize,
    this.density,
    required this.batchTracking,
    required this.active,
    this.createdAt,
  });

  factory Product.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: d['name'] ?? '',
      sku: d['sku'] ?? '',
      categoryId: d['categoryId'] ?? '',
      categoryName: d['categoryName'],
      grade: d['grade'] ?? '',
      description: d['description'] ?? '',
      specifications: d['specifications'] ?? '',
      purchasePrice: (d['purchasePrice'] ?? 0) as num,
      sellingPrice: (d['sellingPrice'] ?? 0) as num,
      baseUnit: d['baseUnit'] ?? 'kg',
      purchaseCurrency: d['purchaseCurrency'] ?? 'PKR',
      reorderLevel: (d['reorderLevel'] ?? 0) as num,
      storageRequirements: d['storageRequirements'] ?? '',
      hazardInfo: d['hazardInfo'] ?? '',
      sdsUrl: d['sdsUrl'] ?? '',
      packagingType: d['packagingType'] ?? '',
      packageSize: d['packageSize'] ?? '',
      density: d['density'] as num?,
      batchTracking: d['batchTracking'] ?? false,
      active: d['active'] ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'sku': sku,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'grade': grade,
        'description': description,
        'specifications': specifications,
        'purchasePrice': purchasePrice,
        'sellingPrice': sellingPrice,
        'baseUnit': baseUnit,
        'purchaseCurrency': purchaseCurrency,
        'reorderLevel': reorderLevel,
        'storageRequirements': storageRequirements,
        'hazardInfo': hazardInfo,
        'sdsUrl': sdsUrl,
        'packagingType': packagingType,
        'packageSize': packageSize,
        'density': density,
        'batchTracking': batchTracking,
        'active': active,
      };
}

class ProductService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Product>> watch({String? search}) {
    Query q = _db.collection('products').orderBy('name');
    return q.snapshots().map((s) {
      var list = s.docs.map(Product.fromDoc).toList();
      if (search != null && search.trim().isNotEmpty) {
        final q2 = search.toLowerCase();
        list = list
            .where((p) =>
                p.name.toLowerCase().contains(q2) ||
                p.sku.toLowerCase().contains(q2))
            .toList();
      }
      return list;
    });
  }

  Future<String> create(Product p) async {
    final existing = await _db
        .collection('products')
        .where('sku', isEqualTo: p.sku)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw Exception('Yeh SKU pehle se mojood hai: ${p.sku}');
    }
    final ref = await _db.collection('products').add({
      ...p.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> update(String id, Product p) async {
    final existing = await _db
        .collection('products')
        .where('sku', isEqualTo: p.sku)
        .get();
    final conflict = existing.docs.any((d) => d.id != id);
    if (conflict) {
      throw Exception('Yeh SKU kisi aur product ke paas hai');
    }
    await _db.collection('products').doc(id).update({
      ...p.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String id) async {
    await _db.collection('products').doc(id).delete();
  }

  // ✅ Yeh naya method add karein
  Future<Product?> getById(String id) async {
    final doc = await _db.collection('products').doc(id).get();
    if (!doc.exists) return null;
    return Product.fromDoc(doc);
  }
}

const baseUnits = ['kg', 'g', 'ton', 'L', 'mL', 'drum', 'bag', 'bottle', 'piece'];

const packagingTypes = [
  'Drum',
  'Bag',
  'Bottle',
  'Jerry Can',
  'IBC Tank',
  'Container',
  'Box',
  'Other',
];