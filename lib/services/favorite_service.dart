import 'package:cloud_firestore/cloud_firestore.dart';

/// Favorites are stored in a top-level `favorites` collection with a
/// deterministic doc id (`userId_vehicleId`) so toggling is a simple
/// set/delete and "who favorited this vehicle" stays queryable.
class FavoriteService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('favorites');

  String _docId(String userId, String vehicleId) => '${userId}_$vehicleId';

  Future<void> setFavorite(String userId, String vehicleId, bool favorite) {
    final doc = _col.doc(_docId(userId, vehicleId));
    if (!favorite) return doc.delete();
    return doc.set({
      'userId': userId,
      'vehicleId': vehicleId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Vehicle ids the user has favorited, live.
  Stream<Set<String>> watchIds(String userId) => _col
      .where('userId', isEqualTo: userId)
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => d.data()['vehicleId'] as String).toSet());

  /// Users who favorited a vehicle — used to notify them about changes.
  Future<List<String>> favoritersOf(String vehicleId) async {
    final snap = await _col.where('vehicleId', isEqualTo: vehicleId).get();
    return snap.docs.map((d) => d.data()['userId'] as String).toList();
  }

  /// Removes all favorite entries pointing at a deleted vehicle.
  Future<void> removeAllFor(String vehicleId) async {
    final snap = await _col.where('vehicleId', isEqualTo: vehicleId).get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
