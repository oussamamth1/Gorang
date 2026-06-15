import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../core/models/app_notification.dart';
import '../core/models/vehicle.dart';
import 'favorite_service.dart';
import 'image_service.dart';
import 'notification_service.dart';

class VehicleService {
  VehicleService(this._images, this._favorites, this._notifications);

  final ImageService _images;
  final FavoriteService _favorites;
  final NotificationService _notifications;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _vehicles => _db.collection('vehicles');

  Stream<List<Vehicle>> watchActiveVehicles({VehicleType? type}) {
    Query<Map<String, dynamic>> query = _vehicles.where('isActive', isEqualTo: true);
    if (type != null) query = query.where('type', isEqualTo: type.name);
    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Vehicle.fromDoc).toList());
  }

  Stream<List<Vehicle>> watchMyVehicles(String ownerId) => _vehicles
      .where('ownerId', isEqualTo: ownerId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(Vehicle.fromDoc).toList());

  Stream<Vehicle?> watchVehicle(String id) =>
      _vehicles.doc(id).snapshots().map((doc) => doc.exists ? Vehicle.fromDoc(doc) : null);

  Future<List<String>> _encodePhotos(List<XFile> photos) async {
    final urls = <String>[];
    // Max 3 photos so the encoded images stay under Firestore's 1 MiB
    // document limit.
    for (final photo in photos.take(3)) {
      urls.add(await _images.encodeImage(photo));
    }
    return urls;
  }

  Future<void> addVehicle(Vehicle vehicle, List<XFile> photos) async {
    final urls = await _encodePhotos(photos);
    await _vehicles.add({...vehicle.toMap(), 'photoUrls': urls});
  }

  /// Updates a listing. When [newPhotos] is empty the existing photos are
  /// kept. Everyone who favorited the vehicle gets notified.
  Future<void> updateVehicle(Vehicle vehicle, {List<XFile> newPhotos = const []}) async {
    final data = vehicle.toMap()..remove('createdAt');
    if (newPhotos.isNotEmpty) {
      data['photoUrls'] = await _encodePhotos(newPhotos);
    } else {
      data.remove('photoUrls');
    }
    await _vehicles.doc(vehicle.id).update(data);
    await _notifyFavoriters(
      vehicle,
      title: 'Listing updated',
      body: '${vehicle.title} was updated by its owner — check the new details.',
    );
  }

  /// Deletes a listing and cleans up favorites pointing at it. Existing
  /// bookings are unaffected: they carry their own snapshot of the pricing.
  Future<void> deleteVehicle(Vehicle vehicle) async {
    await _notifyFavoriters(
      vehicle,
      title: 'Listing removed',
      body: '${vehicle.title} is no longer available on RentGo.',
    );
    await _vehicles.doc(vehicle.id).delete();
    await _favorites.removeAllFor(vehicle.id);
  }

  Future<void> setActive(String id, bool isActive) =>
      _vehicles.doc(id).update({'isActive': isActive});

  Future<void> _notifyFavoriters(Vehicle vehicle,
      {required String title, required String body}) async {
    final users = await _favorites.favoritersOf(vehicle.id);
    for (final userId in users) {
      if (userId == vehicle.ownerId) continue;
      await _notifications.send(
        userId: userId,
        title: title,
        body: body,
        type: NotificationType.vehicle,
        refId: vehicle.id,
      );
    }
  }
}
