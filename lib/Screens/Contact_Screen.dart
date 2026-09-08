import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rahbar_app/utils/App_colors.dart';
import 'package:rahbar_app/utils/Phone_utils.dart';
import 'package:rahbar_app/widget/bottom_navigation.dart';

/// A single trusted contact shown in the list.
class _Contact {
  final String name;
  final String phone; // always stored normalized (E.164)
  final Color avatarColor;
  bool isNotified;

  _Contact({
    required this.name,
    required String phone,
    required this.avatarColor,
    this.isNotified = false,
  }) : phone = normalizePhoneNumber(phone);

  // Initials shown inside the avatar circle, e.g. "Mom" -> "M",
  // "Sara F." -> "SF".
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
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
  // TODO: replace with the real trusted-contact list, e.g. loaded from
  // what the user entered on the "Add a trusted contact" step / backend.
  // Phone numbers here get normalized to E.164 automatically by the
  // _Contact constructor, no matter what format they're written in below.
  final List<_Contact> _contacts = [
    _Contact(
      name: 'Mom',
      phone: '+92 300 1234567',
      avatarColor: AppColors.primaryPurple,
      isNotified: true,
    ),
    _Contact(
      name: 'Sara F.',
      phone: '0321 7654321', // deliberately a different raw format
      avatarColor: const Color(0xFF5C2F4B),
      isNotified: true,
    ),
    _Contact(
      name: 'Ahmed K.',
      phone: '+92 333 9988776',
      avatarColor: const Color(0xFFA79FA9),
      isNotified: false,
    ),
  ];

  void _toggleNotified(int index) {
    setState(() => _contacts[index].isNotified = !_contacts[index].isNotified);
  }

  Future<void> _onAddContactPressed() async {
    // Tells TrustedContactScreen it's in standalone mode (not onboarding),
    // so it shows "Save" and pops back here instead of going to Permissions.
    final result = await Get.toNamed(
      '/trusted-contact',
      arguments: {'fromContacts': true},
    );

    if (result is List) {
      setState(() {
        for (final item in result) {
          if (item is Map) {
            final name = (item['name'] ?? '').toString();
            final phone = (item['phone'] ?? '').toString();
            if (name.isEmpty) continue;
            // TrustedContactScreen already normalizes the phone before
            // handing it back here, but the _Contact constructor also
            // normalizes — safe either way, since normalizing an
            // already-normalized number is a no-op.
            _contacts.add(
              _Contact(
                name: name,
                phone: phone,
                avatarColor: _nextAvatarColor(),
                isNotified: true,
              ),
            );
          }
        }
      });
    }
  }

  // Cycles through a small palette so newly added contacts get a
  // reasonable-looking avatar color without the user picking one.
  Color _nextAvatarColor() {
    const palette = [
      AppColors.primaryPurple,
      Color(0xFF5C2F4B),
      Color(0xFFA79FA9),
      Color(0xFF7A4E6B),
    ];
    return palette[_contacts.length % palette.length];
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
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
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
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentTab: NavTab.contacts),
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
