import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rahbar_app/utils/App_colors.dart';
import 'package:rahbar_app/utils/Phone_utils.dart';
import 'package:rahbar_app/widget/bottom_navigation.dart';

/// Small rotating palette so contacts get a reasonable-looking avatar
/// color without the user picking one, keyed off their position in
/// the list (stable regardless of load order).
const List<Color> _avatarPalette = [
  AppColors.primaryPurple,
  Color(0xFF5C2F4B),
  Color(0xFFA79FA9),
  Color(0xFF7A4E6B),
];

Color _avatarColorFor(int index) =>
    _avatarPalette[index % _avatarPalette.length];

/// A single trusted contact shown in the list. `id` is the Firestore
/// document id under the current user's `trustedContacts` subcollection,
/// so toggling / future edits know exactly which doc to write to.
class _Contact {
  final String id;
  final String name;
  final String phone; // always stored normalized (E.164)
  final Color avatarColor;
  bool isNotified;

  _Contact({
    required this.id,
    required this.name,
    required String phone,
    required this.avatarColor,
    this.isNotified = true,
  }) : phone = normalizePhoneNumber(phone);

  // Initials shown inside the avatar circle, e.g. "Mom" -> "M",
  // "Sara F." -> "SF".
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<_Contact> _contacts = [];
  bool _isLoading = true;
  String? _errorMessage;

  CollectionReference<Map<String, dynamic>>? get _contactsRef {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('trustedContacts');
  }

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  // Loads the real trusted-contact list from Firestore -- the same
  // subcollection TrustedContactScreen writes to during onboarding
  // (users/{uid}/trustedContacts), ordered by when each was added.
  Future<void> _loadContacts() async {
    final ref = _contactsRef;
    if (ref == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'You need to be signed in to see your contacts.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await ref.orderBy('createdAt').get();
      if (!mounted) return;
      setState(() {
        _contacts = snapshot.docs.asMap().entries.map((entry) {
          final index = entry.key;
          final doc = entry.value;
          final data = doc.data();
          return _Contact(
            id: doc.id,
            name: (data['name'] ?? '').toString(),
            phone: (data['phone'] ?? '').toString(),
            avatarColor: _avatarColorFor(index),
            // Onboarding-added contacts may predate this field --
            // default them to notified so nobody silently drops out.
            isNotified: data['isNotified'] as bool? ?? true,
          );
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load your contacts. Pull to try again.';
      });
    }
  }

  // Optimistically flips the toggle locally, then persists it. Reverts
  // and shows an error if the write fails.
  Future<void> _toggleNotified(int index) async {
    final ref = _contactsRef;
    final contact = _contacts[index];
    final newValue = !contact.isNotified;

    setState(() => contact.isNotified = newValue);

    if (ref == null) return;
    try {
      await ref.doc(contact.id).update({'isNotified': newValue});
    } catch (e) {
      if (!mounted) return;
      setState(() => contact.isNotified = !newValue);
      Get.snackbar(
        'Could not update contact',
        'Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF9B2C3A),
        colorText: Colors.white,
      );
    }
  }

  Future<void> _onAddContactPressed() async {
    // Tells TrustedContactScreen it's in standalone mode (not onboarding),
    // so it shows "Save" and pops back here instead of going to Permissions.
    final result = await Get.toNamed(
      '/trusted-contact',
      arguments: {'fromContacts': true},
    );

    if (result is! List || result.isEmpty) return;

    final ref = _contactsRef;
    if (ref == null) {
      Get.snackbar(
        'Could not save contact',
        'You need to be signed in.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF9B2C3A),
        colorText: Colors.white,
      );
      return;
    }

    final batch = FirebaseFirestore.instance.batch();
    final newContacts = <_Contact>[];

    for (final item in result) {
      if (item is! Map) continue;
      final name = (item['name'] ?? '').toString();
      final phone = (item['phone'] ?? '').toString();
      if (name.isEmpty) continue;

      // TrustedContactScreen already normalizes the phone before
      // handing it back here, but the _Contact constructor also
      // normalizes -- safe either way, since normalizing an
      // already-normalized number is a no-op.
      final docRef = ref.doc();
      batch.set(docRef, {
        'name': name,
        'phone': normalizePhoneNumber(phone),
        'isNotified': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      newContacts.add(
        _Contact(
          id: docRef.id,
          name: name,
          phone: phone,
          avatarColor: _avatarColorFor(_contacts.length + newContacts.length),
          isNotified: true,
        ),
      );
    }

    if (newContacts.isEmpty) return;

    try {
      await batch.commit();
      if (!mounted) return;
      setState(() => _contacts.addAll(newContacts));
    } catch (e) {
      if (!mounted) return;
      Get.snackbar(
        'Could not save contact',
        'Something went wrong. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF9B2C3A),
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // ---- Heading ----
              const Text(
                'My contacts',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.title,
                ),
              ),

              const SizedBox(height: 16),

              // ---- Info banner ----
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.ringColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.podcasts_rounded,
                      size: 18,
                      color: AppColors.primaryPurple,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tap to choose who gets notified',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: AppColors.title.withOpacity(0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ---- Contact list ----
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentTab: NavTab.contacts),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryPurple),
      );
    }

    if (_errorMessage != null) {
      return RefreshIndicator(
        onRefresh: _loadContacts,
        color: AppColors.primaryPurple,
        child: ListView(
          children: [
            const SizedBox(height: 40),
            Center(
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.subtitle),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadContacts,
      color: AppColors.primaryPurple,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            if (_contacts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  "You haven't added any trusted contacts yet.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.subtitle),
                ),
              ),

            for (int i = 0; i < _contacts.length; i++)
              _ContactTile(
                contact: _contacts[i],
                onToggle: () => _toggleNotified(i),
              ),

            const SizedBox(height: 8),

            // ---- Add a trusted contact (dashed outline) ----
            _DashedAddContactButton(onTap: _onAddContactPressed),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// One contact row: avatar with initials, name + phone, and a
/// checkbox-style toggle for whether they get notified during SOS.
class _ContactTile extends StatelessWidget {
  final _Contact contact;
  final VoidCallback onToggle;

  const _ContactTile({required this.contact, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Row(
        children: [
          // ---- Avatar ----
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: contact.avatarColor,
            ),
            alignment: Alignment.center,
            child: Text(
              contact.initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // ---- Name + phone ----
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.title,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  // Stored as normalized E.164 ("+923001234567"); shown
                  // as-is here. Swap in a display-formatting helper if
                  // you want spaced-out formatting in the UI later.
                  contact.phone,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.subtitle,
                  ),
                ),
              ],
            ),
          ),

          // ---- Notify toggle (checkbox-style) ----
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: contact.isNotified ? AppColors.success : Colors.white,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: contact.isNotified
                      ? AppColors.success
                      : AppColors.fieldBorder,
                  width: 1.4,
                ),
              ),
              alignment: Alignment.center,
              child: contact.isNotified
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dashed-outline "+ Add a trusted contact" button, matching the design.
class _DashedAddContactButton extends StatelessWidget {
  final VoidCallback onTap;
  const _DashedAddContactButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: AppColors.primaryPurple,
          radius: 14,
        ),
        child: Container(
          width: double.infinity,
          height: 54,
          alignment: Alignment.center,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 18, color: AppColors.primaryPurple),
              SizedBox(width: 6),
              Text(
                'Add a trusted contact',
                style: TextStyle(
                  color: AppColors.primaryPurple,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paints a dashed rounded-rectangle border.
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashedBorderPainter({required this.color, this.radius = 12});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    const dashWidth = 6.0;
    const dashGap = 4.0;

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
