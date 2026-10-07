import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rahbar_app/utils/App_colors.dart';
import 'package:rahbar_app/utils/Phone_utils.dart';
import 'package:rahbar_app/utils/user_lookup.dart';
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
/// so toggling / editing / deleting know exactly which doc to write to.
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
  // subcollection TrustedContactScreen writes to (both during
  // onboarding AND from this screen's "Add a trusted contact" button
  // -- it saves directly now rather than handing data back).
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
      _showErrorSnack('Could not update contact');
    }
  }

  // TrustedContactScreen SAVES THE CONTACT ITSELF now (for both
  // onboarding and this standalone flow) and just pops back with
  // `true` as a plain signal that a save happened -- it no longer
  // hands back the raw contact data for this screen to write. So the
  // fix here is simple: just refetch from Firestore instead of trying
  // to parse a List that doesn't come back anymore.
  Future<void> _onAddContactPressed() async {
    final result = await Get.toNamed(
      '/trusted-contact',
      arguments: {'fromContacts': true},
    );

    if (result == true) {
      await _loadContacts();
    }
  }

  // ---- Edit ----------------------------------------------------------

  Future<void> _editContact(int index) async {
    final ref = _contactsRef;
    if (ref == null) return;
    final contact = _contacts[index];

    final nameController = TextEditingController(text: contact.name);
    final phoneController = TextEditingController(text: contact.phone);
    bool isSaving = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final normalized = normalizePhoneNumber(phoneController.text);
            final isPhoneValid = isPlausiblePhoneNumber(normalized);
            final isNameValid = nameController.text.trim().isNotEmpty;

            return AlertDialog(
              backgroundColor: AppColors.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Edit contact',
                style: TextStyle(
                  color: AppColors.title,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Contact name',
                    style: TextStyle(fontSize: 13, color: AppColors.fieldLabel),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      hintText: 'e.g. Mom, Sara',
                      hintStyle: const TextStyle(color: AppColors.fieldHint),
                      filled: true,
                      fillColor: AppColors.fieldFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.fieldBorder,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Phone number',
                    style: TextStyle(fontSize: 13, color: AppColors.fieldLabel),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      hintText: 'e.g. 0300 1234567',
                      hintStyle: const TextStyle(color: AppColors.fieldHint),
                      filled: true,
                      fillColor: AppColors.fieldFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.fieldBorder,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      suffixIcon: isPhoneValid
                          ? const Icon(
                              Icons.check,
                              color: AppColors.success,
                              size: 20,
                            )
                          : null,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Get.back(result: false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.subtitle),
                  ),
                ),
                TextButton(
                  onPressed: (isSaving || !isNameValid || !isPhoneValid)
                      ? null
                      : () async {
                          setDialogState(() => isSaving = true);

                          final newName = nameController.text.trim();
                          final newPhone = normalizePhoneNumber(
                            phoneController.text,
                          );
                          final phoneChanged = newPhone != contact.phone;

                          try {
                            // If the phone number changed, re-check
                            // whether it belongs to a real Rahbar
                            // account -- linkedUserId must stay in
                            // sync with whatever phone is actually
                            // saved, or SOS alerts could silently try
                            // to notify the WRONG account, or fail to
                            // notify the right one.
                            String? linkedUserId;
                            if (phoneChanged) {
                              final lookup = await findUserByPhone(newPhone);
                              linkedUserId = lookup.found
                                  ? lookup.userId
                                  : null;
                            }

                            await ref.doc(contact.id).update({
                              'name': newName,
                              'phone': newPhone,
                              if (phoneChanged) 'linkedUserId': linkedUserId,
                            });

                            if (context.mounted) Get.back(result: true);
                          } catch (_) {
                            setDialogState(() => isSaving = false);
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Save',
                          style: TextStyle(
                            color: AppColors.primaryPurple,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true) {
      await _loadContacts();
    }
  }

  // ---- Delete ----------------------------------------------------------

  Future<void> _deleteContact(int index) async {
    final ref = _contactsRef;
    if (ref == null) return;
    final contact = _contacts[index];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Remove contact?',
          style: TextStyle(color: AppColors.title, fontWeight: FontWeight.w700),
        ),
        content: Text(
          '${contact.name} will no longer be alerted if you send an SOS.',
          style: const TextStyle(color: AppColors.subtitle),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.subtitle),
            ),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text(
              'Remove',
              style: TextStyle(
                color: Color(0xFF9B2C3A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Optimistic removal, reverted on failure.
    final removed = contact;
    final removedIndex = index;
    setState(() => _contacts.removeAt(index));

    try {
      await ref.doc(contact.id).delete();
    } catch (_) {
      if (!mounted) return;
      setState(() => _contacts.insert(removedIndex, removed));
      _showErrorSnack('Could not remove contact');
    }
  }

  void _showErrorSnack(String title) {
    Get.snackbar(
      title,
      'Please try again.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF9B2C3A),
      colorText: Colors.white,
    );
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
                        'Tap to choose who gets notified · Hold for more',
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
                onEdit: () => _editContact(i),
                onDelete: () => _deleteContact(i),
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
/// Long-press (or tap the overflow icon) opens Edit / Delete.
class _ContactTile extends StatelessWidget {
  final _Contact contact;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ContactTile({
    required this.contact,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  void _showActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.fieldBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(
                Icons.edit_outlined,
                color: AppColors.primaryPurple,
              ),
              title: const Text(
                'Edit contact',
                style: TextStyle(color: AppColors.title),
              ),
              onTap: () {
                Get.back();
                onEdit();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Color(0xFF9B2C3A),
              ),
              title: const Text(
                'Remove contact',
                style: TextStyle(color: Color(0xFF9B2C3A)),
              ),
              onTap: () {
                Get.back();
                onDelete();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onLongPress: () => _showActions(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
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

            const SizedBox(width: 4),

            // ---- Overflow menu (same actions as long-press) ----
            IconButton(
              onPressed: () => _showActions(context),
              icon: const Icon(
                Icons.more_vert,
                color: AppColors.subtitle,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
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
