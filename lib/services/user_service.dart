import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../core/models/app_user.dart';
import 'image_service.dart';

class UserService {
  UserService(this._images);

  final ImageService _images;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

  Stream<AppUser?> watchUser(String uid) =>
      _users.doc(uid).snapshots().map((doc) => doc.exists ? AppUser.fromDoc(doc) : null);

  Future<void> setShowPhone(String uid, {required bool show}) =>
      _users.doc(uid).update({'showPhone': show});

  Future<void> saveFcmToken(String uid, String token) =>
      _users.doc(uid).set({'fcmToken': token}, SetOptions(merge: true));

  Future<void> updateProfile({
    required String uid,
    required String fullName,
    required String phone,
    XFile? photo,
  }) async {
    final updates = <String, dynamic>{
      'fullName': fullName,
      'phone': phone,
    };
    if (photo != null) {
      updates['photoUrl'] = await _images.encodeImage(photo);
    }
    await _users.doc(uid).update(updates);
  }

  /// Saves identity documents. When [autoVerified] is true (the on-device
  /// AI check matched the CIN on the ID photo) the account is verified
  /// immediately; otherwise it waits for manual review.
  Future<void> submitKyc({
    required String uid,
    required String idCardNumber,
    required XFile idCardImage,
    required XFile licenseImage,
    bool autoVerified = false,
  }) async {
    final idCardUrl = await _images.encodeImage(idCardImage);
    final licenseUrl = await _images.encodeImage(licenseImage);
    await _users.doc(uid).update({
      'idCardNumber': idCardNumber,
      'idCardImageUrl': idCardUrl,
      'licenseImageUrl': licenseUrl,
      'kycStatus': (autoVerified ? KycStatus.verified : KycStatus.pending).name,
    });
  }
}
