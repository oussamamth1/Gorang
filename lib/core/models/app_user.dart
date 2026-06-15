import 'package:cloud_firestore/cloud_firestore.dart';

enum KycStatus { none, pending, verified, rejected }

/// A RentGo user. Every user can both rent vehicles and list their own.
class AppUser {
  final String uid;
  final String fullName;
  final String email;
  final String phone;
  final bool showPhone;
  final String idCardNumber;
  final String? idCardImageUrl;
  final String? licenseImageUrl;
  final KycStatus kycStatus;
  final DateTime? createdAt;
  final String? photoUrl;

  const AppUser({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phone,
    this.showPhone = false,
    this.idCardNumber = '',
    this.idCardImageUrl,
    this.licenseImageUrl,
    this.kycStatus = KycStatus.none,
    this.createdAt,
    this.photoUrl,
  });

  /// True once the user has submitted their identity documents.
  bool get hasSubmittedKyc =>
      idCardNumber.isNotEmpty && idCardImageUrl != null && licenseImageUrl != null;

  bool get isVerified => kycStatus == KycStatus.verified;

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppUser(
      uid: doc.id,
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      showPhone: data['showPhone'] ?? false,
      idCardNumber: data['idCardNumber'] ?? '',
      idCardImageUrl: data['idCardImageUrl'],
      licenseImageUrl: data['licenseImageUrl'],
      kycStatus: KycStatus.values.asNameMap()[data['kycStatus']] ?? KycStatus.none,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      photoUrl: data['photoUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'showPhone': showPhone,
        'idCardNumber': idCardNumber,
        'idCardImageUrl': idCardImageUrl,
        'licenseImageUrl': licenseImageUrl,
        'kycStatus': kycStatus.name,
        'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
        if (photoUrl != null) 'photoUrl': photoUrl,
      };
}
