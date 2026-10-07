import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sends the signed-in user's FCM device token to the `rahbar` Supabase
/// Edge Function, which verifies the Firebase login and stores the token
/// server-side. The app never writes device tokens to any database
/// itself.

StreamSubscription<String>? _refreshSub;

Future<void> _callRahbar(Map<String, dynamic> body) async {
  final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
  if (idToken == null) return;
  await Supabase.instance.client.functions.invoke(
    'rahbar',
    headers: {'x-firebase-token': idToken},
    body: body,
  );
}

Future<void> _register(String token) => _callRahbar({
  'action': 'register-token',
  'token': token,
  'platform': Platform.isIOS ? 'ios' : 'android',
});

/// Call once right after a successful login or signup.
Future<void> syncFcmToken() async {
  if (FirebaseAuth.instance.currentUser == null) return;

  try {
    await FirebaseMessaging.instance.requestPermission();
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _register(token);
  } catch (_) {
    // Token not available yet (common on iOS right after install).
    // onTokenRefresh below will deliver it when it is.
  }

  // Tokens change on reinstall or data clear; keep the server current.
  await _refreshSub?.cancel();
  _refreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
    (newToken) => _register(newToken).catchError((_) {}),
  );
}

/// Call on logout, BEFORE FirebaseAuth.instance.signOut() (it needs the
/// still-valid login to prove who is asking). Stops this phone from
/// receiving the previous user's alerts.
Future<void> unregisterFcmToken() async {
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await _callRahbar({'action': 'unregister-token', 'token': token});
    }
  } catch (_) {}
  await _refreshSub?.cancel();
  _refreshSub = null;
}
