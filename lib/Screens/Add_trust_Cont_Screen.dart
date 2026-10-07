import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rahbar_app/utils/App_colors.dart';
import 'package:rahbar_app/utils/Phone_utils.dart';
import 'package:rahbar_app/utils/user_lookup.dart';

/// Holds the two text controllers for a single contact entry,
/// so the user can add more than one trusted contact.
class _ContactEntry {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController(
    text: '+92 ',
  );

  void dispose() {
    nameController.dispose();
    phoneController.dispose();
  }
}

/// "Add a trusted contact" screen, used in two places:
///
/// 1. Onboarding (Step 2 of 3), reached from Signup — "Continue" saves
///    the contact(s) to Firestore, then moves the user on to the
///    Permissions screen.
///
/// 2. From the "My contacts" screen's "+ Add a trusted contact" button,
///    reached any time after onboarding — the button also reads "Save"
///    and ALSO persists directly to Firestore now (previously this
///    just popped the raw data back to ContactsScreen and left saving
///    to that screen — now both paths save for real, here, so the
///    phone-lookup logic below only has to live in one place).
///
/// Which mode it's in is decided by the `fromContacts` navigation
/// argument:
///   Get.toNamed('/trusted-contact', arguments: {'fromContacts': true})
/// for the standalone flow; omit it (or pass false) for onboarding.
class TrustedContactScreen extends StatefulWidget {
  const TrustedContactScreen({super.key});

  @override
  State<TrustedContactScreen> createState() => _TrustedContactScreenState();
}

class _TrustedContactScreenState extends State<TrustedContactScreen> {
  final List<_ContactEntry> _contacts = [_ContactEntry()];

  // True when reached from the Contacts screen instead of onboarding.
  bool _fromContacts = false;

