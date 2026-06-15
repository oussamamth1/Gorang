import 'package:firebase_messaging/firebase_messaging.dart';

import 'user_service.dart';

class FcmService {
  FcmService(this._users);

  final UserService _users;
  final _fcm = FirebaseMessaging.instance;

  Future<void> init(String uid) async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    final token = await _fcm.getToken();
    if (token != null) await _users.saveFcmToken(uid, token);

    _fcm.onTokenRefresh.listen((newToken) => _users.saveFcmToken(uid, newToken));
  }
}
