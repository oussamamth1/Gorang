import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/models/app_notification.dart';

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('notifications');

  Future<void> send({
    required String userId,
    required String title,
    required String body,
    NotificationType type = NotificationType.booking,
    String? refId,
  }) =>
      _col.add({
        'userId': userId,
        'title': title,
        'body': body,
        'type': type.name,
        'refId': refId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Stream<List<AppNotification>> watch(String userId) => _col
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snap) => snap.docs.map(AppNotification.fromDoc).toList());

  Future<void> markAllRead(String userId) async {
    final unread = await _col
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();
    if (unread.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}