  // True while the save-to-Firestore call is in flight.
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is Map && args['fromContacts'] == true) {
      _fromContacts = true;
    }
  }

  void _addAnotherContact() {
    setState(() => _contacts.add(_ContactEntry()));
  }

  void _removeContact(int index) {
    setState(() {
      _contacts[index].dispose();
      _contacts.removeAt(index);
    });
  }

  bool get _hasAtLeastOneContact =>
      _contacts.any((c) => c.nameController.text.trim().isNotEmpty);

  // Builds the plain data list to hand back / carry forward: one map per
  // contact with a non-empty name. The phone number is ALWAYS normalized
  // to E.164 here (e.g. "0300 1234567" -> "+923001234567") — this is the
  // exact same normalizePhoneNumber() used at signup, so a trusted
  // contact's phone here will match that person's own account, no
  // matter which format either of them typed it in.
  List<Map<String, String>> get _filledContacts => _contacts
      .where((c) => c.nameController.text.trim().isNotEmpty)
      .map(
        (c) => {
          'name': c.nameController.text.trim(),
          'phone': normalizePhoneNumber(c.phoneController.text),
        },
      )
      .toList();

  // Writes each filled contact as a doc in the current user's
  // `trustedContacts` subcollection. For each one, looks up whether
  // the phone number belongs to a real registered Rahbar account (via
  // phoneIndex) and stores that as `linkedUserId` -- THIS is what
  // AlertController.startAlert() reads later to know which real users
  // to actually push-notify when SOS is sent. A contact with no
  // linkedUserId is saved (so it still shows in the list) but can
  // never receive a push, since there's no account to send it to.
  Future<void> _saveTrustedContacts(List<Map<String, String>> contacts) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('No signed-in user found.');
    }

    final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);

    for (final contact in contacts) {
      final phone = contact['phone']!;
      final lookup = await findUserByPhone(phone);

      await userDoc.collection('trustedContacts').add({
        'name': contact['name'],
        'phone': phone,
        'isNotified': true,
        'linkedUserId': lookup.found ? lookup.userId : null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _onPrimaryButtonPressed() async {
    if (!_hasAtLeastOneContact || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      await _saveTrustedContacts(_filledContacts);
      if (!mounted) return;

      if (_fromContacts) {
        // Tell ContactsScreen a save happened so it knows to refresh
        // its list from Firestore.
        Get.back(result: true);
      } else {
        Get.toNamed('/permissions');
      }
    } catch (e) {
      if (!mounted) return;
      Get.snackbar(
        'Could not save contacts',
        'Something went wrong. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF9B2C3A),
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    for (final c in _contacts) {
      c.dispose();
    }
    super.dispose();
  }

  // Builds a labeled input field matching the design:
  // grey label, white rounded field, optional trailing icon.
  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    Widget? trailing,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.fieldLabel,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.fieldFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.fieldBorder),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            onChanged: onChanged,
            style: const TextStyle(fontSize: 16, color: AppColors.title),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppColors.fieldHint),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              suffixIcon: trailing,
            ),
          ),
        ),
      ],
    );
  }

  // A single contact's "Contact name" + "Phone number" fields,
  // with a small remove option once there's more than one contact.
  // The phone field shows a live checkmark once what's typed
  // normalizes into a plausible E.164 number.
  Widget _buildContactCard(int index) {
    final entry = _contacts[index];
    final normalized = normalizePhoneNumber(entry.phoneController.text);
    final isPhoneValid = isPlausiblePhoneNumber(normalized);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (index > 0)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _removeContact(index),
                icon: const Icon(
                  Icons.close,
                  size: 16,
                  color: AppColors.subtitle,
                ),
                label: const Text(
                  'Remove',
                  style: TextStyle(color: AppColors.subtitle, fontSize: 13),
                ),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
              ),
            ),
          _buildField(
            label: 'Contact name',
            hint: 'e.g. Mom, Sara',
            controller: entry.nameController,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          _buildField(
            label: 'Phone number',
            hint: 'e.g. 0300 1234567',
            controller: entry.phoneController,
            keyboardType: TextInputType.phone,
            onChanged: (_) => setState(() {}),
            trailing: isPhoneValid
                ? const Icon(Icons.check, color: AppColors.success, size: 20)
                : null,
          ),
        ],
      ),
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

              // ---- Back (+ step indicator only during onboarding) ----
              Row(
                children: [
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.arrow_back, color: AppColors.title),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  if (!_fromContacts)
                    const Text(
                      'Step 2 of 3',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.subtitle,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 28),

              // ---- Heading ----
              Text(
                'Add a trusted contact',
                style: GoogleFonts.tinos(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.title,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "They'll get your location and recording the moment you send SOS",
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.subtitle,
                  height: 1.35,
                ),
              ),

              const SizedBox(height: 28),

              // ---- Scrollable contact list + add / info banner ----
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < _contacts.length; i++)
                        _buildContactCard(i),

                      // ---- Add another contact (dashed outline) ----
                      _DashedAddContactButton(onTap: _addAnotherContact),

                      const SizedBox(height: 20),

                      // ---- Info banner (only nags during onboarding) ----
                      if (!_fromContacts && !_hasAtLeastOneContact)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.ringColor,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline,
                                size: 18,
                                color: AppColors.primaryPurple,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Add at least one contact to finish setup',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: AppColors.title.withOpacity(0.85),
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ---- Primary button: "Continue" (onboarding) or "Save" (contacts) ----
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: (_hasAtLeastOneContact && !_isSaving)
                      ? _onPrimaryButtonPressed
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    disabledBackgroundColor: AppColors.primaryPurple
                        .withOpacity(0.4),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          _fromContacts ? 'Save' : 'Continue',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dashed-outline "+ Add another contact" button, matching the design.
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
                'Add another contact',
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
  final double dashWidth;
  final double dashGap;
  final double strokeWidth;

  _DashedBorderPainter({
    required this.color,
    this.radius = 12,
    this.dashWidth = 6,
    this.dashGap = 4,
    this.strokeWidth = 1.4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

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
