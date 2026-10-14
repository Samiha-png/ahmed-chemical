import 'package:cloud_firestore/cloud_firestore.dart';

class CompanySettings {
  final String companyName;
  final String baseCurrency;
  final String timeZone;
  final String financialYearStart;
  final String logoUrl;
  final String signatureUrl;
  final String address;
  final String phone;
  final String email;
  final String taxNumber;

  CompanySettings({
    required this.companyName,
    required this.baseCurrency,
    required this.timeZone,
    required this.financialYearStart,
    required this.logoUrl,
    required this.signatureUrl,
    required this.address,
    required this.phone,
    required this.email,
    required this.taxNumber,
  });

  factory CompanySettings.defaults() => CompanySettings(
        companyName: 'Ahmed Chemical Co.',
        baseCurrency: 'PKR',
        timeZone: 'Asia/Karachi',
        financialYearStart: '07-01',
        logoUrl: '',
        signatureUrl: '',
        address: '',
        phone: '',
        email: '',
        taxNumber: '',
      );

  factory CompanySettings.fromDoc(DocumentSnapshot doc) {
    if (!doc.exists) return CompanySettings.defaults();
    final d = doc.data() as Map<String, dynamic>;
    return CompanySettings(
      companyName: d['companyName'] ?? 'Ahmed Chemical Co.',
      baseCurrency: d['baseCurrency'] ?? 'PKR',
      timeZone: d['timeZone'] ?? 'Asia/Karachi',
      financialYearStart: d['financialYearStart'] ?? '07-01',
      logoUrl: d['logoUrl'] ?? '',
      signatureUrl: d['signatureUrl'] ?? '',
      address: d['address'] ?? '',
      phone: d['phone'] ?? '',
      email: d['email'] ?? '',
      taxNumber: d['taxNumber'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'companyName': companyName,
        'baseCurrency': baseCurrency,
        'timeZone': timeZone,
        'financialYearStart': financialYearStart,
        'logoUrl': logoUrl,
        'signatureUrl': signatureUrl,
        'address': address,
        'phone': phone,
        'email': email,
        'taxNumber': taxNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

class SettingsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<CompanySettings> watch() {
    return _db
        .collection('settings')
        .doc('company')
        .snapshots()
        .map(CompanySettings.fromDoc);
  }

  Future<void> save(CompanySettings settings) async {
    await _db
        .collection('settings')
        .doc('company')
        .set(settings.toMap(), SetOptions(merge: true));
  }
}