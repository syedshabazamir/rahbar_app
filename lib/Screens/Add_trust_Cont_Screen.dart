import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rahbar_app/utils/App_colors.dart';

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

class TrustedContactScreen extends StatefulWidget {
  const TrustedContactScreen({super.key});

  @override
  State<TrustedContactScreen> createState() => _TrustedContactScreenState();
}

class _TrustedContactScreenState extends State<TrustedContactScreen> {
  final List<_ContactEntry> _contacts = [_ContactEntry()];

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

  void _onContinuePressed() {
    // TODO: validate + save contacts, then move to step 3 of 3.
    Get.toNamed('/permissions');
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
            ),
          ),
        ),
      ],
    );
  }

  // A single contact's "Contact name" + "Phone number" fields,
  // with a small remove option once there's more than one contact.
  Widget _buildContactCard(int index) {
    final entry = _contacts[index];
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
            hint: '+92',
            controller: entry.phoneController,
            keyboardType: TextInputType.phone,
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

              // ---- Back + step indicator ----
              Row(
                children: [
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.arrow_back, color: AppColors.title),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
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

                      // ---- Info banner ----
                      if (!_hasAtLeastOneContact)
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

              // ---- Continue button ----
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _hasAtLeastOneContact ? _onContinuePressed : null,
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
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
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
