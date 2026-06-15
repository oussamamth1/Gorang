import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../services/booking_service.dart';
import '../services/favorite_service.dart';
import '../services/fcm_service.dart';
import '../services/id_verification_service.dart';
import '../services/image_service.dart';
import '../services/notification_service.dart';
import '../services/payment_service.dart';
import '../services/user_service.dart';
import '../services/vehicle_service.dart';

final imageServiceProvider = Provider<ImageService>((ref) => ImageService());

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());

final favoriteServiceProvider = Provider<FavoriteService>((ref) => FavoriteService());

final idVerificationServiceProvider =
    Provider<IdVerificationService>((ref) => IdVerificationService());

final userServiceProvider =
    Provider<UserService>((ref) => UserService(ref.read(imageServiceProvider)));

final vehicleServiceProvider = Provider<VehicleService>((ref) => VehicleService(
      ref.read(imageServiceProvider),
      ref.read(favoriteServiceProvider),
      ref.read(notificationServiceProvider),
    ));

final bookingServiceProvider = Provider<BookingService>(
    (ref) => BookingService(ref.read(notificationServiceProvider)));

final paymentServiceProvider = Provider<PaymentService>((ref) => PaymentService());

final fcmServiceProvider = Provider<FcmService>(
  (ref) => FcmService(ref.read(userServiceProvider)),
);
