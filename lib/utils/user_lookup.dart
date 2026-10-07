import 'package:cloud_firestore/cloud_firestore.dart';

/// Result of looking up whether a phone number belongs to a
/// registered Rahbar user.
class UserLookupResult {
  final bool found;
  final String? userId;
  final String? displayName;

  UserLookupResult({required this.found, this.userId, this.displayName});
}

/// Looks up whether the given (already-normalized, E.164) phone
/// number belongs to a real, registered Rahbar account, by reading
/// the public `phoneIndex/{phone}` document directly.
///
/// This collection ONLY contains { userId, displayName } — never
/// email, fcmToken, or other private data — and is kept in sync
/// automatically by the `syncPhoneIndex` Cloud Function whenever a
/// user's phone number is set/changed (see functions/index.js).
///
/// Used by TrustedContactScreen when saving a contact, so it can
/// store `linkedUserId` — which is what AlertController later reads
/// to know which real accounts to push-notify during an SOS.
Future<UserLookupResult> findUserByPhone(String normalizedPhone) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('phoneIndex')
        .doc(normalizedPhone)
        .get();

    if (!doc.exists) {
      return UserLookupResult(found: false);
    }

    final data = doc.data()!;
    return UserLookupResult(
      found: true,
      userId: data['userId'] as String?,
      displayName: data['displayName'] as String?,
    );
  } catch (_) {
    // Network error, permissions issue, etc. — treat as "not found"
    // so the UI can still let the user save the contact locally,
    // just without a linked account yet.
    return UserLookupResult(found: false);
  }
}
